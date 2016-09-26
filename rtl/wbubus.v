////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbubus.v
//
// Project:	FPGA library
//
// Purpose:	This is the top level file for the entire JTAG-USB to Wishbone
//		bus conversion.  (It's also the place to start debugging, should
//	things not go as planned.)  Bytes come into this routine, bytes go out,
//	and the wishbone bus (external to this routine) is commanded in between.
//
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
module	wbubus(i_clk, i_rx_stb, i_rx_data, 
		o_wb_cyc, o_wb_stb, o_wb_we, o_wb_addr, o_wb_data,
		i_wb_ack, i_wb_stall, i_wb_err, i_wb_data,
		i_interrupt,
		o_tx_stb, o_tx_data, i_tx_busy);
	parameter	LGWATCHDOG=19;
	input			i_clk;
	input			i_rx_stb;
	input		[7:0]	i_rx_data;
	output	wire		o_wb_cyc, o_wb_stb, o_wb_we;
	output	wire	[31:0]	o_wb_addr, o_wb_data;
	input			i_wb_ack, i_wb_stall, i_wb_err;
	input		[31:0]	i_wb_data;
	input			i_interrupt;
	output	wire		o_tx_stb;
	output	wire	[7:0]	o_tx_data;
	input			i_tx_busy;
	// output	wire		o_dbg;


	reg		r_wdt_reset;

	// Decode ASCII input requests into WB bus cycle requests
	wire		in_stb;
	wire	[35:0]	in_word;
	wbuinput	getinput(i_clk, i_rx_stb, i_rx_data, in_stb, in_word);

	wire	w_bus_busy, fifo_in_stb, exec_stb, w_bus_reset;
	wire	[35:0]	fifo_in_word, exec_word;
// `define	NO_INPUT_FIFO
`ifdef	NO_INPUT_FIFO
	assign	fifo_in_stb = in_stb;
	assign	fifo_in_word = in_word;
	assign	w_bus_reset = 1'b0;
`else
	wire		ififo_empty_n, ififo_err;
	assign	fifo_in_stb = (~w_bus_busy)&&(ififo_empty_n);
	assign	w_bus_reset = r_wdt_reset;
	wbufifo	#(36,6) padififo(i_clk, w_bus_reset,
				in_stb, in_word, fifo_in_stb, fifo_in_word,
				ififo_empty_n, ififo_err);
`endif

	// assign	o_dbg = (i_wb_ack)&&(i_wb_cyc);

	// Take requests in, Run the bus, send results out
	// This only works if no requests come in while requests
	// are pending.
	wbuexec	runwb(i_clk, r_wdt_reset, fifo_in_stb, fifo_in_word, w_bus_busy,
		o_wb_cyc, o_wb_stb, o_wb_we, o_wb_addr, o_wb_data,
		i_wb_ack, i_wb_stall, i_wb_err, i_wb_data,
		exec_stb, exec_word);

	/*
	wire	[31:0]	cyc_debug;
	assign	cyc_debug = { 1'b0, o_wb_cyc, o_wb_stb, o_wb_we, i_wb_ack, i_wb_stall,
				(i_wb_err||r_wdt_reset), o_wb_addr[14:0],
				o_wb_data[4:0], i_wb_data[4:0] };
	assign	o_dbg = cyc_debug;
	*/
	/*
	wire	[31:0]	fif_debug;
	assign	fif_debug = { 
			(exec_stb)&&(exec_word[35:30] == 6'h05),// 1
			fifo_in_stb, fifo_in_word[35:30],	// 7
			exec_stb, exec_word[35:30],		// 7
			o_wb_cyc, o_wb_stb, o_wb_we,
				i_wb_ack, i_wb_stall,		// 5
			w_bus_busy, ififo_empty_n, w_bus_reset,	// 3
			i_rx_stb, o_wb_addr[7:0] };		// 9
	assign	o_dbg = fif_debug;
	*/
			
	wire		ofifo_err;
	// wire	[30:0]	out_dbg;
	wbuoutput	wroutput(i_clk, w_bus_reset,
			exec_stb, exec_word,
			o_wb_cyc, i_interrupt, exec_stb,
			o_tx_stb, o_tx_data, i_tx_busy, ofifo_err);

	// Add in a watchdog timer to the bus
	reg	[(LGWATCHDOG-1):0]	r_wdt_timer;
	initial	r_wdt_reset = 1'b0;
	initial	r_wdt_timer = 0;
	always @(posedge i_clk)
		if ((~o_wb_cyc)||(i_wb_ack))
		begin
			r_wdt_timer <= 0;
			r_wdt_reset <= 1'b0;
		end else if (&r_wdt_timer)
		begin
			r_wdt_reset <= 1'b1;
			r_wdt_timer <= 0;
		end else begin
			r_wdt_timer <= r_wdt_timer+{{(LGWATCHDOG-1){1'b0}},1'b1};
			r_wdt_reset <= 1'b0;
		end

endmodule

