////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbucompactlines.v
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
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
`default_nettype none
// }}}
module	wbucompactlines (
		// {{{
		input	wire		i_clk, i_reset, i_stb,
		input	wire	[6:0]	i_nl_hexbits,
		output	reg		o_stb,
		output	reg	[6:0]	o_nl_hexbits,
		input	wire		i_bus_busy,
		input	wire		i_tx_busy,
		output	wire		o_busy,
		output	wire		o_active
		// }}}
	);

	// Local declarations
	// {{{
	localparam	[6:0]	MAX_LINE_LENGTH = 79;
	localparam	[6:0]	TRIGGER_LENGTH = (MAX_LINE_LENGTH-6);
	reg		last_out_nl, last_in_nl, full_line, r_busy;
	reg	[6:0]	linelen;
	// }}}

	// last_out_nl
	// {{{
	initial	last_out_nl = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		last_out_nl <= 1'b1;
	else if (!i_tx_busy && o_stb)
		last_out_nl <= o_nl_hexbits[6];
	// }}}

	// last_in_nl
	// {{{
	initial	last_in_nl = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		last_in_nl <= 1'b1;
	else if (i_stb && !o_busy)
		last_in_nl <= i_nl_hexbits[6];
	// }}}

	// linelen
	// {{{
	// Now, let's count how long our lines are
	initial	linelen = 7'h00;
	always @(posedge i_clk)
	if (i_reset)
		linelen <= 0;
	else if (!i_tx_busy && o_stb)
	begin
		if (o_nl_hexbits[6])
			linelen <= 0;
		else
			linelen <= linelen + 7'h1;
	end
	// }}}

	// full_line
	// {{{
	initial	full_line = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		full_line <= 0;
	else if (!i_tx_busy && o_stb)
	begin
		if (o_nl_hexbits[6])
			full_line <= 0;
		else
			full_line <= (linelen >= TRIGGER_LENGTH);
	end
	// }}}


	// o_stb, o_nl_hexbits
	// {{{
	// Now that we know whether or not the last character was a newline,
	// and indeed how many characters we have in any given line, we can
	// selectively remove newlines from our output stream.
	initial	o_stb = 1'b0;
	always @(posedge i_clk)
	begin
		if (i_stb && !o_busy)
		begin
			// Only accept incoming newline requests if our line is
			// already full, otherwise quietly suppress them
			o_stb <= (full_line)||(!i_nl_hexbits[6]);
			o_nl_hexbits <= i_nl_hexbits;
		end else if (!o_busy)
		begin // Send an EOL if we are idle

			// Without a request, we'll add a newline, but only if
			//	1. There's nothing coming down the channel
			//		(!bus_busy)
			//	2. What we last sent wasn't a new-line
			//	3. The last thing that came in was a newline
			// In otherwords, we can resurrect one of the newlines
			// we squashed above
			o_stb <= (!i_tx_busy)&&(!i_bus_busy)&&(!last_out_nl)&&(last_in_nl);
			o_nl_hexbits <= 7'h40;
		end else if (!i_tx_busy)
			o_stb <= 1'b0;

		if (i_reset)
			o_stb <= 1'b0;
	end
	// }}}

	// o_busy
	// {{{
	initial	r_busy = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		r_busy <= 1'b0;
	else
		r_busy <= o_stb && i_tx_busy;

	assign	o_busy = (r_busy)||(o_stb);
	// }}}

	assign	o_active = i_stb || (i_tx_busy && !last_out_nl && last_in_nl);
	/*
	output	wire	[27:0]	o_dbg;
	assign o_dbg = { o_stb, o_nl_hexbits, o_busy, r_busy, full_line,
			i_bus_busy, linelen, i_tx_busy, i_stb, i_nl_hexbits };
	*/
endmodule
