////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbuidleint.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Creates an output for the interface, inserting idle words and
//		words indicating an interrupt has taken place into the output
//	stream.  Henceforth, the output means more than just bus transaction
//	results.  It may mean there is no bus transaction result to report,
//	or that an interrupt has taken place.
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
module	wbuidleint(i_clk, i_stb, i_codword, i_cyc, i_busy, i_int,
		o_stb, o_codword, o_busy,
		i_tx_busy);
	localparam	CW_INTERRUPT = { 6'h4, 30'h0000 }; // interrupt codeword
	localparam	CW_BUSBUSY   = { 6'h1, 30'h0000 }; // bus busy, ow idle
	localparam	CW_IDLE      = { 6'h0, 30'h0000 }; // idle codeword

	input	wire		i_clk;
	// From the FIFO following the bus executor
	input	wire		i_stb;
	input	wire	[35:0]	i_codword;
	// From the rest of the board
	input	wire		i_cyc, i_busy, i_int;
	// To the next stage
	output	reg		o_stb;
	output	reg	[35:0]	o_codword;
	output	reg		o_busy;
	// Is the next stage busy?
	input	wire		i_tx_busy;

	reg		int_request, int_sent;
	wire		idle_expired;
	reg		idle_state;
	reg	[IDLEBITS-1:0]	idle_counter;

	initial	int_request = 1'b0;
	always @(posedge i_clk)
	if (i_int)
		int_request <= 1;
	else if((o_stb)&&(!i_tx_busy)&&(o_codword[35:30]==CW_INTERRUPT[35:30]))
		int_request <= 0;

`ifdef	VERILATOR
	localparam	IDLEBITS = 22;
`else
	localparam	IDLEBITS = 31;
`endif
	// Now, for the idle counter
	initial	idle_counter = 0;
	always @(posedge i_clk)
	if ((i_stb)||(o_stb)||(i_busy))
		idle_counter <= 0;
	else if (!idle_counter[IDLEBITS-1])
		idle_counter <= idle_counter + 1;

	initial	idle_state = 1'b0;
	always @(posedge i_clk)
	if ((o_stb)&&(!i_tx_busy)&&(o_codword[35:30]==CW_IDLE[35:30]))
		// We are now idle, and can rest
		idle_state <= 1'b1;
	else if (!idle_counter[IDLEBITS-1])
		// We became active, and can rest no longer
		idle_state <= 1'b0;

	assign	idle_expired = (!idle_state)&&(idle_counter[IDLEBITS-1]);

	initial	o_stb  = 1'b0;
	always @(posedge i_clk)
	if(!o_stb || !i_tx_busy)
	begin
		if (i_stb)
		begin // On a valid output, just send it out
			// We'll open this strobe, even if the transmitter
			// is busy, just 'cause we might otherwise lose it
			o_stb <= 1'b1;
			o_codword <= i_codword;
		end else begin
			// Our indicators take a clock to reset, hence
			// we'll idle for one clock before sending either an
			// interrupt or an idle indicator.  The bus busy
			// indicator is really only ever used to let us know
			// that something's broken.
			o_stb <= (!o_stb)&&(int_request || idle_expired);

			if (int_request && !int_sent)
				o_codword[35:30] <= CW_INTERRUPT[35:30];
			else begin
				o_codword[35:30] <= CW_IDLE[35:30];
				if (i_cyc)
					o_codword[35:30] <= CW_BUSBUSY[35:30];
			end
		end
	end

	always @(*)
		o_busy = o_stb;

	initial	int_sent = 1'b0;
	always @(posedge i_clk)
	if ((int_request)&&((!o_stb)&&(!o_busy)&&(!i_stb)))
		int_sent <= 1'b1;
	else if (~i_int)
		int_sent <= 1'b0;

`ifdef	FORMAL
// Formal properties for this module are maintained elsewhere
`endif
endmodule
