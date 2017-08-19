////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbureadcw.v
//
// Project:	FPGA library
//
// Purpose:	Read bytes from a serial port (i.e. the jtagser) and translate
//		those bytes into a 6-byte codeword.  This codeword may specify
//	a number of values to be read, the value to be written, or an address
//	to read/write from, or perhaps the end of a write sequence.
//
//	See the encoding documentation file for more information.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2017, Gisselquist Technology, LLC
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
// Goal: single clock pipeline, 50 slices or less
//
module	wbureadcw(i_clk, i_stb, i_valid, i_hexbits,
			o_stb, o_codword);
	input	wire		i_clk, i_stb, i_valid;
	input	wire	[5:0]	i_hexbits;
	output	reg		o_stb;
	output	reg	[35:0]	o_codword;


	// Timing:
	//	Clock 0:	i_stb is high, i_valid is low
	//	Clock 1:	shiftreg[5:0] is valid, cw_len is valid
	//				r_len = 1
	//	Clock 2:	o_stb = 1, for cw_len = 1;
	//				o_codword is 1-byte valid
	//			i_stb may go high again on this clock as well.
	//	Clock 3:	o_stb = 0 (cw_len=1),
	//			cw_len = 0,
	//			r_len = 0 (unless i_stb)
	//			Ready for next word

	reg	[2:0]	r_len, cw_len;
	reg	[1:0]	lastcw;

	wire	w_stb;
	assign	w_stb = ((r_len == cw_len)&&(cw_len != 0))
			||((i_stb)&&(~i_valid)&&(lastcw == 2'b01));

	// r_len is the length of the codeword as it exists
	// in our register
	initial r_len = 3'h0;
	always @(posedge i_clk)
		if ((i_stb)&&(~i_valid)) // Newline reset
			r_len <= 0;
		else if (w_stb) // reset/restart w/o newline
			r_len <= (i_stb)? 3'h1:3'h0;
		else if (i_stb) //in middle of word
			r_len <= r_len + 3'h1;

	reg	[35:0]	shiftreg;
	always @(posedge i_clk)
		if (w_stb)
			shiftreg[35:30] <= i_hexbits;
		else if (i_stb) case(r_len)
		3'b000: shiftreg[35:30] <= i_hexbits;
		3'b001: shiftreg[29:24] <= i_hexbits;
		3'b010: shiftreg[23:18] <= i_hexbits;
		3'b011: shiftreg[17:12] <= i_hexbits;
		3'b100: shiftreg[11: 6] <= i_hexbits;
		3'b101: shiftreg[ 5: 0] <= i_hexbits;
		default: begin end
		endcase

	always @(posedge i_clk)
		if (o_stb)
			lastcw <= o_codword[35:34];
	always @(posedge i_clk)
		if ((i_stb)&&(~i_valid)&&(lastcw == 2'b01))
			o_codword[35:30] <= 6'h2e;
		else
			o_codword <= shiftreg;

	// How long do we expect this codeword to be?
	initial	cw_len = 3'b000;
	always @(posedge i_clk)
		if ((i_stb)&&(~i_valid))
			cw_len <= 0;
		else if ((i_stb)&&((cw_len == 0)||(w_stb)))
		begin
			if (i_hexbits[5:4] == 2'b11) // 2b vector read
				cw_len <= 3'h2;
			else if (i_hexbits[5:4] == 2'b10) // 1b vector read
				cw_len <= 3'h1;
			else if (i_hexbits[5:3] == 3'b010) // 2b compressed wr
				cw_len <= 3'h2;
			else if (i_hexbits[5:3] == 3'b001) // 2b compressed addr
				cw_len <= 3'b010 + { 1'b0, i_hexbits[2:1] };
			else // long write or set address
				cw_len <= 3'h6;
		end else if (w_stb)
			cw_len <= 0;

	always @(posedge i_clk)
		o_stb <= w_stb;

endmodule

