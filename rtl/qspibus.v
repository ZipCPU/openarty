////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	qspibus.v
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
`default_nettype	none
//
//
// `define	QSPI_READ_ONLY
module	qspibus(i_clk, i_rst, i_cyc, i_data_stb, i_ctrl_stb,
		i_we, i_addr, i_data,
			o_wb_ack, o_wb_stall, o_wb_data,
		o_wr, o_addr, o_data, o_sector,
		o_readreq, o_piperd, o_wrreq, o_erreq, o_pipewr, o_endwr,
			o_ctreq, o_idreq, o_other,
		i_ack, i_xip, i_quad, i_idloaded, i_wip, i_spi_stopped);
	//
	input	wire		i_clk, i_rst;
	// Wishbone bus inputs
	input	wire		i_cyc, i_data_stb, i_ctrl_stb, i_we;
	input	wire	[21:0]	i_addr;
	input	wire	[31:0]	i_data;
	// Wishbone bus outputs
	output	reg		o_wb_ack;
	output	reg		o_wb_stall;
	output	wire	[31:0]	o_wb_data;
	// Internal signals to the QSPI flash interface
	output	reg		o_wr;
	output	reg	[21:0]	o_addr;
	output	reg	[31:0]	o_data;
	output	wire	[21:0]	o_sector;
	output	reg		o_readreq, o_piperd, o_wrreq, o_erreq,
				o_pipewr, o_endwr,
				o_ctreq, o_idreq;
	output	wire		o_other;
	input	wire		i_ack, i_xip, i_quad, i_idloaded;
	input	wire		i_wip, i_spi_stopped;


	//
	reg	pending, lcl_wrreq, lcl_ctreq, lcl_ack, ack, wp_err, wp;
	reg	[12:0]	esector;
	reg	[21:0]	next_addr;


	reg	pipeable;
	reg	same_page;
	always @(posedge i_clk)
		same_page <= (i_data_stb)&&(i_we)
			&&(i_addr[21:6] == o_addr[21:6])
			&&(i_addr[5:0] == o_addr[5:0] + 6'h1);

	initial	pending = 1'b0;
	initial	o_readreq = 1'b0;
	initial	lcl_wrreq = 1'b0;
	initial	lcl_ctreq = 1'b0;
	initial	o_ctreq   = 1'b0;
	initial	o_idreq   = 1'b0;

	initial	ack = 1'b0;
	always @(posedge i_clk)
		ack <= (i_ack)||(lcl_ack);

	// wire	[9:0]	key;
	// assign	key = 10'h1be;
	reg	lcl_key, set_sector, ctreg_stb;
	initial	lcl_key = 1'b0;
	always @(posedge i_clk)
		// Write protect "key" to enable the disabling of write protect
		lcl_key<= (i_ctrl_stb)&&(~wp)&&(i_we)&&(i_addr[5:0]==6'h00)
				&&(i_data[9:0] == 10'h1be)&&(i_data[31:30]==2'b11);
	initial	set_sector = 1'b0;
	always @(posedge i_clk)
		set_sector <= (i_ctrl_stb)&&(~o_wb_stall)
				&&(i_we)&&(i_addr[5:0]==6'h00)
				&&(i_data[9:0] == 10'h1be);

	initial	ctreg_stb = 1'b0;
	initial	o_wb_stall = 1'b0;
	always @(posedge i_clk)
	begin // Inputs: rst, stb, stb, stall, ack, addr[4:0] -- 9
		if (i_rst)
			o_wb_stall <= 1'b0;
		else
			o_wb_stall <= (((i_data_stb)||(i_ctrl_stb))&&(~o_wb_stall))
				||((pending)&&(~ack));

		ctreg_stb <= (i_ctrl_stb)&&(~o_wb_stall)&&(i_addr[4:0]==5'h00)&&(~pending)
				||(pending)&&(ctreg_stb)&&(~lcl_ack)&&(~i_ack);
		if (~o_wb_stall)
		begin // Bus command accepted!
			if (i_data_stb)
				next_addr <= i_addr + 22'h1;
			if ((i_data_stb)||(i_ctrl_stb))
			begin
				pending <= 1'b1;
				o_addr <= i_addr;
				o_data <= i_data;
				o_wr   <= i_we;
			end

			if ((i_data_stb)&&(~i_we))
				o_readreq <= 1'b1;

			if ((i_data_stb)&&(i_we))
				lcl_wrreq <= 1'b1;
			if ((i_ctrl_stb)&&(~i_addr[4]))
			begin
				casez(i_addr[4:0])
				5'h0: lcl_ctreq<= 1'b1;
				5'h1: lcl_ctreq <= 1'b1;
				5'h2: lcl_ctreq <= 1'b1;
				5'h3: lcl_ctreq <= 1'b1;
				5'h4: lcl_ctreq <= 1'b1;
				5'h5: lcl_ctreq <= 1'b1;
				5'h6: lcl_ctreq <= 1'b1;
				5'h7: lcl_ctreq <= 1'b1;
				5'h8: o_idreq  <= 1'b1;	// ID[0]
				5'h9: o_idreq  <= 1'b1;	// ID[1]
				5'ha: o_idreq  <= 1'b1;	// ID[2]
				5'hb: o_idreq  <= 1'b1;	// ID[3]
				5'hc: o_idreq  <= 1'b1;	// ID[4]
				5'hd: lcl_ctreq <= 1'b1;	//
				5'he: lcl_ctreq <= 1'b1;
				5'hf: o_idreq   <= 1'b1; // Program OTP register
				default: begin o_idreq <= 1'b1; end
				endcase
			end else if (i_ctrl_stb)
				o_idreq <= 1'b1;
		end else if (ack)
		begin
			pending <= 1'b0;
			o_readreq <= 1'b0;
			o_idreq <= 1'b0;
			lcl_ctreq <= 1'b0;
			lcl_wrreq <= 1'b0;
		end

		if(i_rst)
		begin
			pending <= 1'b0;
			o_readreq <= 1'b0;
			o_idreq <= 1'b0;
			lcl_ctreq <= 1'b0;
			lcl_wrreq <= 1'b0;
		end

		if ((i_data_stb)&&((~o_wb_stall)||(i_ack)))
			o_piperd <= ((~i_we)&&(pipeable)&&(i_addr == next_addr));
		else if ((i_ack)&&(~i_data_stb))
			o_piperd <= 1'b0;
		if ((i_data_stb)&&(~o_wb_stall))
			pipeable <= (~i_we);
		else if ((i_ctrl_stb)&&(~o_wb_stall))
			pipeable <= 1'b0;

		o_pipewr <= (same_page)||(pending)&&(o_pipewr);
	end

	reg	r_other, last_wip;

	reg	last_pending;
	always @(posedge i_clk)
		last_pending <= pending;
	always @(posedge i_clk)
		last_wip <= i_wip;
	wire	new_req;
	assign	new_req = (pending)&&(~last_pending);

	initial	esector   = 13'h00;
	initial	o_wrreq   = 1'b0;
	initial	o_erreq   = 1'b0;
	initial	wp_err    = 1'b0;
	initial	lcl_ack   = 1'b0;
	initial	r_other   = 1'b0;
	initial	o_endwr   = 1'b1;
	initial	wp        = 1'b1;
	always @(posedge i_clk)
	begin
		if (i_ack)
		begin
			o_erreq <= 1'b0;
			o_wrreq <= 1'b0;
			o_ctreq <= 1'b0;
			r_other <= 1'b0;
		end

		if ((last_wip)&&(~i_wip))
			wp <= 1'b1;

		// o_endwr  <= ((~i_cyc)||(~o_wr)||(o_pipewr))
				// ||(~new_req)&&(o_endwr);
		o_endwr <= ((pending)&&(~o_pipewr))||((~pending)&&(~i_cyc));

		// Default ACK is always set to zero, unless the following ...
		o_wb_ack <= 1'b0;

		if (set_sector)
		begin
			esector[11:0] <= { o_data[21:14], 4'h0 };
			wp <= (o_data[30])&&(new_req)||(wp)&&(~new_req);
			esector[12] <= o_data[28]; // Subsector
			if (o_data[28])
			begin
				esector[3:0] <= o_data[13:10];
			end
		end

		lcl_ack <= 1'b0;
		if ((i_wip)&&(new_req)&&(~same_page))
		begin
			o_wb_ack <= 1'b1;
			lcl_ack <= 1'b1;
		end else if ((ctreg_stb)&&(new_req))
		begin // A request of the status register
			// Always ack control register, even on failed attempts
			// to erase.
			o_wb_ack <= 1'b1;
			lcl_ack <= 1'b1;

			if (lcl_key)
			begin
				o_ctreq <= 1'b0;
				o_erreq <= 1'b1;
				r_other <= 1'b1;
				lcl_ack <= 1'b0;
			end else if ((o_wr)&&(~o_data[31]))
			begin // WEL or WEL disable
				o_ctreq <= (wp == o_data[30]);
				r_other <= (wp == o_data[30]);
				lcl_ack <= (wp != o_data[30]);
				wp <= !o_data[30];
			end else if (~o_wr)
				lcl_ack <= 1'b1;
			wp_err <= (o_data[31])&&(~lcl_key);
		end else if ((lcl_ctreq)&&(new_req))
		begin
			o_ctreq <= 1'b1;
			r_other <= 1'b1;
		end else if ((lcl_wrreq)&&(new_req))
		begin
			if (~wp)
			begin
				o_wrreq <= 1'b1;
				r_other <= 1'b1;
				o_endwr  <= 1'b0;
				lcl_ack <= 1'b0;
			end else begin
				o_wb_ack <= 1'b1;
				wp_err <= 1'b1;
				lcl_ack <= 1'b1;
			end
		end

		if (i_rst)
		begin
			o_ctreq <= 1'b0;
			o_erreq <= 1'b0;
			o_wrreq <= 1'b0;
			r_other <= 1'b0;
		end

	end


	assign o_wb_data[31:0] = { i_wip, ~wp, i_quad, esector[12],
			i_idloaded, wp_err, i_xip, i_spi_stopped,
			2'b00, esector[11:0], 10'h00 };
	assign	o_sector = { 2'b00, esector[11:0], 8'h00 }; // 22 bits
	assign	o_other = (r_other)||(o_idreq);

endmodule
