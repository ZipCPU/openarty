////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	addepad.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To force the minimum packet size of an ethernet frame to be
//		a minimum of 64 bytes.  This assumes that the CRC will be
//	adding 32-bits to the packet after us, so instead of padding to
//	64 bytes, we'll pad to 60 bytes instead.  If the user is providing
//	their own CRC, they'll need to adjust the padding themselves.
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
module addepad(i_clk, i_ce, i_en, i_cancel, i_v, i_d, o_v, o_d);
	parameter	MINNIBBLES=120;
	localparam	LGNCOUNT=(MINNIBBLES<63)? 6
				:((MINNIBBLES<127)? 7:((MINNIBBLES<255)? 8:9));
	input	wire		i_clk, i_ce, i_en, i_cancel;
	input	wire		i_v;	// Valid
	input	wire	[3:0]	i_d;	// Data nibble
	output	reg		o_v;
	output	reg	[3:0]	o_d;

	reg	[(LGNCOUNT-1):0]	r_ncnt;
	initial	o_v = 1'b0;
	always @(posedge i_clk)
	if (i_ce)
	begin
		if (((!i_v)&&(!o_v))||(i_cancel))
		begin
			r_ncnt <= 0;
			o_v <= 1'b0;
		end else if (i_v)
		begin
			o_v <= i_v;
			r_ncnt <= (r_ncnt<MINNIBBLES) ? r_ncnt+1'b1 : r_ncnt;
		end else begin
			o_v <= (r_ncnt<MINNIBBLES);
			r_ncnt <= (r_ncnt<MINNIBBLES) ? r_ncnt+1'b1 : r_ncnt;
		end

		if (i_v)
			o_d <= i_d;
		else
			o_d <= 4'h0;
	end

endmodule
