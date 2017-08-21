////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rtcgps.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Implement a real time clock, including alarm, count--down
//		timer, stopwatch, variable time frequency, and more.
//
//	This particular version has hooks for a GPS 1PPS, as well as a 
//	finely tracked clock speed output, to allow for fine clock precision
//	and good freewheeling even if/when GPS is lost.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2017, Gisselquist Technology, LLC
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
module	rtcgps(i_clk, 
		// Wishbone interface
		i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data,
		//	o_wb_ack, o_wb_stb, o_wb_data, // no reads here
		// Output registers
		o_data, // multiplexed based upon i_wb_addr
		// Output controls
		o_interrupt,
		// A once-per-day strobe on the last clock of the day
		o_ppd,
		// GPS interface
		i_gps_valid, i_gps_pps, i_gps_ckspeed,
		// Our personal timing, for debug purposes
		o_rtc_pps);
	parameter	DEFAULT_SPEED = 32'd2814750; //2af31e = 2^48 / 100e6 MHz
	//
	input	wire		i_clk;
	//
	input	wire		i_wb_cyc, i_wb_stb, i_wb_we;
	input	wire	[1:0]	i_wb_addr;
	input	wire	[31:0]	i_wb_data;
	// input		i_btn;
	output	reg	[31:0]	o_data;
	output	wire		o_interrupt, o_ppd;
	// GPS interface
	input	wire		i_gps_valid, i_gps_pps;
	input	wire	[31:0]	i_gps_ckspeed;
	// Personal PPS
	output	wire		o_rtc_pps;

	reg	[21:0]	clock;
	reg	[31:0]	stopwatch, ckspeed;
	reg	[25:0]	timer;
	
	reg	ck_wr, tm_wr, sw_wr, al_wr, r_data_zero_byte;
	reg	[25:0]	r_data;
	always @(posedge i_clk)
	begin
		ck_wr <= ((i_wb_stb)&&(i_wb_addr==2'b00)&&(i_wb_we));
		tm_wr <= ((i_wb_stb)&&(i_wb_addr==2'b01)&&(i_wb_we));
		sw_wr <= ((i_wb_stb)&&(i_wb_addr==2'b10)&&(i_wb_we));
		al_wr <= ((i_wb_stb)&&(i_wb_addr==2'b11)&&(i_wb_we));
		r_data <= i_wb_data[25:0];
		r_data_zero_byte <= (i_wb_data[7:0] == 8'h00);
	end

	reg	[39:0]	ck_counter;
	reg		ck_carry, ck_sub_carry;
	always @(posedge i_clk)
		if ((i_gps_valid)&&(i_gps_pps))
		begin
			ck_carry   <= 0;
			// Start our counter 2 clocks into the future.
			// Why?  Because if we hit the PPS, we'll be delayed
			// one clock from true time.  This (hopefully) locks
			// us back onto true time.  Further, if we end up
			// off (i.e., go off before the GPS tick ...) then
			// the GPS tick will put us back on track ... likewise
			// we've got code following that should keep us from
			// ever producing two PPS's per second.
			ck_counter <= { 7'h00, ckspeed, 1'b0 };
			ck_sub_carry <= ckspeed[31];
		end else begin
			{ ck_sub_carry, ck_counter[31:0] }
				<= ck_counter[31:0] + ckspeed;
			{ ck_carry, ck_counter[39:32] }
				<= ck_counter[39:32] + { 7'h0, ck_sub_carry };
		end

	reg		ck_pps;
	reg		ck_ppm, ck_pph, ck_ppd;
	reg	[7:0]	ck_sub;
	initial	clock = 22'h00000000;
	always @(posedge i_clk)
		if ((i_gps_pps)&&(i_gps_valid)&&(ck_sub[7]))
			ck_pps <= 1'b1;
		else if ((ck_carry)&&(ck_sub == 8'hff))
			ck_pps <= 1'b1;
		else
			ck_pps <= 1'b0;

	reg	[6:0]	next_clock_secs;
	always @(posedge i_clk)
	begin
		next_clock_secs[3:0] <= (clock[3:0] >= 4'h9) ? 4'h0 // clk 1
						: (clock[3:0] + 4'h1);
		next_clock_secs[6:4] <= (ck_ppm) ? 3'h0 // clk 2
					: (clock[3:0] >= 4'h9)
						? (clock[6:4] + 3'h1)
						: clock[6:4];
	end

	reg	[6:0]	next_clock_mins;
	always @(posedge i_clk)
	begin
		next_clock_mins[3:0] <= (clock[11:8] >= 4'h9) ? 4'h0
						: (clock[11:8] + 4'h1);
		next_clock_mins[6:4] <= (ck_pph) ? 3'h0
					: (clock[11:8] >= 4'h9)
						? (clock[14:12] + 3'h1)
						: clock[14:12];
	end

	reg	[5:0]	next_clock_hrs;
	always @(posedge i_clk)
	begin
		next_clock_hrs[3:0] <= (clock[19:16] >= 4'h9) ? 4'h0
						: (clock[19:16] + 4'h1);
		next_clock_hrs[5:4] <= (ck_ppd) ? 2'h0
					: (clock[19:16] >= 4'h9)
						? (clock[21:20] + 2'h1)
						: (clock[21:20]);
	end

	reg	[4:0] ck_pending;
	assign	o_rtc_pps = ck_pps;
	always @(posedge i_clk)
	begin
		if ((i_gps_valid)&&(i_gps_pps))
			ck_sub <= 0;
		else if (ck_carry)
			ck_sub <= ck_sub + 1;

		if ((ck_pps)&&(~ck_pending[4])) // advance the seconds
			clock[6:0] <= next_clock_secs;
		clock[7] <= 1'b0;
		ck_ppm <= (clock[6:0] == 7'h59);

		if ((ck_pps)&&(ck_ppm)&&(~ck_pending[4])) // advance the minutes
			clock[14:8] <= next_clock_mins;
		clock[15] <= 1'b0;
		ck_pph <= (clock[14:8] == 7'h59)&&(ck_ppm);

		if ((ck_pps)&&(ck_pph)&&(~ck_pending[4])) // advance the hours
			clock[21:16] <= next_clock_hrs;
		ck_ppd <= (clock[21:16] == 6'h23)&&(ck_pph);

		clock[ 7] <= 1'b0;
		clock[15] <= 1'b0;

		if (ck_wr)
		begin
			if (~r_data[7])
				clock[6:0] <= i_wb_data[6:0];
			if (~r_data[15])
				clock[14:8] <= i_wb_data[14:8];
			if (~r_data[22])
				clock[21:16] <= i_wb_data[21:16];
			if ((~i_gps_valid)&&(r_data_zero_byte))
				ck_sub <= 8'h00;
			ck_pending <= 5'h1f;
		end else
			ck_pending <= { ck_pending[3:0], 1'b0 };
	end

	reg	[21:0]	ck_last_clock;
	always @(posedge i_clk)
		ck_last_clock <= clock[21:0];



	// 
	reg	[23:0]	next_timer;
	reg		ztimer;
	reg	[4:0]	tmr_carry;
	always @(posedge i_clk)
	begin
		tmr_carry[0] <= (timer[ 3: 0]== 4'h0);
		tmr_carry[1] <= (timer[ 6: 4]== 3'h0)&&(tmr_carry[0]);
		tmr_carry[2] <= (timer[11: 8]== 4'h0)&&(tmr_carry[1]);
		tmr_carry[3] <= (timer[14:12]== 3'h0)&&(tmr_carry[2]);
		tmr_carry[4] <= (timer[19:16]== 4'h0)&&(tmr_carry[3]);
		ztimer <= (timer[23:0]== 24'h0);

		// Keep unused bits at zero
		next_timer <= 24'h00;
		// Seconds
		next_timer[ 3: 0] <= (tmr_carry[0])? 4'h9: (timer[ 3: 0]-4'h1);
		next_timer[ 6: 4] <= (tmr_carry[1])? 3'h5: (timer[ 6: 4]-3'h1);
		// Minutes
		next_timer[11: 8] <= (tmr_carry[2])? 4'h9: (timer[11: 8]-4'h1);
		next_timer[14:12] <= (tmr_carry[3])? 3'h5: (timer[14:12]-3'h1);
		// Hours
		next_timer[19:16] <= (tmr_carry[4])? 4'h9: (timer[19:16]-4'h1);
		next_timer[23:20] <= (timer[23:20]-4'h1);
	end

	reg	new_timer, new_timer_set, new_timer_last;
	reg	[23:0]	new_timer_val;

	reg	tm_pps, tm_int;
	wire	tm_stopped, tm_running, tm_alarm;
	assign	tm_stopped = ~timer[24];
	assign	tm_running =  timer[24];
	assign	tm_alarm   =  timer[25];
	reg	[23:0]		tm_start;
	reg	[7:0]		tm_sub;
	initial	tm_start = 24'h00;
	initial	timer    = 26'h00;
	initial	tm_int   = 1'b0;
	initial	tm_pps   = 1'b0;
	always @(posedge i_clk)
	begin
		if (ck_carry)
		begin
			tm_sub <= tm_sub + 1;
			tm_pps <= (tm_sub == 8'hff);
		end else
			tm_pps <= 1'b0;
		
		if (new_timer_set) // Conclude a write
			timer[23:0] <= new_timer_val;
		else if ((~tm_alarm)&&(tm_running)&&(tm_pps))
		begin // Otherwise, if we are running ...
			timer[25] <= 1'b0; // Clear any alarm
			if (ztimer) // unless we've hit zero
				timer[25] <= 1'b1;
			else if (~new_timer)
				timer[23:0] <= next_timer;
		end

		tm_int <= (tm_running)&&(tm_pps)&&(~tm_alarm)&&(ztimer);

		if (tm_alarm) // Stop the timer on an alarm
			timer[24] <= 1'b0;

		new_timer <= 1'b0;
		if ((tm_wr)&&(tm_running)) // Writes while running
			// Only allow the timer to stop, nothing more
			timer[24] <= r_data[24];
		else if ((tm_wr)&&(tm_stopped)) // Writes while off
		begin
			// We're going to pipeline this change by a couple
			// of clocks, to get it right
			new_timer <= 1'b1;
			new_timer_val <= r_data[23:0];

			// Still ... any write clears the alarm
			timer[25] <= 1'b0;
		end

		new_timer_set  <= (new_timer)&&(new_timer_val != 24'h000);
		new_timer_last <= (new_timer)&&(new_timer_val == 24'h000);
		if (new_timer_last)
		begin
			new_timer_val <= tm_start;
			tm_sub <= 8'h00;
			new_timer_set <= 1'b1;
		end else if (new_timer_set)
		begin
			tm_start <= new_timer_val;
			tm_sub <= 8'h00;
			timer[24] <= 1'b1;
		end
	end

	//
	// Stopwatch functionality
	//
	// Setting bit '0' starts the stop watch, clearing it stops it.
	// Writing to the register with bit '1' high will clear the stopwatch,
	// and return it to zero provided that the stopwatch is stopped either
	// before or after the write.  Hence, writing a '2' to the device
	// will always stop and clear it, whereas writing a '3' to the device
	// will only clear it if it was already stopped.
	reg	[6:0]	next_sw_secs;
	always @(posedge i_clk)
	begin
		next_sw_secs[3:0] <= (stopwatch[11:8] >= 4'h9) ? 4'h0
						: (stopwatch[11:8] + 4'h1);
		next_sw_secs[6:4] <= (stopwatch[14:8] == 7'h59) ? 3'h0
					: (stopwatch[11:8] == 4'h9)
						? (stopwatch[14:12]+3'h1)
						: stopwatch[14:12];
	end

	reg	[6:0]	next_sw_mins;
	always @(posedge i_clk)
	begin
		next_sw_mins[3:0] <= (stopwatch[19:16] >= 4'h9) ? 4'h0
						: (stopwatch[19:16] + 4'h1);
		next_sw_mins[6:4] <= (stopwatch[22:16] == 7'h59) ? 3'h0
					: (stopwatch[19:16]==4'h9)
						? (stopwatch[22:20]+3'h1)
						: stopwatch[22:20];
	end

	reg	[5:0]	next_sw_hrs;
	always @(posedge i_clk)
	begin
		next_sw_hrs[3:0] <= (stopwatch[27:24] >= 4'h9) ? 4'h0
						: (stopwatch[27:24] + 4'h1);
		next_sw_hrs[5:4] <= (stopwatch[29:24] >= 6'h23) ? 2'h0
					: (stopwatch[27:24]==4'h9)
						? (stopwatch[29:28]+2'h1)
						: stopwatch[29:28];
	end

	reg		sw_pps, sw_ppm, sw_pph;
	reg	[7:0]	sw_sub;
	wire	sw_running;
	assign	sw_running = stopwatch[0];
	initial	stopwatch = 32'h00000;
	always @(posedge i_clk)
	begin
		sw_pps <= 1'b0;
		if ((sw_running)&&(ck_carry))
		begin
			sw_sub <= sw_sub + 1;
			sw_pps <= (sw_sub == 8'hff);
		end

		stopwatch[7:1] <= sw_sub[7:1];

		if (sw_pps) // Second hand
			stopwatch[14:8] <= next_sw_secs;
		sw_ppm <= (stopwatch[14:8] == 7'h59);

		if ((sw_pps)&&(sw_ppm)) // Minutes
			stopwatch[22:16] <= next_sw_mins;
		sw_pph <= (stopwatch[23:16] == 8'h59)&&(sw_ppm);

		if ((sw_pps)&&(sw_pph)) // And hours
			stopwatch[29:24] <= next_sw_hrs;

		if (sw_wr)
		begin
			stopwatch[0] <= r_data[0];
			if((r_data[1])&&((~stopwatch[0])||(~r_data[0])))
			begin
				stopwatch[31:1] <= 31'h00;
				sw_sub <= 8'h00;
				sw_pps <= 1'b0;
				sw_ppm <= 1'b0;
				sw_pph <= 1'b0;
			end
		end
	end

	//
	// The alarm code
	//
	// Set the alarm register to the time you wish the board to "alarm".
	// The "alarm" will take place once per day at that time.  At that
	// time, the RTC code will generate a clock interrupt, and the CPU/host
	// can come and see that the alarm tripped.
	//
	// 
	reg	[21:0]		alarm_time;
	reg			al_int,		// The alarm interrupt line
				al_enabled,	// Whether the alarm is enabled
				al_tripped;	// Whether the alarm has tripped
	initial	al_enabled= 1'b0;
	initial	al_tripped= 1'b0;
	always @(posedge i_clk)
	begin
		if (al_wr)
		begin
			// Only adjust the alarm hours if the requested hours
			// are valid.  This allows writes to the register,
			// without a prior read, to leave these configuration
			// bits alone.
			if (r_data[21:20] != 2'h3)
				alarm_time[21:16] <= i_wb_data[21:16];
			// Here's the same thing for the minutes: only adjust
			// the alarm minutes if the new bits are not all 1's. 
			if (~r_data[15])
				alarm_time[15:8] <= i_wb_data[15:8];
			// Here's the same thing for the seconds: only adjust
			// the alarm seconds if the new bits are not all 1's. 
			if (~r_data[7])
				alarm_time[7:0] <= i_wb_data[7:0];
			al_enabled <= i_wb_data[24];
			// Reset the alarm if a '1' is written to the tripped
			// register, or if the alarm is disabled.
			if ((r_data[25])||(~r_data[24]))
				al_tripped <= 1'b0;
		end

		al_int <= ((ck_last_clock != alarm_time)
				&&(clock[21:0] == alarm_time)&&(al_enabled));
		if (al_int)
			al_tripped <= 1'b1;
	end

	//
	// The ckspeed register is equal to 2^48 divded by the number of
	// clock ticks you expect per second.  Adjust high for a slower
	// clock, lower for a faster clock.  In this fashion, a single
	// real time clock RTL file can handle tracking the clock in any
	// device.  Further, because this is only the lower 32 bits of a 
	// 48 bit counter per seconds, the clock jitter is kept below
	// 1 part in 65 thousand.
	//
	initial	ckspeed = DEFAULT_SPEED;
	// In the case of verilator, comment the above and uncomment the line
	// below.  The clock constant below is "close" to simulation time,
	// meaning that my verilator simulation is running about 300x slower
	// than board time.
	// initial	ckspeed = 32'd786432000;
	always @(posedge i_clk)
		if (i_gps_valid)
			ckspeed <= i_gps_ckspeed;

	assign	o_interrupt = tm_int || al_int;

	// A once-per day strobe, on the last second of the day so that the
	// the next clock is the first clock of the day.  This is useful for
	// connecting this module to a year/month/date date/calendar module.
	assign	o_ppd = (ck_ppd)&&(ck_pps);

	always @(posedge i_clk)
		case(i_wb_addr)
		2'b00: o_data <= { ~i_gps_valid, 7'h0, 2'b00, clock[21:0] };
		2'b01: o_data <= { 6'h00, timer };
		2'b10: o_data <= stopwatch;
		2'b11: o_data <= { 6'h00, al_tripped, al_enabled, 2'b00, alarm_time };
		endcase

	// Make verilator happy
	// verilator lint_off UNUSED
	wire	[6:0] unused;
	assign	unused = { i_wb_cyc, i_wb_data[31:26] };
	// verilator lint_on  UNUSED
endmodule
