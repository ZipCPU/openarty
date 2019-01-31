////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbuinput.v
//
// Project:	FPGA library
//
// Purpose:	Coordinates the receiption of bytes, which are then translated
//		into codewords describing postential bus transactions.  This
//	includes turning the human readable bytes into more compact bits,
//	forming those bits into codewords, and decompressing any that reference
//	addresses within a compression table.
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
module	wbuinput(i_clk, i_stb, i_byte, o_stb, o_codword);
	input	wire		i_clk, i_stb;
	input	wire	[7:0]	i_byte;
	output	wire		o_stb;
	output	wire	[35:0]	o_codword;

	wire		hx_stb, hx_valid;
	wire	[5:0]	hx_hexbits;
	wbutohex	tobits(i_clk, i_stb, i_byte,
				hx_stb, hx_valid, hx_hexbits);

	wire		cw_stb;
	wire	[35:0]	cw_word;
	wbureadcw	formcw(i_clk, hx_stb, hx_valid, hx_hexbits,
				cw_stb, cw_word);

// `define	DEBUGGING
`ifdef	DEBUGGING
	assign	o_stb = cw_stb;
	assign	o_codword = cw_word;
`else
	wbudecompress	unpack(i_clk,cw_stb,cw_word, o_stb, o_codword);
`endif

endmodule
