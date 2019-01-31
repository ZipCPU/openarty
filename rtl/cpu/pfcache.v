////////////////////////////////////////////////////////////////////////////////
//
// Filename:	pfcache.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	Keeping our CPU fed with instructions, at one per clock and
//		with only a minimum number stalls.  The entire cache may also
//	be cleared (if necessary).
//
//	This logic is driven by a couple realities:
//	1. It takes a clock to read from a block RAM address, and hence a clock
//		to read from the cache.
//	2. It takes another clock to check that the tag matches
//
//		Our goal will be to avoid this second check if at all possible.
//		Hence, we'll test on the clock of any given request whether
//		or not the request matches the last tag value, and on the next
//		clock whether it new tag value (if it has changed).  Hence,
//		for anything found within the cache, there will be a one
//		cycle delay on any branch.
//
//
//	Address Words are separated into three components:
//	[ Tag bits ] [ Cache line number ] [ Cache position w/in the line ]
//
//	On any read from the cache, only the second two components are required.
//	On any read from memory, the first two components will be fixed across
//	the bus, and the third component will be adjusted from zero to its
//	maximum value.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2019, Gisselquist Technology, LLC
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
module	pfcache(i_clk, i_reset, i_new_pc, i_clear_cache,
			// i_early_branch, i_from_addr,
			i_stall_n, i_pc, o_insn, o_pc, o_valid,
		o_wb_cyc, o_wb_stb, o_wb_we, o_wb_addr, o_wb_data,
			i_wb_ack, i_wb_stall, i_wb_err, i_wb_data,
			o_illegal
		);
	parameter	LGCACHELEN = 12, ADDRESS_WIDTH=30,
			LGLINES=6; // Log of the number of separate cache lines
	localparam	CACHELEN=(1<<LGCACHELEN); //Wrd Size of our cache memory
	localparam	CW=LGCACHELEN;	// Short hand for LGCACHELEN
	localparam	LS=LGCACHELEN-LGLINES; // Size of a cache line
	localparam	BUSW = 32;	// Number of data lines on the bus
	localparam	AW=ADDRESS_WIDTH; // Shorthand for ADDRESS_WIDTH
	//
	input	wire			i_clk, i_reset;
	//
	// The interface with the rest of the CPU
	input	wire			i_new_pc;
	input	wire			i_clear_cache;
	input	wire			i_stall_n;
	input	wire	[(AW+1):0]	i_pc;
	output	wire	[(BUSW-1):0]	o_insn;
	output	wire	[(AW+1):0]	o_pc;
	output	wire			o_valid;
	//
	// The wishbone bus interface
	output	reg			o_wb_cyc, o_wb_stb;
	output	wire			o_wb_we;
	output	reg	[(AW-1):0]	o_wb_addr;
	output	wire	[(BUSW-1):0]	o_wb_data;
	//
	input	wire			i_wb_ack, i_wb_stall, i_wb_err;
	input	wire	[(BUSW-1):0]	i_wb_data;
	//
	// o_illegal will be true if this instruction was the result of a
	// bus error (This is also part of the CPU interface)
	output	reg			o_illegal;

	// Fixed bus outputs: we read from the bus only, never write.
	// Thus the output data is ... irrelevant and don't care.  We set it
	// to zero just to set it to something.
	assign	o_wb_we = 1'b0;
	assign	o_wb_data = 0;

	wire			r_v;
	reg	[(BUSW-1):0]	cache	[0:((1<<CW)-1)];
	reg	[(AW-CW-1):0]	cache_tags	[0:((1<<(LGLINES))-1)];
	reg	[((1<<(LGLINES))-1):0]	valid_mask;

	reg			r_v_from_pc, r_v_from_last, r_new_request;
	reg			rvsrc;
	wire			w_v_from_pc, w_v_from_last;
	reg	[(AW+1):0]	lastpc;
	reg	[(CW-1):0]	wraddr;
	reg	[(AW-1):CW]	tagvalipc, tagvallst;
	wire	[(AW-1):CW]	tagval;
	wire	[(AW-1):LS]	lasttag;
	reg			illegal_valid;
	reg	[(AW-1):LS]	illegal_cache;

	// initial	o_i = 32'h76_00_00_00;	// A NOOP instruction
	// initial	o_pc = 0;
	reg	[(BUSW-1):0]	r_pc_cache, r_last_cache;
	reg	[(AW+1):0]	r_pc, r_lastpc;
	reg			isrc;
	reg	[1:0]		delay;
	reg			svmask, last_ack, needload, last_addr,
				bus_abort;
	reg	[(LGLINES-1):0]	saddr;

	wire			w_advance;
	assign	w_advance = (i_new_pc)||((r_v)&&(i_stall_n));

	/////////////////////////////////////////////////
	//
	// Read the instruction from the cache
	//
	/////////////////////////////////////////////////
	//
	//
	// We'll read two values from the cache, the first is the value if
	// i_pc contains the address we want, the second is the value we'd read
	// if lastpc (i.e. $past(i_pc)) was the address we wanted.
	initial	r_pc = 0;
	initial	r_lastpc = 0;
	always @(posedge i_clk)
	begin
		// We don't have the logic to select what to read, we must
		// read both the value at i_pc and lastpc.  cache[i_pc] is
		// the value we return if the last cache request was in the
		// cache on the last clock, cacne[lastpc] is the value we
		// return if we've been stalled, weren't valid, or had to wait
		// a clock or two.
		//
		// Part of the issue here is that i_pc is going to increment
		// on this clock before we know whether or not the cache entry
		// we've just read is valid.  We can't stop this.  Hence, we
		// need to read from the lastpc entry.
		//
		//
		// Here we keep track of which answer we want/need.
		// If we reported a valid value to the CPU on the last clock,
		// and the CPU wasn't stalled, then we want to use i_pc.
		// Likewise if the CPU gave us an i_new_pc request, then we'll
		// want to return the value associated with reading the cache
		// at i_pc.
		isrc <= w_advance;

		// Here we read both cache entries, at i_pc and lastpc.
		// We'll select from among these cache possibilities on the
		// next clock
		r_pc_cache <= cache[i_pc[(CW+1):2]];
		r_last_cache <= cache[lastpc[(CW+1):2]];
		//
		// Let's also register(delay) the r_pc and r_lastpc values
		// for the next clock, so we can accurately report the address
		// of the cache value we just looked up.
		r_pc <= i_pc;
		r_lastpc <= lastpc;
	end

	// On our next clock, our result with either be the registered i_pc
	// value from the last clock (if isrc), otherwise r_lastpc
	assign	o_pc  = (isrc) ? r_pc : r_lastpc;
	// The same applies for determining what the next output instruction
	// will be.  We just read it in the last clock, now we just need to
	// select between the two possibilities we just read.
	assign	o_insn= (isrc) ? r_pc_cache : r_last_cache;


	/////////////////////////////////////////////////
	//
	// Read the tag value associated with this tcache line
	//
	/////////////////////////////////////////////////
	//
	//

	//
	// Read the tag value associated with this i_pc value
	initial	tagvalipc = 0;
	always @(posedge i_clk)
		tagvalipc <= cache_tags[i_pc[(CW+1):LS+2]];


	//
	// Read the tag value associated with the lastpc value, from what
	// i_pc was when we could not tell if this value was in our cache or
	// not, or perhaps from when we determined that i was not in the cache.
	initial	tagvallst = 0;
	always @(posedge i_clk)
		tagvallst <= cache_tags[lastpc[(CW+1):LS+2]];

	// Select from between these two values on the next clock
	assign	tagval = (isrc)?tagvalipc : tagvallst;

	// i_pc will only increment when everything else isn't stalled, thus
	// we can set it without worrying about that.   Doing this enables
	// us to work in spite of stalls.  For example, if the next address
	// isn't valid, but the decoder is stalled, get the next address
	// anyway.
	initial	lastpc = 0;
	always @(posedge i_clk)
	if (w_advance)
		lastpc <= i_pc;

	assign	lasttag = lastpc[(AW+1):LS+2];

	/////////////////////////////////////////////////
	//
	// Use the tag value to determine if our output instruction will be
	// valid.
	//
	/////////////////////////////////////////////////
	//
	//
	assign	w_v_from_pc = ((i_pc[(AW+1):LS+2] == lasttag)
				&&(tagval == i_pc[(AW+1):CW+2])
				&&(valid_mask[i_pc[(CW+1):LS+2]]));
	assign	w_v_from_last = ((tagval == lastpc[(AW+1):CW+2])
				&&(valid_mask[lastpc[(CW+1):LS+2]]));

	initial	delay = 2'h3;
	always @(posedge i_clk)
	if ((i_reset)||(i_clear_cache)||(w_advance))
	begin
		// Source our valid signal from i_pc
		rvsrc <= 1'b1;
		// Delay at least two clocks before declaring that
		// we have an invalid result.  This will give us time
		// to check the tag value of what's in the cache.
		delay <= 2'h2;
	end else if ((!r_v)&&(!o_illegal)) begin
		// If we aren't sourcing our valid signal from the
		// i_pc clock, then we are sourcing it from the
		// lastpc clock (one clock later).  If r_v still
		// isn't valid, we may need to make a bus request.
		// Apply our timer and timeout.
		rvsrc <= 1'b0;

		// Delay is two once the bus starts, in case the
		// bus transaction needs to be restarted upon completion
		// This might happen if, after we start loading the
		// cache, we discover a branch.  The cache load will
		// still complete, but the branches address needs to be
		// the onen we jump to.  This may mean we need to load
		// the cache twice.
		if (o_wb_cyc)
			delay <= 2'h2;
		else if (delay != 0)
			delay <= delay + 2'b11; // i.e. delay -= 1;
	end else begin
		// After sourcing our output from i_pc, if it wasn't
		// accepted, source the instruction from the lastpc valid
		// determination instead
		rvsrc <= 1'b0;
		if (o_illegal)
			delay <= 2'h2;
	end

	wire	w_invalidate_result;
	assign	w_invalidate_result = (i_reset)||(i_clear_cache);

	reg	r_prior_illegal;
	initial	r_prior_illegal = 0;
	initial	r_new_request = 0;
	initial	r_v_from_pc = 0;
	initial	r_v_from_last = 0;
	always @(posedge i_clk)
	begin
		r_new_request <= w_invalidate_result;
		r_v_from_pc   <= (w_v_from_pc)&&(!w_invalidate_result)
					&&(!o_illegal);
		r_v_from_last <= (w_v_from_last)&&(!w_invalidate_result);

		r_prior_illegal <= (o_wb_cyc)&&(i_wb_err);
	end

	// Now use rvsrc to determine which of the two valid flags we'll be
	// using: r_v_from_pc (the i_pc address), or r_v_from_last (the lastpc
	// address)
	assign	r_v = ((rvsrc)?(r_v_from_pc):(r_v_from_last))&&(!r_new_request);
	assign	o_valid = (((rvsrc)?(r_v_from_pc):(r_v_from_last))
			||(o_illegal))
			&&(!i_new_pc)&&(!r_prior_illegal);

	/////////////////////////////////////////////////
	//
	// If the instruction isn't in our cache, then we need to load
	// a new cache line from memory.
	//
	/////////////////////////////////////////////////
	//
	//
	initial	needload = 1'b0;
	always @(posedge i_clk)
	if ((i_clear_cache)||(o_wb_cyc))
		needload <= 1'b0;
	else if ((w_advance)&&(!o_illegal))
		needload <= 1'b0;
	else
		needload <= (delay==0)&&(!w_v_from_last)
			// Prevent us from reloading an illegal address
			// (i.e. one that produced a bus error) over and over
			// and over again
			&&((!illegal_valid)
				||(lastpc[(AW+1):LS+2] != illegal_cache));

	//
	// Working from the rule that you want to keep complex logic out of
	// a state machine if possible, we calculate a "last_stb" value one
	// clock ahead of time.  Hence, any time a request is accepted, if
	// last_stb is also true we'll know we need to drop the strobe line,
	// having finished requesting a complete cache  line.
	initial	last_addr = 1'b0;
	always @(posedge i_clk)
	if (!o_wb_cyc)
		last_addr <= 1'b0;
	else if ((o_wb_addr[(LS-1):1] == {(LS-1){1'b1}})
			&&((!i_wb_stall)|(o_wb_addr[0])))
		last_addr <= 1'b1;

	//
	// "last_ack" is almost identical to last_addr, save that this
	// will be true on the same clock as the last acknowledgment from the
	// bus.  The state machine logic will use this to determine when to
	// get off the bus and end the wishbone bus cycle.
	initial	last_ack = 1'b0;
	always @(posedge i_clk)
		last_ack <= (o_wb_cyc)&&(
				(wraddr[(LS-1):1]=={(LS-1){1'b1}})
				&&((wraddr[0])||(i_wb_ack)));

	initial	bus_abort = 1'b0;
	always @(posedge i_clk)
	if (!o_wb_cyc)
		bus_abort <= 1'b0;
	else if ((i_clear_cache)||(i_new_pc))
		bus_abort <= 1'b1;

	//
	// Here's the difficult piece of state machine logic--the part that
	// determines o_wb_cyc and o_wb_stb.  We've already moved most of the
	// complicated logic off of this statemachine, calculating it one cycle
	// early.  As a result, this is a fairly easy piece of logic.
	initial	o_wb_cyc  = 1'b0;
	initial	o_wb_stb  = 1'b0;
	always @(posedge i_clk)
	if ((i_reset)||(i_clear_cache))
	begin
		o_wb_cyc <= 1'b0;
		o_wb_stb <= 1'b0;
	end else if (o_wb_cyc)
	begin
		if (i_wb_err)
			o_wb_stb <= 1'b0;
		else if ((o_wb_stb)&&(!i_wb_stall)&&(last_addr))
			o_wb_stb <= 1'b0;

		if (((i_wb_ack)&&(last_ack))||(i_wb_err))
			o_wb_cyc <= 1'b0;

	end else if ((needload)&&(!i_new_pc))
	begin
		o_wb_cyc  <= 1'b1;
		o_wb_stb  <= 1'b1;
	end

	// If we are reading from this cache line, then once we get the first
	// acknowledgement, this cache line has the new tag value
	always @(posedge i_clk)
	if ((o_wb_cyc)&&(i_wb_ack))
		cache_tags[o_wb_addr[(CW-1):LS]] <= o_wb_addr[(AW-1):CW];


	// On each acknowledgment, increment the address we use to write into
	// our cache.  Hence, this is the write address into our cache block
	// RAM.
	initial	wraddr    = 0;
	always @(posedge i_clk)
	if ((o_wb_cyc)&&(i_wb_ack)&&(!last_ack))
		wraddr <= wraddr + 1'b1;
	else if (!o_wb_cyc)
		wraddr <= { lastpc[(CW+1):LS+2], {(LS){1'b0}} };

	//
	// The wishbone request address.  This has meaning anytime o_wb_stb
	// is active, and needs to be incremented any time an address is
	// accepted--WITH THE EXCEPTION OF THE LAST ADDRESS.  We need to keep
	// this steady for that last address, unless the last address returns
	// a bus error.  In that case, the whole cache line will be marked as
	// invalid--but we'll need the value of this register to know how
	// to do that propertly.
	initial	o_wb_addr = {(AW){1'b0}};
	always @(posedge i_clk)
	if ((o_wb_stb)&&(!i_wb_stall)&&(!last_addr))
		o_wb_addr[(LS-1):0] <= o_wb_addr[(LS-1):0]+1'b1;
	else if (!o_wb_cyc)
		o_wb_addr <= { lastpc[(AW+1):LS+2], {(LS){1'b0}} };

	// Since it is impossible to initialize an array, our cache will start
	// up cache uninitialized.  We'll also never get a valid ack without
	// cyc being active, although we might get one on the clock after
	// cyc was active--so we need to test and gate on whether o_wb_cyc
	// is true.
	//
	// wraddr will advance forward on every clock cycle where ack is true,
	// hence we don't need to check i_wb_ack here.  This will work because
	// multiple writes to the same address, ending with a valid write,
	// will always yield the valid write's value only after our bus cycle
	// is over.
	always @(posedge i_clk)
	if (o_wb_cyc)
		cache[wraddr] <= i_wb_data;

	// VMask ... is a section loaded?
	// Note "svmask".  It's purpose is to delay the valid_mask setting by
	// one clock, so that we can insure the right value of the cache is
	// loaded before declaring that the cache line is valid.  Without
	// this, the cache line would get read, and the instruction would
	// read from the last cache line.
	initial	valid_mask = 0;
	initial	svmask = 1'b0;
	always @(posedge i_clk)
	if ((i_reset)||(i_clear_cache))
	begin
		valid_mask <= 0;
		svmask<= 1'b0;
	end else begin
		svmask <= ((o_wb_cyc)&&(i_wb_ack)&&(last_ack)&&(!bus_abort));

		if (svmask)
			valid_mask[saddr] <= (!bus_abort);
		if ((!o_wb_cyc)&&(needload))
			valid_mask[lastpc[(CW+1):LS+2]] <= 1'b0;
	end

	always @(posedge i_clk)
	if ((o_wb_cyc)&&(i_wb_ack))
		saddr <= wraddr[(CW-1):LS];

	/////////////////////////////////////////////////
	//
	// Handle bus errors here.  If a bus read request
	// returns an error, then we'll mark the entire
	// line as having a (valid) illegal value.
	//
	/////////////////////////////////////////////////
	//
	//
	//
	//
	initial	illegal_cache = 0;
	initial	illegal_valid = 0;
	always @(posedge i_clk)
	if ((i_reset)||(i_clear_cache))
	begin
		illegal_cache <= 0;
		illegal_valid <= 0;
	end else if ((o_wb_cyc)&&(i_wb_err))
	begin
		illegal_cache <= o_wb_addr[(AW-1):LS];
		illegal_valid <= 1'b1;
	end

	initial o_illegal = 1'b0;
	always @(posedge i_clk)
	if ((i_reset)||(i_clear_cache)||(i_new_pc))
		o_illegal <= 1'b0;
	else if ((o_illegal)||((o_valid)&&(i_stall_n)))
		o_illegal <= 1'b0;
	else
		o_illegal <= (illegal_valid)
			&&(illegal_cache == lastpc[(AW+1):LS+2]);

`ifdef	FORMAL
// Formal properties for this module are maintained elsewhere
`endif	// FORMAL
endmodule
