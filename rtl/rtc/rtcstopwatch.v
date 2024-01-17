////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rtcstopwatch.v
// {{{
// Project:	A Wishbone Controlled Real--time Clock Core, w/ GPS synch
//
// Purpose:	Implement a stop watch in BCD.
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
module	rtcstopwatch(
		// {{{
		input	wire		i_clk, i_reset,
		//
		input	wire	[31:0]	i_ckstep,
		input	wire		i_clear, i_start, i_stop,
		output	wire	[30:0]	o_value,
		output	wire		o_running
		// }}}
	);

	// Signal declarations
	// {{{
	reg	[30:0]	counter;
	reg	[45:0]	sw_subticks;
	reg	[36:0]	sw_step;
	reg	[13:0]	last_step;
	reg	[6:0]	sw_carry;
	reg		sw_ppms, carry, sw_running;
	reg	[30:0]	next_sw;
	// }}}

	// i_ckstep
	// {{{
	// i_ckstep is the bottom 32 bits of a 48 counter step that rolls over
	// once per second.  If we multiply by 100, we'll then have a 48 bit
	// counter step that will roll over once every 10 milliseconds.
	// The bottom two of those bits are always zero, so they can be
	// dropped.  This will give us a 46 bit step.
	always @(posedge i_clk)
		sw_step <= { 1'b0, i_ckstep, 4'h0 }
       			+ { 2'b0, i_ckstep, 3'h0 }
			+ { 5'h0, i_ckstep };
	// }}}

	always @(posedge i_clk)
		last_step <= sw_step[36:23];

	// sw_ppms, sw_subticks, carry
	// {{{
	initial	sw_ppms = 0;
	initial	sw_subticks = 0;
	initial	carry = 0;
	always @(posedge i_clk)
	if (i_reset)
		{ sw_ppms, carry, sw_subticks } <= 0;
	else if ((i_start)||((sw_running)&&(!i_stop)))
	begin
		{ carry, sw_subticks[22:0] }
				<= sw_subticks[22:0] + sw_step[22:0];
		{ sw_ppms, sw_subticks[45:23] } <=
				sw_subticks[45:23]
				+ {{(9){1'b0}}, last_step[13:0]}
				+ {{(23){1'b0}}, carry };
	end else
		sw_ppms <= 1'b0;
	// }}}

	//
	// Stopwatch functionality
	//
	// Setting bit '0' starts the stop watch, clearing it stops it.
	// Writing to the register with bit '1' high will clear the stopwatch,
	// and return it to zero provided that the stopwatch is stopped either
	// before or after the write.  Hence, writing a '2' to the device
	// will always stop and clear it, whereas writing a '3' to the device
	// will only clear it if it was already stopped.
	//

	// next_sw
	// {{{
	initial	next_sw = 0;
	always @(posedge i_clk)
	if (i_reset || i_clear)
	begin
		sw_carry <= 0;
		next_sw  <= 0;
	end else begin
		sw_carry[0] <= (counter[ 3: 0] >= 4'h9);
		sw_carry[1] <= (counter[ 7: 4] >= 4'h9) && (sw_carry[0]);
		sw_carry[2] <= (counter[11: 8] >= 4'h9) && (&sw_carry[1]);
		sw_carry[3] <= (counter[14:12] >= 3'h5) && (&sw_carry[2]);
		sw_carry[4] <= (counter[19:16] >= 4'h9) && (&sw_carry[3]);
		sw_carry[5] <= (counter[22:20] >= 3'h5) && (&sw_carry[4]);
		sw_carry[6] <= (counter[27:24] >= 4'h9) && (&sw_carry[5]);

		// Tens of Milliseconds
		if (sw_carry[0])
			next_sw[3:0] <= 0;
		else
			next_sw[3:0] <= counter[3:0] + 4'h1;

		if (sw_carry[1])
			next_sw[7:4] <= 0;
		else if (sw_carry[0])
			next_sw[7:4] <= counter[7:4] + 4'h1;
		else
			next_sw[7:4] <= counter[7:4];

		// Seconds
		if (sw_carry[2])
			next_sw[11:8] <= 0;
		else if (sw_carry[1])
			next_sw[11:8] <= counter[11:8] + 4'h1;
		else
			next_sw[11:8] <= counter[11:8];

		if (sw_carry[3])
			next_sw[14:12] <= 0;
		else if (sw_carry[2])
			next_sw[14:12] <= counter[14:12] + 3'h1;
		else
			next_sw[14:12] <= counter[14:12];
		next_sw[15] <= 1'b0;

		// Minute
		if (sw_carry[4])
			next_sw[19:16] <= 0;
		else if (sw_carry[3])
			next_sw[19:16] <= counter[19:16] + 4'h1;
		else
			next_sw[19:16] <= counter[19:16];

		if (sw_carry[5])
			next_sw[22:20] <= 0;
		else if (sw_carry[4])
			next_sw[22:20] <= counter[22:20] + 3'h1;
		else
			next_sw[22:20] <= counter[22:20];
		next_sw[23] <= 1'b0;

		// Hour
		if (sw_carry[6])
			next_sw[27:24] <= 0;
		else if (sw_carry[5])
			next_sw[27:24] <= counter[27:24] + 4'h1;
		else
			next_sw[27:24] <= counter[27:24];

		if (sw_carry[6])
			next_sw[30:28] <= counter[30:28] + 1'b1;
	end
	// }}}

	// counter
	// {{{
	initial	counter = 31'h00000;
	always @(posedge i_clk)
	if (i_reset || i_clear)
		counter <= 0;
	else if ((sw_ppms)&&(sw_running))
		counter <= next_sw;
	// }}}

	// sw_running
	// {{{
	initial	sw_running = 0;
	always @(posedge i_clk)
	if (i_reset || i_stop)
		sw_running <= 1'b0;
	else if (i_start)
		sw_running <= 1'b1;
	// }}}

	assign	o_value = counter;
	assign	o_running = sw_running;

	// Make verilator happy
	// {{{
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, sw_step[2:0] };
	// verilator lint_on  UNUSED
	// }}}
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
`ifdef	STOPWATCH
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

	always @(*)
		`ASSUME(i_ckstep > 0);

	initial	`ASSUME(!i_clear);
	initial	`ASSUME(!i_start);
	initial	`ASSUME(!i_stop);

	always @(posedge i_clk)
	if ((!f_past_valid)||($past(i_reset)))
	begin
		`ASSERT(counter == 0);
		`ASSERT(!sw_running);
	end else if ($past(i_clear))
		`ASSERT(counter == 0);
	else if (!$past(sw_running))
		`ASSERT($stable(counter));

	always @(*)
	begin
		// Tens of Milliseconds
		`ASSERT(counter[ 3: 0] <= 4'h9);
		`ASSERT(counter[ 7: 4] <= 4'h9);
		// Seconds
		`ASSERT(counter[11: 8] <= 4'h9);
		`ASSERT(counter[15:12] <= 4'h5);
		// Minutes
		`ASSERT(counter[19:16] <= 4'h9);
		`ASSERT(counter[23:20] <= 4'h5);
		// Hours
		`ASSERT(counter[27:24] <= 4'h9);
	end

	always @(*)
	if (sw_subticks[45:37] != 0)
		`ASSUME(!sw_ppms);

	always @(posedge i_clk)
	if ((f_past_valid)&&($past(sw_ppms)))
		`ASSERT(!sw_ppms);

`endif
// }}}
endmodule
