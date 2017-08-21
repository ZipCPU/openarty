////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	readqspi.v
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
//
`define	RD_IDLE			4'h0
`define	RD_IDLE_GET_PORT	4'h1
`define	RD_SLOW_DUMMY		4'h2
`define	RD_SLOW_READ_DATA	4'h3
`define	RD_QUAD_READ_DATA	4'h4
`define	RD_QUAD_DUMMY		4'h5
`define	RD_QUAD_ADDRESS		4'h6
`define	RD_XIP			4'h7
`define	RD_GO_TO_IDLE		4'h8
`define	RD_GO_TO_XIP		4'h9
`define RD_IDLE_QUAD_PORT	4'ha

module	readqspi(i_clk, i_readreq, i_piperd, i_other_req, i_addr, o_bus_ack,
		o_qspi_req, i_grant,
			o_spi_wr, o_spi_hold, o_spi_word, o_spi_len,
				o_spi_spd, o_spi_dir, o_spi_recycle,
			i_spi_data, i_spi_valid, i_spi_busy, i_spi_stopped,
			o_data_ack, o_data, i_quad, i_xip, o_leave_xip);
	input	wire		i_clk;
	input	wire		i_readreq, i_piperd, i_other_req;
	input	wire	[21:0]	i_addr;
	output	reg		o_bus_ack, o_qspi_req;
	input	wire		i_grant;
	output	reg		o_spi_wr;
	output	wire		o_spi_hold;
	output	reg	[31:0]	o_spi_word;
	output	reg	[1:0]	o_spi_len;
	output	reg		o_spi_spd, o_spi_dir, o_spi_recycle;
	input	wire	[31:0]	i_spi_data;
	input	wire		i_spi_valid, i_spi_busy, i_spi_stopped;
	output	reg		o_data_ack;
	output	reg	[31:0]	o_data;
	input	wire		i_quad, i_xip;
	output	wire		o_leave_xip;

	reg	accepted;
	initial	accepted = 1'b0;
	always @(posedge i_clk)
		accepted <= (~i_spi_busy)&&(i_grant)&&(o_spi_wr)&&(~accepted);

	reg	[3:0]	rd_state;
	reg		r_leave_xip, r_xip, r_quad, r_requested;
	reg	[3:0]	invalid_ack_pipe;
	initial	rd_state = `RD_IDLE;
	initial o_data_ack = 1'b0;
	initial o_bus_ack  = 1'b0;
	initial o_qspi_req = 1'b0;
	always @(posedge i_clk)
	begin
		o_data_ack <= 1'b0;
		o_bus_ack <= 1'b0;
		o_spi_recycle <= 1'b0;
		if (i_spi_valid)
			o_data <= i_spi_data;
		invalid_ack_pipe <= { invalid_ack_pipe[2:0], accepted };
		case(rd_state)
		`RD_IDLE: begin
			r_requested <= 1'b0;
			o_qspi_req <= 1'b0;
			// 0x0b is a fast read, uses all SPI protocol
			// 0x6b is a Quad output fast read, uses SPI cmd,
			//			SPI address, QSPI data
			// 0xeb is a Quad I/O fast read, using SPI cmd,
			//			QSPI address and data
			o_spi_word <= { ((i_quad)? 8'hEB: 8'h0b), i_addr, 2'b00 };
			o_spi_wr <= 1'b0;
			o_spi_dir <= 1'b0;
			o_spi_spd <= 1'b0;
			o_spi_len <= (i_quad)? 2'b00 : 2'b11;
			r_xip <= (i_xip)&&(i_quad);
			r_leave_xip <= 1'b0; // Not in it, so can't leave it
			r_quad <= i_quad;
			if (i_readreq)
			begin
				rd_state <= `RD_IDLE_GET_PORT;
				o_bus_ack <= 1'b1;
			end end
		`RD_IDLE_GET_PORT: begin
			o_spi_wr <= 1'b1; // Write the address
			o_qspi_req <= 1'b1;
			if (accepted)
			begin
				rd_state <= (r_quad) ? `RD_IDLE_QUAD_PORT : `RD_SLOW_DUMMY;
				o_spi_word[31:8] <= o_spi_word[23:0];
			end end
		`RD_IDLE_QUAD_PORT: begin
			o_spi_wr <= 1'b1; // Write the command
			o_qspi_req <= 1'b1;
			o_spi_spd <= 1'b1;
			o_spi_dir <= 1'b0;
			o_spi_len <= 2'b10;

			// We haven't saved our address any where but in the
			// SPI word we just sent.  Hence, let's just
			// grab it from there.
			if (accepted)
				rd_state <= `RD_SLOW_DUMMY;
			end
		`RD_SLOW_DUMMY: begin
			o_spi_wr <= 1'b1; // Write 8 dummy clocks--this is the same for
			o_qspi_req <= 1'b1; // both Quad I/O, Quad O, and fast-read commands
			o_spi_dir <= 1'b0;
			o_spi_spd <= r_quad;
			o_spi_word[31:0] <= (r_xip) ? 32'h00 : 32'hffffffff;
			o_spi_len  <= (r_quad)? 2'b11:2'b00; // 8 clocks
			if (accepted)
				rd_state <= (r_quad)?`RD_QUAD_READ_DATA
						: `RD_SLOW_READ_DATA;
			end
		`RD_SLOW_READ_DATA: begin
			o_qspi_req <= 1'b1;
			o_spi_dir <= 1'b1;
			o_spi_spd <= 1'b0;
			o_spi_len <= 2'b11;
			o_spi_wr <= (~r_requested)||(i_piperd);
			invalid_ack_pipe[0] <= (!r_requested);
			o_data_ack <=  (!invalid_ack_pipe[3])&&(i_spi_valid)&&(r_requested);
			o_bus_ack <=   (r_requested)&&(accepted)&&(i_piperd);
			r_requested <= (r_requested)||(accepted);
			if ((i_spi_valid)&&(~o_spi_wr))
				rd_state <= `RD_GO_TO_IDLE;
			end
		`RD_QUAD_READ_DATA: begin
			o_qspi_req <= 1'b1; // Insist that we keep the port
			o_spi_dir <= 1'b1;  // Read
			o_spi_spd <= 1'b1;  // Read at Quad rates
			o_spi_len <= 2'b11; // Read 4-bytes
			o_spi_recycle <= (r_leave_xip)? 1'b1: 1'b0;
			invalid_ack_pipe[0] <= (!r_requested);
			r_requested <= (r_requested)||(accepted); // Make sure at least one request goes through
			o_data_ack <=  (!invalid_ack_pipe[3])&&(i_spi_valid)&&(r_requested)&&(~r_leave_xip);
			o_bus_ack  <= (r_requested)&&(accepted)&&(i_piperd)&&(~r_leave_xip);
			o_spi_wr <= (~r_requested)||(i_piperd);
			// if (accepted)
				// o_spi_wr <= (i_piperd);
			if (accepted) // only happens if (o_spi_wr)
				o_data <= i_spi_data;
			if ((i_spi_valid)&&(~o_spi_wr))
				rd_state <= ((r_leave_xip)||(~r_xip))?`RD_GO_TO_IDLE:`RD_GO_TO_XIP;
			end
		`RD_QUAD_ADDRESS: begin
			o_qspi_req <= 1'b1;
			o_spi_wr <= 1'b1;
			o_spi_dir <= 1'b0; // Write the address
			o_spi_spd <= 1'b1; // High speed
			o_spi_word[31:0] <= { i_addr, 2'b00, 8'h00 };
			o_spi_len  <= 2'b10; // 24 bits, High speed, 6 clocks
			if (accepted)
				rd_state <= `RD_QUAD_DUMMY;
			end
		`RD_QUAD_DUMMY: begin
			o_qspi_req <= 1'b1;
			o_spi_wr <= 1'b1;
			o_spi_dir <= 1'b0; // Write the dummy
			o_spi_spd <= 1'b1; // High speed
			o_spi_word[31:0] <= (r_xip)? 32'h00 : 32'hffffffff;
			o_spi_len  <= 2'b11; // 8 clocks = 32-bits, quad speed
			if (accepted)
				rd_state <= (r_quad)?`RD_QUAD_READ_DATA
						: `RD_SLOW_READ_DATA;
			end
		`RD_XIP: begin
			r_requested <= 1'b0;
			o_qspi_req <= 1'b1;
			o_spi_word <= { i_addr, 2'b00, 8'h00 };
			o_spi_wr <= 1'b0;
			o_spi_dir <= 1'b0; // Write to SPI
			o_spi_spd <= 1'b1; // High speed
			o_spi_len <= 2'b11;
			r_leave_xip <= i_other_req;
			r_xip <= (~i_other_req);
			o_bus_ack <= 1'b0;
			if ((i_readreq)||(i_other_req))
			begin
				rd_state <= `RD_QUAD_ADDRESS;
				o_bus_ack <= i_readreq;
			end end
		`RD_GO_TO_IDLE: begin
			if ((!invalid_ack_pipe[3])&&(i_spi_valid)&&(~r_leave_xip))
				o_data_ack <=  1'b1;
			o_spi_wr   <= 1'b0;
			o_qspi_req <= 1'b0;
			if ((i_spi_stopped)&&(~i_grant))
				rd_state <= `RD_IDLE;
			end
		`RD_GO_TO_XIP: begin
			r_requested <= 1'b0;
			if ((i_spi_valid)&&(!invalid_ack_pipe[3]))
				o_data_ack <=  1'b1;
			o_qspi_req <= 1'b1;
			o_spi_wr   <= 1'b0;
			if (i_spi_stopped)
				rd_state <= `RD_XIP;
			end
		default: begin
			// rd_state <= (i_grant)?`RD_BREAK;
			o_qspi_req <= 1'b0;
			o_spi_wr <= 1'b0;
			if ((i_spi_stopped)&&(~i_grant))
				rd_state <= `RD_IDLE;
			end
		endcase
	end

	assign	o_spi_hold = 1'b0;
	assign	o_leave_xip = r_leave_xip;

endmodule
