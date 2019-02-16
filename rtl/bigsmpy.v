////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	bigsmpy.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To multiply two 32-bit numbers into a 64-bit number.  We try
//		to use the hardware multiply to do this, but just what kind of
//	hardware multiply is actually available ... can be used to determine
//	how many clocks to take.
//
//	If you look at the algorithm below, it's actually a series of a couple
//	of independent algorithms dependent upon the parameter NCLOCKS.  If your
//	timing through here becomes a problem, set NCLOCKS to a higher number
//	and see if that doesn't help things.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2019, Gisselquist Technology, LLC
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
`default_nettype	none
//
module	bigsmpy(i_clk, i_sync, i_sgn, i_a, i_b, o_r, o_sync);
	parameter	NCLOCKS = 1;
	input	wire		i_clk, i_sync, i_sgn;
	input	wire	[31:0]	i_a, i_b;
	output	reg	[63:0]	o_r;
	output	reg		o_sync;

	generate
	if (NCLOCKS == 1)
	begin
		wire	signed	[31:0]	w_sa, w_sb;
		wire		[31:0]	w_ua, w_ub;

		assign	w_sa = i_a;
		assign	w_sb = i_b;
		assign	w_ua = i_a;
		assign	w_ub = i_b;

		always @(posedge i_clk)
		begin
			o_sync <= i_sync;
			if (i_sgn)
				o_r <= w_sa * w_sb;
			else
				o_r <= w_ua * w_ub;
		end

	end else if (NCLOCKS == 2)
	begin
		reg	r_sync;
		reg	signed	[31:0]	r_sa, r_sb;
		wire		[31:0]	w_ua, w_ub;

		initial r_sync = 1'b0;
		always @(posedge i_clk)
		begin
			r_sync <=i_sync;
			r_sa <= i_a;
			r_sb <= i_b;
		end

		assign	w_ua = r_sa;
		assign	w_ub = r_sb;

		always @(posedge i_clk)
		begin
			o_sync <= r_sync;
			if (i_sgn)
				o_r <= r_sa * r_sb;
			else
				o_r <= w_ua * w_ub;
		end

	
	end else if (NCLOCKS == 5)
	begin
		//
		// A pipeline, shift register, to track our
		// synchronization pulse as it transits our pipeline
		//
		reg	[3:0]	r_s;

		//
		// Clock #1: Register our inputs, copy the value of the sign
		//		bit.
		reg		r_mpy_signed;
		reg	[31:0]	r_mpy_a_input, r_mpy_b_input;
		always @(posedge i_clk)
		begin
			if (i_sgn)
			begin
				// This is about more than making the inputs
				// unsigned, as you'll notice it makes positive
				// inputs otherwise negative.  Instead,
				// this is about making the inputs have offset
				// mode.  Hence
				//	i_a = r_mpy_a_input - 2^31
				// and so forth
				r_mpy_a_input <= {(~i_a[31]), i_a[30:0] };
				r_mpy_b_input <= {(~i_b[31]), i_b[30:0] };
			end else begin
				r_mpy_a_input <= i_a[31:0];
				r_mpy_b_input <= i_b[31:0];
			end

			r_mpy_signed <= i_sgn;
			r_s[0] <= i_sync;
		end

		reg	[31:0]	pp_f, pp_o, pp_i, pp_l;
		reg	[32:0]	pp_s;
		always @(posedge i_clk)
		begin
			pp_f <= r_mpy_a_input[31:16] * r_mpy_b_input[31:16];
			pp_o <= r_mpy_a_input[31:16] * r_mpy_b_input[15: 0];
			pp_i <= r_mpy_a_input[15: 0] * r_mpy_b_input[31:16];
			pp_l <= r_mpy_a_input[15: 0] * r_mpy_b_input[15: 0];

			if (r_mpy_signed)
				pp_s <= 32'h8000_0000 - (r_mpy_a_input[31:0]
					+ r_mpy_b_input[31:0]);
			else
				pp_s <= 33'h0;
			r_s[1] <= r_s[0];
		end

		reg	[32:0]	partial_mpy_oi, partial_mpy_lo;
		reg	[31:0]	partial_mpy_hi;
		always @(posedge i_clk)
		begin
			partial_mpy_lo[30: 0] <= pp_l[30:0];
			partial_mpy_lo[32:31] <= pp_s[0] + pp_l[31];
			partial_mpy_oi[32: 0] <= pp_o + pp_i;
			partial_mpy_hi[31: 0] <= pp_s[32:1] + pp_f;
			r_s[2] <= r_s[1];
		end

		reg		partial_mpy_2cl, partial_mpy_2ch;
		reg	[31:0]	partial_mpy_2lo, partial_mpy_2hi;
		always @(posedge i_clk)
		begin
			partial_mpy_2lo[15:0] <= partial_mpy_lo[15:0];
			{ partial_mpy_2cl, partial_mpy_2lo[31:16] }
				<= { 1'b0, partial_mpy_oi[15:0]}
						+ partial_mpy_lo[32:16];
			{ partial_mpy_2ch, partial_mpy_2hi[16:0] }
				<= partial_mpy_oi[32:16] + partial_mpy_hi[16:0];
			partial_mpy_2hi[31:16] <= { partial_mpy_2hi[31:17],
							1'b0 };
			r_s[3] <= r_s[2];
		end

		always @(posedge i_clk)
		begin
			o_r[31: 0] <= partial_mpy_2lo[31:0];
			o_r[63:32] <= partial_mpy_2hi
				+ { 14'h0, partial_mpy_2ch, 1'b0,
						15'h0, partial_mpy_2cl };
			o_sync <= r_s[3];
		end
	end endgenerate


endmodule
