////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rxehwmac.v
//
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
//
// Copyright (C) 2016, Gisselquist Technology, LLC
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
module	rxehwmac(i_clk, i_ce, i_en, i_cancel, i_hwmac, i_v, i_d, o_v, o_d, o_err, o_broadcast);
	input			i_clk, i_ce, i_en, i_cancel;
	input		[47:0]	i_hwmac;
	input			i_v;
	input		[3:0]	i_d;
	output	reg		o_v;
	output	reg	[3:0]	o_d;
	output	wire		o_err;
	output	reg		o_broadcast;

	reg	[47:0]	r_hwmac;
	reg		r_cancel, r_err, r_hwmatch, r_broadcast;
	reg	[19:0]	r_buf;
	reg	[29:0]	r_p;

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

		r_err <= (i_en)&&(!r_hwmatch)&&(!r_broadcast)&&(i_v);
		o_broadcast <= (r_broadcast)&&(!r_p[11])&&(i_v);

		r_buf <= { r_buf[14:0], i_v, i_d };
		if (((!i_v)&&(!o_v))||(i_cancel))
		begin
			r_p <= 30'h3fff_ffff;
			r_hwmac <= i_hwmac;
			r_hwmatch   <= 1'b1;
			r_broadcast <= 1'b1;
			r_buf[ 4] <= 1'b0;
			r_buf[ 9] <= 1'b0;
			r_buf[14] <= 1'b0;
			r_buf[19] <= 1'b0;
			o_v <= 1'b0;
			o_d <= i_d;
		end else begin
			r_p <= { r_p[28:0], 1'b0 };
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
