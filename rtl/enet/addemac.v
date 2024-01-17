////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	addemac.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To add the device hardware MAC address into a data stream
//		that doesn't have it.
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
module	addemac(i_clk, i_ce, i_en, i_cancel, i_hw_mac,
		i_v, i_nibble, o_v, o_nibble);
	input	wire		i_clk, i_ce, i_en, i_cancel;
	input	wire	[47:0]	i_hw_mac;
	input	wire		i_v;
	input	wire	[3:0]	i_nibble;
	output	reg		o_v;
	output	reg	[3:0]	o_nibble;

	wire	[47:0]	mac_remapped;
	assign	mac_remapped[47:44] = i_hw_mac[43:40];
	assign	mac_remapped[43:40] = i_hw_mac[47:44];
	assign	mac_remapped[39:36] = i_hw_mac[35:32];
	assign	mac_remapped[35:32] = i_hw_mac[39:36];
	assign	mac_remapped[31:28] = i_hw_mac[27:24];
	assign	mac_remapped[27:24] = i_hw_mac[31:28];
	assign	mac_remapped[23:20] = i_hw_mac[19:16];
	assign	mac_remapped[19:16] = i_hw_mac[23:20];
	assign	mac_remapped[15:12] = i_hw_mac[11: 8];
	assign	mac_remapped[11: 8] = i_hw_mac[15:12];
	assign	mac_remapped[ 7: 4] = i_hw_mac[ 3: 0];
	assign	mac_remapped[ 3: 0] = i_hw_mac[ 7: 4];

	reg	[47:0]	r_hw;
	reg	[59:0]	r_buf;
	reg	[5:0]	r_pos;

	always @(posedge i_clk)
	if (i_ce)
	begin
		r_buf <= { r_buf[54:0], i_v, i_nibble };

		if (((!i_v)&&(!o_v))||(i_cancel))
		begin
			r_buf[ 4] <= 1'b0;
			r_buf[ 9] <= 1'b0;
			r_buf[14] <= 1'b0;
			r_buf[19] <= 1'b0;
			r_buf[24] <= 1'b0;
			r_buf[29] <= 1'b0;
			r_buf[34] <= 1'b0;
			r_buf[39] <= 1'b0;
			r_buf[44] <= 1'b0;
			r_buf[49] <= 1'b0;
			r_buf[54] <= 1'b0;
			r_buf[59] <= 1'b0;
		end

		if ((!i_v)||(i_cancel))
			r_hw <= mac_remapped;
		else
			r_hw <= { r_hw[43:0], r_hw[47:44] };

		if (((!i_v)&&(!o_v))||(i_cancel))
			r_pos <= 6'h0;
		else if ((r_pos < 6'h18 )&&(i_en))
			r_pos <= r_pos + 6'h1;
		else if ((r_pos < 6'h20 )&&(!i_en))
			r_pos <= r_pos + 6'h1;

		if (i_en)
		begin
			if (((!i_v)&&(!o_v))||(i_cancel))
			begin
				o_v <= 1'b0;
			end else begin
				if (r_pos < 6'hc) // six bytes, but counted as 
				begin		// nibbles
					{ o_v, o_nibble } <= { i_v, i_nibble };
				end else if (r_pos < 6'h18)
				begin
					{ o_v, o_nibble } <= { 1'b1, r_hw[47:44] };
				end else
					{ o_v, o_nibble } <= r_buf[59:55];
			end
		end else if (r_pos < 6'h20)
			{ o_v, o_nibble } <= r_buf[19:15];
		else
			{ o_v, o_nibble } <= { i_v, i_nibble };
		if(i_cancel)
			o_v <= 1'b0;
	end

endmodule
