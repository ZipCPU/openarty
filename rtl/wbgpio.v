////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbgpio.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	A General Purpose Input/Output controller.  This controller 
//		allows a user to read the current state of the 16-GPIO input
//	pins, or to set the state of the 16-GPIO output pins. Specific numbers
//	of pins are configurable from 1-16.
//
//	Unlike other controllers, this controller offers no capability to
//	change input/output direction, or to implement pull-up or pull-down
//	resistors.  It simply changes and adjusts the values going out the
//	output pins, while allowing a user to read the values on the input
//	pins.
//
//	Any change of an input pin value will result in the generation of an
//	interrupt signal.
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
module wbgpio(i_clk, i_wb_cyc, i_wb_stb, i_wb_we, i_wb_data, o_wb_data,
		i_gpio, o_gpio, o_int);
	parameter	NIN=16, NOUT=16, DEFAULT=16'h00;
	input			i_clk;
	//
	input			i_wb_cyc, i_wb_stb, i_wb_we;
	input		[31:0]	i_wb_data;
	output	wire	[31:0]	o_wb_data;
	//
	input		[(NIN-1):0]	i_gpio;
	output	reg	[(NOUT-1):0]	o_gpio;
	//
	output	reg		o_int;

	// 9LUT's, 16 FF's
	always @(posedge i_clk)
		if ((i_wb_stb)&&(i_wb_we))
			o_gpio <= ((o_gpio)&(~i_wb_data[(NOUT+16-1):16]))
				|((i_wb_data[(NOUT-1):0])&(i_wb_data[(NOUT+16-1):16]));

	reg	[(NIN-1):0]	x_gpio, r_gpio;
	// 3 LUTs, 33 FF's
	always @(posedge i_clk)
	begin
		x_gpio <= i_gpio;
		r_gpio <= x_gpio;
		o_int  <= (x_gpio != r_gpio);
	end

	assign	o_wb_data = { {(16-NIN){1'b0}}, r_gpio,
					{(16-NOUT){1'b0}}, o_gpio };
endmodule
