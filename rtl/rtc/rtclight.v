////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rtclight.v
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Implement a real time clock, including alarm, count--down
//		timer, stopwatch, variable time frequency, and more.
//
//	This is a light-weight version of the RTC found in this directory.
//	Unlike the full RTC, this version does not support time hacks, seven
//	segment display outputs, or LED's.  It is an RTC for an internal core
//	only.  (That's how I was using it on one of my projects anyway ...)
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
module	rtclight #(
		// {{{
		parameter	DEFAULT_SPEED = 32'd2814750,	// 100 Mhz
		parameter [0:0]	OPT_TIMER       = 1'b1,
		parameter [0:0]	OPT_STOPWATCH   = 1'b1,
		parameter [0:0]	OPT_ALARM       = 1'b1,
		parameter [0:0]	OPT_FIXED_SPEED = 1'b1
		// }}}
	) (
		// {{{
		input	wire		i_clk, i_reset,
		// Wishbone interface
		input	wire		i_wb_cyc, i_wb_stb, i_wb_we,
		input	wire	[2:0]	i_wb_addr,
		input	wire	[31:0]	i_wb_data,
		input	wire	[3:0]	i_wb_sel,
		//
		output	wire		o_wb_stall,
		output	reg		o_wb_ack,
		output	reg	[31:0]	o_wb_data,
		// Output controls
		output	wire		o_interrupt,
		// A once-per-second strobe
					o_pps,
		// A once-per-day strobe on the last clock of the day
					o_ppd
		// }}}
	);

	// Signal declarations
	// {{{
	reg	[31:0]	ckspeed;

	wire	[21:0]	clock_data;
	wire	[31:0]	timer_data, alarm_data;
	wire	[30:0]	stopwatch_data;
	wire		sw_running;

	reg		ck_wr, tm_wr, al_wr, wr_zero;
	reg	[31:0]	wr_data;
	reg	[2:0]	wr_valid;
	wire		tm_int, al_int;

	reg		ck_carry;
	reg	[39:0]	ck_counter;
	wire		ck_pps, ck_ppd;
	reg		ck_prepps;
	reg	[7:0]	ck_sub;
	wire		sp_sel;
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
		ck_wr <= ((i_wb_stb)&&(i_wb_addr==3'b000)&&(i_wb_we));
		tm_wr <= ((i_wb_stb)&&(i_wb_addr==3'b001)&&(i_wb_we));
		//sw_wr<=((i_wb_stb)&&(i_wb_addr==3'b010)&&(i_wb_we));
		al_wr <= ((i_wb_stb)&&(i_wb_addr==3'b011)&&(i_wb_we));
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
	// Sub-clock handling, PPS generation
	// {{{
	////////////////////////////////////////////////////////////////////////
	//

	initial		ck_carry = 1'b0;
	initial		ck_counter = 40'h00;
	always @(posedge i_clk)
		{ ck_carry, ck_counter } <= ck_counter + { 8'h00, ckspeed };

	assign	ck_pps = (ck_carry)&&(ck_prepps);
	assign	o_pps  = ck_pps;

	always @(posedge i_clk)
	begin
		if (ck_carry)
			ck_sub <= ck_sub + 8'h1;
		ck_prepps <= (ck_sub == 8'hff);
	end
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Bare clock
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
	begin
		rtctimer #(.LGSUBCK(8))
			timer(i_clk, i_reset, ck_carry,
				tm_wr, wr_data[24:0],
				wr_valid, wr_zero, timer_data, tm_int);
	end else begin
		assign	tm_int = 0;
		assign	timer_data = 0;

		// Verilator lint_off UNUSED
		wire	unused_timer;
		assign	unused_timer = tm_wr;
		// Verilator lint_on  UNUSED
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
	begin
		reg	[2:0]	sw_ctrl;

		initial	sw_ctrl = 0;
		always @(posedge i_clk)
		if (i_reset)
			sw_ctrl <= 0;
		else if (i_wb_stb && i_wb_we && i_wb_sel[0] && i_wb_addr == 3'b010)
			sw_ctrl <= { i_wb_data[1:0], !i_wb_data[0] };
		else
			sw_ctrl <= 0;

		rtcstopwatch rtcstop(i_clk, i_reset, ckspeed,
			sw_ctrl[2], sw_ctrl[1], sw_ctrl[0],
			stopwatch_data, sw_running);

	end else begin

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
	begin

		rtcalarm alarm(i_clk, i_reset, clock_data[21:0],
			al_wr, wr_data[25], wr_data[24], wr_data[21:0],
				wr_valid, alarm_data, al_int);
	end else begin

		assign	alarm_data = 0;
		assign	al_int = 0;

		// Verilator lint_off UNUSED
		wire	unused_alarm;
		assign	unused_alarm = al_wr;
		// Verilator lint_on  UNUSED
	end endgenerate
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Clock speedx control
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
	generate if (!OPT_FIXED_SPEED)
	begin : ADJUSTABLE_CLOCK_RATE

		assign	sp_sel = ((i_wb_stb)&&(i_wb_addr[2:0]==3'b100));

		initial	ckspeed = DEFAULT_SPEED; // 2af31e = 2^48 / 100e6 MHz
		always @(posedge i_clk)
		if ((sp_sel)&&(i_wb_we))
			ckspeed <= i_wb_data;

	end else begin : FIXED_CLOCK_DIVIDER

		assign	sp_sel = 0;
		always @(*)
			ckspeed = DEFAULT_SPEED;

	end endgenerate
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Bus returns
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	assign	o_wb_stall = 1'b0;

	initial	o_wb_ack = 0;
	always @(posedge i_clk)
	if (i_reset)
		o_wb_ack <= 1'b0;
	else
		o_wb_ack <= i_wb_stb;

	always @(posedge i_clk)
	case(i_wb_addr[2:0])
	3'b000: o_wb_data <= { 10'h0, clock_data };
	3'b001: o_wb_data <= timer_data;
	3'b010: o_wb_data <= { sw_running, stopwatch_data };
	3'b011: o_wb_data <= alarm_data;
	3'b100: o_wb_data <= ckspeed;
	default: o_wb_data <= 32'h000;
	endcase
	// }}}

	// o_ppd
	// {{{
	// A once-per day strobe, on the last second of the day so that the
	// the next clock is the first clock of the day.  This is useful for
	// connecting this module to a year/month/date date/calendar module.
	assign	o_ppd = (ck_ppd);
	// }}}

	assign	o_interrupt = tm_int || al_int;


	// Make verilator hapy
	// {{{
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, sp_sel, i_wb_cyc, wr_data[31:25], i_wb_sel[3] };
	// verilator lint_on UNUSED
	// }}}
`ifdef	FORMAL
//
`ifdef	RTCLIGHT
	`define	ASSUME	assume
	`define	ASSERT	assert
`else
	`define ASSUME	assert
	`define	ASSERT	assume
`endif

	always @(*)
	if ((sp_sel)&&(i_wb_we))
		`ASSUME(i_wb_data > 0);

`endif
endmodule
