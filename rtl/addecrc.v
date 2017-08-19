////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	addecrc.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To (optionally) add a CRC to a stream of nibbles.   The CRC
//		is calculated from the stream.
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
`default_nettype	none
//
module addecrc(i_clk, i_ce, i_en, i_cancel, i_v, i_d, o_v, o_d);
	localparam	INVERT = 1; // Proper operation requires INVERT=1
	input	wire		i_clk, i_ce, i_en, i_cancel;
	input	wire		i_v;
	input	wire	[3:0]	i_d;
	output	reg		o_v;
	output	reg	[3:0]	o_d;

	reg	[7:0]	r_p;
	reg	[31:0]	r_crc;
	wire	[3:0]	lownibble;
	wire	[31:0]	shifted_crc;

	assign	lownibble = r_crc[3:0] ^ i_d;
	assign	shifted_crc = { 4'h0, r_crc[31:4] };

	initial	o_v = 1'b0;
	always @(posedge i_clk)
	if (i_ce)
	begin
		if (((!i_v)&&(!o_v))||(i_cancel))
		begin
			r_crc <= (INVERT==0)? 32'h00 : 32'hffffffff;
			r_p <= 8'hff;
		end else if (i_v)
		begin
			o_v <= i_v;
			r_p <= 8'hff;
			o_d <= i_d;

`define	CRCBIT8	32'hedb88320
`define	CRCBIT4	32'h76dc4190
`define	CRCBIT2	32'h3b6e20c8
`define	CRCBIT1	32'h1db71064

			// 0xedb88320 . 76dc4190 . 3b6e20c8 . 1db71064 . 0edb8832
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

			default: r_crc <= { 4'h0, r_crc[31:4] };
			endcase
		end else begin
			r_p <= { r_p[6:0], 1'b0 };
			o_v <= (i_en)?r_p[7]:1'b0;
			o_d <= r_crc[3:0] ^ ((INVERT==0)? 4'h0:4'hf);
			r_crc <= { 4'h0, r_crc[31:4] };
		end
	end

endmodule

