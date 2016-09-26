////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wboled.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	
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
module	wboled(i_clk, i_cyc, i_stb, i_we, i_addr, i_data,
			o_ack, o_stall, o_data,
		o_sck, o_cs_n, o_mosi, o_dbit,
		o_pwr, o_int);
	parameter	CBITS=4; // 2^4*2@6.25ns -> 200ns/clock > 150ns min
	input			i_clk, i_cyc, i_stb, i_we;
	input		[1:0]	i_addr;
	input		[31:0]	i_data;
	output	reg		o_ack;
	output	wire		o_stall;
	output	reg	[31:0]	o_data;
	output	wire		o_sck, o_cs_n, o_mosi, o_dbit;
	output	reg	[2:0]	o_pwr;
	output	wire		o_int;

	reg		dev_wr, dev_dbit;
	reg	[31:0]	dev_word;
	reg	[1:0]	dev_len;
	wire		dev_busy;
	lloled	#(CBITS)
		lwlvl(i_clk, dev_wr, dev_dbit, dev_word, dev_len, dev_busy,
			o_sck, o_cs_n, o_mosi, o_dbit);

`define	EXTRA_WB_DELAY
`ifdef	EXTRA_WB_DELAY
	reg		r_wb_stb, r_wb_we;
	reg	[31:0]	r_wb_data;
	reg	[1:0]	r_wb_addr;
	always @(posedge i_clk)
		r_wb_stb <= i_stb;
	always @(posedge i_clk)
		r_wb_we <= i_we;
	always @(posedge i_clk)
		r_wb_data <= i_data;
	always @(posedge i_clk)
		r_wb_addr <= i_addr;
`else
	wire		r_wb_stb, r_wb_we;
	wire		r_wb_data;
	wire	[1:0]	r_wb_addr;

	assign	r_wb_stb  = i_stb;
	assign	r_wb_we   = i_we;
	assign	r_wb_data = i_data;
	assign	r_wb_addr = i_addr;
`endif



	reg		r_busy;
	reg	[3:0]	r_len;
	reg	[31:0]	r_a, r_b;
	always @(posedge i_clk)
		if ((r_wb_stb)&&(r_wb_we))
		begin
			if (r_wb_addr[1:0]==2'b01)
				r_a <= r_wb_data;
			if (r_wb_addr[1:0]==2'b10)
				r_b <= r_wb_data;
		end else if (r_cstb)
		begin
			r_a <= 32'h00;
			r_b <= 32'h00;
		end

	always @(posedge i_clk)
	begin
		case (r_wb_addr)
		2'b00: o_data <= { 13'h00, o_pwr, 8'h00, r_len, 3'h0, r_busy };
		2'b01: o_data <= r_a;
		2'b10: o_data <= r_b;
		2'b11: o_data <= { 13'h00, o_pwr, 8'h00, r_len, 3'h0, r_busy };
		endcase
	end

	initial	o_ack = 1'b0;
	always @(posedge i_clk)
		o_ack <= r_wb_stb;
	assign	o_stall = 1'b0;

	reg	r_cstb, r_dstb, r_pstb;
	reg	[23:0]	r_data;
	initial	r_cstb = 1'b0;
	initial	r_dstb = 1'b0;
	initial	r_pstb = 1'b0;
	always @(posedge i_clk)
		r_cstb <= (r_wb_stb)&&(r_wb_addr[1:0]==2'b00);
	always @(posedge i_clk)
		r_dstb <= (r_wb_stb)&&(r_wb_addr[1:0]==2'b11)&&(r_wb_data[22:20]==3'h0);
	always @(posedge i_clk)
		r_pstb <= (r_wb_stb)&&(r_wb_addr[1:0]==2'b11)&&(r_wb_data[22:20]!=3'h0);
	always @(posedge i_clk)
		r_data <= r_wb_data[23:0];

	initial	o_pwr = 3'h0;
	always @(posedge i_clk)
		if (r_pstb)
			o_pwr <= ((o_pwr)&(~r_data[22:20]))
					|((r_wb_data[18:16])&(r_data[22:20]));

	reg	[3:0]	b_len;
	always @(posedge i_clk)
		casez(r_wb_data[31:28])
		4'b000?: b_len <= (r_wb_data[16])? 4'h1:4'h2;
		4'b0010: b_len <= 4'h3;
		4'b0011: b_len <= 4'h4;
		4'b0100: b_len <= 4'h5;
		4'b0101: b_len <= 4'h6;
		4'b0110: b_len <= 4'h7;
		4'b0111: b_len <= 4'h8;
		4'b1000: b_len <= 4'h9;
		4'b1001: b_len <= 4'ha;
		4'b1010: b_len <= 4'hb;
		default: b_len <= 4'h0;
		endcase

	reg	[87:0]	r_sreg;
	initial	r_busy = 1'b0;
	always @(posedge i_clk)
	if ((~r_busy)&&(r_cstb))
	begin
		dev_wr   <= 1'b0;
		dev_dbit <= 1'b0;
		r_sreg <= { r_data[23:0], r_a, r_b };
		r_len <= b_len;
		r_busy <= (b_len != 4'h0);
		if (b_len == 4'h1)
			r_sreg[87:72] <= { r_data[7:0], r_data[7:0] };
		else if (b_len == 4'h2)
			r_sreg[87:72] <= r_data[15:0];
		else
			r_sreg[87:72] <= r_data[23:8];
	end else if ((~dev_busy)&&(r_dstb))
	begin
		dev_wr   <= 1'b0;
		dev_dbit <= 1'b1;
		r_sreg <= { r_data[15:0], 72'h00 };
		r_len <= 4'h2;
		r_busy <= 1'b1;
	end else if ((r_busy)&&(~dev_busy))
	begin
		dev_word <= r_sreg[87:56];
		r_sreg <= { r_sreg[55:0], 32'h00 };
		dev_len <= (r_len > 4'h4)? 2'b11:(r_len[1:0]+2'b11);
		r_len <= (r_len > 4'h4) ? (r_len-4'h4):0;
	end else if (r_busy)
		r_busy <= (r_len != 4'h0);

	assign	o_int = (~r_busy);

endmodule
