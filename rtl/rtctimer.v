////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rtctimer.v
//
// Project:	A Wishbone Controlled Real--time Clock Core, w/ GPS synch
//
// Purpose:	Implements a count down timer
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2019, Gisselquist Technology, LLC
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
module	rtctimer(i_clk, i_reset,
		i_sub_ck, i_wr, i_data, i_valid, i_zero,
		o_data, o_interrupt);
	parameter	LGSUBCK = 2;
	parameter [0:0] 	OPT_PREVALIDATED_INPUT = 1'b0;
	parameter [21:0]	OPT_FIXED_INTERVAL = 0;
	//
	input	wire		i_clk, i_reset;
	//
	input	wire		i_sub_ck;
	//
	input	wire		i_wr;
	input	wire	[24:0]	i_data;
	input	wire	[2:0]	i_valid;
	input	wire		i_zero;
	output	wire	[31:0]	o_data;
	output	wire		o_interrupt;

	reg	[23:0]	bcd_timer;
	// wire	[6:0]	bcd_hours, bcd_minutes, bcd_seconds;
	// assign	bcd_seconds = bcd_timer[ 6:0];
	// assign	bcd_minutes = bcd_timer[14:8];
	// assign	bcd_hours   = bcd_timer[22:16];

	//
	reg	[23:0]	next_timer;
	reg	[4:0]	tmr_carry, pre_tmr_carry;
	reg		last_tick;

	initial	tmr_carry = 0;
	initial	next_timer = 0;
	always @(posedge i_clk)
	begin
		pre_tmr_carry[0] <= (bcd_timer[ 3: 0]== 4'h0);
		pre_tmr_carry[1] <= (bcd_timer[ 6: 4]== 3'h0);//&&(tmr_carry[0]);
		pre_tmr_carry[2] <= (bcd_timer[11: 8]== 4'h0);//&&(tmr_carry[1]);
		pre_tmr_carry[3] <= (bcd_timer[14:12]== 3'h0);//&&(tmr_carry[2]);
		pre_tmr_carry[4] <= (bcd_timer[19:16]== 4'h0);//&&(tmr_carry[3]);
		tmr_carry[0] <= pre_tmr_carry[0];
		tmr_carry[1] <= (&pre_tmr_carry[1:0]);
		tmr_carry[2] <= (&pre_tmr_carry[2:0]);
		tmr_carry[3] <= (&pre_tmr_carry[3:0]);
		tmr_carry[4] <= (&pre_tmr_carry[4:0]);
		last_tick <= (bcd_timer[23:1] == 0);

		// Keep unused bits at zero
		next_timer <= 24'h00;
		// Seconds
		if (tmr_carry[0])
			next_timer[3:0] <= 4'h9;
		else
			next_timer[ 3: 0] <= (bcd_timer[ 3: 0]-4'h1);

		if (tmr_carry[1])
			next_timer[6:4] <= 3'h5;
		else if (tmr_carry[0])
			next_timer[ 6: 4] <= (bcd_timer[ 6: 4]-3'h1);
		else
			next_timer[6:4] <= bcd_timer[6:4];

		// Minutes
		if (tmr_carry[2])
			next_timer[11:8] <= 4'h9;
		else if (tmr_carry[1])
			next_timer[11:8] <= bcd_timer[11:8]-4'h1;
		else
			next_timer[11:8] <= bcd_timer[11:8];
		if (tmr_carry[3])
			next_timer[14:12] <= 3'h5;
		else if (tmr_carry[2])
			next_timer[14:12] <= (bcd_timer[14:12]-3'h1);
		else
			next_timer[14:12] <= bcd_timer[14:12];

		// Hours
		if (tmr_carry[4])
			next_timer[19:16] <= 4'h9;
		else if (tmr_carry[3])
			next_timer[19:16] <= bcd_timer[19:16]-4'h1;
		else
			next_timer[19:16] <= bcd_timer[19:16];

		if (tmr_carry[4])
			next_timer[23:20] <= (bcd_timer[23:20]-4'h1);
		else
			next_timer[23:20] <= bcd_timer[23:20];
	end

	reg	tm_pre_pps, tm_int, tm_running, tm_alarm;
	wire	tm_stopped, tm_pps;
	assign	tm_stopped = !tm_running;

	reg	[(LGSUBCK-1):0]		tm_sub;

	initial	tm_sub     = 0;
	always @(posedge i_clk)
	if ((i_reset)||((i_wr)&&(!tm_running)&&(&i_valid)&&(!i_zero)))
		tm_sub <= 0;
	else if ((i_sub_ck)&&(tm_running))
		tm_sub <= tm_sub + 1;

	initial	tm_pre_pps     = 1'b0;
	always @(posedge i_clk)
	if ((i_reset)||((i_wr)&&(!tm_running)))
		tm_pre_pps <= 0;
	else if ((i_sub_ck)&&(tm_running))
		tm_pre_pps <= (&tm_sub[LGSUBCK-1:1])&&(!tm_sub[0]);
	else
		tm_pre_pps <= (&tm_sub);

	assign	tm_pps = (tm_pre_pps)&&(i_sub_ck);

	initial	bcd_timer      = 24'h00;
	initial	tm_int     = 1'b0;
	initial	tm_running = 1'b0;
	initial	tm_alarm   = 1'b0;

	always @(posedge i_clk)
	if (i_reset)
	begin
		tm_alarm   <= 0;
		bcd_timer      <= 0;
		tm_running <= 0;
		tm_int     <= 0;
	end else begin
		if ((tm_pps)&&(tm_running))
			bcd_timer <= next_timer;
		if ((tm_running)&&(tm_pps))
		begin
			bcd_timer <= next_timer;
			if (last_tick)
				tm_alarm <= 1'b1;
		end

		bcd_timer[ 7] <= 1'b0;
		bcd_timer[15] <= 1'b0;

		tm_int <= (tm_running)&&(tm_pps)&&(!tm_alarm)&&(last_tick);

		if ((tm_pps)&&(last_tick)) // Stop the timer on an alarm
			tm_running <= 1'b0;
		else if (i_wr)
		begin
			if (tm_running)
				tm_running <= i_data[24];
			else if ((i_zero)&&(bcd_timer != 0))
				tm_running <= i_data[24];
			else
				tm_running <= (!i_zero)&&(&i_valid);
		end

		if ((i_wr)&&(tm_stopped)) // Writes while stopped
		begin
			//
			if ((&i_valid)&&(!i_zero))
				bcd_timer[23:0] <= i_data[23:0];

			// Still ... any write clears the alarm
			tm_alarm <= 1'b0;
		end
	end

	assign	o_interrupt = tm_int;
	assign	o_data = { 6'h00, tm_alarm, tm_running, bcd_timer };

	// Make Verilator happy
	// verilator lint_off UNUSED
	// wire	[6:0]	unused;
	// assign	unused = i_data[31:25];
	// verilator lint_on  UNUSED

`ifdef	FORMAL
`ifdef	RTCTIMER
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
	if ((!f_past_valid)||($past(i_reset)))
	begin
		`ASSUME(!i_wr);
		//
		`ASSERT(tm_sub == 0);
		`ASSERT(!tm_pps);
		`ASSERT(bcd_timer == 0);
	end

	always @(*)
	if (i_wr)
	begin
		if (i_valid[0])
		begin
			`ASSUME(i_data[3:0] <= 4'h9);
			`ASSUME(i_data[7:4] <= 4'h5);
		end
		if (i_valid[1])
		begin
			`ASSUME(i_data[11: 8] <= 4'h9);
			`ASSUME(i_data[15:12] <= 4'h5);
		end
		if (i_valid[2])
		begin
			`ASSUME(i_data[19:16] <= 4'h9);
		end

		`ASSUME(i_zero == (i_data[23:0] == 0));
	end
	//
	//
	// Timer assertions
	//
	//
	initial	`ASSERT(tm_stopped);
	initial	`ASSERT(!tm_alarm);
	always @(posedge i_clk)
	begin
		`ASSERT(bcd_timer[ 3: 0] <= 4'h9);
		`ASSERT(bcd_timer[ 7: 4] <= 4'h5);
		`ASSERT(bcd_timer[11: 8] <= 4'h9);
		`ASSERT(bcd_timer[15:12] <= 4'h5);
		`ASSERT(bcd_timer[19:16] <= 4'h9);
		//
		`ASSERT(bcd_timer[ 7] == 1'b0);
		`ASSERT(bcd_timer[15] == 1'b0);
		//
	end

	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_reset)))
	begin
		if ((!$past(tm_running))&&(!$past(i_wr)))
			`ASSERT($stable(bcd_timer));
		if (($past(tm_pps))&&(!$past(i_wr)))
		begin
			if ($past(bcd_timer[3:0] != 4'h0))
				`ASSERT($stable(bcd_timer[23:4]));
			if ($past(bcd_timer[6:0] != 7'h00))
				`ASSERT($stable(bcd_timer[23:8]));
			if ($past(bcd_timer[11:0] != 12'h0000))
				`ASSERT($stable(bcd_timer[23:12]));
			if ($past(bcd_timer[15:0] != 16'h0000))
				`ASSERT($stable(bcd_timer[23:16]));
			if ($past(bcd_timer[19:0] != 20'h00000))
				`ASSERT($stable(bcd_timer[23:20]));
		end

		if (($past(tm_running))&&(!$past(tm_pps)))
			`ASSERT($stable(bcd_timer));

		if (tm_alarm)
			`ASSERT(bcd_timer[23:0] == 0);
	end

	always @(*)
	if (tm_alarm)
		`ASSERT(!tm_running);
	always @(*)
	if (tm_running)
		`ASSERT(bcd_timer[23:0] != 0);
	always @(*)
	if (tm_sub > 2)
		`ASSERT(last_tick == (bcd_timer[23:1] == 0));
	always @(*)
	if (!&tm_sub)
		`ASSERT(tm_pps == 0);
	/*
	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_reset))
			&&($past(tm_sub != 0))&&(tm_sub == 0))
		`ASSERT($past(i_wr)||(tm_pps));
		*/

	always @(posedge i_clk)
		cover(tm_int);

	always @(posedge i_clk)
	if ((f_past_valid)&&($past(!tm_alarm)))
		cover(tm_alarm);

	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_reset))&&($past(tm_alarm)))
		cover(!tm_alarm);
`endif
endmodule
