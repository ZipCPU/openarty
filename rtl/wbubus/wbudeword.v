////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbudeword.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Once a word has come from the bus, undergone compression, had
//		idle cycles and interrupts placed in it, this routine converts
//	that word form a 36-bit single word into a series of 6-bit words
//	that can head to the output routine.  Hence, it 'deword's the value:
//	unencoding the 36-bit word encoding.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2020, Gisselquist Technology, LLC
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
`default_nettype none
//
module	wbudeword(i_clk, i_stb, i_word, i_tx_busy, o_stb, o_nl_hexbits, o_busy);
	input	wire		i_clk, i_stb;
	input	wire	[35:0]	i_word;
	input	wire		i_tx_busy;
	output	reg		o_stb;
	output	reg	[6:0]	o_nl_hexbits;
	output	reg		o_busy;


	wire	[2:0]	w_len;
	assign w_len = (i_word[35:33]==3'b000)? 3'b001
			: (i_word[35:32]==4'h2)? 3'b110
			: (i_word[35:32]==4'h3)? (3'b010+{1'b0,i_word[31:30]})
			: (i_word[35:34]==2'b01)? 3'b010
			: (i_word[35:34]==2'b10)? 3'b001
			:  3'b110;

	reg	[2:0]	r_len;
	reg	[29:0]	r_word;
	initial o_stb  = 1'b0;
	initial o_busy = 1'b0;
	initial	o_nl_hexbits = 7'h40;
	initial	r_len = 0;
	always @(posedge i_clk)
	if ((i_stb)&&(!o_busy)) // Only accept when not busy
	begin
		r_word <= i_word[29:0];
		o_nl_hexbits <= { 1'b0, i_word[35:30] }; // No newline ... yet
	end else if (!i_tx_busy)
	begin
		if (r_len > 1)
		begin
			o_nl_hexbits <= { 1'b0, r_word[29:24] };
			r_word[29:6] <= r_word[23:0];
		end else if (!o_nl_hexbits[6])
		begin
			// Place a 7'h40 between every pair of words
			o_nl_hexbits <= 7'h40;
		end
	end

	initial	o_stb = 1'b0;
	always @(posedge i_clk)
	if (i_stb && !o_busy)
		o_stb <= 1'b1;
	else if (r_len == 0 && !i_tx_busy)
		o_stb <= 1'b0;

	initial	r_len = 0;
	always @(posedge i_clk)
	if (i_stb && !o_busy)
		r_len <= w_len;
	else if (!i_tx_busy && (r_len > 0))
		r_len <= r_len - 1;

	always @(*)
		o_busy = o_stb;

`ifdef	FORMAL
// Formal properties for this module are maintained elsewhere
`endif
endmodule

