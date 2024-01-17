////////////////////////////////////////////////////////////////////////////////
//
// Filename:	dblfetch.v
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This is one step beyond the simplest instruction fetch,
//		prefetch.v.  dblfetch.v uses memory pipelining to fetch two
//	(or more) instruction words in one bus cycle.  If the CPU consumes
//	either of these before the bus cycle completes, a new request will be
//	made of the bus.  In this way, we can keep the CPU filled in spite
//	of a (potentially) slow memory operation.  The bus request will end
//	when both requests have been sent and both result locations are empty.
//
//	This routine is designed to be a touch faster than the single
//	instruction prefetch (prefetch.v), although not as fast as the
//	prefetch and cache approach found elsewhere (pfcache.v).
//
//	20180222: Completely rebuilt.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2017-2024, Gisselquist Technology, LLC
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
////////////////////////////////////////////////////////////////////////////////
//
`default_nettype	none
// }}}
module	dblfetch #(
		// {{{
		parameter		ADDRESS_WIDTH=30,	// Byte addr
		parameter		INSN_WIDTH=32,
		parameter		DATA_WIDTH = INSN_WIDTH,
		localparam		AW=ADDRESS_WIDTH,
					DW=DATA_WIDTH,
		parameter	[0:0]	OPT_LITTLE_ENDIAN = 1'b1
		// }}}
	) (
		// {{{
		input	wire			i_clk, i_reset,
		// CPU signals--from the CPU
		input	wire			i_new_pc, i_clear_cache,i_ready,
		input	wire	[AW-1:0]	i_pc,
		// ... and in return
		output	reg			o_valid,
		output	reg			o_illegal,
		output	reg [INSN_WIDTH-1:0]	o_insn,
		output	reg	[AW-1:0]	o_pc,
		// Wishbone outputs
		output	reg			o_wb_cyc, o_wb_stb,
		// verilator coverage_off
		output	wire			o_wb_we,
		// verilator coverage_on
		output	reg [AW-$clog2(DW/8)-1:0] o_wb_addr,
		// verilator coverage_off
		output	wire	[DW-1:0]	o_wb_data,
		// verilator coverage_on
		// And return inputs
		input	wire			i_wb_stall, i_wb_ack, i_wb_err,
		input	wire	[DW-1:0]	i_wb_data
		// }}}
	);

	// Local declarations
	// {{{
	wire			last_stb;
	reg			invalid_bus_cycle;

	reg	[(DW-1):0]	cache_word;
	reg			cache_valid;
	reg	[1:0]		inflight;
	reg			cache_illegal;

	wire				r_valid;
	wire	[DATA_WIDTH-1:0]	r_insn, i_wb_shifted;
	// }}}

	assign	o_wb_we = 1'b0;
	assign	o_wb_data = {(DATA_WIDTH){1'b0}};

	// o_wb_cyc, o_wb_stb
	// {{{
	initial	o_wb_cyc = 1'b0;
	initial	o_wb_stb = 1'b0;
	always @(posedge i_clk)
	if (i_reset || i_clear_cache || (o_wb_cyc && i_wb_err))
	begin : RESET_ABORT
		// {{{
		o_wb_cyc <= 1'b0;
		o_wb_stb <= 1'b0;
		// }}}
	end else if (o_wb_cyc)
	begin : END_CYCLE
		// {{{
		if (!o_wb_stb || !i_wb_stall)
			o_wb_stb <= (!last_stb);

		// Relase the bus on the second ack
		if ((!o_wb_stb || !i_wb_stall) && last_stb
			&& inflight + (o_wb_stb ? 1:0) == (i_wb_ack ? 1:0))
		begin
			o_wb_cyc <= 1'b0;
			o_wb_stb <= 1'b0;
		end

		if (i_new_pc) // || i_clear_cache)
			{ o_wb_cyc, o_wb_stb } <= 2'b0;
		// }}}
	end else if ((i_new_pc || invalid_bus_cycle)
		||(o_valid && i_ready && !r_valid && !cache_illegal))
	begin : START_CYCLE
		// {{{
		// Initiate a bus cycle if ... the last bus cycle was
		// aborted (bus error or new_pc), we've been given a
		// new PC to go get, or we just exhausted our one
		// instruction cache
		o_wb_cyc <= 1'b1;
		o_wb_stb <= 1'b1;
		// }}}
	end
	// }}}

	// inflight
	// {{{
	initial	inflight = 2'b00;
	always @(posedge i_clk)
	if (!o_wb_cyc)
		inflight <= 2'b00;
	else begin
		case({ (o_wb_stb && !i_wb_stall), i_wb_ack })
		2'b01:	inflight <= inflight - 1'b1;
		2'b10:	inflight <= inflight + 1'b1;
		// If neither ack nor request, then no change.  Likewise
		// if we have both an ack and a request, there's no change
		// in the number of requests in flight.
		default: begin end
		endcase
	end
	// }}}

	// last_stb
	// {{{
	// assign last_stb = (inflight != 2'b00)||(o_valid&& (!i_ready||r_valid));
	assign	last_stb = (!o_wb_stb||!i_wb_stall)&&(inflight
		+ (o_wb_stb ? 1:0)
		+ (o_valid&&(!i_ready || r_valid)) >= 2'b10);
	// }}}

	// invalid_bus_cycle
	// {{{
	initial	invalid_bus_cycle = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		invalid_bus_cycle <= 1'b0;
	else if (o_wb_cyc && i_new_pc)
		invalid_bus_cycle <= 1'b1;
	else if (!o_wb_cyc)
		invalid_bus_cycle <= 1'b0;
	// }}}

	// o_wb_addr
	// {{{
	initial	o_wb_addr = {(AW-$clog2(DATA_WIDTH/8)){1'b1}};
	always @(posedge i_clk)
	if (i_new_pc)
		o_wb_addr <= i_pc[AW-1:$clog2(DATA_WIDTH/8)];
	// else if (i_clear_cache)
	//	o_wb_addr <= o_pc[AW-1:$clog2(DATA_WIDTH/8)];
	else if (o_wb_stb && !i_wb_stall)
		o_wb_addr <= o_wb_addr + 1'b1;
	// }}}

	////////////////////////////////////////////////////////////////////////
	//
	// Now for the immediate output word to the CPU
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// This only applies when the bus size doesn't match the instruction
	// word size.  Here, we only support bus sizes greater than the
	// instruction word size.

	generate if (DATA_WIDTH > INSN_WIDTH)
	begin : GEN_SUBSHIFT
		// {{{
		localparam	NSHIFT = $clog2(DATA_WIDTH/INSN_WIDTH);

		reg			rg_valid;
		reg [DATA_WIDTH-1:0]	rg_insn;
		reg	[NSHIFT:0]	r_count;
		reg	[NSHIFT-1:0]	r_shift;

		// rg_valid
		// {{{
		always @(posedge i_clk)
		if (i_reset || i_new_pc) // || i_clear_cache)
			rg_valid <= 1'b0;
		else if (r_valid)
			rg_valid <= !i_ready || (r_count > 1);
		else if (!o_valid || i_ready)
		begin
			rg_valid <= 1'b0;
			if (cache_valid)
				rg_valid <= 1'b1;
			if (o_wb_cyc && i_wb_ack && !(&r_shift))
				rg_valid <= 1'b1;
		end
		// }}}

		// rg_insn
		// {{{
		always @(posedge i_clk)
		if (!o_valid || i_ready)
		begin
			if (cache_valid && !r_valid)
			begin
				if (OPT_LITTLE_ENDIAN)
					rg_insn <= cache_word >> INSN_WIDTH;
				else
					rg_insn <= cache_word << INSN_WIDTH;
			end else if (i_wb_ack && !r_valid)
			begin
				rg_insn <= i_wb_data;
				if (OPT_LITTLE_ENDIAN)
					rg_insn <= i_wb_shifted >> INSN_WIDTH;
				else
					rg_insn <= i_wb_shifted << INSN_WIDTH;
			end else begin
				if (OPT_LITTLE_ENDIAN)
					rg_insn <= rg_insn >> INSN_WIDTH;
				else
					rg_insn <= rg_insn << INSN_WIDTH;
			end
		end
		// }}}

		// r_count
		// {{{
		always @(posedge i_clk)
		if (i_reset || i_new_pc) // || i_clear_cache)
			r_count <= 0;
		else if (o_valid && i_ready && r_valid)
		begin
			r_count <= r_count - 1;
		end else if (!o_valid || (i_ready && !r_valid))
		begin
			if (cache_valid)
				r_count <= { 1'b0, {(NSHIFT){1'b1}} };
			else if (o_wb_cyc && i_wb_ack)
				r_count <= { 1'b0, ~r_shift };
		end
		// }}}

		// r_shift
		// {{{
		always @(posedge i_clk)
		if (i_new_pc)
			r_shift <= i_pc[$clog2(DW/8)-1:$clog2(INSN_WIDTH/8)];
		// else if (i_clear_cache)
		//	r_shift <= o_pc[$clog2(DW/8)-1:$clog2(INSN_WIDTH/8)];
		else if (o_wb_cyc && (i_wb_ack || i_wb_err))
			r_shift <= 0;
		// }}}

		assign	r_valid = rg_valid;
		assign	r_insn  = rg_insn;
		if (OPT_LITTLE_ENDIAN)
		begin : GEN_LITTLE_ENDIAN_SHIFT
			assign	i_wb_shifted = i_wb_data >> (r_shift * INSN_WIDTH);
		end else begin : GEN_BIGENDIAN_SHIFT
			assign	i_wb_shifted = i_wb_data << (r_shift * INSN_WIDTH);
		end

		// Keep Verilator happy
		// {{{
		// Verilator lint_off UNUSED
		wire	unused_shift;
		assign	unused_shift = &{ 1'b0,
				r_insn[DATA_WIDTH-1:INSN_WIDTH],
				i_wb_shifted[DATA_WIDTH-1:INSN_WIDTH] };
		// Verilator lint_on  UNUSED
		// }}}
		// }}}
	end else begin : NO_SUBSHIFT
		// {{{
		assign	r_valid = 1'b0;
		assign	r_insn  = {(INSN_WIDTH){1'b0}};
		assign	i_wb_shifted = i_wb_data;
		// }}}
	end endgenerate

	// o_valid
	// {{{
	initial	o_valid = 1'b0;
	always @(posedge i_clk)
	if (i_reset || i_new_pc || i_clear_cache)
		o_valid <= 1'b0;
	else if (o_wb_cyc &&(i_wb_ack || i_wb_err))
		o_valid <= 1'b1;
	else if (i_ready)
		o_valid <= cache_valid || r_valid;
	// }}}

	// o_insn
	// {{{
	always @(posedge i_clk)
	if (!o_valid || i_ready)
	begin
		if (OPT_LITTLE_ENDIAN)
		begin
			if (r_valid)
				o_insn <= r_insn[INSN_WIDTH-1:0];
			else if (cache_valid)
				o_insn <= cache_word[INSN_WIDTH-1:0];
			else
				o_insn <= i_wb_shifted[INSN_WIDTH-1:0];
		end else begin
			if (r_valid)
				o_insn <= r_insn[DW-1:DW-INSN_WIDTH];
			else if (cache_valid)
				o_insn <= cache_word[DW-1:DW-INSN_WIDTH];
			else
				o_insn <= i_wb_shifted[DW-1:DW-INSN_WIDTH];
		end
	end
	// }}}

	// o_pc
	// {{{
	always @(posedge i_clk)
	if (i_new_pc)
		o_pc <= i_pc;
	else if (o_valid && i_ready) // && !i_clear_cache
	begin
		o_pc <= 0;
		o_pc[AW-1:$clog2(INSN_WIDTH/8)]
			<= o_pc[AW-1:$clog2(INSN_WIDTH/8)] + 1'b1;
	end
	// }}}

	// o_illegal
	// {{{
	initial	o_illegal = 1'b0;
	always @(posedge i_clk)
	if (i_reset || i_new_pc || i_clear_cache)
		o_illegal <= 1'b0;
	else if (!r_valid && (!o_valid || i_ready) && !o_illegal)
	begin
		if (cache_valid)
			o_illegal <= cache_illegal;
		else if (o_wb_cyc && i_wb_err)
			o_illegal <= 1'b1;
	end
	// }}}

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Now for the output/cached word
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// cache_valid
	// {{{
	initial	cache_valid = 1'b0;
	always @(posedge i_clk)
	if ((i_reset)||(i_new_pc)||(i_clear_cache))
		cache_valid <= 1'b0;
	else begin
		if (o_valid && o_wb_cyc &&(i_wb_ack || i_wb_err))
			cache_valid <= !i_ready || r_valid;
		else if (i_ready && !r_valid)
			cache_valid <= 1'b0;
	end
	// }}}

	// cache_word
	// {{{
	always @(posedge i_clk)
	if (i_wb_ack)
		cache_word <= i_wb_data;
	// }}}

	// cache_illegal
	// {{{
	initial	cache_illegal = 1'b0;
	always @(posedge i_clk)
	if (i_reset || i_clear_cache || i_new_pc)
		cache_illegal <= 1'b0;
	// Older logic ...
	// else if ((o_wb_cyc)&&(i_wb_err)&&(o_valid)&&(!i_ready))
	//	cache_illegal <= 1'b1;
	else if (o_wb_cyc && i_wb_err)
			//  && o_valid && (!i_ready || r_valid))
		cache_illegal <= 1'b1;
	// }}}

	// }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal property section
// {{{
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef	FORMAL
// The formal properties for this design are maintained elsewhere
`endif	// FORMAL
// }}}
endmodule
//
// Usage:		(this)	(prior)	(old)  (S6)
//    Cells		374	387	585	459
//	FDRE		135	108	203	171
//	LUT1		  2	  3	  2
//	LUT2		  9	  3	  4	  5
//	LUT3		 98	 76	104	 71
//	LUT4		  2	  0	  2	  2
//	LUT5		  3	 35	 35	  3
//	LUT6		  6	  5	 10	 43
//	MUXCY		 58	 62	 93	 62
//	MUXF7		  1	  0	  2	  3
//	MUXF8		  0	  1	  1
//	RAM64X1D	  0	 32	 32	 32
//	XORCY		 60	 64	 96	 64
//
