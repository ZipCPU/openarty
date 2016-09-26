///////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbscopc.v
//
// Project:	FPGA Library of Routines
//
// Purpose:	This scope is identical in function to the wishbone scope
//	found in wbscope, save that the output is compressed and that (as a
//	result) it can only handle recording 31 bits at a time.  This allows
//	the top bit to indicate an 'address difference'.   Okay, there's 
//	another difference as well: this version only works in a synchronous
//	fashion with the clock from the WB bus.  You cannot have a separate
//	bus and data clock.
//
//	Reading/decompressing the output of this scope works in this fashion:
//	Once the scope has stopped, read from the port.  Any time the high
//	order bit is set, the other 31 bits tell you how many times to repeat
//	the last value.  If the high order bit is not set, then the value
//	is a new data value.
//
//	I've provided this version of a compressed scope to OpenCores for
//	discussion purposes.  While wbscope.v works and works well by itself,
//	this compressed scope has a couple of fundamental flaw that I have
//	yet to fix.  One of them is that it is impossible to know when the
//	trigger took place.  The second problem is that it may be impossible
//	to know the state of the scope at the beginning of the buffer--should
//	the buffer begin with an address difference value instead of a data
//	value.
//
//	Ideally, the first item read out of the scope should be a data value,
//	even if the scope was skipping values to a new address at the time.
//	If it was in the middle of a skip, the next item out of the scope
//	should be the skip length.  This, though, violates the rule that there
//	are (1<<LGMEMLEN) items in the memory, and that the trigger took place
//	on the last item of memory ... so that portion of this compressed
//	scope is still to be defined.
//
//	Like I said, this version is placed here for discussion purposes,
//	not because it runs well nor because I have recognized that it has any
//	particular value (yet).
//
//	Well, I take that back.  When dealing with an interface such as the
//	PS/2 interface, or even the 16x2 LCD interface, it is often true
//	that things change _very_ slowly.  They could change so slowly that
//	the other approach to the scope doesn't work.  This then gives you
//	a working scope, by only capturing the changes.  You'll still need
//	to figure out (after the fact) when the trigge took place.  Perhaps
//	you'll wish to add the trigger as another data line, so you can find
//	when it took place in your own data?
//
//	Okay, I take that back twice: I'm finding this compressed scope very
//	valuable for evaluating the timing associated with a GPS PPS and
//	associated NMEA stream.  I need to collect over a seconds worth of
//	data, and I don't have enough memory to handle one memory value per
//	clock, yet I still want to know exactly when the GPS PPS goes high,
//	when it goes low, when I'm adjusting my clock, and when the clock's
//	PPS output goes high.  Did I synchronize them well?  Oh, and when does
//	the NMEA time string show up when compared with the PPS?  All of those
//	are valuable, but could never be done if the scope wasn't compressed.
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
//
//
module wbscopc(i_clk, i_ce, i_trigger, i_data,
	i_wb_clk, i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data,
	o_wb_ack, o_wb_stall, o_wb_data,
	o_interrupt);
	parameter	LGMEM = 5'd10, NELM=31, BUSW = 32, SYNCHRONOUS=1;
	// The input signals that we wish to record
	input				i_clk, i_ce, i_trigger;
	input		[(NELM-1):0]	i_data;
	// The WISHBONE bus for reading and configuring this scope
	input				i_wb_clk, i_wb_cyc, i_wb_stb, i_wb_we;
	input				i_wb_addr; // One address line only
	input		[(BUSW-1):0]	i_wb_data;
	output	wire			o_wb_ack, o_wb_stall;
	output	wire	[(BUSW-1):0]	o_wb_data;
	// And, finally, for a final flair --- offer to interrupt the CPU after
	// our trigger has gone off.  This line is equivalent to the scope 
	// being stopped.  It is not maskable here.
	output	wire			o_interrupt;


	// Let's first see how far we can get by cheating.  We'll use the
	// wbscope program, and suffer a lack of several features

	// When is the full scope reset?  Capture that reset bit from any
	// write.
	wire	lcl_reset;
	assign	lcl_reset = (i_wb_cyc)&&(i_wb_stb)&&(~i_wb_addr)&&(i_wb_we)
				&&(~i_wb_data[31]);

	// A big part of this scope is the 'address' of any particular
	// data value.  As of this current version, the 'address' changed
	// in definition from an absolute time (which had all kinds of
	// problems) to a difference in time.  Hence, when the address line
	// is high on decompression, the 'address' field will record an
	// address difference.
	//
	// To implement this, we set our 'address' to zero any time the
	// data changes, but increment it on all other clocks.  Should the
	// address difference get to our maximum value, we let it saturate
	// rather than overflow.
	reg	[(BUSW-2):0]	ck_addr;
	reg	[(NELM-1):0]	lst_dat;
	initial	ck_addr = 0;
	always @(posedge i_clk)
		if ((lcl_reset)||((i_ce)&&(i_data != lst_dat)))
			ck_addr <= 0;
		else if (&ck_addr)
			;	// Saturated (non-overflowing) address diff
		else
			ck_addr <= ck_addr + 1;

	wire	[(BUSW-2):0]	w_data;
	generate
	if (NELM == BUSW-1)
		assign w_data = i_data;
	else
		assign w_data = { {(BUSW-NELM-1){1'b0}}, i_data };
	endgenerate
	
	//
	// To do our compression, we keep track of two registers: the most
	// recent data to the device (imm_ prefix) and the data from one
	// clock ago.  This allows us to suppress writes to the scope which
	// would otherwise be two address writes in a row.
	reg	imm_adr, lst_adr; // Is this an address (1'b1) or data value?
	reg	[(BUSW-2):0]	lst_val, // Data for the scope, delayed by one
				imm_val; // Data to write to the scope
	initial	lst_dat = 0;
	initial	lst_adr = 1'b1;
	initial	imm_adr = 1'b1;
	always @(posedge i_clk)
		if (lcl_reset)
		begin
			imm_val <= 31'h0;
			imm_adr <= 1'b1;
			lst_val <= 31'h0;
			lst_adr <= 1'b1;
			lst_dat <= 0;
		end else if ((i_ce)&&(i_data != lst_dat))
		begin
			imm_val <= w_data;
			imm_adr <= 1'b0;
			lst_val <= imm_val;
			lst_adr <= imm_adr;
			lst_dat <= i_data;
		end else begin
			imm_val <= ck_addr; // Minimum value here is '1'
			imm_adr <= 1'b1;
			lst_val <= imm_val;
			lst_adr <= imm_adr;
		end

	//
	// Here's where we suppress writing pairs of address words to the
	// scope at once.
	//
	reg			r_ce;
	reg	[(BUSW-1):0]	r_data;
	initial			r_ce = 1'b0;
	always @(posedge i_clk)
		r_ce <= (~lst_adr)||(~imm_adr);
	always @(posedge i_clk)
		r_data <= ((~lst_adr)||(~imm_adr))
			? { lst_adr, lst_val }
			: { {(32 - NELM){1'b0}}, i_data };


	//
	// The trigger needs some extra attention, in order to keep triggers
	// that happen between events from being ignored.  
	//
	wire	w_trigger;
	assign	w_trigger = (r_trigger)||(i_trigger);

	reg	r_trigger;
	initial	r_trigger = 1'b0;
	always @(posedge i_clk)
		if (lcl_reset)
			r_trigger <= 1'b0;
		else
			r_trigger <= w_trigger;

	//
	// Call the regular wishbone scope to do all of our real work, now
	// that we've compressed the input.
	//
	wbscope	#(.SYNCHRONOUS(1), .LGMEM(LGMEM),
		.BUSW(BUSW))	cheatersscope(i_clk, r_ce, w_trigger, r_data,
		i_wb_clk, i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data,
		o_wb_ack, o_wb_stall, o_wb_data, o_interrupt);
endmodule
