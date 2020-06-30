////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rxepreambl.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To detect, and then remove, any ethernet hardware preamble.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2016-2020, Gisselquist Technology, LLC
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
module	rxepreambl(i_clk, i_ce, i_en, i_cancel, i_v, i_d, o_v, o_d);
	input	wire		i_clk, i_ce, i_en, i_cancel;
	input	wire		i_v;
	input	wire	[3:0]	i_d;
	output	reg		o_v;
	output	reg	[3:0]	o_d;

	reg	r_inpkt, r_cancel;
	reg	[14:0]	r_buf;

	always @(posedge i_clk)
	if(i_ce)
	begin
		if (((!i_v)&&(!o_v))||(i_cancel))
		begin
			// Set us up
			r_inpkt <= 1'b0;
			r_cancel <= (i_v)||(o_v);
		end else if (r_cancel)
			r_cancel <= (i_v)||(o_v);

		if ((i_en)&&(!r_inpkt))
		begin
			r_buf <= { r_buf[9:0], i_v, i_d };
			r_inpkt <= (!r_cancel)&&((r_buf == { 5'h15, 5'h15, 5'h15 })&&(i_v)&&(i_d == 4'hd));
			o_v <= 1'b0;
		end else begin
			o_v <= (i_v)&&(!r_cancel)&&(r_inpkt);
			o_d <= i_d;
		end
	end
endmodule

