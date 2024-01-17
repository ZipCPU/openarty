////////////////////////////////////////////////////////////////////////////////
//
// Filename:	busdelay.v
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Delay any access to the wishbone bus by a single clock.
//
//	When the first Zip System would not meet the timing requirements of
//	the board it was placed upon, this bus delay was added to help out.
//	It may no longer be necessary, having cleaned some other problems up
//	first, but it will remain here as a means of alleviating timing
//	problems.
//
//	The specific problem takes place on the stall line: a wishbone master
//	*must* know on the first clock whether or not the bus will stall.
//
//
//	After a period of time, I started a new design where the timing
//	associated with this original bus clock just wasn't ... fast enough.
//	I needed to delay the stall line as well.  A new busdelay was then
//	written and debugged whcih delays the stall line.  (I know, you aren't
//	supposed to delay the stall line--but what if you *have* to in order
//	to meet timing?)  This new logic has been merged in with the old,
//	and the DELAY_STALL line can be set to non-zero to use it instead
//	of the original logic.  Don't use it if you don't need it: it will
//	consume resources and slow your bus down more, but if you do need
//	it--don't be afraid to use it.  
//
//	Both versions of the bus delay will maintain a single access per
//	clock when pipelined, they only delay the time between the strobe
//	going high and the actual command being accomplished.
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
module	busdelay #(
		// {{{
		parameter		AW=32, DW=32,
`ifdef	FORMAL
		localparam		F_LGDEPTH=4,
`endif
		parameter	 [0:0]	DELAY_STALL  = 1,
		parameter	 [0:0]	OPT_LOWPOWER = 0
		// }}}
	) (
		// {{{
		input	wire			i_clk, i_reset,
		// Input/master bus
		// {{{
		input	wire			i_wb_cyc, i_wb_stb, i_wb_we,
		input	wire	[(AW-1):0]	i_wb_addr,
		input	wire	[(DW-1):0]	i_wb_data,
		input	wire	[(DW/8-1):0]	i_wb_sel,
		output	wire			o_wb_stall,
		output	reg			o_wb_ack,
		output	reg	[(DW-1):0]	o_wb_data,
		output	reg			o_wb_err,
		// }}}
		// Delayed bus
		// {{{
		output	reg			o_dly_cyc, o_dly_stb, o_dly_we,
		output	reg	[(AW-1):0]	o_dly_addr,
		output	reg	[(DW-1):0]	o_dly_data,
		output	reg	[(DW/8-1):0]	o_dly_sel,
		input	wire			i_dly_stall,
		input	wire			i_dly_ack,
		input	wire	[(DW-1):0]	i_dly_data,
		input	wire			i_dly_err
		// }}}
		// }}}
	);


	generate if (DELAY_STALL)
	begin : SKIDBUFFER
		// {{{
		reg			r_stb, r_we;
		reg	[(AW-1):0]	r_addr;
		reg	[(DW-1):0]	r_data;
		reg	[(DW/8-1):0]	r_sel;

		// o_dly_cyc
		// {{{
		initial	o_dly_cyc  = 1'b0;
		always @(posedge i_clk)
		if (i_reset || !i_wb_cyc)
			o_dly_cyc <= 1'b0;
		else
			o_dly_cyc <= (!o_wb_err)&&((!i_dly_err)||(!o_dly_cyc));
		// }}}

		// o_dly_stb
		// {{{
		initial	o_dly_stb  = 1'b0;
		always @(posedge i_clk)
		if (i_reset || !i_wb_cyc || o_wb_err || (o_dly_cyc && i_dly_err))
			o_dly_stb <= 1'b0;
		else if (!o_dly_stb || !i_dly_stall)
			o_dly_stb <= i_wb_stb || r_stb;
		// }}}

		// r_stb
		// {{{
		initial	r_stb      = 1'b0;
		always @(posedge i_clk)
		if (i_reset || !i_wb_cyc || o_wb_err || i_dly_err
					|| !i_dly_stall || !o_dly_stb)
			r_stb <= 1'b0;
		else if (i_wb_stb && !o_wb_stall) // && (o_dly_stb&&i_dly_stall)
			r_stb <= 1'b1;
		// }}}

		// r_*
		// {{{
		initial { r_we, r_addr, r_data, r_sel } = 0;
		always @(posedge i_clk)
		if (OPT_LOWPOWER && (i_reset || !i_wb_cyc || i_dly_err
					|| !o_dly_stb || !i_dly_stall))
			{ r_we, r_addr, r_data, r_sel } <= 0;
		else if (i_wb_stb && !o_wb_stall) // && (o_dly_stb&&i_dly_stall)
			{ r_we, r_addr, r_data, r_sel }
				<= { i_wb_we, i_wb_addr, i_wb_data, i_wb_sel };
		// }}}

		initial	o_dly_we   = 1'b0;
		initial	o_dly_addr = 0;
		initial	o_dly_data = 0;
		initial	o_dly_sel  = 0;
		always @(posedge i_clk)
		if (OPT_LOWPOWER && (i_reset || (!i_wb_cyc || o_wb_err || (o_dly_cyc && i_dly_err))))
			{ o_dly_we, o_dly_addr, o_dly_data, o_dly_sel } <= 0;
		else if (!o_dly_stb || !i_dly_stall)
		begin
			if (r_stb)
				{ o_dly_we, o_dly_addr, o_dly_data, o_dly_sel } <= { r_we, r_addr, r_data, r_sel };
			else if (!OPT_LOWPOWER || i_wb_stb)
				{ o_dly_we, o_dly_addr, o_dly_data, o_dly_sel } <= { i_wb_we, i_wb_addr, i_wb_data, i_wb_sel };
			else
				{ o_dly_addr, o_dly_data, o_dly_sel } <= 0;

		end

		assign	o_wb_stall = r_stb;

		// o_wb_ack
		// {{{
		initial	o_wb_ack = 0;
		always @(posedge i_clk)
		if (i_reset || !i_wb_cyc || o_wb_err || !o_dly_cyc)
			o_wb_ack <= 1'b0;
		else
			o_wb_ack  <= (i_dly_ack);
		// }}}

		// o_wb_data
		// {{{
		initial	o_wb_data = 0;
		always @(posedge i_clk)
		if (OPT_LOWPOWER && (i_reset || !i_wb_cyc || !o_dly_cyc
				|| o_wb_err || !i_dly_ack))
			o_wb_data <= 0;
		else
			o_wb_data <= i_dly_data;
		// }}}

		// o_wb_err
		// {{{
		initial	o_wb_err   = 1'b0;
		always @(posedge i_clk)
		if (i_reset || !i_wb_cyc || !o_dly_cyc)
			o_wb_err <= 1'b0;
		else
			o_wb_err  <= i_dly_err;
		// }}}

		// }}}
	end else begin : NO_SKIDBUFFER
		// {{{
		initial	o_dly_cyc   = 1'b0;
		initial	o_dly_stb   = 1'b0;
		initial	o_dly_we    = 1'b0;
		initial	o_dly_addr  = 0;
		initial	o_dly_data  = 0;
		initial	o_dly_sel   = 0;

		always @(posedge i_clk)
		if (i_reset)
			o_dly_cyc <= 1'b0;
		else if ((i_dly_err)&&(o_dly_cyc))
			o_dly_cyc <= 1'b0;
		else if ((o_wb_err)&&(i_wb_cyc))
			o_dly_cyc <= 1'b0;
		else
			o_dly_cyc <= i_wb_cyc;

		// Add the i_wb_cyc criteria here, so we can simplify the
		// o_wb_stall criteria below, which would otherwise *and*
		// these two.
		always @(posedge i_clk)
		if (i_reset)
			o_dly_stb <= 1'b0;
		else if ((i_dly_err)&&(o_dly_cyc))
			o_dly_stb <= 1'b0;
		else if ((o_wb_err)&&(i_wb_cyc))
			o_dly_stb <= 1'b0;
		else if (!i_wb_cyc)
			o_dly_stb <= 1'b0;
		else if (!o_wb_stall)
			o_dly_stb <= (i_wb_stb);

		always @(posedge i_clk)
		if (!o_wb_stall)
			o_dly_we  <= i_wb_we;

		initial	o_dly_addr = 0;
		always @(posedge i_clk)
		if (OPT_LOWPOWER && (i_reset || !i_wb_cyc || o_wb_err
						|| (o_dly_cyc && i_dly_err)))
			{ o_dly_addr, o_dly_data, o_dly_sel } <= 0;
		else if (!o_dly_stb || !i_dly_stall)
		begin
			{ o_dly_addr, o_dly_data, o_dly_sel }	
				<= { i_wb_addr, i_wb_data, i_wb_sel };
			if (OPT_LOWPOWER && !i_wb_stb)
				{ o_dly_addr, o_dly_data, o_dly_sel } <= 0;
		end

		initial	o_wb_ack    = 0;
		always @(posedge i_clk)
		if (i_reset)
			o_wb_ack <= 1'b0;
		else
			o_wb_ack  <= ((i_dly_ack)&&(!i_dly_err)
				&&(o_dly_cyc)&&(i_wb_cyc))
				&&(!o_wb_err);

		initial	o_wb_err    = 0;
		always @(posedge i_clk)
		if (i_reset)
			o_wb_err <= 1'b0;
		else if (!o_dly_cyc)
			o_wb_err <= 1'b0;
		else
			o_wb_err  <= (o_wb_err)||(i_dly_err)&&(i_wb_cyc);

		initial	o_wb_data   = 0;
		always @(posedge i_clk)
		if (OPT_LOWPOWER && (i_reset || !i_wb_cyc || !o_dly_cyc || o_wb_err || !i_dly_ack))
			o_wb_data <= 0;
		else
			o_wb_data <= i_dly_data;

		// Our only non-delayed line, yet still really delayed.  Perhaps
		// there's a way to register this?
		// o_wb_stall <= (i_wb_cyc)&&(i_wb_stb) ... or some such?
		// assign o_wb_stall=((i_wb_cyc)&&(i_dly_stall)&&(o_dly_stb));//&&o_cyc
		assign	o_wb_stall = (i_dly_stall)&&(o_dly_stb);
		// }}}
	end endgenerate
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
// The formal proof for this module is maintained elsewhere
`endif
// }}}
endmodule
