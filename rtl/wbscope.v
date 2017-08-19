////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbscope.v
//
// Project:	WBScope, a wishbone hosted scope
//
// Purpose:	This is a generic/library routine for providing a bus accessed
//	'scope' or (perhaps more appropriately) a bus accessed logic analyzer.
//	The general operation is such that this 'scope' can record and report
//	on any 32 bit value transiting through the FPGA.  Once started and
//	reset, the scope records a copy of the input data every time the clock
//	ticks with the circuit enabled.  That is, it records these values up
//	until the trigger.  Once the trigger goes high, the scope will record
//	for br_holdoff more counts before stopping.  Values may then be read
//	from the buffer, oldest to most recent.  After reading, the scope may
//	then be reset for another run.
//
//	In general, therefore, operation happens in this fashion:
//		1. A reset is issued.
//		2. Recording starts, in a circular buffer, and continues until
//		3. The trigger line is asserted.
//			The scope registers the asserted trigger by setting
//			the 'o_triggered' output flag.
//		4. A counter then ticks until the last value is written
//			The scope registers that it has stopped recording by
//			setting the 'o_stopped' output flag.
//		5. The scope recording is then paused until the next reset.
//		6. While stopped, the CPU can read the data from the scope
//		7. -- oldest to most recent
//		8. -- one value per i_rd&i_data_clk
//		9. Writes to the data register reset the address to the
//			beginning of the buffer
//
//	Although the data width DW is parameterized, it is not very changable,
//	since the width is tied to the width of the data bus, as is the 
//	control word.  Therefore changing the data width would require changing
//	the interface.  It's doable, but it would be a change to the interface.
//
//	The SYNCHRONOUS parameter turns on and off meta-stability
//	synchronization.  Ideally a wishbone scope able to handle one or two
//	clocks would have a changing number of ports as this SYNCHRONOUS
//	parameter changed.  Other than running another script to modify
//	this, I don't know how to do that so ... we'll just leave it running
//	off of two clocks or not.
//
//
//	Internal to this routine, registers and wires are named with one of the
//	following prefixes:
//
//	i_	An input port to the routine
//	o_	An output port of the routine
//	br_	A register, controlled by the bus clock
//	dr_	A register, controlled by the data clock
//	bw_	A wire/net, controlled by the bus clock
//	dw_	A wire/net, controlled by the data clock
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
`default_nettype	none
//
module wbscope(i_data_clk, i_ce, i_trigger, i_data,
	i_wb_clk, i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data,
	o_wb_ack, o_wb_stall, o_wb_data,
	o_interrupt);
	parameter [4:0]			LGMEM = 5'd10;
	parameter			BUSW = 32;
	parameter [0:0]			SYNCHRONOUS=1;
	parameter		 	HOLDOFFBITS = 20;
	parameter [(HOLDOFFBITS-1):0]	DEFAULT_HOLDOFF = ((1<<(LGMEM-1))-4);
	// The input signals that we wish to record
	input	wire			i_data_clk, i_ce, i_trigger;
	input	wire	[(BUSW-1):0]	i_data;
	// The WISHBONE bus for reading and configuring this scope
	input	wire			i_wb_clk, i_wb_cyc, i_wb_stb, i_wb_we;
	input	wire			i_wb_addr; // One address line only
	input	wire	[(BUSW-1):0]	i_wb_data;
	output	wire			o_wb_ack, o_wb_stall;
	output	wire	[(BUSW-1):0]	o_wb_data;
	// And, finally, for a final flair --- offer to interrupt the CPU after
	// our trigger has gone off.  This line is equivalent to the scope 
	// being stopped.  It is not maskable here.
	output	wire			o_interrupt;

	wire	bus_clock;
	assign	bus_clock = i_wb_clk;

	///////////////////////////////////////////////////
	//
	// Decode and handle the WB bus signaling in a
	// (somewhat) portable manner
	//
	///////////////////////////////////////////////////
	//
	//
	assign	o_wb_stall = 1'b0;

	wire	read_from_data;
	assign	read_from_data = (i_wb_stb)&&(!i_wb_we)&&(i_wb_addr);

	wire	write_stb;
	assign	write_stb = (i_wb_stb)&&(i_wb_we);

	wire	write_to_control;
	assign	write_to_control = (write_stb)&&(!i_wb_addr);

	reg	read_address;
	always @(posedge bus_clock)
		read_address <= i_wb_addr;

	reg	[(LGMEM-1):0]	raddr;
	reg	[(BUSW-1):0]	mem[0:((1<<LGMEM)-1)];

	// Our status/config register
	wire		bw_reset_request, bw_manual_trigger,
			bw_disable_trigger, bw_reset_complete;
	reg	[2:0]	br_config;
	reg	[(HOLDOFFBITS-1):0]	br_holdoff;
	initial	br_config = 3'b0;
	initial	br_holdoff = DEFAULT_HOLDOFF;
	always @(posedge bus_clock)
		if (write_to_control)
		begin
			br_config <= { i_wb_data[31],
				i_wb_data[27],
				i_wb_data[26] };
			br_holdoff <= i_wb_data[(HOLDOFFBITS-1):0];
		end else if (bw_reset_complete)
			br_config[2] <= 1'b1;
	assign	bw_reset_request   = (!br_config[2]);
	assign	bw_manual_trigger  = (br_config[1]);
	assign	bw_disable_trigger = (br_config[0]);

	wire	dw_reset, dw_manual_trigger, dw_disable_trigger;
	generate
	if (SYNCHRONOUS > 0)
	begin
		assign	dw_reset = bw_reset_request;
		assign	dw_manual_trigger = bw_manual_trigger;
		assign	dw_disable_trigger = bw_disable_trigger;
		assign	bw_reset_complete = bw_reset_request;
	end else begin
		reg		r_reset_complete;
		(* ASYNC_REG = "TRUE" *) reg	[2:0]	q_iflags;
		reg	[2:0]	r_iflags;

		// Resets are synchronous to the bus clock, not the data clock
		// so do a clock transfer here
		initial	q_iflags = 3'b000;
		initial	r_reset_complete = 1'b0;
		always @(posedge i_data_clk)
		begin
			q_iflags <= { bw_reset_request, bw_manual_trigger, bw_disable_trigger };
			r_iflags <= q_iflags;
			r_reset_complete <= (dw_reset);
		end

		assign	dw_reset = r_iflags[2];
		assign	dw_manual_trigger = r_iflags[1];
		assign	dw_disable_trigger = r_iflags[0];

		(* ASYNC_REG = "TRUE" *) reg	q_reset_complete;
		reg	qq_reset_complete;
		// Pass an acknowledgement back from the data clock to the bus
		// clock that the reset has been accomplished
		initial	q_reset_complete = 1'b0;
		initial	qq_reset_complete = 1'b0;
		always @(posedge bus_clock)
		begin
			q_reset_complete  <= r_reset_complete;
			qq_reset_complete <= q_reset_complete;
		end

		assign bw_reset_complete = qq_reset_complete;
	end endgenerate

	//
	// Set up the trigger
	//
	//
	// Write with the i-clk, or input clock.  All outputs read with the
	// bus clock, or bus_clock  as we've called it here.
	reg	dr_triggered, dr_primed;
	wire	dw_trigger;
	assign	dw_trigger = (dr_primed)&&(
				((i_trigger)&&(!dw_disable_trigger))
				||(dw_manual_trigger));
	initial	dr_triggered = 1'b0;
	always @(posedge i_data_clk)
		if (dw_reset)
			dr_triggered <= 1'b0;
		else if ((i_ce)&&(dw_trigger))
			dr_triggered <= 1'b1;

	//
	// Determine when memory is full and capture is complete
	//
	// Writes take place on the data clock
	// The counter is unsigned
	(* ASYNC_REG="TRUE" *) reg	[(HOLDOFFBITS-1):0]	counter;

	reg		dr_stopped;
	initial	dr_stopped = 1'b0;
	initial	counter = 0;
	always @(posedge i_data_clk)
		if (dw_reset)
			counter <= 0;
		else if ((i_ce)&&(dr_triggered)&&(!dr_stopped))
		begin
			counter <= counter + 1'b1;
		end
	always @(posedge i_data_clk)
		if ((!dr_triggered)||(dw_reset))
			dr_stopped <= 1'b0;
		else if (HOLDOFFBITS > 1) // if (i_ce)
			dr_stopped <= (counter >= br_holdoff);
		else if (HOLDOFFBITS <= 1)
			dr_stopped <= ((i_ce)&&(dw_trigger));

	//
	//	Actually do our writes to memory.  Record, via 'primed' when
	//	the memory is full.
	//
	//	The 'waddr' address that we are using really crosses two clock
	//	domains.  While writing and changing, it's in the data clock
	//	domain.  Once stopped, it becomes part of the bus clock domain.
	//	The clock transfer on the stopped line handles the clock
	//	transfer for these signals.
	//
	reg	[(LGMEM-1):0]	waddr;
	initial	waddr = {(LGMEM){1'b0}};
	initial	dr_primed = 1'b0;
	always @(posedge i_data_clk)
		if (dw_reset) // For simulation purposes, supply a valid value
		begin
			waddr <= 0; // upon reset.
			dr_primed <= 1'b0;
		end else if ((i_ce)&&(!dr_stopped))
		begin
			// mem[waddr] <= i_data;
			waddr <= waddr + {{(LGMEM-1){1'b0}},1'b1};
			if (!dr_primed)
			begin
				//if (br_holdoff[(HOLDOFFBITS-1):LGMEM]==0)
				//	dr_primed <= (waddr >= br_holdoff[(LGMEM-1):0]);
				// else
				
					dr_primed <= (&waddr);
			end
		end

	// Delay the incoming data so that we can get our trigger
	// logic to line up with the data.  The goal is to have a
	// hold off of zero place the trigger in the last memory
	// address.
	localparam	STOPDELAY = 1;
	wire	[(BUSW-1):0]		wr_piped_data;
	generate
	if (STOPDELAY == 0)
		// No delay ... just assign the wires to our input lines
		assign	wr_piped_data = i_data;
	else if (STOPDELAY == 1)
	begin
		//
		// Delay by one means just register this once
		reg	[(BUSW-1):0]	data_pipe;
		always @(posedge i_data_clk)
			if (i_ce)
				data_pipe <= i_data;
		assign	wr_piped_data = data_pipe;
	end else begin
		// Arbitrary delay ... use a longer pipe
		reg	[(STOPDELAY*BUSW-1):0]	data_pipe;

		always @(posedge i_data_clk)
			if (i_ce)
				data_pipe <= { data_pipe[((STOPDELAY-1)*BUSW-1):0], i_data };
		assign	wr_piped_data = { data_pipe[(STOPDELAY*BUSW-1):((STOPDELAY-1)*BUSW)] };
	end endgenerate

	always @(posedge i_data_clk)
		if ((i_ce)&&(!dr_stopped))
			mem[waddr] <= wr_piped_data;

	//
	// Clock transfer of the status signals
	//
	wire	bw_stopped, bw_triggered, bw_primed;
	generate
	if (SYNCHRONOUS > 0)
	begin
		assign	bw_stopped   = dr_stopped;
		assign	bw_triggered = dr_triggered;
		assign	bw_primed    = dr_primed;
	end else begin
		// These aren't a problem, since none of these are strobe
		// signals.  They goes from low to high, and then stays high
		// for many clocks.  Swapping is thus easy--two flip flops to
		// protect against meta-stability and we're done.
		//
		(* ASYNC_REG = "TRUE" *) reg	[2:0]	q_oflags;
		reg	[2:0]	r_oflags;
		initial	q_oflags = 3'h0;
		initial	r_oflags = 3'h0;
		always @(posedge bus_clock)
			if (bw_reset_request)
			begin
				q_oflags <= 3'h0;
				r_oflags <= 3'h0;
			end else begin
				q_oflags <= { dr_stopped, dr_triggered, dr_primed };
				r_oflags <= q_oflags;
			end

		assign	bw_stopped   = r_oflags[2];
		assign	bw_triggered = r_oflags[1];
		assign	bw_primed    = r_oflags[0];
	end endgenerate

	// Reads use the bus clock
	reg	br_wb_ack, br_pre_wb_ack;
	initial	br_wb_ack = 1'b0;
	wire	bw_cyc_stb;
	assign	bw_cyc_stb = (i_wb_stb);
	initial	br_pre_wb_ack = 1'b0;
	initial	br_wb_ack = 1'b0;
	always @(posedge bus_clock)
	begin
		if ((bw_reset_request)||(write_to_control))
			raddr <= 0;
		else if ((read_from_data)&&(bw_stopped))
			raddr <= raddr + 1'b1; // Data read, when stopped

		br_pre_wb_ack <= bw_cyc_stb;
		br_wb_ack <= (br_pre_wb_ack)&&(i_wb_cyc);
	end
	assign	o_wb_ack = (i_wb_cyc)&&(br_wb_ack);

	reg	[(LGMEM-1):0]	this_addr;
	always @(posedge bus_clock)
		if (read_from_data)
			this_addr <= raddr + waddr + 1'b1;
		else
			this_addr <= raddr + waddr;

	reg	[31:0]	nxt_mem;
	always @(posedge bus_clock)
		nxt_mem <= mem[this_addr];

	wire	[19:0]	full_holdoff;
	assign full_holdoff[(HOLDOFFBITS-1):0] = br_holdoff;
	generate if (HOLDOFFBITS < 20)
		assign full_holdoff[19:(HOLDOFFBITS)] = 0;
	endgenerate

	reg	[31:0]	o_bus_data;
	wire	[4:0]	bw_lgmem;
	assign		bw_lgmem = LGMEM;
	always @(posedge bus_clock)
		if (!read_address) // Control register read
			o_bus_data <= { bw_reset_request,
					bw_stopped,
					bw_triggered,
					bw_primed,
					bw_manual_trigger,
					bw_disable_trigger,
					(raddr == {(LGMEM){1'b0}}),
					bw_lgmem,
					full_holdoff  };
		else if (!bw_stopped) // read, prior to stopping
			o_bus_data <= i_data;
		else // if (i_wb_addr) // Read from FIFO memory
			o_bus_data <= nxt_mem; // mem[raddr+waddr];

	assign	o_wb_data = o_bus_data;

	reg	br_level_interrupt;
	initial	br_level_interrupt = 1'b0;
	assign	o_interrupt = (bw_stopped)&&(!bw_disable_trigger)
					&&(!br_level_interrupt);
	always @(posedge bus_clock)
		if ((bw_reset_complete)||(bw_reset_request))
			br_level_interrupt<= 1'b0;
		else
			br_level_interrupt<= (bw_stopped)&&(!bw_disable_trigger);

	// verilator lint_off UNUSED
	// Make verilator happy
	wire	[28:0]	unused;
	assign unused = { i_wb_data[30:28], i_wb_data[25:0] };
	// verilator lint_on UNUSED
endmodule
