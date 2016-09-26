///////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbscope.v
//
// Project:	FPGA Library of Routines
//
// Purpose:	This is a generic/library routine for providing a bus accessed
//		'scope' or (perhaps more appropriately) a bus accessed logic
//		analyzer.  The general operation is such that this 'scope' can
//		record and report on any 32 bit value transiting through the
//		FPGA.  Once started and reset, the scope records a copy of the
//		input data every time the clock ticks with the circuit enabled.
//		That is, it records these values up until the trigger.  Once
//		the trigger goes high, the scope will record for bw_holdoff
//		more counts before stopping.  Values may then be read from the
//		buffer, oldest to most recent.  After reading, the scope may
//		then be reset for another run.
//
//		In general, therefore, operation happens in this fashion:
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
//		8. -- one value per i_rd&i_clk
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
///////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015, Gisselquist Technology, LLC
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
// with this program.  (It's in the $(ROOT)/doc directory, run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
/////////////////////////////////////////////////////////////////////////////
module wbscope(i_clk, i_ce, i_trigger, i_data,
	i_wb_clk, i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data,
	o_wb_ack, o_wb_stall, o_wb_data,
	o_interrupt);
	parameter	LGMEM = 5'd10, BUSW = 32, SYNCHRONOUS=1;
	// The input signals that we wish to record
	input				i_clk, i_ce, i_trigger;
	input		[(BUSW-1):0]	i_data;
	// The WISHBONE bus for reading and configuring this scope
	input				i_wb_clk, i_wb_cyc, i_wb_stb, i_wb_we;
	input				i_wb_addr; // One address line only
	input		[(BUSW-1):0]	i_wb_data;
	output	wire			o_wb_ack, o_wb_stall;
	output	reg	[(BUSW-1):0]	o_wb_data;
	// And, finally, for a final flair --- offer to interrupt the CPU after
	// our trigger has gone off.  This line is equivalent to the scope 
	// being stopped.  It is not maskable here.
	output	wire			o_interrupt;

	reg	[(LGMEM-1):0]	raddr;
	reg	[(BUSW-1):0]	mem[0:((1<<LGMEM)-1)];

	// Our status/config register
	wire		bw_reset_request, bw_manual_trigger,
			bw_disable_trigger, bw_reset_complete;
	reg	[22:0]	br_config;
	wire	[19:0]	bw_holdoff;
	initial	br_config = ((1<<(LGMEM-1))-4);
	always @(posedge i_wb_clk)
		if ((i_wb_cyc)&&(i_wb_stb)&&(~i_wb_addr))
		begin
			if (i_wb_we)
				br_config <= { i_wb_data[31],
					(i_wb_data[27]), 
					i_wb_data[26],
					i_wb_data[19:0] };
		end else if (bw_reset_complete)
			br_config[22] <= 1'b1;
	assign	bw_reset_request   = (~br_config[22]);
	assign	bw_manual_trigger  = (br_config[21]);
	assign	bw_disable_trigger = (br_config[20]);
	assign	bw_holdoff         = br_config[19:0];

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
		reg	[2:0]	r_iflags, q_iflags;

		// Resets are synchronous to the bus clock, not the data clock
		// so do a clock transfer here
		initial	q_iflags = 3'b000;
		initial	r_reset_complete = 1'b0;
		always @(posedge i_clk)
		begin
			q_iflags <= { bw_reset_request, bw_manual_trigger, bw_disable_trigger };
			r_iflags <= q_iflags;
			r_reset_complete <= (dw_reset);
		end

		assign	dw_reset = r_iflags[2];
		assign	dw_manual_trigger = r_iflags[1];
		assign	dw_disable_trigger = r_iflags[0];

		reg	q_reset_complete, qq_reset_complete;
		// Pass an acknowledgement back from the data clock to the bus
		// clock that the reset has been accomplished
		initial	q_reset_complete = 1'b0;
		initial	qq_reset_complete = 1'b0;
		always @(posedge i_wb_clk)
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
	// WISHBONE-clk, or i_wb_clk clock.
	reg	dr_triggered, dr_primed;
	wire	dw_trigger;
	assign	dw_trigger = (dr_primed)&&(
				((i_trigger)&&(~dw_disable_trigger))
				||(dr_triggered)
				||(dw_manual_trigger));
	initial	dr_triggered = 1'b0;
	always @(posedge i_clk)
		if (dw_reset)
			dr_triggered <= 1'b0;
		else if ((i_ce)&&(dw_trigger))
			dr_triggered <= 1'b1;

	//
	// Determine when memory is full and capture is complete
	//
	// Writes take place on the data clock
	reg		dr_stopped;
	reg	[19:0]	counter;	// This is unsigned
	initial	dr_stopped = 1'b0;
	initial	counter = 20'h0000;
	always @(posedge i_clk)
		if (dw_reset)
		begin
			counter <= 0;
			dr_stopped <= 1'b0;
		end else if ((i_ce)&&(dr_triggered))
		begin // MUST BE a < and not <=, so that we can keep this w/in
			// 20 bits.  Else we'd need to add a bit to comparison 
			// here.
			if (counter < bw_holdoff)
				counter <= counter + 20'h01;
			else
				dr_stopped <= 1'b1;
		end

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
	always @(posedge i_clk)
		if (dw_reset) // For simulation purposes, supply a valid value
		begin
			waddr <= 0; // upon reset.
			dr_primed <= 1'b0;
		end else if ((i_ce)&&((~dr_triggered)||(counter < bw_holdoff)))
		begin
			// mem[waddr] <= i_data;
			waddr <= waddr + {{(LGMEM-1){1'b0}},1'b1};
			dr_primed <= (dr_primed)||(&waddr);
		end
	always @(posedge i_clk)
		if ((i_ce)&&((~dr_triggered)||(counter < bw_holdoff)))
			mem[waddr] <= i_data;

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
		reg	[2:0]	q_oflags, r_oflags;
		initial	q_oflags = 3'h0;
		initial	r_oflags = 3'h0;
		always @(posedge i_wb_clk)
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
	reg	br_wb_ack;
	initial	br_wb_ack = 1'b0;
	wire	bw_cyc_stb;
	assign	bw_cyc_stb = ((i_wb_cyc)&&(i_wb_stb));
	always @(posedge i_wb_clk)
	begin
		if ((bw_reset_request)
			||((bw_cyc_stb)&&(i_wb_addr)&&(i_wb_we)))
			raddr <= 0;
		else if ((bw_cyc_stb)&&(i_wb_addr)&&(~i_wb_we)&&(bw_stopped))
			raddr <= raddr + {{(LGMEM-1){1'b0}},1'b1}; // Data read, when stopped

		if ((bw_cyc_stb)&&(~i_wb_we))
		begin // Read from the bus
			br_wb_ack <= 1'b1;
		end else if ((bw_cyc_stb)&&(i_wb_we))
			// We did this write above
			br_wb_ack <= 1'b1;
		else // Do nothing if either i_wb_cyc or i_wb_stb are low
			br_wb_ack <= 1'b0;
	end

	reg	[31:0]	nxt_mem;
	always @(posedge i_wb_clk)
		nxt_mem <= mem[raddr+waddr+
			(((bw_cyc_stb)&&(i_wb_addr)&&(~i_wb_we)) ?
				{{(LGMEM-1){1'b0}},1'b1} : { (LGMEM){1'b0}} )];

	wire	[4:0]	bw_lgmem;
	assign		bw_lgmem = LGMEM;
	always @(posedge i_wb_clk)
		if (~i_wb_addr) // Control register read
			o_wb_data <= { bw_reset_request,
					bw_stopped,
					bw_triggered,
					bw_primed,
					bw_manual_trigger,
					bw_disable_trigger,
					(raddr == {(LGMEM){1'b0}}),
					bw_lgmem,
					bw_holdoff  };
		else if (~bw_stopped) // read, prior to stopping
			o_wb_data <= i_data;
		else // if (i_wb_addr) // Read from FIFO memory
			o_wb_data <= nxt_mem; // mem[raddr+waddr];

	assign	o_wb_stall = 1'b0;
	assign	o_wb_ack = (i_wb_cyc)&&(br_wb_ack);

	reg	br_level_interrupt;
	initial	br_level_interrupt = 1'b0;
	assign	o_interrupt = (bw_stopped)&&(~bw_disable_trigger)
					&&(~br_level_interrupt);
	always @(posedge i_wb_clk)
		if ((bw_reset_complete)||(bw_reset_request))
			br_level_interrupt<= 1'b0;
		else
			br_level_interrupt<= (bw_stopped)&&(~bw_disable_trigger);

endmodule
