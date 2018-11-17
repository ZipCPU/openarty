////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rtcalarm.v
//
// Project:	A Wishbone Controlled Real--time Clock Core, w/ GPS synch
//
// Purpose:	Implement an alarm for a real time clock.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2018, Gisselquist Technology, LLC
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
// set, clear, turn on, turn off
module	rtcalarm(i_clk, i_reset, i_now,
		//
		i_wr, i_clear, i_enable, i_alarm_time, i_valid,
		//
		o_data, o_alarm);
	parameter [0:0]		OPT_PREVALIDATED_INPUT = 1'b0;
	parameter [21:0]	OPT_INITIAL_ALARM_TIME = 0;
	parameter [0:0]		OPT_START_ENABLED = 0;
	parameter [0:0]		OPT_FIXED_ALARM_TIME = 0;
	//
	input	wire		i_clk, i_reset;
	//
	input	wire	[21:0]	i_now;
	//
	input	wire		i_wr;
	input	wire		i_enable, i_clear;
	input	wire	[21:0]	i_alarm_time;
	input	wire	[2:0]	i_valid;
	//
	output	wire	[31:0]	o_data;
	output	wire		o_alarm;

	//
	// The alarm code
	//
	// Set the alarm register to the time you wish the board to "alarm".
	// The "alarm" will take place once per day at that time.  At that
	// time, the RTC code will generate a clock interrupt, and the CPU/host
	// can come and see that the alarm tripped.
	//
	//
	reg	[21:0]		alarm_time, past_time;
	reg			enabled,	// Whether the alarm is enabled
				tripped;	// Whether the alarm has tripped

	initial	enabled = OPT_START_ENABLED;
	always @(posedge i_clk)
	if (i_reset)
		enabled <= OPT_START_ENABLED;
	else if (i_wr)
		enabled <= i_enable;

	always @(posedge i_clk)
		past_time <= i_now;

	initial	tripped= 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		tripped <= 1'b0;
	else if ((enabled)&&(i_now == alarm_time)&&(i_now != past_time))
		tripped <= 1'b1;
	else if ((i_wr)&&(i_clear))
		tripped <= 1'b0;

	reg	[2:0]	pre_valid;
	reg	[21:0]	validated_alarm_time;
	generate if (OPT_PREVALIDATED_INPUT)
	begin : INPUT_IS_VALID

		always @(*)
			pre_valid = ((!OPT_FIXED_ALARM_TIME)&&(i_wr))
					? i_valid : 0;

		always @(*)
			validated_alarm_time = i_valid;

	end else begin : CHECK_INPUT_VALIDITY

		initial	pre_valid = 0;
		always @(posedge i_clk)
		if ((i_reset)||(!i_wr)||(OPT_FIXED_ALARM_TIME))
			pre_valid <= 0;
		else begin

			pre_valid[0] <= (i_valid[0])
					&&(i_alarm_time[7:0] <= 8'h59)
					&&(i_alarm_time[3:0] <= 4'h9);

			pre_valid[1] <= (i_valid[1])
					&&(i_alarm_time[15:8] <= 8'h59)
					&&(i_alarm_time[11:8] <= 4'h9);

			pre_valid[2] <= (i_valid[2])
					&&(i_alarm_time[21:16] <= 6'h23)
					&&(i_alarm_time[19:16] <= 4'h9);
		end

		always @(posedge i_clk)
			validated_alarm_time <= i_alarm_time;

	end endgenerate

	initial	alarm_time = OPT_INITIAL_ALARM_TIME;
	always @(posedge i_clk)
	if (i_reset)
		alarm_time <= OPT_INITIAL_ALARM_TIME;
	else if (!OPT_FIXED_ALARM_TIME) begin
		// Only adjust the alarm hours if the requested hours
		// are valid.  This allows writes to the register,
		// without a prior read, to leave these configuration
		// bits alone.
		if (pre_valid[0]) // Seconds
			alarm_time[7:0]   <= validated_alarm_time[7:0];
		if (pre_valid[1]) // Minutes
			alarm_time[15:8]  <= validated_alarm_time[15:8];
		if (pre_valid[2]) // Hours
			alarm_time[21:16] <= validated_alarm_time[21:16];
	end

	assign	o_data  = { 6'h0, tripped, enabled, 2'b00, alarm_time };
	assign	o_alarm = tripped;

	// Make verilator happy
	// verilator lint_off UNUSED
	// wire	[6:0] unused;
	// assign	unused = { i_wb_cyc, i_wb_data[31:26] };
	// verilator lint_on  UNUSED

`ifdef	FORMAL
`ifdef	RTCALARM
`define	ASSUME	assume
`define	ASSERT	assert
`else
`define	ASSUME	assert
`define	ASSERT	assume
`endif

	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;

	always @(posedge i_clk)
	if (!f_past_valid)
		`ASSUME((i_now == 0)&&(!i_wr));

	always @(posedge i_clk)
	if ((!f_past_valid)||($past(i_reset)))
	begin
		`ASSERT(!tripped);
		`ASSERT(enabled == OPT_START_ENABLED);
		`ASSERT(alarm_time == OPT_INITIAL_ALARM_TIME);
	end

	always @(*)
	if (OPT_FIXED_ALARM_TIME)
		`ASSERT(alarm_time == OPT_INITIAL_ALARM_TIME);

	always @(*)
	begin
		`ASSUME(i_now[ 3: 0] <= 4'h9);
		`ASSUME(i_now[ 7: 4] <= 4'h5);
		`ASSUME(i_now[11: 8] <= 4'h9);
		`ASSUME(i_now[15:12] <= 4'h5);
		`ASSUME(i_now[19:16] <= 4'h9);
		`ASSUME(i_now[21:16] <= 8'h23);
	end

	generate if (OPT_PREVALIDATED_INPUT)
	begin : F_ASSUME_VALID_INPUTS

		always @(*)
		if (pre_valid[0])
		begin
			`ASSUME(i_alarm_time[ 3: 0] <= 4'h9);
			`ASSUME(i_alarm_time[ 7: 4] <= 4'h5);
		end

		always @(*)
		if (pre_valid[1])
		begin
			`ASSUME(i_alarm_time[11: 8] <= 4'h9);
			`ASSUME(i_alarm_time[15:12] <= 4'h5);
		end
	
		always @(*)
		if (pre_valid[2])
		begin
			`ASSUME(i_alarm_time[19:16] <= 4'h9);
			`ASSUME(i_alarm_time[21:16] <= 8'h23);
		end

	end endgenerate

	always @(*)
	begin
		`ASSERT(alarm_time[ 3: 0] <= 4'h9);
		`ASSERT(alarm_time[ 7: 4] <= 4'h5);
		`ASSERT(alarm_time[11: 8] <= 4'h9);
		`ASSERT(alarm_time[15:12] <= 4'h5);
		`ASSERT(alarm_time[19:16] <= 4'h9);
		`ASSERT(alarm_time[21:16] <= 8'h23);
	end

	always @(posedge i_clk)
	if ((f_past_valid)&&($past(enabled))&&(!$past(i_reset))
			&&($past(i_now) == $past(alarm_time))
			&&($past(i_now) != $past(past_time)))
		`ASSERT(tripped);
	else if ((!f_past_valid)||($past(i_reset))||(!$past(tripped)))
		`ASSERT(!tripped);
	else if (($past(i_wr))&&($past(i_clear)))
		`ASSERT(!tripped);

	always @(posedge i_clk)
	if ((f_past_valid)&&($past(i_wr))&&(!$past(i_reset)))
		`ASSERT(enabled == $past(i_enable));

	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(tripped)))
		cover(tripped);

	always @(posedge i_clk)
	if ((f_past_valid)&&($past(tripped)))
		cover(!tripped);

`endif
endmodule
