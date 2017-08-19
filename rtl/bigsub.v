////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	bigsub.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To subtract two 64-bit numbers, while maintaining
//		synchronization to whatever purpose these numbers had
//	originally.  For this reason, there is an i_sync input and an o_sync
//	output.  If i_sync is true with a particular set of data, o_sync will
//	then be true when that data is placed on the output.
//
//	If we needed to slow this down even more, I suppose we could register
//	the inputs before we used them ...
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
`default_nettype	none
//
module	bigsub(i_clk, i_sync, i_a, i_b, o_r, o_sync);
	parameter	NCLOCKS = 1;
	input	wire	i_clk, i_sync;
	input	wire	[63:0]	i_a, i_b;
	output	wire	[63:0]	o_r;
	output	wire	o_sync;

	generate
	if (NCLOCKS == 0)
	begin
		assign	o_sync= i_sync;
		assign	o_r = i_a - i_b;
	end else if (NCLOCKS == 1)
	begin
		reg		r_sync;
		reg	[63:0]	r_out;
		always @(posedge i_clk)
			r_sync <= i_sync;
		always @(posedge i_clk)
			r_out <= i_a - i_b;

		assign	o_sync = r_sync;
		assign	o_r = r_out;
	end else // if (NCLOCKS == 2)
	begin
		reg		r_sync, r_pps;
		reg	[31:0]	r_hi, r_low;

		reg	[63:0]	f_r;
		reg		f_sync;

		wire	[63:0]	i_b_n;
		assign		i_b_n = ~i_b;

		initial	r_sync = 1'b0;
		always @(posedge i_clk)
			r_sync <= i_sync;

		always @(posedge i_clk)
			{ r_pps, r_low } <= i_a[31:0] + i_b_n[31:0] + 1'b1;
		always @(posedge i_clk)
			r_hi <= i_a[63:32] + i_b_n[63:32];

		initial	f_sync = 1'b0;
		always @(posedge i_clk)
			f_sync <= r_sync;
		always @(posedge i_clk)
			f_r[31:0] <= r_low;
		always @(posedge i_clk)
			f_r[63:32] <= r_hi + { 31'h00, r_pps };

		assign	o_sync = f_sync;
		assign	o_r    = f_r;

	end endgenerate

endmodule

