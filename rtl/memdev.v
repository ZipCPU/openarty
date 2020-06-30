////////////////////////////////////////////////////////////////////////////////
//
// Filename:	memdev.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This file is really simple: it creates an on-chip memory,
//		accessible via the wishbone bus, that can be used in this
//	project.  The memory has single cycle pipeline access, although the
//	memory pipeline here still costs a cycle and there may be other cycles
//	lost between the ZipCPU (or whatever is the master of the bus) and this,
//	thus costing more cycles in access.  Either way, operations can be
//	pipelined for single cycle access on subsequent transactions.
//
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
module	memdev(i_clk, i_reset,
		i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data, i_wb_sel,
		o_wb_stall, o_wb_ack, o_wb_data);
	parameter	LGMEMSZ=15, DW=32, EXTRACLOCK= 0;
	parameter	HEXFILE="";
	parameter [0:0]	OPT_ROM = 1'b0;
	localparam	AW = LGMEMSZ - 2;
	input	wire			i_clk, i_reset;
	input	wire			i_wb_cyc, i_wb_stb, i_wb_we;
	input	wire	[(AW-1):0]	i_wb_addr;
	input	wire	[(DW-1):0]	i_wb_data;
	input	wire	[(DW/8-1):0]	i_wb_sel;
	output	wire			o_wb_stall;
	output	reg			o_wb_ack;
	output	reg	[(DW-1):0]	o_wb_data;

	wire			w_wstb, w_stb;
	wire	[(DW-1):0]	w_data;
	wire	[(AW-1):0]	w_addr;
	wire	[(DW/8-1):0]	w_sel;

	reg	[(DW-1):0]	mem	[0:((1<<AW)-1)];

	generate if (HEXFILE != 0)
	begin : PRELOAD_MEMORY

		initial	$readmemh(HEXFILE, mem);

	end endgenerate

	generate
	if (EXTRACLOCK == 0)
	begin

		assign	w_wstb = (i_wb_stb)&&(i_wb_we);
		assign	w_stb  = i_wb_stb;
		assign	w_addr = i_wb_addr;
		assign	w_data = i_wb_data;
		assign	w_sel  = i_wb_sel;

	end else begin

		reg		last_wstb, last_stb;
		always @(posedge i_clk)
			last_wstb <= (i_wb_stb)&&(i_wb_we);

		initial	last_stb = 1'b0;
		always @(posedge i_clk)
		if (i_reset)
			last_stb <= 1'b0;
		else
			last_stb <= (i_wb_stb);

		reg	[(AW-1):0]	last_addr;
		reg	[(DW-1):0]	last_data;
		reg	[(DW/8-1):0]	last_sel;
		always @(posedge i_clk)
			last_data <= i_wb_data;
		always @(posedge i_clk)
			last_addr <= i_wb_addr;
		always @(posedge i_clk)
			last_sel <= i_wb_sel;

		assign	w_wstb = last_wstb;
		assign	w_stb  = last_stb;
		assign	w_addr = last_addr;
		assign	w_data = last_data;
		assign	w_sel  = last_sel;
	end endgenerate

	always @(posedge i_clk)
		o_wb_data <= mem[w_addr];

	generate if (!OPT_ROM)
	begin : WRITE_TO_MEMORY

		always @(posedge i_clk)
		begin
			if ((w_wstb)&&(w_sel[3]))
				mem[w_addr][31:24] <= w_data[31:24];
			if ((w_wstb)&&(w_sel[2]))
				mem[w_addr][23:16] <= w_data[23:16];
			if ((w_wstb)&&(w_sel[1]))
				mem[w_addr][15: 8] <= w_data[15:8];
			if ((w_wstb)&&(w_sel[0]))
				mem[w_addr][ 7: 0] <= w_data[7:0];
		end
`ifdef	VERILATOR
	end else begin : VERILATOR_ROM

		// Make Verilator happy
		// Verilator lint_off UNUSED
		wire	[DW+DW/8:0]	rom_unused;
		assign	rom_unused = { w_wstb, w_data, w_sel };
		// Verilator lint_on  UNUSED
`endif
	end endgenerate

	initial	o_wb_ack = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_wb_ack <= 1'b0;
	else
		o_wb_ack <= (w_stb)&&(i_wb_cyc);

	assign	o_wb_stall = 1'b0;

	// Make verilator happy
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = i_wb_cyc;
	// verilator lint_on UNUSED


`ifdef	FORMAL
// Formal properties for this module are maintained elsewhere
`endif
endmodule
