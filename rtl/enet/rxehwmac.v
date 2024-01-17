////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rxehwmac.v
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To remove MACs that aren't our own.  The input is a nibble
//		stream, where the first nibble is the first nibble of the
//	destination MAC (our MAC).  If enabled, this MAC is removed from the
//	stream.  If the MAC matches, the stream is allowed to continue.  If
//	the MAC doesn't match, the packet is thrown away.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2016-2020, Gisselquist Technology, LLC
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
module	rxehwmac(
		// {{{
		input	wire		i_clk, i_ce, i_en, i_cancel,
		input	wire	[47:0]	i_hwmac,
		input	wire		i_v,
		input	wire	[3:0]	i_d,
		output	reg		o_v,
		output	reg	[3:0]	o_d,
		output	wire		o_err,
		output	reg		o_broadcast
		// }}}
	);

	wire	[47:0]	mac_remapped;

	assign	mac_remapped[47:44] = i_hwmac[43:40];
	assign	mac_remapped[43:40] = i_hwmac[47:44];
	assign	mac_remapped[39:36] = i_hwmac[35:32];
	assign	mac_remapped[35:32] = i_hwmac[39:36];
	assign	mac_remapped[31:28] = i_hwmac[27:24];
	assign	mac_remapped[27:24] = i_hwmac[31:28];
	assign	mac_remapped[23:20] = i_hwmac[19:16];
	assign	mac_remapped[19:16] = i_hwmac[23:20];
	assign	mac_remapped[15:12] = i_hwmac[11: 8];
	assign	mac_remapped[11: 8] = i_hwmac[15:12];
	assign	mac_remapped[ 7: 4] = i_hwmac[ 3: 0];
	assign	mac_remapped[ 3: 0] = i_hwmac[ 7: 4];

	reg	[47:0]	r_hwmac;
	reg		r_cancel, r_err, r_hwmatch, r_broadcast;
	reg	[19:0]	r_buf;
	reg	[27:0]	r_p;

	always @(posedge i_clk)
	if (i_ce)
	begin
		if (i_cancel)
			r_cancel <= 1'b1;
		else if ((!i_v)&&(!o_v))
			r_cancel <= 1'b0;

		if ((i_en)&&(i_v)&&(r_p[11]))
		begin
			if (r_hwmac[47:44] != i_d)
				r_hwmatch <= 1'b0;
			if (4'hf != i_d)
				r_broadcast<= 1'b0;
		end

		if ((i_v)&&(r_p[11]))
			r_hwmac <= { r_hwmac[43:0], 4'h0 };

		r_err <= (i_en)&&(!r_hwmatch)&&(!r_broadcast)&&(i_v);
		o_broadcast <= (r_broadcast)&&(!r_p[11])&&(i_v);

		r_buf <= { r_buf[14:0], i_v, i_d };
		if (((!i_v)&&(!o_v))||(i_cancel))
		begin
			r_p <= 28'hfff_ffff;
			r_hwmac <= mac_remapped;
			r_hwmatch   <= 1'b1;
			r_broadcast <= 1'b1;
			r_buf[ 4] <= 1'b0;
			r_buf[ 9] <= 1'b0;
			r_buf[14] <= 1'b0;
			r_buf[19] <= 1'b0;
			o_v <= 1'b0;
			o_d <= i_d;
		end else begin
			r_p <= { r_p[26:0], 1'b0 };
			if (i_en)
			begin
				// Skip the first 6 bytes, and everything
				// following if the MAC doesn't match
				o_v <= (!r_p[11])&&(!r_cancel)&&(i_v);
				o_d <= i_d;
			end else begin
				// In this case, we wish to ignore everything,
				// but still duplicate the EtherType words
				if (r_p[27])
					{ o_v, o_d } <= { (i_v)&&(!r_cancel), i_d };
				else
					{ o_v, o_d } <= { (r_buf[19])&&(!r_cancel), r_buf[18:15] };
			end
		end

		if ((!i_en)&&(r_p[27]))
		begin // Clear out the top half of the EtherType word
			r_buf[18:15] <= 4'h0;
			r_buf[13:10] <= 4'h0;
		end
	end

	assign	o_err = r_err;

endmodule
