////////////////////////////////////////////////////////////////////////////////
//
// Filename:	prefetch.v
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This is a very simple instruction fetch approach.  It gets
//		one instruction at a time.  Future versions should pipeline
//	fetches and perhaps even cache results--this doesn't do that.  It
//	should, however, be simple enough to get things running.
//
//	The interface is fascinating.  The 'i_pc' input wire is just a
//	suggestion of what to load.  Other wires may be loaded instead. i_pc
//	is what must be output, not necessarily input.
//
//   20150919 -- Added support for the WB error signal.  When reading an
//	instruction results in this signal being raised, the pipefetch module
//	will set an illegal instruction flag to be returned to the CPU together
//	with the instruction.  Hence, the ZipCPU can trap on it if necessary.
//
//   20171020 -- Added a formal proof to prove that the module works.  This
//	also involved adding a req_addr register, and the logic associated
//	with it.
//
//   20171113 -- Removed the req_addr register, replacing it with a bus abort
//	capability.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2024, Gisselquist Technology, LLC
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
module	prefetch #(
		// {{{
		parameter		ADDRESS_WIDTH=30,	// Byte addr wid
					INSN_WIDTH=32,
					DATA_WIDTH=INSN_WIDTH,
		localparam		AW=ADDRESS_WIDTH,
					DW=DATA_WIDTH,
		parameter	[0:0]	OPT_ALIGNED = 1'b0,
		parameter	[0:0]	OPT_LITTLE_ENDIAN = 1'b1
		// }}}
	) (
		// {{{
		input	wire			i_clk, i_reset,
		// CPU interaction wires
		input	wire			i_new_pc, i_clear_cache,
						i_ready,
		// We ignore i_pc unless i_new_pc is true as well
		input	wire	[AW-1:0]	i_pc,
		output	reg			o_valid, // If output is valid
		output	reg			o_illegal, // bus err result
		output	reg [INSN_WIDTH-1:0]	o_insn,	// Insn read from WB
		output	reg	[AW-1:0]	o_pc,	// Byt addr of that insn
		// Wishbone outputs
		output	reg			o_wb_cyc, o_wb_stb,
		// verilator coverage_off
		output	wire			o_wb_we,	// == const 0
		// verilator coverage_on
		output	reg [AW-$clog2(DW/8)-1:0]	o_wb_addr,
		// verilator coverage_off
		output	wire	[DW-1:0]	o_wb_data,	// == const 0
		// verilator coverage_on
		// And return inputs
		input	wire			i_wb_stall, i_wb_ack, i_wb_err,
		input	wire	[DW-1:0]	i_wb_data
		// }}}
	);

	// Declare local variables
	// {{{
	reg			invalid;

	wire			r_valid;
	wire [DATA_WIDTH-1:0]	r_insn, i_wb_shifted;
	// }}}

	// These are kind of obligatory outputs when dealing with a bus, that
	// we'll set them here.  Nothing's going to pay attention to these,
	// though, this is primarily for form.
	assign	o_wb_we = 1'b0;
	assign	o_wb_data = {(DATA_WIDTH){1'b0}};

	// o_wb_cyc, o_wb_stb
	// {{{
	// Let's build it simple and upgrade later: For each instruction
	// we do one bus cycle to get the instruction.  Later we should
	// pipeline this, but for now let's just do one at a time.
	initial	o_wb_cyc = 1'b0;
	initial	o_wb_stb = 1'b0;
	always @(posedge i_clk)
	if ((i_reset || i_clear_cache)||(o_wb_cyc &&(i_wb_ack||i_wb_err)))
	begin
		// {{{
		// End any bus cycle on a reset, or a return ACK
		// or error.
		o_wb_cyc <= 1'b0;
		o_wb_stb <= 1'b0;
		// }}}
	end else if (!o_wb_cyc &&(
			// Start if the last instruction output was
			// accepted, *and* it wasn't a bus error
			// response
			(i_ready && !o_illegal && !r_valid)
			// Start if the last bus result ended up
			// invalid
			||(invalid)
			// Start on any request for a new address
			||i_new_pc))
	begin
		// {{{
		// Initiate a bus transaction
		o_wb_cyc <= 1'b1;
		o_wb_stb <= 1'b1;
		// }}}
	end else if (o_wb_cyc)
	begin
		// {{{
		// If our request has been accepted, then drop the
		// strobe line
		if (!i_wb_stall)
			o_wb_stb <= 1'b0;

		// Abort on new-pc
		// ... clear_cache  is identical, save that it will
		// immediately be followed by a new PC, so we don't
		// need to worry about that other than to drop
		// CYC and STB here.
		if (i_new_pc)
		begin
			o_wb_cyc <= 1'b0;
			o_wb_stb <= 1'b0;
		end
		// }}}
	end
	// }}}

	// invalid
	// {{{
	// If during the current bus request, a command came in from the CPU
	// that will invalidate the results of that request, then we need to
	// keep track of an "invalid" flag to remember that and so squash
	// the result.
	//
	initial	invalid = 1'b0;
	always @(posedge i_clk)
	if (i_reset || !o_wb_cyc)
		invalid <= 1'b0;
	else if (i_new_pc)
		invalid <= 1'b1;
	// }}}

	// The wishbone request address, o_wb_addr
	// {{{
	// The rule regarding this address is that it can *only* be changed
	// when no bus request is active.  Further, since the CPU is depending
	// upon this value to know what "PC" is associated with the instruction
	// it is processing, we can't change until either the CPU has accepted
	// our result, or it is requesting a new PC (and hence not using the
	// output).
	//
	initial	o_wb_addr= 0;
	always @(posedge i_clk)
	if (i_new_pc)
		o_wb_addr  <= i_pc[AW-1:$clog2(DATA_WIDTH/8)];
	else if (o_valid && i_ready && !r_valid)
		o_wb_addr  <= o_wb_addr + 1'b1;
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// (Optionally) shift the output word into place
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// This only applies when the bus size doesn't match the instruction
	// word size.  Here, we only support bus sizes greater than the
	// instruction word size.
`ifdef	FORMAL
	wire	[DATA_WIDTH-1:0]	f_bus_word;
`endif

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
		if (i_reset || i_new_pc || i_clear_cache)
			rg_valid <= 1'b0;
		else if (r_count <= ((o_valid && i_ready) ? 1:0))
		begin
			rg_valid <= 1'b0;
			if (o_wb_cyc && i_wb_ack && !(&r_shift))
				rg_valid <= 1'b1;
		end
		// }}}

		// rg_insn
		// {{{
		always @(posedge i_clk)
		if (i_wb_ack && (r_count <= ((o_valid && i_ready) ? 1:0)))
		begin
			rg_insn <= i_wb_data;
			if (OPT_LITTLE_ENDIAN)
			begin
				rg_insn <= i_wb_shifted >> INSN_WIDTH;
			end else begin
				rg_insn <= i_wb_shifted << INSN_WIDTH;
			end
		end else if (o_valid && i_ready)
		begin
			if (OPT_LITTLE_ENDIAN)
				rg_insn <= rg_insn >> INSN_WIDTH;
			else
				rg_insn <= rg_insn << INSN_WIDTH;
		end
		// }}}

		// r_count
		// {{{
		always @(posedge i_clk)
		if (i_reset || i_new_pc || i_clear_cache)
			r_count <= 0;
		// Verilator lint_off CMPCONST
		else if (o_valid && i_ready && r_valid)
		// Verilator lint_on  CMPCONST
			r_count <= r_count - 1;
		else if (o_wb_cyc && i_wb_ack)
		begin
			// if (OPT_LITTLE_ENDIAN)
			r_count <= { 1'b0, ~r_shift };
		end
`ifdef	FORMAL
		always @(*)
		if (!i_reset)
		begin
			assert(r_valid == (r_count > 0));
			assert(r_count <= (1<<NSHIFT));
			if (r_valid)
			begin
				assert(!o_wb_cyc);
				assert(r_shift == 0);
			end else if (!i_new_pc && !i_clear_cache && !o_illegal)
				assert(invalid || o_valid || o_wb_cyc);
		end
`endif
		// }}}

		// r_shift
		// {{{
		always @(posedge i_clk)
		if (i_reset)
			r_shift <= 0;
		else if (i_new_pc)
			r_shift <= i_pc[$clog2(DW/8)-1:$clog2(INSN_WIDTH/8)];
		else if (o_wb_cyc && (i_wb_ack || i_wb_err))
			r_shift <= 0;

`ifdef	FORMAL
		always @(*)
		if (!i_reset && r_shift > 0)
			assert(!o_valid && !r_valid);
`endif
		// }}}

		assign	r_valid = rg_valid;
;
		assign	r_insn  = rg_insn;
		if (OPT_LITTLE_ENDIAN)
		begin : GEN_LIL_ENDIAN_SHIFT
			assign	i_wb_shifted = i_wb_data >> (r_shift * INSN_WIDTH);
		end else begin : GEN_BIG_ENDIAN_SHIFT
			assign	i_wb_shifted = i_wb_data << (r_shift * INSN_WIDTH);
		end

		// Keep Verilator happy
		// {{{
		// Verilator coverage_off
		// Verilator lint_off UNUSED
		wire	unused_shift;
		assign	unused_shift = &{ 1'b0,
				r_insn[DATA_WIDTH-1:INSN_WIDTH],
				i_wb_shifted[DATA_WIDTH-1:INSN_WIDTH] };
		// Verilator lint_on  UNUSED
		// Verilator coverage_on
		// }}}
`ifdef	FORMAL
		assign	f_bus_word = rg_insn << ((r_count-1)* INSN_WIDTH);
		always @(*)
		if (!i_reset && r_valid)
		begin
			assert(o_valid);
			assert(r_shift == 0);
			// assert((r_count + o_pc[NSHIFT-1:0]) == ((1<<NSHIFT)-1));
			assert((r_count + o_pc[$clog2(DW/8)-1:$clog2(INSN_WIDTH/8)])
				== ((1<<NSHIFT)-1));
		end else if (!i_reset && o_wb_cyc && !invalid)
		begin
			assert(r_shift == o_pc[$clog2(DW/8)-1:$clog2(INSN_WIDTH/8)]);
		end
`endif
		// }}}
	end else begin : NO_SUBSHIFT
		// {{{
		assign	r_valid = 1'b0;
		assign	r_insn  = {(INSN_WIDTH){1'b0}};
		assign	i_wb_shifted = i_wb_data;
`ifdef	FORMAL
		assign	f_bus_word = 0;
`endif
		// Verilator lint_off UNUSED
		wire	unused_shift;
		assign	unused_shift = &{ 1'b0, OPT_LITTLE_ENDIAN };
		// Verilator lint_on  UNUSED
		// }}}
	end endgenerate
	// }}}

	// o_insn
	// {{{
	// The instruction returned is given by the data returned from the bus.
	always @(posedge i_clk)
	if (i_wb_ack)
	begin
		if (OPT_LITTLE_ENDIAN)
			o_insn <= i_wb_shifted[INSN_WIDTH-1:0];
		else
			o_insn <= i_wb_shifted[DW-1:DW-INSN_WIDTH];
	end else if (i_ready && (DATA_WIDTH != INSN_WIDTH))
	begin
		if (OPT_LITTLE_ENDIAN)
			o_insn <= r_insn[INSN_WIDTH-1:0];
		else
			o_insn <= r_insn[DW-1:DW-INSN_WIDTH];
	end
`ifdef	FORMAL
	always @(posedge i_clk) if (!i_reset && o_valid) assert(!i_wb_ack);
`endif
	// }}}

	// o_valid, o_illegal
	// {{{
	// Finally, the flags associated with the prefetch.  The rule is that
	// if the output represents a return from the bus, then o_valid needs
	// to be true.  o_illegal will be true any time the last bus request
	// resulted in an error.  o_illegal is only relevant to the CPU when
	// o_valid is also true, hence o_valid will be true even in the case
	// of a bus error in our request.
	//
	initial o_valid   = 1'b0;
	initial o_illegal = 1'b0;
	always @(posedge i_clk)
	if (i_reset || i_new_pc || i_clear_cache)
	begin
		// On any reset, request for a new PC (i.e. a branch),
		// or a request to clear our cache (i.e. the data
		// in memory may have changed), we invalidate any
		// output.
		o_valid   <= 1'b0;
		o_illegal <= 1'b0;
	end else if (o_wb_cyc &&(i_wb_ack || i_wb_err))
	begin
		// Otherwise, at the end of our bus cycle, the
		// answer will be valid.  Well, not quite.  If the
		// user requested something mid-cycle (i_new_pc)
		// or (i_clear_cache), then we'll have to redo the
		// bus request, so we aren't valid.
		//
		o_valid   <= 1'b1;
		o_illegal <= ( i_wb_err);
	end else if (i_ready)
	begin
		// Once the CPU accepts any result we produce, clear
		// the valid flag, lest we send two identical
		// instructions to the CPU.
		//
		o_valid <= r_valid;
		//
		// o_illegal doesn't change ... that way we don't
		// access the bus again until a new address request
		// is given to us, via i_new_pc, or we are asked
		//  to check again via i_clear_cache
		//
		// o_illegal <= (!i_ready);
	end
	// }}}

	// The o_pc output shares its value with the (last) wishbone address
	// {{{
	generate if (OPT_ALIGNED && (INSN_WIDTH == DATA_WIDTH))
	begin : ALIGNED_PF_PC
		// {{{
		always @(*)
			o_pc = { o_wb_addr,
				{($clog2(DATA_WIDTH/8)){1'b0}} };
		// }}}
	end else begin : GENERATE_PF_PC
		// {{{
		initial	o_pc = 0;
		always @(posedge i_clk)
		if (i_new_pc)
			o_pc <= i_pc;
		else if (o_valid && i_ready)
		begin
			o_pc <= 0;
			o_pc[AW-1:$clog2(INSN_WIDTH/8)]
				<= o_pc[AW-1:$clog2(INSN_WIDTH/8)] + 1;
		end
		// }}}
	end endgenerate
`ifdef	FORMAL
	always @(*)
	if (!i_reset && !o_illegal && !i_new_pc && !i_clear_cache)
		assert(o_pc[AW-1:$clog2(DATA_WIDTH/8)] == o_wb_addr);
`endif
	// }}}

	// Make verilator happy
	// {{{
	// verilator coverage_off
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, i_pc[1:0] };
	// verilator lint_on  UNUSED
	// verilator coverage_on
	// }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal properties
// {{{
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef	FORMAL
// Formal properties for this module are maintained elsewhere
`endif
endmodule
