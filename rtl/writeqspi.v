////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	writeqspi.v
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
module	writeqspi(i_clk, i_wreq, i_ereq, i_pipewr, i_endpipe, i_addr, i_data,
			o_bus_ack, o_qspi_req, i_qspi_grant,
				o_spi_wr, o_spi_hold, o_spi_word, o_spi_len,
				o_spi_spd, o_spi_dir, i_spi_data, i_spi_valid,
					i_spi_busy, i_spi_stopped,
				o_data_ack, i_quad, o_wip);
	input	wire	i_clk;
	//
	input	wire	i_wreq, i_ereq, i_pipewr, i_endpipe;
	input	wire	[21:0]	i_addr;
	input	wire	[31:0]	i_data;
	output	reg		o_bus_ack, o_qspi_req;
	input	wire		i_qspi_grant;
	output	reg		o_spi_wr, o_spi_hold;
	output	reg	[31:0]	o_spi_word;
	output	reg	[1:0]	o_spi_len;
	output	reg		o_spi_spd, o_spi_dir;
	input	wire	[31:0]	i_spi_data;
	input	wire		i_spi_valid;
	input	wire		i_spi_busy, i_spi_stopped;
	output	reg		o_data_ack;
	input	wire		i_quad;
	output	reg		o_wip;

`ifdef	QSPI_READ_ONLY
	always @(posedge i_clk)
		o_data_ack <= (i_wreq)||(i_ereq);
	always @(posedge i_clk)
		o_bus_ack <= (i_wreq)||(i_ereq);

	always @(posedge i_clk)
	begin
		o_qspi_req <= 1'b0;
		o_spi_wr   <= 1'b0;
		o_spi_hold <= 1'b0;
		o_spi_dir  <= 1'b1; // Read
		o_spi_spd  <= i_quad;
		o_spi_len  <= 2'b00;
		o_spi_word <= 32'h00;
		o_wip <= 1'b0;
	end
`else

`define	WR_IDLE				4'h0
`define	WR_START_WRITE			4'h1
`define	WR_START_QWRITE			4'h2
`define	WR_PROGRAM			4'h3
`define	WR_PROGRAM_GETNEXT		4'h4
`define	WR_START_ERASE			4'h5
`define	WR_WAIT_ON_STOP			4'h6
`define	WR_REQUEST_STATUS		4'h7
`define	WR_REQUEST_STATUS_NEXT		4'h8
`define	WR_READ_STATUS			4'h9
`define	WR_WAIT_ON_FINAL_STOP		4'ha

	reg	accepted;
	initial	accepted = 1'b0;
	always @(posedge i_clk)
		accepted <= (~i_spi_busy)&&(i_qspi_grant)&&(o_spi_wr)&&(~accepted);


	reg		cyc, chk_wip, valid_status;
	reg	[3:0]	wr_state;
	initial	wr_state = `WR_IDLE;
	initial	cyc = 1'b0;
	always @(posedge i_clk)
	begin
		chk_wip <= 1'b0;
		o_bus_ack  <= 1'b0;
		o_data_ack <= 1'b0;
		case(wr_state)
		`WR_IDLE: begin
			valid_status <= 1'b0;
			o_qspi_req <= 1'b0;
			cyc <= 1'b0;
			if (i_ereq)
				wr_state <= `WR_START_ERASE;
			else if (i_wreq)
				wr_state <= (i_quad)?`WR_START_QWRITE
					: `WR_START_WRITE;
			end
		`WR_START_WRITE: begin
			o_wip      <= 1'b1;
			o_qspi_req <= 1'b1;
			o_spi_wr   <= 1'b1;
			o_spi_dir  <= 1'b0;
			o_spi_len  <= 2'b11;
			o_spi_spd  <= 1'b0;
			o_spi_hold <= 1'b1;
			o_spi_word <= { 8'h02, i_addr, 2'b00 };
			cyc <= 1'b1;
			if (accepted)
			begin
				o_bus_ack  <= 1'b1;
				o_data_ack <= 1'b1;
				wr_state <= `WR_PROGRAM;
				o_spi_word <= i_data;
			end end
		`WR_START_QWRITE: begin
			o_wip      <= 1'b1;
			o_qspi_req <= 1'b1;
			o_spi_wr   <= 1'b1;
			o_spi_dir  <= 1'b0;
			o_spi_len  <= 2'b11;
			o_spi_spd  <= 1'b0;
			o_spi_hold <= 1'b1;
			o_spi_word <= { 8'h32, i_addr, 2'b00 };
			cyc <= 1'b1;
			if (accepted)
			begin
				o_bus_ack  <= 1'b1;
				o_data_ack <= 1'b1;
				wr_state <= `WR_PROGRAM;
				o_spi_word <= i_data;
			end end
		`WR_PROGRAM: begin
			o_wip     <= 1'b1;
			o_qspi_req <= 1'b1;
			o_spi_wr   <= 1'b1;
			o_spi_dir  <= 1'b0;
			o_spi_len  <= 2'b11;
			o_spi_spd  <= i_quad;
			o_spi_hold <= 1'b1;
			// o_spi_word <= i_data;
			if (accepted)
				wr_state <= `WR_PROGRAM_GETNEXT;
			end
		`WR_PROGRAM_GETNEXT: begin
			o_wip      <= 1'b1;
			o_qspi_req <= 1'b1;
			o_spi_wr   <= 1'b0;
			o_spi_dir  <= 1'b0;
			o_spi_len  <= 2'b11;
			o_spi_spd  <= i_quad;
			o_spi_hold <= 1'b1;
			o_spi_word <= i_data;
			cyc <= (cyc)&&(~i_endpipe);
			if (~cyc)
				wr_state <= `WR_WAIT_ON_STOP;
			else if (i_pipewr)
			begin
				o_bus_ack  <= 1'b1;
				o_data_ack <= 1'b1;
				wr_state <= `WR_PROGRAM;
			end end
		`WR_START_ERASE: begin
			o_wip <= 1'b1;
			o_qspi_req <= 1'b1;
			o_spi_wr  <= 1'b1;
			o_spi_dir <= 1'b0;
			o_spi_spd <= 1'b0;
			o_spi_len <= 2'b11;
			if (i_data[28])
				// Subsector erase
				o_spi_word[31:24] <= 8'h20;
			else
				// Sector erase
				o_spi_word[31:24] <= 8'hd8;
			o_spi_word[23:0] <= { i_data[21:10], 12'h0 };
			// Data has already been ack'd, so no need to ack
			// it again.  However, we can now free the QSPI
			// bus processor to accept another command from the
			// bus.
			o_bus_ack <= accepted;
			if (accepted)
				wr_state <= `WR_WAIT_ON_STOP;
			end
		`WR_WAIT_ON_STOP: begin
			o_wip <= 1'b1;
			o_qspi_req <= 1'b0;
			o_spi_wr   <= 1'b0;
			o_spi_hold <= 1'b0;
			if (i_spi_stopped)
				wr_state <= `WR_REQUEST_STATUS;
			end
		`WR_REQUEST_STATUS: begin
			o_wip <= 1'b1;
			o_qspi_req <= 1'b1;
			o_spi_hold <= 1'b0;
			o_spi_wr   <= 1'b1;
			o_spi_spd  <= 1'b0; // Slow speed
			o_spi_len  <= 2'b00; // 8 bytes
			o_spi_dir  <= 1'b0; // Write
			o_spi_word <= { 8'h05, 24'h00 };
			if (accepted)
				wr_state <= `WR_REQUEST_STATUS_NEXT;
			end
		`WR_REQUEST_STATUS_NEXT: begin
			o_wip <= 1'b1;
			o_qspi_req <= 1'b1;
			o_spi_hold <= 1'b0;
			o_spi_wr   <= 1'b1;
			o_spi_spd  <= 1'b0; // Slow speed
			o_spi_len  <= 2'b00; // 8 bytes
			o_spi_dir  <= 1'b1; // Read
			o_spi_word <= 32'h00;
			if (accepted)
				wr_state <= `WR_READ_STATUS;
			valid_status <= 1'b0;
			end
		`WR_READ_STATUS: begin
			o_wip <= 1'b1;
			o_qspi_req <= 1'b1;
			o_spi_hold <= 1'b0;
			o_spi_wr   <= 1'b1;
			o_spi_spd  <= 1'b0; // Slow speed
			o_spi_len  <= 2'b00; // 8 bytes
			o_spi_dir  <= 1'b1; // Read
			o_spi_word <= 32'h00;
			if (i_spi_valid)
				valid_status <= 1'b1;
			if ((i_spi_valid)&&(valid_status))
				chk_wip <= 1'b1;
			if ((chk_wip)&&(~i_spi_data[0]))
				wr_state <= `WR_WAIT_ON_FINAL_STOP;
			end
		// `WR_WAIT_ON_FINAL_STOP: // Same as the default
		default: begin
			o_qspi_req <= 1'b0;
			o_spi_wr <= 1'b0;
			o_wip <= 1'b0;
			if (i_spi_stopped)
				wr_state <= `WR_IDLE;
			end
		endcase
	end
`endif

	// verilator lint_off UNUSED
	wire	[30:0] unused;
	assign	unused = i_spi_data[31:1];
	// verilator lint_on  UNUSED
endmodule
