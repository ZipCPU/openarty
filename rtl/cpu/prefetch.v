////////////////////////////////////////////////////////////////////////////////
//
// Filename:	prefetch.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
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
//
// Copyright (C) 2015,2017-2018, Gisselquist Technology, LLC
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
//
module	prefetch(i_clk, i_reset, i_new_pc, i_clear_cache, i_stalled_n, i_pc,
			o_insn, o_pc, o_valid, o_illegal,
		o_wb_cyc, o_wb_stb, o_wb_we, o_wb_addr, o_wb_data,
			i_wb_ack, i_wb_stall, i_wb_err, i_wb_data);
	parameter		ADDRESS_WIDTH=30, DATA_WIDTH=32;
	parameter	[0:0]	F_OPT_CLK2FFLOGIC = 1'b0;
	localparam		AW=ADDRESS_WIDTH,
				DW=DATA_WIDTH;
	input	wire			i_clk, i_reset;
	// CPU interaction wires
	input	wire			i_new_pc, i_clear_cache, i_stalled_n;
	// We ignore i_pc unless i_new_pc is true as well
	input	wire	[(AW+1):0]	i_pc;
	output	reg	[(DW-1):0]	o_insn;	// Instruction read from WB
	output	wire	[(AW+1):0]	o_pc;	// Address of that instruction
	output	reg			o_valid; // If the output is valid
	output	reg			o_illegal; // Result is from a bus err
	// Wishbone outputs
	output	reg			o_wb_cyc, o_wb_stb;
	output	wire			o_wb_we;
	output	reg	[(AW-1):0]	o_wb_addr;
	output	wire	[(DW-1):0]	o_wb_data;
	// And return inputs
	input	wire			i_wb_ack, i_wb_stall, i_wb_err;
	input	wire	[(DW-1):0]	i_wb_data;

	// Declare local variables
	reg			invalid;

	// These are kind of obligatory outputs when dealing with a bus, that
	// we'll set them here.  Nothing's going to pay attention to these,
	// though, this is primarily for form.
	assign	o_wb_we = 1'b0;
	assign	o_wb_data = 32'h0000;

	// Let's build it simple and upgrade later: For each instruction
	// we do one bus cycle to get the instruction.  Later we should
	// pipeline this, but for now let's just do one at a time.
	initial	o_wb_cyc = 1'b0;
	initial	o_wb_stb = 1'b0;
	always @(posedge i_clk)
		if ((i_reset)||((o_wb_cyc)&&((i_wb_ack)||(i_wb_err))))
		begin
			// End any bus cycle on a reset, or a return ACK
			// or error.
			o_wb_cyc <= 1'b0;
			o_wb_stb <= 1'b0;
		end else if ((!o_wb_cyc)&&(
				// Start if the last instruction output was
				// accepted, *and* it wasn't a bus error
				// response
				((i_stalled_n)&&(!o_illegal))
				// Start if the last bus result ended up
				// invalid
				||(invalid)
				// Start on any request for a new address
				||(i_new_pc)))
		begin
			// Initiate a bus transaction
			o_wb_cyc <= 1'b1;
			o_wb_stb <= 1'b1;
		end else if (o_wb_cyc)
		begin
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
		end

	//
	// If during the current bus request, a command came in from the CPU
	// that will invalidate the results of that request, then we need to
	// keep track of an "invalid" flag to remember that and so squash
	// the result.
	//
	initial	invalid = 1'b0;
	always @(posedge i_clk)
		if ((i_reset)||(!o_wb_cyc))
			invalid <= 1'b0;
		else if (i_new_pc)
			invalid <= 1'b1;

	// The wishbone request address, o_wb_addr
	//
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
			o_wb_addr  <= i_pc[AW+1:2];
		else if ((o_valid)&&(i_stalled_n)&&(!o_illegal))
			o_wb_addr  <= o_wb_addr + 1'b1;

	// The instruction returned is given by the data returned from the bus.
	always @(posedge i_clk)
	if ((o_wb_cyc)&&(i_wb_ack))
		o_insn <= i_wb_data;

	//
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
		if ((i_reset)||(i_new_pc)||(i_clear_cache))
		begin
			// On any reset, request for a new PC (i.e. a branch),
			// or a request to clear our cache (i.e. the data
			// in memory may have changed), we invalidate any
			// output.
			o_valid   <= 1'b0;
			o_illegal <= 1'b0;
		end else if ((o_wb_cyc)&&((i_wb_ack)||(i_wb_err)))
		begin
			// Otherwise, at the end of our bus cycle, the
			// answer will be valid.  Well, not quite.  If the
			// user requested something mid-cycle (i_new_pc)
			// or (i_clear_cache), then we'll have to redo the
			// bus request, so we aren't valid.
			//
			o_valid   <= 1'b1;
			o_illegal <= ( i_wb_err);
		end else if (i_stalled_n)
		begin
			// Once the CPU accepts any result we produce, clear
			// the valid flag, lest we send two identical
			// instructions to the CPU.
			//
			o_valid <= 1'b0;
			//
			// o_illegal doesn't change ... that way we don't
			// access the bus again until a new address request
			// is given to us, via i_new_pc, or we are asked
			//  to check again via i_clear_cache
			//
			// o_illegal <= (!i_stalled_n);
		end

	// The o_pc output shares its value with the (last) wishbone address
	assign	o_pc = { o_wb_addr, 2'b00 };

	// Make verilator happy
	// verilator lint_off UNUSED
	wire	[1:0]	unused;
	assign	unused = i_pc[1:0];
	// verilator lint_on  UNUSED
`ifdef	FORMAL
// Formal properties for this module are maintained elsewhere
`endif
endmodule
