////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbutohex.v
//
// Project:	FPGA library
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
module	wbutohex(i_clk, i_stb, i_byte, o_stb, o_valid, o_hexbits);
	input	wire		i_clk, i_stb;
	input	wire	[7:0]	i_byte;
	output	reg		o_stb, o_valid;
	output	reg	[5:0]	o_hexbits;

	always @(posedge i_clk)
		o_stb <= i_stb;

	always @(posedge i_clk)
	begin
		// These are the defaults, to be overwridden by the ifs below
		o_valid <= 1'b1;
		o_hexbits <= 6'h00;

		if ((i_byte >= 8'h30)&&(i_byte <= 8'h39)) // A digit
			o_hexbits <= { 2'b0, i_byte[3:0] };
		else if ((i_byte >= 8'h41)&&(i_byte <= 8'h5a)) // Upper case
			o_hexbits <= (i_byte[5:0] - 6'h01 + 6'h0a);// -'A'+10
		else if ((i_byte >= 8'h61)&&(i_byte <= 8'h7a))
			o_hexbits <= (i_byte[5:0] +6'h03);	// -'a'+(10+26)
		else if (i_byte == 8'h40) // An '@' sign
			o_hexbits <= 6'h3e;
		else if (i_byte == 8'h25) // A '%' sign
			o_hexbits <= 6'h3f;
		else
			o_valid <= 1'b0;
	end
endmodule

