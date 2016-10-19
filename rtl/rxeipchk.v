////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rxeipchk.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To cull any IP packets (EtherType=0x0806) from the stream
//		whose packet header checksums don't match.
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
module rxeipchk(i_clk, i_ce, i_en, i_cancel, i_v, i_d, o_err);
	input			i_clk, i_ce, i_en, i_cancel;
	input			i_v;	// Valid
	input		[3:0]	i_d;	// Data nibble
	output	reg		o_err;

	reg		r_v;
	reg	[15:0]	r_word;
	reg	[7:0]	r_cnt;
	reg	[5:0]	r_idx;
	always @(posedge i_clk)
	if (i_ce)
	begin
		if ((!i_v)||(i_cancel))
		begin
			r_cnt <= 0;
			r_idx <= 0;
		end else if(i_v)
		begin
			if (!(&r_cnt))
				r_cnt <= r_cnt + 1'b1;
			if (&r_cnt)
				r_v <= 1'b0;
			else
				r_v <= (r_cnt[1:0] == 2'b11);
			if (r_cnt[1:0]==2'b11)
				r_idx[5:0] <= r_cnt[7:2];
			if (!r_cnt[0])
				r_word <= { r_word[7:0], 4'h0, i_d };
			else
				r_word[7:4] <= i_d;
		end
	end

	reg		r_ip;
	reg	[5:0]	r_hlen;
	reg	[16:0]	r_check;
	always @(posedge i_clk)
	if (i_ce)
	begin
		if ((!i_v)||(i_cancel))
		begin
			o_err   <= 0;
			r_check <= 0;
			r_ip    <= 0;
		end else if (r_v)
		begin
			if (r_idx == 6'h6)
				r_ip <= (r_word == 16'h0800);
			else if (r_idx == r_hlen)
				r_ip <= 1'b0;
			if (r_idx == 6'h7)
				r_hlen <= {r_word[11:8], 1'b0 } + 5'h7;
			if (r_idx == r_hlen)
				o_err <= (r_ip)&&(i_en)&&(r_check[15:0] != 16'hffff);
			if (r_ip)
				r_check <= r_check[15:0] + r_word + { 15'h0, r_check[16]};
		end
	end

endmodule
