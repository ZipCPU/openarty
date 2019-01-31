////////////////////////////////////////////////////////////////////////////////
//
// Filename:	dblfetch.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
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
//
// Copyright (C) 2017-2019, Gisselquist Technology, LLC
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
module	dblfetch(i_clk, i_reset, i_new_pc, i_clear_cache,
			i_stall_n, i_pc, o_insn, o_pc, o_valid,
		o_wb_cyc, o_wb_stb, o_wb_we, o_wb_addr, o_wb_data,
			i_wb_ack, i_wb_stall, i_wb_err, i_wb_data,
		o_illegal);
	parameter		ADDRESS_WIDTH=30, AUX_WIDTH = 1;
	localparam		AW=ADDRESS_WIDTH, DW = 32;
	input	wire			i_clk, i_reset, i_new_pc, i_clear_cache,
						i_stall_n;
	input	wire	[(AW+1):0]	i_pc;
	output	reg	[(DW-1):0]	o_insn;
	output	reg	[(AW+1):0]	o_pc;
	output	reg			o_valid;
	// Wishbone outputs
	output	reg			o_wb_cyc, o_wb_stb;
	output	wire			o_wb_we;
	output	reg	[(AW-1):0]	o_wb_addr;
	output	wire	[(DW-1):0]	o_wb_data;
	// And return inputs
	input	wire			i_wb_ack, i_wb_stall, i_wb_err;
	input	wire	[(DW-1):0]	i_wb_data;
	// And ... the result if we got an error
	output	reg		o_illegal;

	assign	o_wb_we = 1'b0;
	assign	o_wb_data = 32'h0000;

	reg	last_stb, invalid_bus_cycle;

	reg	[(DW-1):0]	cache_word;
	reg			cache_valid;
	reg	[1:0]		inflight;
	reg			cache_illegal;

	initial	o_wb_cyc = 1'b0;
	initial	o_wb_stb = 1'b0;
	always @(posedge i_clk)
		if ((i_reset)||((o_wb_cyc)&&(i_wb_err)))
		begin
			o_wb_cyc <= 1'b0;
			o_wb_stb <= 1'b0;
		end else if (o_wb_cyc)
		begin
			if ((!o_wb_stb)||(!i_wb_stall))
				o_wb_stb <= (!last_stb);

			// Relase the bus on the second ack
			if (((i_wb_ack)&&(!o_wb_stb)&&(inflight<=1))
				||((!o_wb_stb)&&(inflight == 0))
				// Or any new transaction request
				||((i_new_pc)||(i_clear_cache)))
			begin
				o_wb_cyc <= 1'b0;
				o_wb_stb <= 1'b0;
			end

		end else if ((i_new_pc)||(invalid_bus_cycle)
			||((o_valid)&&(i_stall_n)&&(!o_illegal)))
		begin
			// Initiate a bus cycle if ... the last bus cycle was
			// aborted (bus error or new_pc), we've been given a
			// new PC to go get, or we just exhausted our one
			// instruction cache
			o_wb_cyc <= 1'b1;
			o_wb_stb <= 1'b1;
		end

	initial	inflight = 2'b00;
	always @(posedge i_clk)
	if (!o_wb_cyc)
		inflight <= 2'b00;
	else begin
		case({ ((o_wb_stb)&&(!i_wb_stall)), i_wb_ack })
		2'b01:	inflight <= inflight - 1'b1;
		2'b10:	inflight <= inflight + 1'b1;
		// If neither ack nor request, then no change.  Likewise
		// if we have both an ack and a request, there's no change
		// in the number of requests in flight.
		default: begin end
		endcase
	end

	always @(*)
		last_stb = (inflight != 2'b00)||((o_valid)&&(!i_stall_n));

	initial	invalid_bus_cycle = 1'b0;
	always @(posedge i_clk)
		if ((o_wb_cyc)&&(i_new_pc))
			invalid_bus_cycle <= 1'b1;
		else if (!o_wb_cyc)
			invalid_bus_cycle <= 1'b0;

	initial	o_wb_addr = {(AW){1'b1}};
	always @(posedge i_clk)
		if (i_new_pc)
			o_wb_addr <= i_pc[AW+1:2];
		else if ((o_wb_stb)&&(!i_wb_stall))
			o_wb_addr <= o_wb_addr + 1'b1;

	//////////////////
	//
	// Now for the immediate output word to the CPU
	//
	//////////////////

	initial	o_valid = 1'b0;
	always @(posedge i_clk)
		if ((i_reset)||(i_new_pc)||(i_clear_cache))
			o_valid <= 1'b0;
		else if ((o_wb_cyc)&&((i_wb_ack)||(i_wb_err)))
			o_valid <= 1'b1;
		else if (i_stall_n)
			o_valid <= cache_valid;

	always @(posedge i_clk)
	if ((!o_valid)||(i_stall_n))
	begin
		if (cache_valid)
			o_insn <= cache_word;
		else
			o_insn <= i_wb_data;
	end

	initial o_pc[1:0] = 2'b00;
	always @(posedge i_clk)
	if (i_new_pc)
		o_pc <= i_pc;
	else if ((o_valid)&&(i_stall_n))
		o_pc[AW+1:2] <= o_pc[AW+1:2] + 1'b1;

	initial	o_illegal = 1'b0;
	always @(posedge i_clk)
		if ((i_reset)||(i_new_pc)||(i_clear_cache))
			o_illegal <= 1'b0;
		else if ((!o_valid)||(i_stall_n))
		begin
			if (cache_valid)
				o_illegal <= (o_illegal)||(cache_illegal);
			else if ((o_wb_cyc)&&(i_wb_err))
				o_illegal <= 1'b1;
		end


	//////////////////
	//
	// Now for the output/cached word
	//
	//////////////////

	initial	cache_valid = 1'b0;
	always @(posedge i_clk)
		if ((i_reset)||(i_new_pc)||(i_clear_cache))
			cache_valid <= 1'b0;
		else begin
			if ((o_valid)&&(o_wb_cyc)&&((i_wb_ack)||(i_wb_err)))
				cache_valid <= (!i_stall_n)||(cache_valid);
			else if (i_stall_n)
				cache_valid <= 1'b0;
		end

	always @(posedge i_clk)
		if ((o_wb_cyc)&&(i_wb_ack))
			cache_word <= i_wb_data;

	initial	cache_illegal = 1'b0;
	always @(posedge i_clk)
	if ((i_reset)||(i_clear_cache)||(i_new_pc))
		cache_illegal <= 1'b0;
	else if ((o_wb_cyc)&&(i_wb_err)&&(o_valid)&&(!i_stall_n))
		cache_illegal <= 1'b1;
`ifdef	FORMAL
// The formal properties for this design are maintained elsewhere
`endif	// FORMAL
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
