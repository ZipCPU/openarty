////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	clrled.v
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	The ARTY contains 4 Color LEDs.  Each color LED is composed of
//		three LEDs: one red, one blue, and one green.  These LEDs need
//	to be toggled in a PWM manner in order to create varying amounts of
//	reds, blues, greens, and other colors with varying components of red,
//	green, and blue.  This Verilog core creates a bus controlled core
//	so that these LEDs can be controlled by any bus master.  While the core
//	is ostensibly controlled via a wishbone bus, none of the control wires
//	are wishbone wires, save the i_stb wire.  Address wires are not needed,
//	as this core only implements a single address.  Stall is permanently
//	set to zero.  Ack is always on the clock after STB is true (but not set
//	here), and the output data is given by o_data.  See fastio.v for how to
//	connect this to a wishbone bus.
//
//	The core also accepts 9-bits from a counter created elsewhere.  This
//	counter is created quite simply, and phase is irrelevant for our
//	purposes here.  Thy reason why we don't create the counter within this
//	core is because the same counter can also be shared with the other
//	clrled cores.  The code to generate this counter is quite simple:
//
//		reg	[8:0]	counter;
//		always @(posedge i_clk)
//			counter <= counter + 9'h1;
//
//
//	The core creates and maintains one 32-bit register on the bus.  This
//	register contains four bytes:
//
//	Byte 0 (MSB)
//		Contains the most significant bits of the red, green, and blue
//		color.  Since using these bits sets the CLRLED to be *very*
//		bright, the design is set to assume they will rarely be used.
//
//	Byte 1
//		The red control.  The higher the value, the brighter the red
//		component will be.
//
//	Byte 2	Blue control.
//	Byte 3	Green control.
//
//	As examples, setting this register to 0x0ffffff will produce a bright
//	white light from the color LED.  Setting it to 0x070000 will produce
//	a dimmer red light.
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
// }}}
module	clrled(
		input	wire		i_clk, i_stb,
		input	wire	[31:0]	i_data,
		input	wire	[8:0]	i_counter,
		output	wire	[31:0]	o_data,
		output	reg	[2:0]	o_led
	);

	genvar		gk;
	reg	[8:0]	r_clr_led_r, r_clr_led_g, r_clr_led_b;
	wire	[8:0]	rev_counter;

	// If i_counter isn't available, just build one as in:
	//
	// reg [8:0] counter;
	// always @(posedge i_clk) counter <= counter + 1'b1;
	//

	initial	r_clr_led_r = 9'h003; // Color LED on the far right
	initial	r_clr_led_g = 9'h000;
	initial	r_clr_led_b = 9'h000;

	always @(posedge i_clk)
	if (i_stb)
	begin
		r_clr_led_r <= { i_data[26], i_data[23:16] };
		r_clr_led_g <= { i_data[25], i_data[15: 8] };
		r_clr_led_b <= { i_data[24], i_data[ 7: 0] };
	end

	assign	o_data = { 5'h0,
			r_clr_led_r[8], r_clr_led_g[8], r_clr_led_b[8],
			r_clr_led_r[7:0], r_clr_led_g[7:0], r_clr_led_b[7:0]
		};

	generate for(gk=0; gk<9; gk=gk+1)
	begin : GEN_BITREVERSE
		assign	rev_counter[gk] = i_counter[8-gk];
	end endgenerate

	always @(posedge i_clk)
		o_led <= {	(rev_counter[8:0] < r_clr_led_r),
				(rev_counter[8:0] < r_clr_led_g),
				(rev_counter[8:0] < r_clr_led_b) };

	// Make Verilator happy
	// {{{
	// verilator lint_off UNUSED
	wire	[4:0]	unused;
	assign	unused = { i_data[31:27] };
	// verilator lint_on  UNUSED
	// }}}
endmodule
