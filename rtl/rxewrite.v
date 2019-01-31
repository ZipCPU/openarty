////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rxewrite.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	The purpose of this module is quite simple: to simplify the
//		receive process.  By running the receive data through a 
//	series of "filter" processes (of which this is one), I hope to reduce
//	the complexity of the filter design.  This particular filter determines
//	if/when to write to memory, and at what address to write to.  Further,
//	because nibbles come into the interface in LSB order, and because we
//	are storing the first byte in the MSB, we need to shuffle bytes around
//	in this interface.  Therefore, this interface is also design to make
//	certain that, no matter how many bytes come in, we have always 
//	written a complete word to the output.  Hence, each word may be
//	written 8-times (once for each nibble) ... but that be as it may.
//
//	This routine also measures packet length in bytes.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2016-2019, Gisselquist Technology, LLC
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
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none
//
module	rxewrite(i_clk, i_ce, i_cancel, i_v, i_d, o_v, o_addr, o_data, o_len);
	parameter	AW = 12;
	localparam	DW = 32;
	input	wire			i_clk, i_ce;
	input	wire			i_cancel;
	input	wire			i_v;
	input	wire	[3:0]		i_d;
	output	reg			o_v;
	output	reg	[(AW-1):0]	o_addr;
	output	reg	[(DW-1):0]	o_data;
	output	wire	[(AW+1):0]	o_len;

	reg	[(AW+2):0]	lcl_addr, r_len;

	initial	r_len = 0;
	always @(posedge i_clk)
	if (i_ce)
	begin
		lcl_addr <= lcl_addr + 1'b1;
		if (i_v)
			r_len <= lcl_addr  + {{(AW+1){1'b0}},2'b10}; // i.e. +2
		o_v <= i_v;
		case(lcl_addr[2:0])
		3'b000: o_data <= { 4'h0, i_d, 24'h00 };
		3'b001: o_data <= { i_d, o_data[27:24], 24'h00 };
		3'b010: o_data <= { o_data[31:24], 4'h0, i_d, 16'h00 };
		3'b011: o_data <= { o_data[31:24], i_d, o_data[19:16], 16'h00 };
		3'b100: o_data <= { o_data[31:16], 4'h0, i_d, 8'h00 };
		3'b101: o_data <= { o_data[31:16], i_d, o_data[11:8], 8'h00 };
		3'b110: o_data <= { o_data[31: 8], 4'h0, i_d };
		3'b111: o_data <= { o_data[31: 8], i_d, o_data[3:0] };
		endcase
		o_addr <= lcl_addr[(AW+2):3];

		if (((!i_v)&&(!o_v))||(i_cancel))
		begin
			o_v <= 0;
			lcl_addr <= 0;
		end
	end

	assign	o_len  = r_len[(AW+2):1];

	// Make verilator happy
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = r_len[0];
	// verilator lint_on  UNUSED
endmodule

