////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbutohex.v
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Supports a printable character conversion from a printable
//		ASCII character to six bits of valid data.  The encoding is
//		as follows:
//
//		0-9	->	0-9
//		A-Z	->	10-35
//		a-z	->	36-61
//		@	->	62
//		%	->	63
//
//		Note that decoding is stateless, yet requires one clock.
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
`default_nettype none
// }}}
module	wbutohex (
		// {{{
		input	wire		i_clk, i_reset, i_stb,
		output	wire		o_busy,
		input	wire	[7:0]	i_byte,
		output	reg		o_soft_reset,
		output	reg		o_stb, o_valid,
		input	wire		i_busy,
		output	reg	[5:0]	o_hexbits
		// }}}
	);

	// Local declarations
	// {{{
	reg	[6:0]	remap	[0:127];
	integer	k;
	reg	[6:0]	newv;
	// }}}

	assign	o_busy = o_stb && i_busy;

	// o_stb
	// {{{
	initial	o_stb = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_stb <= 1'b0;
	else if (!o_stb || !i_busy)
		o_stb <= i_stb;
	// }}}

	// newv, remap
	// {{{
	always @(*)
	// initial
	begin
		for(k=0; k<128; k=k+1)
		begin
			newv = 7'h40;
			// verilator lint_off WIDTH
			if ((k >= 48)&&(k <= 57)) // A digit
			begin
				newv = k;
				newv[6:4] = 3'b100;
			end else if ((k >= 65)&&(k <= 90)) // Upper case
			begin
				newv[5:0] = ((k&8'h3f) + 6'h09);// -'A'+10
				newv[6] = 1'b1;
			end else if ((k >= 97)&&(k <= 122))
				newv[5:0] = ((k&8'h3f) + 6'h03);	// -'a'+(10+26)
			// verilator lint_on WIDTH
			else if (k == 64) // An '@' sign
				newv[5:0] = 6'h3e;
			else if (k == 37) // A '%' sign
				newv[5:0] = 6'h3f;
			else
				newv = 0;

			remap[k] = newv;
		end
	end
	// }}}

	// o_valid
	// {{{
	always @(posedge i_clk)
	if (!o_stb || !i_busy)
	begin
		{ o_valid, o_hexbits } <= remap[i_byte[6:0]];
		if (i_byte[7])
			o_valid <= 0;
	end
	// }}}

	// o_soft_reset
	// {{{
	initial	o_soft_reset = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		o_soft_reset <= 1;
	else if (!o_stb || !i_busy)
		o_soft_reset <= i_stb && (i_byte[6:0] == 7'h3);
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
`endif
// }}}
endmodule

