////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbuconsole.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This is the top level file for the entire JTAG-USB to Wishbone
//		bus conversion.  (It's also the place to start debugging, should
//	things not go as planned.)  Bytes come into this routine, bytes go out,
//	and the wishbone bus (external to this routine) is commanded in between.
//
//	You may find some strong similarities between this module and the
//	wbubus module.  They two are essentially the same, with the exception
//	that this version will also multiplex a serial port together with
//	the JTAG-USB->wishbone conversion.  Graphically:
//
//	devbus  -> TCP/IP	\			/ -> WB master
//				MUXED over USB -> UART
//	console -> TCP/IP	/			\ -> wbuconsole
//
//	Doing this, however, also entails stripping the 8th bit from the UART
//	port, so the serial port so contrived can only handle 7-bit data.
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
`default_nettype	none
//
module	wbuconsole(i_clk, i_rx_stb, i_rx_data,
		o_wb_cyc, o_wb_stb, o_wb_we, o_wb_addr, o_wb_data,
		i_wb_stall, i_wb_ack, i_wb_err, i_wb_data,
		i_interrupt,
		o_tx_stb, o_tx_data, i_tx_busy,
		i_console_stb, i_console_data, o_console_busy,
		o_console_stb, o_console_data,
		o_dbg);
	parameter	LGWATCHDOG=19,
			LGINPUT_FIFO=6,
			LGOUTPUT_FIFO=10;
	parameter [0:0] CMD_PORT_OFF_UNTIL_ACCESSED = 1'b1;
	input	wire		i_clk;
	input	wire		i_rx_stb;
	input	wire	[7:0]	i_rx_data;
	output	wire		o_wb_cyc, o_wb_stb, o_wb_we;
	output	wire	[31:0]	o_wb_addr, o_wb_data;
	input	wire		i_wb_stall, i_wb_ack, i_wb_err;
	input	wire	[31:0]	i_wb_data;
	input	wire		i_interrupt;
	output	wire		o_tx_stb;
	output	wire	[7:0]	o_tx_data;
	input	wire		i_tx_busy;
	//
	input	wire		i_console_stb;
	input	wire	[6:0]	i_console_data;
	output	wire		o_console_busy;
	//
	output	reg		o_console_stb;
	output	reg	[6:0]	o_console_data;
	//
	output	wire		o_dbg;




	always @(posedge i_clk)
		o_console_stb <= (i_rx_stb)&&(i_rx_data[7] == 1'b0);
	always @(posedge i_clk)
		o_console_data <= i_rx_data[6:0];



	reg		r_wdt_reset, cmd_port_active;

	generate if (CMD_PORT_OFF_UNTIL_ACCESSED)
	begin

		initial	cmd_port_active = 1'b0;
		always @(posedge i_clk)
		if (i_rx_stb && i_rx_data[7])
			cmd_port_active <= 1'b1;

	end else begin

		always @(*)
			cmd_port_active = 1'b1;

	end endgenerate

	// Decode ASCII input requests into WB bus cycle requests
	wire		in_stb;
	wire	[35:0]	in_word;
	wbuinput	getinput(i_clk, (i_rx_stb)&&(i_rx_data[7]), { 1'b0, i_rx_data[6:0] }, in_stb, in_word);

	wire		w_bus_busy, fifo_valid, exec_stb, w_bus_reset;
	wire	[35:0]	fifo_in_word, exec_word;

	generate
	if (LGINPUT_FIFO < 2)
	begin : NO_INCOMING_FIFO
		assign	fifo_valid   = in_stb;
		assign	fifo_in_word = in_word;
		assign	w_bus_reset = 1'b0;
	end else begin : INCOMING_FIFO

		wire	ififo_err, fifo_rd;
		assign	fifo_rd = (!w_bus_busy)&&(fifo_valid);
		assign	w_bus_reset = r_wdt_reset;
		wbufifo	#(36,LGINPUT_FIFO)
			padififo(i_clk, w_bus_reset,
				in_stb, in_word,
				fifo_rd, fifo_in_word, fifo_valid,
				ififo_err);

		// Make verilator happy
		// verilator lint_off UNUSED
		wire	unused_fifo;
		assign	unused_fifo = ififo_err;
		// verilator lint_on  UNUSED
	end endgenerate

	// Take requests in, Run the bus, send results out
	// This only works if no requests come in while requests
	// are pending.
	wbuexec	runwb(i_clk, r_wdt_reset, fifo_valid, fifo_in_word, w_bus_busy,
		o_wb_cyc, o_wb_stb, o_wb_we, o_wb_addr, o_wb_data,
		i_wb_stall, i_wb_ack, i_wb_err, i_wb_data,
		exec_stb, exec_word);

	reg		ps_full;
	reg	[7:0]	ps_data;
	wire		wbu_tx_stb;
	wire	[7:0]	wbu_tx_data;

	wire		ofifo_err;
	// wire	[30:0]	out_dbg;
	wbuoutput #(LGOUTPUT_FIFO)
		wroutput(i_clk, w_bus_reset,
			exec_stb, exec_word,
			o_wb_cyc, i_interrupt, exec_stb,
			wbu_tx_stb, wbu_tx_data,
				ps_full && cmd_port_active, ofifo_err);

	// Let's now arbitrate between the two outputs
	initial	ps_full = 1'b0;
	always @(posedge i_clk)
	if (!ps_full)
	begin
		if (cmd_port_active && wbu_tx_stb)
		begin
			ps_full <= 1'b1;
			ps_data <= { 1'b1, wbu_tx_data[6:0] };
		end else if (i_console_stb)
		begin
			ps_full <= 1'b1;
			ps_data <= { 1'b0, i_console_data[6:0] };
		end
	end else if (!i_tx_busy)
		ps_full <= 1'b0;

	assign	o_tx_stb = ps_full;
	assign	o_tx_data = ps_data;
	assign	o_console_busy = (wbu_tx_stb && cmd_port_active)||(ps_full);

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

	assign	o_dbg = w_bus_reset;

	// Make verilator happy
	// verilator lint_off UNUSED
	wire	[1:0]	unused;
	assign	unused = { ofifo_err, wbu_tx_data[7] };
	// verilator lint_on  UNUSED
endmodule

