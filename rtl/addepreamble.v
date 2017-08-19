////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	addepreamble.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To add the ethernet preamble to a stream of values (i.e., to
//		an ethernet packet ...)
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
module addepreamble(i_clk, i_ce, i_en, i_cancel, i_v, i_d, o_v, o_d);
	input	wire		i_clk, i_ce, i_en, i_cancel;
	input	wire		i_v;	// Valid
	input	wire	[3:0]	i_d;	// Data nibble
	output	wire		o_v;
	output	wire	[3:0]	o_d;

	reg	[84:0]	shiftreg;
	reg		r_v;
	reg	[3:0]	r_d;

	initial	r_v = 1'b0;
	always @(posedge i_clk)
	if (i_ce)
	begin
		shiftreg <= { shiftreg[79:0], { i_v, i_d }};
		r_v <= shiftreg[84];
		r_d <= shiftreg[83:80];
		if (((!i_v)&&(!o_v))||(i_cancel))
		begin
			shiftreg <= { 5'h00, 5'h15, 5'h15, 5'h15, 5'h15,
				5'h15, 5'h15, 5'h15, 5'h15,
				5'h15, 5'h15, 5'h15, 5'h15,
				5'h15, 5'h15, 5'h15, 5'h1d };
			if (!i_en)
			begin
				shiftreg[ 4] <= 1'b0;
				shiftreg[ 9] <= 1'b0;
				shiftreg[14] <= 1'b0;
				shiftreg[19] <= 1'b0;
				shiftreg[24] <= 1'b0;
				shiftreg[29] <= 1'b0;
				shiftreg[34] <= 1'b0;
				shiftreg[39] <= 1'b0;
				shiftreg[44] <= 1'b0;
				shiftreg[49] <= 1'b0;
				shiftreg[54] <= 1'b0;
				shiftreg[59] <= 1'b0;
				shiftreg[64] <= 1'b0;
				shiftreg[69] <= 1'b0;
				shiftreg[74] <= 1'b0;
				shiftreg[79] <= 1'b0;
			end
		end
	end

	assign	o_v = r_v;
	assign	o_d = r_d;

endmodule
