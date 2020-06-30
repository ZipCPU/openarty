////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	gpsclock.v
//		
// Project:	A GPS Schooled Clock Core
//
// Purpose:	The purpose of this module is to school a counter, run off of
//		the FPGA's local oscillator, to match a GPS 1PPS signal.  Should
//		the GPS 1PPS vanish, the result will flywheel with its last
//		solution (both frequency and phase) until GPS is available
//		again.
//
//		This approach can be used to measure the speed of the
//		local oscillator, although there may be other more appropriate
//		means to do this.
//
//		Note that this core does not produce anything more than
//		subsecond timing resolution.
//
// Parameters:	This core needs two parameters set below, the DEFAULT_STEP
//		and the DEFAULT_WORD_STEP.  The first must be set to
//		2^RW / (nominal local clock rate), whereas the second must be
//		set to 2^(RW/2) / (nominal clock rate), where RW is the register
//		width used for our computations.  (64 is sufficient for up to
//		4 GHz clock speeds, 56 is minimum for 100 MHz.)  Although
//		RW is listed as a variable parameter, I have no plans to 
//		test values other than 64.  So your mileage might vary there.
//
//		Other parameters, alpha, beta, and gamma are specific to the
//		loop bandwidth you would like to choose.  Please see the
//		accompanying specification for a selection of what values
//		may be useful.
//
// Inputs:
//	i_clk	A synchronous clock signal for all logic.  Must be slow enough
//		that the FPGA can accomplish 64 bit math.
//
//	i_rst	Resets the clock speed / counter step to be the nominal
//		value given by our parameter.  This is useful in case the
//		control loop has gone off into never never land and doesn't
//		seem to be returning.
//
//	i_pps	The 1PPS signal from the GPS chip.
//
//	Wishbone bus
//
// Outputs:	
//	o_led	No circuit would be complete without a properly blinking LED.
//		This one blinks an LED at the top of the GPS 1PPS and the
//		internal 1PPS.  When the two match, the LED will be on for
//		1/16th of a second.  When no GPS 1PPS is present, the LED
//		will blink with a 50% duty cycle.
//
//	o_tracking	A boolean value indicating whether the control loop
//		is open (0) or closed (1).  Does not indicate performance.
//
//	o_count		A counter, from zero to 2^RW-1, indicating the position
//		of the current clock within a second.  (This'll be off by 
//		two clocks due to internal latencies.)
//
//	o_step		The amount the counter, o_count, is stepped each clock.
//		This is related to the actual speed of the oscillator (when
//		locked) by f_XO = 2^(RW) / o_step.
//
//	o_err	For those interested in how well this device is performing,
//		this is the error signal coming out of the device.
//
//	o_locked	Indicates a locked condition.  While it should work,
//		it isn't the best and most versatile lock indicator.  A better
//		indicator should be based upon how good the user wants the
//		lock indicator to be.  This isn't that.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2020, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none
//
//
module	gpsclock(i_clk, i_rst, i_pps, o_pps, o_led,
		i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data, i_wb_sel,
			o_wb_stall, o_wb_ack, o_wb_data,
		o_tracking, o_count, o_step, o_err, o_locked, o_dbg);
	parameter [31:0] DEFAULT_STEP = 32'h834d_c736;//2^64/81.25 MHz
	parameter	RW=64, // Needs to be 2ceil(Log_2(i_clk frequency))
			DW=32, // The width of our data bus
			ONE_SECOND = 0,
			NPW=RW-DW, // Width of non-parameter data
			HRW=RW/2; // Half of RW
	input	wire	i_clk, i_rst;
	input	wire	i_pps;	// From the GPS device
	output	reg	o_pps;	// To our local circuitry
	output	reg	o_led;	// A blinky light showing how well we're doing
	// Wishbone Configuration interface
	input	wire			i_wb_cyc, i_wb_stb, i_wb_we;
	input	wire	[1:0]		i_wb_addr;
	input	wire	[(DW-1):0]	i_wb_data;
	input	wire	[(DW/8-1):0]	i_wb_sel;
	output	wire			o_wb_stall;
	output	reg			o_wb_ack;
	output	reg	[(DW-1):0]	o_wb_data;
	// Status and timing outputs
	output	reg			o_tracking; // 1=closed loop, 0=open
	output	reg	[(RW-1):0]	o_count, // Fraction of a second
					o_step, // 2^RW / clock speed (in Hz)
					o_err; // Fraction of a second err
	output	reg			o_locked; // 1 if Locked, 0 o.w.
	output	wire	[1:0]		o_dbg;


	// Clock resynchronization variables
	reg	pps_d, ck_pps, lst_pps;
	wire	tick;		// And a variable indicating the top of GPS 1PPS

	//
	// Configuration variables.  These control the loop bandwidth, the speed
	// of convergence, the speed of adaptation to changes, and more.  If
	// you adjust these outside of what the specification recommends, 
	// be careful that the control loop still synchronizes!
	reg			new_config;
	reg	[5:0]		r_alpha;
	reg	[(DW-1):0]	r_beta, r_gamma, r_def_step;
	reg	[(RW-1):0]	pre_step;

	//
	// This core really operates rather slowly, in FPGA time.  Of the
	// millions of ticks per second, we only do things on about less than
	// a handful.  These timing signals below help us to determine when
	// our data is valid during those handful.
	//
	// Timing
	reg	err_tick, shift_tick, mpy_aux, mpy_sync_two,
		delay_step_clk, step_carry_tick;
	wire	sub_tick, fltr_tick;

	//
	// When tracking, each second we'll produce a lowpass filtered_err
	// (via a recursive average), a count_correction and a step_correction.
	// The two _correction terms then get applied at the top of the second.
	// Here's the declaration of those parameters.  The
	// 'pre_count_correction' parameter allows us to avoid adding three
	// 64-bit numbers in a single clock, splitting part of that amount into
	// an earlier clock.
	//
	// Tracking
	reg			config_filter_errors;
	reg	[(RW-1):0]	pre_count_correction, r_count_correction,
				r_filtered_err;
	wire	[(RW-1):0]	count_correction;
	reg	[(HRW-1):0]	step_correction;
	reg	[(HRW-1):0]	delayed_step_correction, delayed_step;
	reg	signed [(HRW-1):0]	mpy_input;
	wire		[(RW-1):0]	w_mpy_out;
	wire	signed [(RW-1):0]	filter_sub_count, filtered_err;

	wire	[1:0]	wb_addr;
	wire	[31:0]	wb_data;
	reg		wb_write;
	reg	[1:0]	r_wb_addr;
	reg	[31:0]	r_wb_data;
	reg	[7:0]	lost_ticks;
	reg		dly_config;
	wire		w_tick_enable;
	reg	[31:0]	tick_enable_counter;
	reg		tick_enable_carry;
	reg	cnt_carry;
	reg	[31:0]	p_count;
	reg	[(HRW):0]	step_correction_plus_carry;
	wire	w_step_correct_unused;
	wire	[(RW-1):0]	new_step;
	reg	delayed_carry;
	reg	signed [(RW-1):0] shift_hi, shift_lo;
	reg	[(RW-1):0]	r_mpy_err;
	reg	no_pulse;
	reg	[32:0]	time_since_pps;
	reg	[2:0]	count_valid_ticks;



	//
	//
	//
	// Wishbone access ... adjust our tracking parameters
	//
	//
	//
	// DEFAULT_STEP = 64'h0000_0034_dc73_67da, // 2^64 / 81.25 MHz
	//    = 28'hd371cd9 << (20-10), and hence we have 32'had37_1cd9
	// Other useful values:
	//	32'had6bf94d	//  80MHz
	//	32'haabcc771	// 100MHz
	//	32'hbd669d0e	// 160.5MHz
	initial	r_def_step = DEFAULT_STEP;
	always @(posedge i_clk)
		pre_step <= { 16'h00,
			(({ r_def_step[27:0], 20'h00 })>>r_def_step[31:28])};

	// Delay writes by one clock

	initial	lost_ticks = 0;
	always @(posedge i_clk)
		wb_write <= (i_wb_stb)&&(i_wb_we);
	always @(posedge i_clk)
		r_wb_data <= i_wb_data;
	always @(posedge i_clk)
		r_wb_addr <= i_wb_addr;
	assign	wb_data = r_wb_data;
	assign	wb_addr = r_wb_addr;

	initial	config_filter_errors = 1'b1;
	initial	r_alpha = 6'h2;
	initial	r_beta  = 32'h14bda12f;
	initial	r_gamma = 32'h1f533ae8;
	initial	new_config = 1'b0;
	always @(posedge i_clk)
	if (wb_write)
	begin
		new_config <= 1'b1;
		case(wb_addr)
		2'b00: begin
			r_alpha    <= wb_data[5:0];
			config_filter_errors <= (wb_data[5:0] != 6'h0);
			end
		2'b01: r_beta     <= wb_data;
		2'b10: r_gamma    <= wb_data;
		2'b11: r_def_step <= wb_data;
		// default: begin end
		// r_defstep <= i_wb_data;
		endcase
	end else
		new_config <= 1'b0;

	always @(posedge i_clk)
	case (i_wb_addr)
	2'b00: o_wb_data <= { lost_ticks, 18'h00, r_alpha };
	2'b01: o_wb_data <= r_beta;
	2'b10: o_wb_data <= r_gamma;
	2'b11: o_wb_data <= r_def_step;
	// default: o_wb_data <= 0;
	endcase

	initial	dly_config = 1'b0;
	always @(posedge i_clk)
		dly_config <= new_config;

	initial	o_wb_ack = 1'b0;
	always @(posedge i_clk)
		o_wb_ack <= i_wb_stb;

	assign	o_wb_stall = 1'b0;
	

	//
	//
	// Deal with the realities of an unsynchronized 1PPS signal: 
	// register it with two flip flops to avoid metastability issues.
	// Create a 'tick' variable to note the top of a second.
	//
	//
	always @(posedge i_clk)
	begin // This will delay our resulting time by a known 2 clock ticks
		pps_d <= i_pps;
		ck_pps <= pps_d;
		lst_pps <= ck_pps;
	end

	// Provide a touch of debounce protection ... equal to about
	// one quarter of a second.  This is a coarse predictor, however,
	// since it uses only the top 32-bits of the step.
	//
	// Here's the idea: on any tick, we start a 32-bit counter, stepping
	// unevenly by o_step[61:30] at each tick.  Once the counter crosses
	// zero, we stop counting and we enable the clock tick.  Since the
	// counter should overflow 4x per second (assuming our clock rate is
	// less than 16GHz), we should be good to go.  Oh, and we also round
	// our step up by one ... to guarantee that we always end earlier than
	// designed, rather than ever later.
	//
	initial	tick_enable_carry   = 0;
	initial	tick_enable_counter = 0;
	always @(posedge i_clk)
	begin
		if ((ck_pps)&&(~lst_pps))
			{ tick_enable_carry, tick_enable_counter } <= 0;
		else if (tick_enable_carry)
			tick_enable_counter <= 32'hffff_ffff;
		else
			{tick_enable_carry, tick_enable_counter}
				<= o_step[(RW-3):(RW-34)]
					+ tick_enable_counter + 1'b1;
	end
	assign	w_tick_enable = tick_enable_carry;

	assign	tick= (ck_pps)&&(~lst_pps)&&(w_tick_enable);
	always @(posedge i_clk)
		if (wb_write)
			lost_ticks <= 8'h00;
		else if ((ck_pps)&&(~lst_pps)&&(!w_tick_enable))
			lost_ticks <= lost_ticks+1'b1;
	assign	o_dbg[0] = tick;
	assign	o_dbg[1] = w_tick_enable;

	//
	//
	// Here's our counter proper: Add o_step to o_count each clock tick
	// to have a current time value.  Corrections are applied at the top
	// of the second if we are in tracking mode.  The 'o_pps' signal is
	// generated from the carry/overflow of the o_count addition.
	//
	// The output of this loop, both o_pps and o_count, is the current
	// subsecond time as determined by this clock.
	//
	//
	initial	o_count = 0;
	initial	o_pps = 1'b0;
	always @(posedge i_clk)
`ifndef USE_THE_OLD_CODE
		begin
		// Very simple: we add the count correction, which is given by
		// a pre-determined sum of the step and any error, to our
		// "count" at every clock tick.  If this ever overflows, the
		// overflow or carry is our PPS signal.  Unlike the last time
		// we built this logic, here we acknowledge that the count
		// correction can never be negative.  As a result, we have no
		// o_pps suppression.
		{ cnt_carry, p_count } <= p_count[31:0] + r_count_correction[31:0];
		{ o_pps, o_count[63:32] } <= o_count[63:32]
				+ r_count_correction[63:32]
				+ { 31'h00, cnt_carry };
		if (r_count_correction[(RW-1)])
			o_pps <= 1'b0;
		// Delay the bottom bits of o_count by one clock, so that they
		// now match up with the top bits.
		o_count[31:0] <= p_count;
		end
`else
		if ((o_tracking)&&(tick))
		begin
			// Save the carry to be applied at the next clock, so
			// that we never have to do more than a 32-bit add.
			// (well, okay, a 33-bit add ...)
			//
			// The count_correction value here is really our step,
			// plus a value determined from our filter loop.
			{ cnt_carry, p_count }
			   <= p_count[31:0] + count_correction[31:0];
			//
			// On the second clock, we add the high order bits
			// together, and possibly get a carry.  We use this
			// carry as our o_pps output.
			if (~count_correction[(RW-1)])
			begin
				// Here, we need to correct by jumping forward.
				//
				// Note that we don't create an o_pps just
				// because the gps_pps states that there should
				// be one.  Instead, we hold to the normal
				// means of business.  At the tick, however,
				// we add both the step and the correction to
				// the current count.
				{ o_pps, o_count[63:32] } <= o_count[63:32]
					+ count_correction[63:32]
					+ { 31'h00, cnt_carry };
			end else begin
				// If the count correction is negative, it means
				// we need to go backwards.  In this case,
				// there shouldn't be any o_pps, least we get
				// two of them.  So ... we skip an output PPS,
				// knowing the correct PPS is coming next.
				o_pps <= 1'b0;
				o_count[63:32] <= o_count[63:32]
						+ count_correction[63:32]
					+ { 31'h00, cnt_carry };
			end
		end else begin
			// The difference between count_correction and
			// o_step is the phase correction from the last tick.
			// If we aren't tracking, we don't want to use the
			// correction.  Likewise, even if we are, we only
			// want to use it on the ticks.
			{ cnt_carry, p_count } <= p_count + o_step[31:0];
			{ o_pps, o_count[63:32] } <= o_count[63:32]
						+ o_step[63:32]
						+ { 31'h00, cnt_carry};
		end

	// Here we delay the bottom bits of o_count by one clock, so that they
	// now match up with the top bits.
	always @(posedge i_clk)
		o_count[31:0] <= p_count;
`endif



	//
	// The step
	//
	// The counter above is only as good as the step size given to it.
	// Here, we work with that step size, and apply a correction based
	// upon the last tick.  The idea in the step correction is that we
	// wish to add this step correction to our step amount.  We have one
	// clock tick (i.e. one second) from when we make our error measurement
	// until we must apply the correction.
	//
	// The correction, calculated far below, will be placed into the value
	//
	//	step_correction
	//
	// We just need to figure out what the new step will be here, given
	// that correction.
	//
	always @(posedge i_clk)
		if (step_carry_tick)
			step_correction_plus_carry
				<= { step_correction[(HRW-1)],step_correction }
					+ { 32'h00, delayed_carry };


	bigadd	getnewstep(i_clk, 1'b0, o_step,
			{ { (HRW-1){step_correction_plus_carry[HRW]} }, 
				step_correction_plus_carry},
			new_step, w_step_correct_unused);

	initial	delayed_carry = 0;

	initial	o_step = { 16'h00, (({ DEFAULT_STEP[27:0], 20'h00 })
				>> DEFAULT_STEP[31:28])};
	always @(posedge i_clk)
		if ((i_rst)||(dly_config))
			o_step <= pre_step;
		else if ((o_tracking) && (tick))
			 o_step <= new_step;

	initial	delayed_step = 0;
	always @(posedge i_clk)
		if ((i_rst)||(dly_config))
			{ delayed_carry, delayed_step } <= 0;
		else if (delay_step_clk)
			{ delayed_carry, delayed_step } <= delayed_step
					+ delayed_step_correction;
		


	//
	//
	// Now to start our tracking loop.  The steps are:
	//	1. Measure our error
	//	2. Filter our error (lowpass, recursive averager)
	//	3. Multiply the filtered error by two user-supplied constants
	//		(beta and gamma)
	//	4. The results of this multiply then become the new
	//		count and step corrections.
	//
	//
	// A negative error means we were too fast ... the count rolled over
	// and is near zero, the o_err is then the negation of this when the
	// tick does show up.
	//

	// Note that our measured error, o_err, will be valid one tick *after*
	// the top of the second tick (tick).
	//
	// ONE_SECOND in this equation is set to 2^64, or zero during
	// implementation.  This makes the 64-bit subtract ... doable.
	initial	o_err = 0;
	always @(posedge i_clk)
		if (tick)
			o_err <= ONE_SECOND - o_count;

	// Because o_err is delayed one clock from the tick, we create a strobe
	// capturing when the error is valid.
	initial	err_tick = 1'b0;
	always @(posedge i_clk)
		err_tick <= tick;

	//
	// We are now going to filter this error, via:
	//
	//	filtered_err <= o_err>>r_alpha + (1-1>>r_alpha)*filtered_err
	//
	// This implements a very simple recursive averager.
	//
	// You may not recognize it below, though, since we have simplified the
	// equation into:
	//
	//	filtered_err <= filtered_err + (o_err - filtered_err)>>r_alpha
	//

	// On some architectures, adding and subtracting 64'bit number cannot
	// be done in a single clock tick.  On these architectures, we may
	// take a couple clocks.  Here, the "bigsub" module captures what it 
	// takes to subtract 64-bit numbers.
	//
	// Either way, here we subtract our error from our filtered_err.  This
	// is the first step of the recursive average--figuring out what value
	// we are going to apply to the recursive average.
	bigsub	suberri(i_clk, err_tick, o_err,
			filtered_err, filter_sub_count, sub_tick);

	//
	// This shouldn't be required: We only want to shift our 
	// filter_sub_count by r_alpha bits, why the extra struggles?
	// Why is because Verilator decides that these values are unsigned,
	// and so despite being told that they are signed values, verilator
	// doesn't sign extend them upon shifting.  Put together,
	// { shift_hi[low-bits], shift_lo[low-bits] } make up a full RW (i.e.64)
	// bit correction factor.
	always @(posedge i_clk)
	begin
		shift_tick<= sub_tick;

		// Because we do our add (below) on *every* clock tick, we must
		// make certain that the value we add to it is only non-zero
		// on one clock tick.  Hence, we wait for sub_tick to be true,
		// set the value, and otherwise keep it clear.
		if (sub_tick)
		begin
			shift_hi <= { {(HRW){filter_sub_count[(RW-1)]}},
				filter_sub_count[(RW-1):HRW] }>>r_alpha;
			shift_lo <= filter_sub_count[(RW-1):0]>>r_alpha;
		end else begin
			shift_hi <= 0;
			shift_lo <= 0;
		end
	end

	// You may notice, it's now been several clocks since the top of the
	// second.  Still, filtered_err hasn't changed.  It only changes once
	// a second based upon the results of these computations.  Here we take
	// another clock (or two) to figure out the next step in our algorithm.
	bigadd adderr(i_clk, shift_tick, r_filtered_err,
			{ shift_hi[(HRW-1):0], shift_lo[(HRW-1):0] },
			filtered_err, fltr_tick);

	always @(posedge i_clk)
		if (fltr_tick)
			r_filtered_err <= filtered_err;
		else if ((dly_config)||(!o_tracking))
			r_filtered_err <= 0;

	always @(posedge i_clk)
		if (err_tick)
		r_mpy_err <= (config_filter_errors) ? r_filtered_err : o_err;

	// Okay, so we've gone from our original tick to the err_tick, the
	// sub_tick, the shift_tick, and now the fltr_tick. 
	//
	// We want to multiply our filtered error by one of two constants.
	// Here, we set up those constants.  We use the fltr_tick as a strobe,
	// but also to select one particular constant.  When the multiply comes
	// back, and the strobe is true, we'll know that the constant going
	// in with the strobe on (r_beta) corresponds to the product coming out,
	// and that the second product we need will be on the next clock.
	always @(posedge i_clk)
		if (err_tick)
			mpy_input <= r_beta;
		else
			mpy_input <= r_gamma;
	always @(posedge i_clk)
		mpy_aux <= err_tick;

	//
	// The multiply
	//
	// Remember, we take our filtered error and multiply it by a constant
	// to determine our step correction and another constant to determine
	// our count correction?  We'll ... here's that multiply.
	//
	wire			mpy_sync;
	initial	mpy_sync_two = 1'b0;
	// Sign extend all inputs to RW bits
	wire	signed	[(RW-1):0]	w_mpy_input, w_mpy_err;
	assign	w_mpy_input = { {(RW-DW){mpy_input[(DW-1)]}},
						mpy_input[(DW-1):0]};
	assign	w_mpy_err   = { {(RW-NPW){r_mpy_err[(RW-1)]}},
						r_mpy_err[(RW-1):(RW-NPW)]};
	//
	// Here's our big multiply.
	//
	bigsmpy #(.NCLOCKS(1))
		mpyi(i_clk, mpy_aux, 1'b1, w_mpy_input[31:0], w_mpy_err[31:0],
			w_mpy_out, mpy_sync);

	// We use this to grab the second product from the multiply.  This
	// second product is true the clock after mpy_sync is high, so we
	// just do a simple delay to get this strobe logic.
	always @(posedge i_clk)
		mpy_sync_two <= mpy_sync;


	// The post-multiply
	//
	// Remember, the mpy_sync line coming out of the multiply will be true
	// when the product of the error and i_beta comes out.
	//
	initial	pre_count_correction    = 0;
	initial	step_correction         = 0;
	initial	delayed_step_correction = 0;
	always @(posedge i_clk)
		if (mpy_sync)	// i_beta product
			pre_count_correction <= w_mpy_out;
	always @(posedge i_clk)
		if (mpy_sync_two) begin // i_gamma product
			step_correction <= w_mpy_out[(RW-1):HRW];
			delayed_step_correction <= w_mpy_out[(HRW-1):0];
		end

	// The correction for the number of counts in our counter is given
	// by pre_count_correction.  When we add this to the counter, we'll
	// need to add the step to it as well.  To help timing out with 64-bit
	// math, let's do that step+correction math here, so that we can later
	// do 
	//	counts = counts + count_correction
	// instead of
	//	counts = counts + step + pre_count_correction
	// saves us one addition--especially since we have the clock to do this.
	wire	count_correction_strobe;
	bigadd	ccounts(i_clk, mpy_sync_two, o_step, pre_count_correction, 
			count_correction, count_correction_strobe);

	// Our original plan was to apply this correction at the top of the
	// second.  The problem is that our loop filter math depends upon this
	// correction being applied before the top of the second error gets
	// measured.  Hence, we'll apply it at some time mid-second, not
	// long after the error is measured (w/in 16 clocks or so), and never
	// notice the difference until the top of the next second where it 
	// now appears to have properly taken place.
	always @(posedge i_clk)
		if (count_correction_strobe)
			r_count_correction <= count_correction;
		else
			r_count_correction <= o_step;

	initial	delay_step_clk = 1'b0;
	always @(posedge i_clk)
		delay_step_clk <= mpy_sync_two;
	initial	step_carry_tick = 1'b0;
	always @(posedge i_clk)
		step_carry_tick <= delay_step_clk;

	//
	//
	// LED Logic -- Note that this is where we tell if we've had a GPS
	// 1PPS pulse or not.  To have had such a pulse, it needs to have
	// been within the last two seconds.
	//
	//
	initial	no_pulse = 1'b1;
	initial	time_since_pps = 33'hffffffff;
	always @(posedge i_clk)
		if (tick)
		begin
			time_since_pps <= 0;
			no_pulse <= 0;
		end else if (time_since_pps[32:29] == 4'hf)
		begin
			time_since_pps <= 33'hffffffff;
			no_pulse <= 1'b1;
		end else
			time_since_pps <= time_since_pps + pre_step[(RW-1):HRW];

	//
	// 1. Pulse with a 50% duty cycle every second if no GPS is available.
	// 2. Pulse with a 6% duty cycle any time a pulse is present, and any
	//      time we think (when a pulse is present) that we have time.
	//
	// This should produce a set of conflicting pulses when out of lock,
	// and a nice short once per second pulse when locked.  Further, you
	// should be able to tell when the core is flywheeling by the duration
	// of the pulses (50% vs 6%).
	//
	always @(posedge i_clk)
		if (no_pulse)
			o_led <= o_count[(RW-1)];
		else
			o_led <= ((time_since_pps[31:28] == 4'h0)
				||(o_count[(RW-1):(RW-4)]== 4'h0));

	//
	//
	// Now, are we tracking or not?
	// We'll attempt to close the loop after seeing 7 valid GPS 1PPS
	// rising edges.
	//
	//
	initial	count_valid_ticks = 3'h0;
	always @(posedge i_clk)
		if ((tick)&&(count_valid_ticks < 3'h7))
			count_valid_ticks <= count_valid_ticks+1;
		else if (no_pulse)
			count_valid_ticks <= 3'h0;
	initial	o_tracking = 1'b0;
	always @(posedge i_clk)
		if (dly_config) // Break the tracking loop on a config change
			o_tracking <= 1'b0;
		else if ((tick)&&(&count_valid_ticks))
			o_tracking <= 1'b1;
		else if ((tick)||(count_valid_ticks == 0))
			o_tracking <= 1'b0;

	//
	//
	// Are we locked or not?
	// We'll use the top eight bits of our error to tell.  If the top eight
	// bits are all ones or all zeros, then we'll call ourselves locked.
	// This is equivalent to calling ourselves locked if, at the top of
	// the second, we are within 1/128th of a second of the GPS 1PPS.
	//
	initial	o_locked = 1'b0;
	always @(posedge i_clk)
		if ((o_tracking)&&(tick)&&(
			((   o_err[(RW-1)])&&(o_err[(RW-1):(RW-8)]==8'hff))
			||((~o_err[(RW-1)])&&(o_err[(RW-1):(RW-8)]==8'h00))))
			o_locked <= 1'b1;
		else if (tick)
			o_locked <= 1'b0;

	// Make verilator happy
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, shift_hi[63:32], shift_lo[63:32], w_mpy_input[63:32], w_mpy_err[63:32], i_wb_cyc, i_wb_sel };
	// verilator lint_on  UNUSED
endmodule

