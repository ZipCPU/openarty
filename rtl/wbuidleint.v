////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbuidleint.v
//
// Project:	FPGA library
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
module	wbuidleint(i_clk, i_stb, i_codword, i_cyc, i_busy, i_int,
		o_stb, o_codword, o_busy,
		i_tx_busy);
	input			i_clk;
	// From the FIFO following the bus executor
	input			i_stb;
	input		[35:0]	i_codword;
	// From the rest of the board
	input			i_cyc, i_busy, i_int;
	// To the next stage
	output	reg		o_stb;
	output	reg	[35:0]	o_codword;
	output	reg		o_busy;
	// Is the next stage busy?
	input			i_tx_busy;

	reg	int_request, int_sent;
	initial	int_request = 1'b0;
	always @(posedge i_clk)
		if((o_stb)&&(~i_tx_busy)&&(o_codword[35:30]==6'h4))
			int_request <= i_int;
		else
			int_request <= (int_request)||(i_int);


	// Now, for the idle counter
	wire		idle_expired;
	reg		idle_state;
	reg	[35:0]	idle_counter;
	initial	idle_counter = 36'h0000;
	always @(posedge i_clk)
		if ((i_stb)||(o_stb))
			idle_counter <= 36'h000;
		else if (~idle_counter[35])
			idle_counter <= idle_counter + 36'd43;

	initial	idle_state = 1'b0;
	always @(posedge i_clk)
		if ((o_stb)&&(~i_tx_busy)&&(o_codword[35:31]==5'h0))
			idle_state <= 1'b1;
		else if (~idle_counter[35])
			idle_state <= 1'b0;

	assign	idle_expired = (~idle_state)&&(idle_counter[35]);

	initial	o_stb  = 1'b0;
	initial	o_busy = 1'b0;
	always @(posedge i_clk)
		if ((o_stb)&&(i_tx_busy))
		begin
			o_busy <= 1'b1;
		end else if (o_stb) // and not i_tx_busy
		begin
			// Idle one clock before becoming not busy
			o_stb <= 1'b0;
			o_busy <= 1'b1;
		end else if (o_busy)
			o_busy <= 1'b0;
		else if (i_stb) // and (~o_busy)&&(~o_stb)
		begin // On a valid output, just send it out
			// We'll open this strobe, even if the transmitter
			// is busy, just 'cause we might otherwise lose it
			o_codword <= i_codword;
			o_stb <= 1'b1;
			o_busy <= 1'b1;
		end else if ((int_request)&&(~int_sent))
		begin
			o_stb <= 1'b1;
			o_codword <= { 6'h4, 30'h0000 }; // interrupt codeword
			o_busy <= 1'b1;
		end else if (idle_expired)
		begin // Strobe, if we're not writing or our
			// last command wasn't an idle
			o_stb  <= 1'b1;
			o_busy <= 1'b1;
			if (i_cyc)
				o_codword <= { 6'h1, 30'h0000 }; // idle codeword, bus busy
			else
				o_codword <= { 6'h0, 30'h0000 };
		end

	initial	int_sent = 1'b0;
	always @(posedge i_clk)
		if ((int_request)&&((~o_stb)&&(~o_busy)&&(~i_stb)))
			int_sent <= 1'b1;
		else if (~i_int)
			int_sent <= 1'b0;
endmodule
