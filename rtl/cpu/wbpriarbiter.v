////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbpriarbiter.v
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This is a priority bus arbiter.  It allows two separate wishbone
//		masters to connect to the same bus, while also guaranteeing
//	that one master can have the bus with no delay any time the other
//	master is not using the bus.  The goal is to eliminate the combinatorial
//	logic required in the other wishbone arbiter, while still guarateeing
//	access time for the priority channel.
//
//	The core logic works like this:
//
//	1. When no one requests the bus, 'A' is granted the bus and guaranteed
//		that any access will go right through.
//	2. If 'B' requests the bus (asserts cyc), and the bus is idle, then
//		'B' will be granted the bus.
//	3. Bus grants last as long as the 'cyc' line is high.
//	4. Once 'cyc' is dropped, the bus returns to 'A' as the owner.
//
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
module	wbpriarbiter #(
		// {{{
		parameter			DW=32, AW=32,
		// OPT_ZERO_ON_IDLE
		// {{{
		// ZERO_ON_IDLE uses more logic than the alternative.  It should
		// be useful for reducing power, as these circuits tend to drive
		// wires all the way across the design, but it may also slow
		// down the master clock.  I've used it as an option when using
		// VER1LATOR, 'cause zeroing things on idle can make them stand
		// out all the more when staring at wires and dumps and such.
		parameter	[0:0]		OPT_ZERO_ON_IDLE = 1'b0
		// }}}
		// }}}
	) (
		// {{{
		input	wire			i_clk,
		// Bus A
		// {{{
		input	wire			i_a_cyc, i_a_stb, i_a_we,
		input	wire	[(AW-1):0]	i_a_adr,
		input	wire	[(DW-1):0]	i_a_dat,
		input	wire	[(DW/8-1):0]	i_a_sel,
		output	wire			o_a_stall, o_a_ack, o_a_err,
		// }}}
		// Bus B
		// {{{
		input	wire			i_b_cyc, i_b_stb, i_b_we,
		input	wire	[(AW-1):0]	i_b_adr,
		input	wire	[(DW-1):0]	i_b_dat,
		input	wire	[(DW/8-1):0]	i_b_sel,
		output	wire			o_b_stall, o_b_ack, o_b_err,
		// }}}
		// Outgoing combined bus
		// {{{
		output	wire			o_cyc, o_stb, o_we,
		output	wire	[(AW-1):0]	o_adr,
		output	wire	[(DW-1):0]	o_dat,
		output	wire	[(DW/8-1):0]	o_sel,
		input	wire			i_stall, i_ack, i_err
		// }}}
		// }}}
	);

	reg	r_a_owner;

	// r_a_owner
	// {{{
	// Go high immediately (new cycle) if ...
	//	Previous cycle was low and *someone* is requesting a bus cycle
	// Go low immadiately if ...
	//	We were just high and the owner no longer wants the bus
	// WISHBONE Spec recommends no logic between a FF and the o_cyc
	//	This violates that spec.  (Rec 3.15, p35)
	initial	r_a_owner = 1'b1;
	always @(posedge i_clk)
	if (!i_b_cyc)
		r_a_owner <= 1'b1;
	// Allow B to set its CYC line w/o activating this interface
	else if ((i_b_cyc)&&(i_b_stb)&&(!i_a_cyc))
		r_a_owner <= 1'b0;
	// }}}

	// CYC, STB, and WE
	// {{{
	// Realistically, if neither master owns the bus, the output is a
	// don't care.  Thus we trigger off whether or not 'A' owns the bus.
	// If 'B' owns it all we care is that 'A' does not.  Likewise, if
	// neither owns the bus than the values on these various lines are
	// irrelevant.

	assign o_cyc = (r_a_owner) ? i_a_cyc : i_b_cyc;
	assign o_we  = (r_a_owner) ? i_a_we  : i_b_we;
	assign o_stb   = (r_a_owner) ? i_a_stb   : i_b_stb;
	// }}}

	// Everything else
	// {{{
	generate if (OPT_ZERO_ON_IDLE)
	begin : OPT_LOWPOWER
		// {{{
		assign	o_adr     = (o_stb)?((r_a_owner) ? i_a_adr  : i_b_adr):0;
		assign	o_dat     = (o_stb)?((r_a_owner) ? i_a_dat  : i_b_dat):0;
		assign	o_sel     = (o_stb)?((r_a_owner) ? i_a_sel  : i_b_sel):0;
		assign	o_a_ack   = (o_cyc)&&( r_a_owner) ? i_ack   : 1'b0;
		assign	o_b_ack   = (o_cyc)&&(!r_a_owner) ? i_ack   : 1'b0;
		assign	o_a_stall = (o_cyc)&&( r_a_owner) ? i_stall : 1'b1;
		assign	o_b_stall = (o_cyc)&&(!r_a_owner) ? i_stall : 1'b1;
		assign	o_a_err   = (o_cyc)&&( r_a_owner) ? i_err : 1'b0;
		assign	o_b_err   = (o_cyc)&&(!r_a_owner) ? i_err : 1'b0;
		// }}}
	end else begin : OPT_LOWLOGIC
		// {{{
		assign o_adr   = (r_a_owner) ? i_a_adr   : i_b_adr;
		assign o_dat   = (r_a_owner) ? i_a_dat   : i_b_dat;
		assign o_sel   = (r_a_owner) ? i_a_sel   : i_b_sel;

		// We cannot allow the return acknowledgement to ever go high if
		// the master in question does not own the bus.  Hence we force it
		// low if the particular master doesn't own the bus.
		assign	o_a_ack   = ( r_a_owner) ? i_ack   : 1'b0;
		assign	o_b_ack   = (!r_a_owner) ? i_ack   : 1'b0;

		// Stall must be asserted on the same cycle the input master asserts
		// the bus, if the bus isn't granted to him.
		assign	o_a_stall = ( r_a_owner) ? i_stall : 1'b1;
		assign	o_b_stall = (!r_a_owner) ? i_stall : 1'b1;

		//
		//
		assign	o_a_err = ( r_a_owner) ? i_err : 1'b0;
		assign	o_b_err = (!r_a_owner) ? i_err : 1'b0;
		// }}}
	end endgenerate
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
