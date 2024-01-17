////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rtcbare.v
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This is the bare RTC clock logic.  It accepts an (optional)
// 		1pps signal input, and has a write interface for setting
// 	the clock.  The clock itself is a BCD integer of the form 00HHMMSS.
//
// 	Writes to the clock will change the current data.  The change will
// 	take roughly five clocks to propagate, to insure that there are no
// 	violations of the BCD clock format.
//
// 	Upon a PPS strobe (true for one clock only), the clock will advance.
// 	The clock rate is assumed to be faster than 5Hz, allowing BCD
// 	propagation through the clock fabric.
//
// 	The clock also outputs a PPD output.  This is a once-per-day strobe
// 	that will be true on the clock prior to the new day.  It is used by
// 	the rtcdate core to advance the date.
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
module	rtcbare #(
		// {{{
		// Set OPT_PREVALIDATED_INPUT to 1'b1 if the instantiating
		// module will never set i_wr true with invalid BCD data in
		// i_data.  Otherwise, setting it to zero will cause a
		// validation check, and ignore any incoming values that are
		// not valid BCD on a bytewise level.
		parameter [0:0]	OPT_PREVALIDATED_INPUT = 1'b0
		// }}}
	) (	
		// {{{
		input	wire		i_clk, i_reset,
		// Wishbone interface
		input	wire		i_pps, i_wr,
		input	wire	[21:0]	i_data,
		input	wire	[2:0]	i_valid,
		// Output registers
		output	wire	[21:0]	o_data, // multiplexed based on i_wb_adr
		// A once-per-day strobe on the last clock of the day
		output	wire		o_ppd
		// }}}
	);

	// Signal declarations
	// {{{
	reg	[21:0]	bcd_clock, next_clock;
	reg	[5:0]	carry;
	reg		pre_ppd;

	reg	[2:0]	pre_valid;
	reg	[21:0]	pre_bcd_clock;

	reg	[2:0]	suppressed, suppress_count;
	// }}}

	// pre_ppd
	// {{{
	initial	pre_ppd = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		pre_ppd <= 1'b0;
	else
		pre_ppd <= (bcd_clock == 22'h23_59_59);
	// }}}

	// carry, next_clock
	// {{{
	initial	carry = 0;
	initial	next_clock = 22'h00_00_01;
	always @(posedge i_clk)
	if (i_reset)
	begin
		next_clock <= 22'h00_00_01;
		carry <= 0;
	end else begin
		// Takes 7 clocks to converge

		// Seconds
		carry[0] <= (bcd_clock[ 3: 0] >=  4'h9);
		carry[1] <= (bcd_clock[ 7: 4] >=  4'h5)&&( carry[  0]);
		// Minutes
		carry[2] <= (bcd_clock[11: 8] >=  4'h9)&&(&carry[1:0]);
		carry[3] <= (bcd_clock[15:12] >=  4'h5)&&(&carry[2:0]);
		// Hours
		carry[4] <= (bcd_clock[19:16] >=  4'h9)&&(&carry[3:0]);
		carry[5] <= (bcd_clock[21:16] >= 6'h23)&&(&carry[3:0]);

		// Seconds
		if (carry[0])
			next_clock[3:0] <= 4'h0;
		else
			next_clock[3:0] <= bcd_clock[3:0] + 4'h1;

		if (carry[1])
			next_clock[7:4] <= 4'h0;
		else if (carry[0])
			next_clock[7:4] <= bcd_clock[7:4] + 4'h1;
		else
			next_clock[7:4] <= bcd_clock[7:4];

		// Minutes
		if (carry[2])
			next_clock[11:8] <= 4'h0;
		else if (carry[1])
			next_clock[11:8] <= bcd_clock[11:8] + 4'h1;
		else
			next_clock[11:8] <= bcd_clock[11:8];

		if (carry[3])
			next_clock[15:12] <= 4'h0;
		else if (carry[2])
			next_clock[15:12] <= bcd_clock[15:12] + 4'h1;
		else
			next_clock[15:12] <= bcd_clock[15:12];

		// Hours
		if ((carry[4])||(carry[5]))
			next_clock[19:16] <= 4'h0;
		else if (carry[3])
			next_clock[19:16] <= bcd_clock[19:16] + 4'h1;
		else
			next_clock[19:16] <= bcd_clock[19:16];

		if (carry[5])
			next_clock[21:20] <= 2'h0;
		else if (carry[4])
			next_clock[21:20] <= bcd_clock[21:20] + 2'h1;
		else
			next_clock[21:20] <= bcd_clock[21:20];
	end
	// }}}

	// pre_bcd_clock, pre_valid
	// {{{
	// Validate the input before setting the clock
	generate if (OPT_PREVALIDATED_INPUT)
	begin : NO_VALIDATION_REQUIRED
		// {{{
		// Write data through with no check
		// This can be combinatorial, with no clock required.
		//
		always @(*)
		if (i_wr)
			pre_valid = i_valid;
		else
			pre_valid = 0;

		always @(*)
			pre_bcd_clock = i_data;
		// }}}
	end else begin : VALIDATE_INPUT_BCD
		// {{{
		// Double check that the input contains valid BCD data
		//
		// We'll use this to prevent a write given invalid data
		// Requires one clock between write request and data update
		//
		initial	pre_valid = 0;
		always @(posedge i_clk)
		if (i_reset)
			pre_valid <= 0;
		else if (i_wr)
		begin
			// Seconds
			pre_valid[0] <= (i_valid[0])&&(i_data[7:0] <= 8'h59)
					&&(i_data[3:0] <= 4'h9);
			// Minutes
			pre_valid[1] <= (i_valid[1])&&(i_data[15:8] <= 8'h59)
					&&(i_data[11:8] <= 4'h9);
			// Hours
			pre_valid[2] <= (i_valid[2])&&(i_data[21:16] <= 6'h23)
					&&(i_data[19:16] <= 4'h9);
		end else
			pre_valid <= 0;

		always @(posedge i_clk)
			pre_bcd_clock <= i_data;
		// }}}
	end endgenerate
	// }}}

	// suprpressed, suppress_count
	// {{{
	initial	suppressed = 3'h7;
	initial	suppress_count = 3'h5;
	always @(posedge i_clk)
	if (i_reset)
	begin
		suppressed <= 3'h7;
		suppress_count <= 3'h5;
	end else if (|pre_valid)
	begin
		suppressed[0] <= (suppressed[0])||(pre_valid[  0]!=1'b0);
		suppressed[1] <= (suppressed[1])||(pre_valid[1:0]!=2'b00);
		suppressed[2] <= (suppressed[2])||(pre_valid[2:0]!=3'b000);
		suppress_count <= 3'h5;
	end else if (suppress_count > 0)
		suppress_count <= suppress_count - 1;
	else
		suppressed <= 0;
	// }}}

	// bcd_clock
	// {{{
	initial	bcd_clock = 0;
	always @(posedge i_clk)
	if (i_reset)
		bcd_clock <= 0;
	else begin
		if (i_pps)
		begin
			if (!suppressed[0])
				bcd_clock[7:0] <= next_clock[7:0];
			if (!suppressed[1])
				bcd_clock[15:8] <= next_clock[15:8];
			if (!suppressed[2])
				bcd_clock[21:16] <= next_clock[21:16];
		end
		if (pre_valid[0])
			bcd_clock[7:0] <= pre_bcd_clock[7:0];
		if (pre_valid[1])
			bcd_clock[15:8] <= pre_bcd_clock[15:8];
		if (pre_valid[2])
			bcd_clock[21:16] <= pre_bcd_clock[21:16];
	end
	// }}}

	assign	o_data = bcd_clock;
	assign	o_ppd  = (pre_ppd)&&(i_pps);
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal properties
// {{{
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef	FORMAL
`ifdef	RTCBARE
`define	ASSUME	assume
`define	ASSERT	assert
`else
`define	ASSUME	assert
`define	ASSERT	assert
`endif

	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;

	//
	always @(*)
	begin
		`ASSERT(bcd_clock[ 3: 0] <= 4'h9);
		`ASSERT(bcd_clock[ 7: 4] <= 4'h5);
		`ASSERT(bcd_clock[11: 8] <= 4'h9);
		`ASSERT(bcd_clock[15:12] <= 4'h5);
		`ASSERT(bcd_clock[19:16] <= 4'h9);
		`ASSERT(bcd_clock[21:16] <= 6'h23);
	end


	generate if (OPT_PREVALIDATED_INPUT)
	begin : F_ASSUME_VALID_INPUTS

		always @(*)
		if (i_wr)
		begin
			if (i_valid[0])
			begin
				`ASSUME(i_data[ 3: 0] <= 4'h9);
				`ASSUME(i_data[ 7: 4] <= 4'h5);
			end

			if (i_valid[1])
			begin
				`ASSUME(i_data[11: 8] <= 4'h9);
				`ASSUME(i_data[15:12] <= 4'h5);
			end

			if (i_valid[2])
			begin
				`ASSUME(i_data[19:16] <= 4'h9);
				`ASSUME(i_data[21:16] <= 8'h23);
			end
		end

	end else begin : F_ASSERT_PREVALIDATED

		always @(*)
		if (pre_valid[0])
		begin
			`ASSERT(pre_bcd_clock[ 3: 0] <= 4'h9);
			`ASSERT(pre_bcd_clock[ 7: 4] <= 4'h5);
		end

		always @(*)
		if (pre_valid[1])
		begin
			`ASSERT(pre_bcd_clock[11: 8] <= 4'h9);
			`ASSERT(pre_bcd_clock[15:12] <= 4'h5);
		end

		always @(*)
		if (pre_valid[2])
		begin
			`ASSERT(pre_bcd_clock[19:16] <= 4'h9);
			`ASSERT(pre_bcd_clock[21:16] <= 8'h23);
		end

	end endgenerate

	always @(*)
	begin
		`ASSERT(bcd_clock[ 3: 0] <= 4'h9);
		`ASSERT(bcd_clock[ 7: 4] <= 4'h5);
		`ASSERT(bcd_clock[11: 8] <= 4'h9);
		`ASSERT(bcd_clock[15:12] <= 4'h5);
		`ASSERT(bcd_clock[19:16] <= 4'h9);
		`ASSERT(bcd_clock[21:16] <= 8'h23);
	end

	reg	[7:0]	f_past_pps;
	initial	f_past_pps = 0;
	always @(posedge i_clk)
	if (i_reset)
		f_past_pps <= 0;
	else if (i_pps)
		f_past_pps <= 8'hff;
	else
		f_past_pps <= { f_past_pps[6:0], 1'b0 };

	always @(*)
	if (f_past_pps[7])
		`ASSUME(!i_pps);

	always @(*)
		`ASSERT(suppress_count <= 3'h5);
	always @(*)
	if (suppressed[0])
		`ASSERT(suppressed[1]);
	always @(*)
	if (suppressed[1])
		`ASSERT(suppressed[2]);
`endif
// }}}}
endmodule
