////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbscopc.v
//
// Project:	WBScope, a wishbone hosted scope
//
// Purpose:	This scope is identical in function to the wishbone scope
//	found in wbscope, save that the output is compressed via a run-length
//	encoding scheme and that (as a result) it can only handle recording
//	31 bits at a time.  This allows the top bit to indicate the presence
//	of an 'address difference' rather than actual incoming recorded data.
//
//	Reading/decompressing the output of this scope works in this fashion:
//	Once the scope has stopped, read from the port.  Any time the high
//	order bit is set, the other 31 bits tell you how many times to repeat
//	the last value.  If the high order bit is not set, then the value
//	is a new data value.
//
//	Previous versions of the compressed scope have had some fundamental
//	flaws: 1) it was impossible to know when the trigger took place, and
//	2) if things never changed, the scope would never fill or complete
//	its capture.  These two flaws have been fixed with this release.
//
//	When dealing with a slow interface such as the PS/2 interface, or even
//	the 16x2 LCD interface, it is often true that things can change _very_
//	slowly.  They could change so slowly that the standard wishbone scope
//	doesn't work.  This scope then gives you a working scope, by sampling
//	at diverse intervals, and only capturing anything that changes within
//	those intervals.  
//
//	Indeed, I'm finding this compressed scope very valuable for evaluating
//	the timing associated with a GPS PPS and associated NMEA stream.  I
//	need to collect over a seconds worth of data, and I don't have enough
//	memory to handle one memory value per clock, yet I still want to know
//	exactly when the GPS PPS goes high, when it goes low, when I'm
//	adjusting my clock, and when the clock's PPS output goes high.  Did I
//	synchronize them well?  Oh, and when does the NMEA time string show up
//	when compared with the PPS?  All of those are valuable, but could never
//	be done if the scope wasn't compressed.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2020, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
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
module wbscopc(i_data_clk, i_ce, i_trigger, i_data,
	i_wb_clk, i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data, i_wb_sel,
	o_wb_stall, o_wb_ack, o_wb_data,
	o_interrupt);
	parameter [4:0]			LGMEM = 5'd10;
	parameter			BUSW = 32, NELM=(BUSW-1);
	parameter [0:0]			SYNCHRONOUS=1;
	parameter			HOLDOFFBITS=20;
	parameter [(HOLDOFFBITS-1):0]	DEFAULT_HOLDOFF = ((1<<(LGMEM-1))-4);
	parameter			STEP_BITS=BUSW-1;
	parameter [(STEP_BITS-1):0]	MAX_STEP= {(STEP_BITS){1'b1}};
	// The input signals that we wish to record
	input	wire			i_data_clk, i_ce, i_trigger;
	input	wire	[(NELM-1):0]	i_data;
	// The WISHBONE bus for reading and configuring this scope
	input	wire			i_wb_clk, i_wb_cyc, i_wb_stb, i_wb_we;
	input	wire			i_wb_addr; // One address line only
	input	wire	[(BUSW-1):0]	i_wb_data;
	input	wire	[(BUSW/8-1):0]	i_wb_sel;
	output	wire			o_wb_stall, o_wb_ack;
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
	reg	[2:0]	br_config;
	reg	[(HOLDOFFBITS-1):0]	br_holdoff;
	initial	br_config = 3'b0;
	initial	br_holdoff = DEFAULT_HOLDOFF;
	always @(posedge i_wb_clk)
		if ((i_wb_stb)&&(!i_wb_addr))
		begin
			if (i_wb_we)
			begin
				br_config <= { i_wb_data[31],
					i_wb_data[27],
					i_wb_data[26] };
				br_holdoff <= i_wb_data[(HOLDOFFBITS-1):0];
			end
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
	(* ASYNC_REG="TRUE" *) reg	[(HOLDOFFBITS-1):0]	holdoff_counter;

	reg		dr_stopped;
	initial	dr_stopped = 1'b0;
	initial	holdoff_counter = 0;
	always @(posedge i_data_clk)
		if (dw_reset)
			holdoff_counter <= 0;
		else if ((i_ce)&&(dr_triggered)&&(!dr_stopped))
		begin
			holdoff_counter <= holdoff_counter + 1'b1;
		end

	always @(posedge i_data_clk)
		if ((!dr_triggered)||(dw_reset))
			dr_stopped <= 1'b0;
		else if ((i_ce)&&(!dr_stopped))
		begin
			if (HOLDOFFBITS > 1) // if (i_ce)
				dr_stopped <= (holdoff_counter >= br_holdoff);
			else if (HOLDOFFBITS <= 1)
				dr_stopped <= ((i_ce)&&(dw_trigger));
		end

	localparam	DLYSTOP=5;
	reg	[(DLYSTOP-1):0]	dr_stop_pipe;
	always @(posedge i_data_clk)
		if (dw_reset)
			dr_stop_pipe <= 0;
		else if (i_ce)
			dr_stop_pipe <= { dr_stop_pipe[(DLYSTOP-2):0], dr_stopped };

	wire	dw_final_stop;
	assign	dw_final_stop = dr_stop_pipe[(DLYSTOP-1)];

	// A big part of this scope is the run length of any particular
	// data value.  Hence, when the address line (i.e. data[31])
	// is high on decompression, the run length field will record an
	// address difference.
	//
	// To implement this, we set our run length to zero any time the
	// data changes, but increment it on all other clocks.  Should the
	// address difference get to our maximum value, we let it saturate
	// rather than overflow.
	reg	[(STEP_BITS-1):0]	ck_addr;
	reg	[(NELM-1):0]		qd_data;
	reg				dr_force_write, dr_run_timeout,
					new_data;

	//
	// The "dr_force_write" logic here is designed to make sure we write
	// at least every MAX_STEP samples, and that we stop as soon as
	// we are able.  Hence, if an interface is slow
	// and idle, we'll at least prime the scope, and even if the interface
	// doesn't have enough transitions to fill our buffer, we'll at least
	// fill the buffer with repeats.
	//
	reg		dr_force_inhibit;
	initial	ck_addr = 0;
	initial	dr_force_write = 1'b0;
	always @(posedge i_data_clk)
		if (dw_reset)
		begin
			dr_force_write    <= 1'b1;
			dr_force_inhibit  <= 1'b0;
		end else if (i_ce)
		begin
			dr_force_inhibit <= (dr_force_write);
			if ((dr_run_timeout)&&(!dr_force_write)&&(!dr_force_inhibit))
				dr_force_write <= 1'b1;
			else if (((dw_trigger)&&(!dr_triggered))||(!dr_primed))
				dr_force_write <= 1'b1;
			else
				dr_force_write <= 1'b0;
		end

	//
	// Keep track of how long it has been since the last write
	//
	always @(posedge i_data_clk)
		if (dw_reset)
			ck_addr <= 0;
		else if (i_ce)
		begin
			if ((dr_force_write)||(new_data)||(dr_stopped))
				ck_addr <= 0;
			else
				ck_addr <= ck_addr + 1'b1;
		end

	always @(posedge i_data_clk)
		if (dw_reset)
			dr_run_timeout <= 1'b1;
		else if (i_ce)
			dr_run_timeout <= (ck_addr >= MAX_STEP-1'b1);

	always @(posedge i_data_clk)
		if (dw_reset)
			new_data <= 1'b1;
		else if (i_ce)
			new_data <= (i_data != qd_data);

	always @(posedge i_data_clk)
		if (i_ce)
			qd_data <= i_data;

	wire	[(BUSW-2):0]	w_data;
	generate
	if (NELM == BUSW-1)
		assign w_data = qd_data;
	else
		assign w_data = { {(BUSW-NELM-1){1'b0}}, qd_data };
	endgenerate

	//
	// To do our RLE compression, we keep track of two registers: the most
	// recent data to the device (imm_ prefix) and the data from one
	// clock ago.  This allows us to suppress writes to the scope which
	// would otherwise be two address writes in a row.
	reg	imm_adr, lst_adr; // Is this an address (1'b1) or data value?
	reg	[(BUSW-2):0]	lst_val, // Data for the scope, delayed by one
				imm_val; // Data to write to the scope
	initial	lst_adr = 1'b1;
	initial	imm_adr = 1'b1;
	always @(posedge i_data_clk)
		if (dw_reset)
		begin
			imm_val <= 31'h0;
			imm_adr <= 1'b1;
			lst_val <= 31'h0;
			lst_adr <= 1'b1;
		end else if (i_ce)
		begin
			if ((new_data)||(dr_force_write)||(dr_stopped))
			begin
				imm_val <= w_data;
				imm_adr <= 1'b0; // Last thing we wrote was data
				lst_val <= imm_val;
				lst_adr <= imm_adr;
			end else begin
				imm_val <= ck_addr; // Minimum value here is '1'
				imm_adr <= 1'b1; // This (imm) is an address
				lst_val <= imm_val;
				lst_adr <= imm_adr;
			end
		end

	//
	// Here's where we suppress writing pairs of address words to the
	// scope at once.
	//
	reg			record_ce;
	reg	[(BUSW-1):0]	r_data;
	initial			record_ce = 1'b0;
	always @(posedge i_data_clk)
		record_ce <= (i_ce)&&((!lst_adr)||(!imm_adr))&&(!dr_stop_pipe[2]);
	always @(posedge i_data_clk)
		r_data <= ((!lst_adr)||(!imm_adr))
			? { lst_adr, lst_val }
			: { {(32 - NELM){1'b0}}, qd_data };

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
		end else if (record_ce)
		begin
			// mem[waddr] <= i_data;
			waddr <= waddr + {{(LGMEM-1){1'b0}},1'b1};
			dr_primed <= (dr_primed)||(&waddr);
		end
	always @(posedge i_data_clk)
		if (record_ce)
			mem[waddr] <= r_data;


	//
	//
	//
	// Bus response
	//
	//

	//
	// Clock transfer of the status signals
	//
	wire	bw_stopped, bw_triggered, bw_primed;
	generate
	if (SYNCHRONOUS > 0)
	begin
		assign	bw_stopped   = dw_final_stop;
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
		always @(posedge i_wb_clk)
			if (bw_reset_request)
			begin
				q_oflags <= 3'h0;
				r_oflags <= 3'h0;
			end else begin
				q_oflags <= { dw_final_stop, dr_triggered, dr_primed };
				r_oflags <= q_oflags;
			end

		assign	bw_stopped   = r_oflags[2];
		assign	bw_triggered = r_oflags[1];
		assign	bw_primed    = r_oflags[0];
	end endgenerate


	//
	// Reads use the bus clock
	//
	reg	br_wb_ack, br_pre_wb_ack;
	initial	br_wb_ack = 1'b0;
	wire	bw_cyc_stb;
	assign	bw_cyc_stb = (i_wb_stb);
	initial	br_pre_wb_ack = 1'b0;
	initial	br_wb_ack = 1'b0;
	always @(posedge i_wb_clk)
	begin
		if ((bw_reset_request)
			||((bw_cyc_stb)&&(i_wb_addr)&&(i_wb_we)))
			raddr <= 0;
		else if ((bw_cyc_stb)&&(i_wb_addr)&&(!i_wb_we)&&(bw_stopped))
			raddr <= raddr + 1'b1; // Data read, when stopped

		br_pre_wb_ack <= bw_cyc_stb;
		br_wb_ack <= (br_pre_wb_ack)&&(i_wb_cyc);
	end



	reg	[(LGMEM-1):0]	this_addr;
	always @(posedge i_wb_clk)
		if ((bw_cyc_stb)&&(i_wb_addr)&&(!i_wb_we))
			this_addr <= raddr + waddr + 1'b1;
		else
			this_addr <= raddr + waddr;

	reg	[31:0]	nxt_mem;
	always @(posedge i_wb_clk)
		nxt_mem <= mem[this_addr];

	wire	[19:0]	full_holdoff;
	assign full_holdoff[(HOLDOFFBITS-1):0] = br_holdoff;
	generate if (HOLDOFFBITS < 20)
		assign full_holdoff[19:(HOLDOFFBITS)] = 0;
	endgenerate

	wire	[4:0]	bw_lgmem;
	assign		bw_lgmem = LGMEM;
	always @(posedge i_wb_clk)
		if (!i_wb_addr) // Control register read
			o_wb_data <= { bw_reset_request,
					bw_stopped,
					bw_triggered,
					bw_primed,
					bw_manual_trigger,
					bw_disable_trigger,
					(raddr == {(LGMEM){1'b0}}),
					bw_lgmem,
					full_holdoff  };
		else if (!bw_stopped) // read, prior to stopping
			o_wb_data <= {1'b0, w_data };// Violates clk tfr rules
		else // if (i_wb_addr) // Read from FIFO memory
			o_wb_data <= nxt_mem; // mem[raddr+waddr];

	assign	o_wb_stall = 1'b0;
	assign	o_wb_ack = (i_wb_cyc)&&(br_wb_ack);

	reg	br_level_interrupt;
	initial	br_level_interrupt = 1'b0;
	assign	o_interrupt = (bw_stopped)&&(!bw_disable_trigger)
					&&(!br_level_interrupt);
	always @(posedge i_wb_clk)
	if ((bw_reset_complete)||(bw_reset_request))
		br_level_interrupt<= 1'b0;
	else
		br_level_interrupt<= (bw_stopped)&&(!bw_disable_trigger);

	// Make Verilator happy
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, i_wb_data[30:28], i_wb_data[25:HOLDOFFBITS],
			i_wb_sel };
	// verilator lint_on  UNUSED

endmodule
