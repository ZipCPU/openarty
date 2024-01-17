////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rtl/spio.v
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	
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
`default_nettype none
// }}}
module	spio #(
		parameter	NLEDS=8, NBTN=8, NSW=8
	) (
		// {{{
		input	wire			i_clk,
		input	wire			i_wb_cyc, i_wb_stb, i_wb_we,
		input	wire	[31:0]		i_wb_data,
		input	wire	[3:0]		i_wb_sel,
		output	wire			o_wb_stall,
		output	reg			o_wb_ack,
		output	wire	[31:0]		o_wb_data,
		input	wire	[(NSW-1):0]	i_sw,
		input	wire	[(NBTN-1):0]	i_btn,
		output	reg	[(NLEDS-1):0]	o_led,
		output	reg			o_int
		// }}}
	);

	// Local declarations
	// {{{
	reg			led_demo;
	reg	[(8-1):0]	r_led;
	wire	[(8-1):0]	o_btn;
	reg	[(NBTN-1):0]	last_btn;
	wire	[(NLEDS-1):0]	bounced;
	wire	[(8-1):0]	w_sw;
	reg			sw_int;
	// }}}

	initial	r_led = 0;
	always @(posedge i_clk)
	if ((i_wb_stb)&&(i_wb_we)&&(i_wb_sel[0]))
	begin
		if (!i_wb_sel[1])
			r_led[NLEDS-1:0] <= i_wb_data[(NLEDS-1):0];
		else
			r_led[NLEDS-1:0] <= (r_led[NLEDS-1:0]&(~i_wb_data[(8+NLEDS-1):8]))
				|(i_wb_data[(NLEDS-1):0]&i_wb_data[(8+NLEDS-1):8]);
	end

	generate if (NBTN > 0)
	begin : GEN_DEBOUNCER
		debouncer #(NBTN) thedebouncer(i_clk,
			i_btn, o_btn[(NBTN-1):0]);
	end endgenerate

	generate if (NBTN < 8)
	begin : GEN_EXTRA_BUTTONS
		assign	o_btn[7:NBTN] = 0;
	end endgenerate

	// 2FF synchronizer for our switches
	generate if (NSW > 0)
	begin : GEN_SWITCH_LOGIC
		reg	[2*NSW-1:0]	sw_pipe;
		reg	[8-1:0]		r_sw;

		initial	r_sw    = 0;
		initial	sw_pipe = 0;
		always @(posedge i_clk)
		begin
			r_sw <= 0;
			{ r_sw[NSW-1:0], sw_pipe } <= { sw_pipe, i_sw };

			sw_int <= (r_sw[NSW-1:0] != sw_pipe[2*NSW-1:NSW]);
		end

		assign	w_sw = r_sw;

	end else begin : NO_SWITCHES

		assign	w_sw = 0;

	end endgenerate

	initial	led_demo = 1'b1;
	always @(posedge i_clk)
	if ((i_wb_stb)&&(i_wb_we)&&(i_wb_sel[3]))
		led_demo <= i_wb_data[24];

	assign	o_wb_data = { 7'h0, led_demo, w_sw, o_btn, r_led };

	always @(posedge i_clk)
		last_btn <= o_btn[(NBTN-1):0];
	always @(posedge i_clk)
		o_int <= sw_int || (|((o_btn[(NBTN-1):0])&(~last_btn)));

	ledbouncer	#(NLEDS, 25)
		knightrider(i_clk, bounced);

	always @(posedge i_clk)
	if (led_demo)
		o_led <= bounced;
	else
		o_led <= r_led[NLEDS-1:0];

	assign	o_wb_stall = 1'b0;

	initial	o_wb_ack = 1'b0;
	always @(posedge i_clk)
		o_wb_ack <= (i_wb_stb);

	// Make Verilator happy
	// {{{
	// verilator lint_on  UNUSED
	wire		unused;
	assign	unused = &{ 1'b0, i_wb_cyc, i_wb_data, i_wb_sel[2] };
	// verilator lint_off UNUSED
	// }}}
endmodule
