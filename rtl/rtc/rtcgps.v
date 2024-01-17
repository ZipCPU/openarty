////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rtcgps.v
// {{{
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
// }}}
// Copyright (C) 2015-2024, Gisselquist Technology, LLC
// {{{
// This file is part of the OpenArty project.
//
// The OpenArty project is free software and gateware, licensed under the terms
// of the 3rd version of the GNU General Public License as published by the
// Free Software Foundation.
//
// This project is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
`default_nettype	none
// }}}
module	rtcgps #(
		// {{{
		parameter	DEFAULT_SPEED = 32'd2814750, //= 2^48 / CkSpd
		parameter [0:0]	OPT_TIMER       = 1'b1,
		parameter [0:0]	OPT_STOPWATCH   = 1'b1,
		parameter [0:0]	OPT_ALARM       = 1'b1
		// }}}
	) (
		// {{{
		input	wire		i_clk, i_reset,
		//
		// Wishbone interface
		input	wire		i_wb_cyc, i_wb_stb, i_wb_we,
		input	wire	[1:0]	i_wb_addr,
		input	wire	[31:0]	i_wb_data,
		input	wire	[3:0]	i_wb_sel,
		//
		output	reg		o_wb_ack,
		output	wire		o_wb_stall,
		output	reg	[31:0]	o_wb_data,
		// Output registers
		output	wire		o_interrupt,
		// A once-per-day strobe on the last clock of the day
					o_ppd,
		// GPS interface
		input	wire		i_gps_valid, i_gps_pps,
		input	wire	[31:0]	i_gps_ckspeed,
		// Our personal timing PPS, for debug purposes
		output	wire		o_rtc_pps
		// }}}
	);

	// Signal descriptions
	// {{{
	reg	[31:0]	ckspeed;

	wire	[21:0]	clock_data;
	wire	[31:0]	timer_data, alarm_data;
	wire	[30:0]	stopwatch_data;
	wire		sw_running, ck_ppd;

	reg		ck_wr, tm_wr, al_wr, wr_zero;
	reg	[31:0]	wr_data;
	reg	[2:0]	wr_valid;
	wire		tm_int, al_int;
	reg	[39:0]	ck_counter;
	reg		ck_carry, ck_sub_carry;
	wire	[7:0]	ck_sub;
	reg		ck_pps;
	// }}}

	// ck_wr, tm_wr, al_wr
	// {{{
	initial	ck_wr = 1'b0;
	initial	tm_wr = 1'b0;
	initial	al_wr = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		ck_wr <= 1'b0;
		tm_wr <= 1'b0;
		al_wr <= 1'b0;
	end else begin
		ck_wr <= ((i_wb_stb)&&(i_wb_addr==2'b00)&&(i_wb_we));
		tm_wr <= ((i_wb_stb)&&(i_wb_addr==2'b01)&&(i_wb_we));
		//sw_wr<=((i_wb_stb)&&(i_wb_addr==2'b10)&&(i_wb_we));
		al_wr <= ((i_wb_stb)&&(i_wb_addr==2'b11)&&(i_wb_we));
	end
	// }}}

	// wr_data, wr_valid, wr_zero
	// {{{
	always @(posedge i_clk)
	begin
		wr_data <= i_wb_data;
		wr_valid[0] <= (i_wb_sel[0])&&(i_wb_data[3:0] <= 4'h9)
				&&(i_wb_data[7:4] <= 4'h5);
		wr_valid[1] <= (i_wb_sel[1])&&(i_wb_data[11:8] <= 4'h9)
				&&(i_wb_data[15:12] <= 4'h5);
		wr_valid[2] <= (i_wb_sel[2])&&(i_wb_data[19:16] <= 4'h9)
				&&(i_wb_data[21:16] <= 6'h23);
		wr_zero     <= (i_wb_data[23:0]==0);
	end
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// The bare clock
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	rtcbare	clock(i_clk, i_reset, ck_pps,
			ck_wr, wr_data[21:0], wr_valid, clock_data, ck_ppd);
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Timer
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	generate if (OPT_TIMER)
	begin : GEN_TIMER
		rtctimer #(.LGSUBCK(8))
			timer(i_clk, i_reset, ck_sub_carry,
				tm_wr, wr_data[24:0],
				wr_valid, wr_zero, timer_data, tm_int);
	end else begin : NO_TIMER
		assign	tm_int = 0;
		assign	timer_data = 0;
	end endgenerate
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Stopwatch
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	generate if (OPT_STOPWATCH)
	begin : GEN_STOPWATCH
		reg	[2:0]	sw_ctrl;

		initial	sw_ctrl = 0;
		always @(posedge i_clk)
		if (i_reset)
			sw_ctrl <= 0;
		else if (i_wb_stb && i_wb_sel[0] && i_wb_addr == 2'b10)
			sw_ctrl <= { i_wb_data[1:0], !i_wb_data[0] };
		else
			sw_ctrl <= 0;

		rtcstopwatch rtcstop(i_clk, i_reset, ckspeed,
			sw_ctrl[2], sw_ctrl[1], sw_ctrl[0],
			stopwatch_data, sw_running);

	end else begin : NO_STOPWATCH

		assign stopwatch_data = 0;
		assign sw_running = 0;

	end endgenerate
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Alarm
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	generate if (OPT_ALARM)
	begin : GEN_ALARM

		rtcalarm alarm(i_clk, i_reset, clock_data[21:0],
			al_wr, wr_data[25], wr_data[24], wr_data[21:0],
				wr_valid, alarm_data, al_int);
	end else begin : NO_ALARM

		assign	alarm_data = 0;
		assign	al_int = 0;

	end endgenerate
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Sub-second tracking
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	initial	ck_carry = 1'b0;
	initial	ck_sub_carry = 1'b0;
	initial	ck_counter = 0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		ck_counter   <= 0;
		ck_carry     <= 1'b0;
		ck_sub_carry <= 1'b0;
	end else if ((i_gps_valid)&&(i_gps_pps))
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
		ck_counter   <= { 7'h00, ckspeed, 1'b0 };
		ck_sub_carry <= ckspeed[31];

	end else begin

		{ ck_sub_carry, ck_counter[31:0] }
			<= ck_counter[31:0] + ckspeed;
		{ ck_carry, ck_counter[39:32] }
			<= ck_counter[39:32] + { 7'h0, ck_sub_carry };
	end

	assign	ck_sub = ck_counter[39:32];

	always @(posedge i_clk)
	if ((i_gps_pps)&&(i_gps_valid)&&(ck_sub[7]))
		// If the GPS is ahead of us, jump forward and set
		// the PPS high
		ck_pps <= 1'b1;
	else if ((ck_carry)&&(ck_sub == 8'h00))
		// Otherwise, if there is no GPS, or if the GPS is
		// late, then set the ck_pps on the roll over of
		// ck_sub
		ck_pps <= 1'b1;
	else
		// in all other cases, ck_pps should be zero.  It's a
		// strobe signal that should only (if ever) be true
		// for a single clock cycle per second
		ck_pps <= 1'b0;
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Clock speed
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

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
	always @(posedge i_clk)
	if (i_gps_valid)
		ckspeed <= i_gps_ckspeed;
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// o_interrupt and bus responses
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	assign	o_interrupt = tm_int || al_int;

	// A once-per day strobe, on the last second of the day so that the
	// the next clock is the first clock of the day.  This is useful for
	// connecting this module to a year/month/date date/calendar module.
	assign	o_ppd = (ck_ppd)&&(ck_pps);

	// o_wb_data
	// {{{
	initial	o_wb_data = 0;
	always @(posedge i_clk)
	case(i_wb_addr)
	2'b00: o_wb_data <= { !i_gps_valid, 7'h0, 2'b00,clock_data[21:0] };
	2'b01: o_wb_data <= timer_data;
	2'b10: o_wb_data <= { sw_running, stopwatch_data };
	2'b11: o_wb_data <= alarm_data;
	endcase
	// }}}

	// o_wb_ack
	// {{{
	initial	o_wb_ack = 0;
	always @(posedge i_clk)
	if (i_reset)
		o_wb_ack <= 0;
	else
		o_wb_ack <= i_wb_stb;
	// }}}

	assign	o_wb_stall = 0;
	// }}}

	assign	o_rtc_pps = ck_pps;

	// Make verilator happy
	// {{{
	// verilator lint_off UNUSED
	wire	 unused;
	assign	unused = &{ 1'b0, i_wb_cyc, wr_data[31:26], i_wb_sel[3] };
	// verilator lint_on  UNUSED
	// }}}
`ifdef	FORMAL
`ifdef	RTCGPS
`define	ASSUME	assume
`define	ASSERT	assert
`else
`define	ASSUME	assert
`define	ASSERT	assume
`endif

	always @(*)
		`ASSUME(i_gps_ckspeed >0);
	always @(*)
		`ASSUME(!i_gps_ckspeed[31]);

//	reg	f_past_valid;
//	initial	f_past_valid = 1'b0;
//	always @(posedge i_clk)
//		f_past_valid <= 1'b1;

`endif
endmodule
