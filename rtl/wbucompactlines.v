////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbucompactlines.v
//
// Project:	FPGA library
//
// Purpose:	Removes 'end of line' characters placed at the end of every
//		deworded word, unless we're idle or the line is too long.
//	This helps to format the output nicely to fit in an 80-character
//	display, should you need to do so for debugging.
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
// When to apply a new line?
//	When no prior new line exists
//		or when prior line length exceeds (72)
//	Between codewords (need inserted newline)
//	When bus has become idle (~wb_cyc)&&(~busys)
//
// So, if every codeword ends in a newline, what we
// really need to do is to remove newlines.  Thus, if
// i_stb goes high while i_tx_busy, we skip the newline
// unless the line is empty.  ... But i_stb will always
// go high while i_tx_busy.  How about if the line
// length exceeds 72, we do nothing, but record the
// last word.  If the last word was a  <incomplete-thought>
//
//
module	wbucompactlines(i_clk, i_stb, i_nl_hexbits, o_stb, o_nl_hexbits,
		i_bus_busy, i_tx_busy, o_busy);
	input	i_clk, i_stb;
	input	[6:0]	i_nl_hexbits;
	output	reg	o_stb;
	output	reg	[6:0]	o_nl_hexbits;
	input			i_bus_busy;
	input			i_tx_busy;
	output	wire		o_busy;

	reg	last_out_nl, last_in_nl;
	initial	last_out_nl = 1'b1;
	initial	last_in_nl = 1'b1;
	always @(posedge i_clk)
		if ((~i_tx_busy)&&(o_stb))
			last_out_nl <= (o_nl_hexbits[6]);
	always @(posedge i_clk)
		if ((i_stb)&&(~o_busy))
			last_in_nl <= (i_nl_hexbits[6]);

	// Now, let's count how long our lines are
	reg	[6:0]	linelen;
	initial	linelen = 7'h00;
	always @(posedge i_clk)
		if ((~i_tx_busy)&&(o_stb))
		begin
			if (o_nl_hexbits[6])
				linelen <= 0;
			else
				linelen <= linelen + 7'h1;
		end

	reg	full_line;
	initial	full_line = 1'b0;
	always @(posedge i_clk)
		full_line <= (linelen > 7'd72);


	// Now that we know whether or not the last character was a newline,
	// and indeed how many characters we have in any given line, we can
	// selectively remove newlines from our output stream.
	initial	o_stb = 1'b0;
	always @(posedge i_clk)
		if ((i_stb)&&(~o_busy))
		begin
			o_stb <= (full_line)||(~i_nl_hexbits[6]);
			o_nl_hexbits <= i_nl_hexbits;
		end else if (~o_busy)
		begin // Send an EOL if we are idle
			o_stb <= (~i_tx_busy)&&(~i_bus_busy)&&(~last_out_nl)&&(last_in_nl);
			o_nl_hexbits <= 7'h40;
		end else if (~i_tx_busy)
			o_stb <= 1'b0;

	reg	r_busy;
	initial	r_busy = 1'b0;
	always @(posedge i_clk)
		r_busy <= (o_stb);
	assign	o_busy = (r_busy)||(o_stb);

	/*
	output	wire	[27:0]	o_dbg;
	assign o_dbg = { o_stb, o_nl_hexbits, o_busy, r_busy, full_line, 
			i_bus_busy, linelen, i_tx_busy, i_stb, i_nl_hexbits };
	*/
endmodule
