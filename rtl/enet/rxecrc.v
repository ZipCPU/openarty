////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rxecrc.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To detect any CRC errors in the packet as received.  The CRC
//		is not stripped as part of this process.  However, any bytes
//	following the CRC, up to four, will be stripped from the output.
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
`define	CRCBIT8	32'hedb88320
`define	CRCBIT4	32'h76dc4190
`define	CRCBIT2	32'h3b6e20c8
`define	CRCBIT1	32'h1db71064
module	rxecrc(i_clk, i_ce, i_en, i_cancel, i_v, i_d, o_v, o_d, o_err);
	input	wire		i_clk, i_ce, i_en, i_cancel;
	input	wire		i_v;
	input	wire	[3:0]	i_d;
	output	reg		o_v;
	output	reg	[3:0]	o_d;
	output	wire		o_err;

	reg	r_err;
	reg	[6:0]	r_mq; // Partial CRC matches
	reg	[3:0]	r_mp; // Prior CRC matches

	reg	[31:0]	r_crc;
	reg	[27:0]	r_crc_q0;
	reg	[23:0]	r_crc_q1;
	reg	[19:0]	r_crc_q2;
	reg	[15:0]	r_crc_q3;
	reg	[11:0]	r_crc_q4;
	reg	[ 7:0]	r_crc_q5;
	reg	[ 3:0]	r_crc_q6;

	reg	[14:0]	r_buf;

	wire	[3:0]	lownibble;
	assign	lownibble = r_crc[3:0] ^ i_d;

	wire	[31:0]	shifted_crc;
	assign	shifted_crc = { 4'h0, r_crc[31:4] };
	always @(posedge i_clk)
	if (i_ce)
	begin

		r_crc_q0 <= r_crc[31:4];
		r_crc_q1 <= r_crc_q0[27:4];
		r_crc_q2 <= r_crc_q1[23:4];
		r_crc_q3 <= r_crc_q2[19:4];
		r_crc_q4 <= r_crc_q3[15:4];
		r_crc_q5 <= r_crc_q4[11:4];
		r_crc_q6 <= r_crc_q5[ 7:4];

		r_buf <= { r_buf[9:0], i_v, i_d };
		if (((!i_v)&&(!o_v))||(i_cancel))
		begin
			r_crc <= 32'hffff_ffff;
			r_err <= 1'b0;

			r_mq[6:0] <= 7'h0;

			r_mp <= 4'h0;

			r_buf[ 4] <= 1'b0;
			r_buf[ 9] <= 1'b0;
			r_buf[14] <= 1'b0;
		end else
		begin
			/// Calculate the CRC
			case(lownibble)
			4'h0: r_crc <= shifted_crc;
			4'h1: r_crc <= shifted_crc ^ `CRCBIT1;
			4'h2: r_crc <= shifted_crc ^ `CRCBIT2;
			4'h3: r_crc <= shifted_crc ^ `CRCBIT2 ^ `CRCBIT1;
			4'h4: r_crc <= shifted_crc ^ `CRCBIT4;
			4'h5: r_crc <= shifted_crc ^ `CRCBIT4 ^ `CRCBIT1;
			4'h6: r_crc <= shifted_crc ^ `CRCBIT4 ^ `CRCBIT2;
			4'h7: r_crc <= shifted_crc ^ `CRCBIT4 ^ `CRCBIT2 ^ `CRCBIT1;
			4'h8: r_crc <= shifted_crc ^ `CRCBIT8;
			4'h9: r_crc <= shifted_crc ^ `CRCBIT8 ^ `CRCBIT1;
			4'ha: r_crc <= shifted_crc ^ `CRCBIT8 ^ `CRCBIT2;
			4'hb: r_crc <= shifted_crc ^ `CRCBIT8 ^ `CRCBIT2 ^ `CRCBIT1;
			4'hc: r_crc <= shifted_crc ^ `CRCBIT8 ^ `CRCBIT4;
			4'hd: r_crc <= shifted_crc ^ `CRCBIT8 ^ `CRCBIT4 ^ `CRCBIT1;
			4'he: r_crc <= shifted_crc ^ `CRCBIT8 ^ `CRCBIT4 ^ `CRCBIT2;
			4'hf: r_crc <= shifted_crc ^ `CRCBIT8 ^ `CRCBIT4 ^ `CRCBIT2 ^ `CRCBIT1;
			endcase

			r_mq[0] <=            (i_v)&&(i_d == (~r_crc[3:0]));
			r_mq[1] <= (r_mq[0])&&(i_v)&&(i_d == (~r_crc_q0[3:0]));
			r_mq[2] <= (r_mq[1])&&(i_v)&&(i_d == (~r_crc_q1[3:0]));
			r_mq[3] <= (r_mq[2])&&(i_v)&&(i_d == (~r_crc_q2[3:0]));
			r_mq[4] <= (r_mq[3])&&(i_v)&&(i_d == (~r_crc_q3[3:0]));
			r_mq[5] <= (r_mq[4])&&(i_v)&&(i_d == (~r_crc_q4[3:0]));
			r_mq[6] <= (r_mq[5])&&(i_v)&&(i_d == (~r_crc_q5[3:0]));
			//r_mq7<=(r_mq6)&&(i_v)&&(i_d == r_crc_q6[3:0]);

			r_mp <= { r_mp[2:0], 
				(r_mq[6])&&(i_v)&&(i_d == (~r_crc_q6[3:0])) };

			// Now, we have an error if ...
			// On the first empty, none of the prior N matches
			// matched.
			r_err <= (r_err)||((i_en)&&(!i_v)&&(r_buf[4])&&(r_mp == 4'h0));
			if ((!i_v)&&(r_buf[4]))
			begin
				if (r_mp[3])
				begin
					r_buf[ 4] <= 1'b0;
					r_buf[ 9] <= 1'b0;
					r_buf[14] <= 1'b0;
				end else if (r_mp[2])
				begin
					r_buf[4] <= 1'b0;
					r_buf[9] <= 1'b0;
				end else if (r_mp[1])
					r_buf[4] <= 1'b0;
				// else if (r_mp[0]) ... keep everything
			end

			o_v <= r_buf[14];
			o_d <= r_buf[13:10];
		end
	end

	assign o_err = r_err;

endmodule
