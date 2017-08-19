////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	xoddr.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	For the DDR3 SDRAM, this handles the Xilinx specific portions
//		of the output necessary to make this happen for one pin only.
//	For the QSPI, this helps to make certain that as much of the logic
//	delay as possible has been removed from the path--to get the full
//	100MHz speed.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2016, Gisselquist Technology, LLC
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
module	xoddr(i_clk, i_v, o_pin);
	input	wire		i_clk;
	input	wire	[1:0]	i_v;
	output	wire		o_pin;

	wire	w_internal;
	reg	last;

	always @(posedge i_clk)
		last <= i_v[1];

	ODDR #(
		.DDR_CLK_EDGE("SAME_EDGE"),
		.INIT(1'b0),
		.SRTYPE("SYNC")
	) ODDRi(
		.Q(o_pin),
		.C(i_clk),
		.CE(1'b1),
		.D1(last),	// Negative clock edge (goes first)
		.D2(i_v[0]),	// Positive clock edge
		.R(1'b0),
		.S(1'b0));

endmodule
