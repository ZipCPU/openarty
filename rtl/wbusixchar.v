////////////////////////////////////////////////////////////////////////////////
//
//
// Filename: 	wbusixchar.v
//
// Project:	FPGA library
//
// Purpose:	Supports a conversion from a six digit bus to a printable
//		ASCII character representing those six bits.  The encoding is
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
// Copyright (C) 2015-2016, Gisselquist Technology, LLC
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
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
//
module	wbusixchar(i_clk, i_stb, i_bits, o_stb, o_char, o_busy, i_busy);
	input			i_clk;
	input			i_stb;
	input		[6:0]	i_bits;
	output	reg		o_stb;
	output	reg	[7:0]	o_char;
	output	wire		o_busy;
	input			i_busy;

	initial	o_char = 8'h00;
	always @(posedge i_clk)
		if ((i_stb)&&(~o_busy))
		begin
			if (i_bits[6])
				o_char <= 8'h0a;
			else if (i_bits[5:0] <= 6'h09) // A digit, WORKS
				o_char <= "0" + { 4'h0, i_bits[3:0] };
			else if (i_bits[5:0] <= 6'd35) // Upper case
				o_char <= "A" + { 2'h0, i_bits[5:0] } - 8'd10; // -'A'+10
			else if (i_bits[5:0] <= 6'd61)
				o_char <= "a" + { 2'h0, i_bits[5:0] } - 8'd36;// -'a'+(10+26)
			else if (i_bits[5:0] == 6'd62) // An '@' sign
				o_char <= 8'h40;
			else // if (i_char == 6'h63) // A '%' sign
				o_char <= 8'h25;
		end

	always @(posedge i_clk)
		if ((o_stb)&&(~i_busy))
			o_stb <= 1'b0;
		else if ((i_stb)&&(~o_stb))
			o_stb <= 1'b1;

	assign	o_busy = o_stb;

endmodule

