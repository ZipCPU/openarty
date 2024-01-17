////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	xioddr.v
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	For the DDR3 SDRAM, this handles the Xilinx specific portions
//		of the IO necessary to make this happen for one pin only.  (In
//	the end, this never worked for the DDR3 SDRAM ...)  In the case of the
//	QSPI flash, this module helps to reduce the logic delays on the "high
//	speed" flash data wires (it's not really used in any DDR mode in that
//	case ...).
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
module	xioddr(
		input	wire		i_clk, i_oe,
		input	wire	[1:0]	i_v,
		output	wire	[1:0]	o_v,
		inout	wire		io_pin
	);

	wire	w_internal;
	reg	last;

	always @(posedge i_clk)
		last <= i_v[1];

	ODDR #(
		.DDR_CLK_EDGE("SAME_EDGE"),
		.INIT(1'b0),
		.SRTYPE("SYNC")
	) ODDRi(
		.Q(w_internal),
		.C(i_clk),
		.CE(1'b1),
		.D1(last),	// Negative clock edge (goes first)
		.D2(i_v[0]),	// Positive clock edge
		.R(1'b0),
		.S(1'b0));

	IDDR #(
		.DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
		.INIT_Q1(1'b0),
		.INIT_Q2(1'b0),
		.SRTYPE("SYNC")
	) IDDRi(
		.Q1(o_v[0]),
		.Q2(o_v[1]),
		.C(i_clk),
		.CE(1'b1),
		.D(io_pin),
		.R(1'b0),
		.S(1'b0));

	reg	oedelay;
	initial	oedelay = 0;
	always @(posedge i_clk)
		oedelay = i_oe;
	assign	io_pin = (oedelay) ? w_internal:1'bz;

endmodule
