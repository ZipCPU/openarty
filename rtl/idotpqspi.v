////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	idotpqspi.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2017, Gisselquist Technology, LLC
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
`define	ID_IDLE				5'h00
`define	ID_WAIT_ON_START_ID		5'h01
`define	ID_WAIT_ON_START_OTP		5'h02
`define	ID_WAIT_ON_START_OTP_WRITE	5'h03
`define	ID_READ_DATA_COMMAND		5'h04
`define	ID_GET_DATA			5'h05
`define	ID_LOADED			5'h06
`define	ID_LOADED_NEXT			5'h07
`define	ID_OTP_SEND_DUMMY		5'h08
`define	ID_OTP_CLEAR			5'h09
`define	ID_OTP_GET_DATA			5'h0a
`define	ID_OTP_WRITE			5'h0b
`define	ID_WAIT_ON_STOP			5'h0c
`define	ID_REQ_STATUS			5'h0d
`define	ID_REQ_STATUS_NEXT		5'h0e
`define	ID_READ_STATUS			5'h0f
//
`define	ID_FINAL_STOP			5'h10

module	idotpqspi(i_clk, i_req, i_wr, i_addr, i_data, o_bus_ack,
		o_qspi_req, i_qspi_grant,
		o_spi_wr, o_spi_hold, o_spi_word, o_spi_len,
		o_spi_spd, o_spi_dir, i_spi_data, i_spi_valid,
		i_spi_busy, i_spi_stopped, o_data_ack, o_data, o_loaded,
		o_wip);
	input	wire		i_clk;
	input	wire		i_req, i_wr;
	input	wire	[4:0]	i_addr;
	input	wire	[31:0]	i_data;
	output	reg		o_bus_ack, o_qspi_req;
	input	wire		i_qspi_grant;
	output	reg		o_spi_wr, o_spi_hold;
	output	reg	[31:0]	o_spi_word;
	output	reg	[1:0]	o_spi_len;
	output	wire		o_spi_spd;
	output	reg		o_spi_dir;
	input	wire	[31:0]	i_spi_data;
	input	wire		i_spi_valid, i_spi_busy, i_spi_stopped;
	output	reg		o_data_ack;
	output	reg	[31:0]	o_data;
	output	wire		o_loaded;
	output	reg		o_wip;

	reg	id_loaded;
	initial	id_loaded = 1'b0;
	assign	o_loaded= id_loaded;

/*	
	// Only the ID register will be kept in memory, OTP will be read
	// or written upon request
	always @(posedge i_clk)
		if (i_addr[4])
			o_data <= otpmem[i_addr[3:0]];
		else
			o_data <= idmem[i_addr[2:0]];

	always @(posedge i_clk)
		if ((otp_loaded)&&(i_req)&&(i_addr[4]))
			o_data_ack <= 1'b1;
		else if ((id_loaded)&&(i_req)&&(~i_addr[4]))
			o_data_ack <= idmem[i_addr[2:0]];
		else
			o_data_ack <= 1'b0;
*/

	reg	otp_read_request, id_read_request, accepted, otp_wr_request,
		id_read_device, last_id_read;
	reg	[4:0]	req_addr;
	reg	[2:0]	lcl_id_addr;
	reg	[4:0]	id_state;
	always @(posedge i_clk)
	begin
		otp_read_request <= (i_req)&&(~i_wr)&&((i_addr[4])||(i_addr[3:0]==4'hf));
		last_id_read     <= (i_req)&&(~i_addr[4])&&(i_addr[3:0]!=4'hf);
		id_read_request  <= (i_req)&&(~i_addr[4])&&(i_addr[3:0]!=4'hf)&&(~last_id_read);
		id_read_device   <= (i_req)&&(~i_addr[4])&&(i_addr[3:0]!=4'hf)&&(~id_loaded);
		accepted <= (~i_spi_busy)&&(i_qspi_grant)&&(o_spi_wr)&&(~accepted);

		otp_wr_request <= (i_req)&&(i_wr)&&((i_addr[4])||(i_addr[3:0]==4'hf));

		if (id_state == `ID_IDLE)
			req_addr <= (i_addr[4:0]==5'h0f) ? 5'h10
				: { 1'b0, i_addr[3:0] };
	end

	reg	last_addr;
	always @(posedge i_clk)
		last_addr <= (lcl_id_addr >= 3'h4);

	reg	[31:0]	idmem[0:5];
	reg	[31:0]	r_data;

	// Now, quickly, let's deal with the fact that the data from the
	// bus comes one clock later ...
	reg	nxt_data_ack, nxt_data_spi;
	reg	[31:0]	nxt_data;

	reg	set_val, chk_wip;
	reg	[2:0]	set_addr;
	reg	[3:0]	invalid_ack_pipe;

	always @(posedge i_clk)
	begin // Depends upon state[4], otp_rd, otp_wr, otp_pipe, id_req, accepted, last_addr
		o_bus_ack <= 1'b0;
		// o_data_ack <= 1'b0;
		o_spi_hold <= 1'b0;
		nxt_data_ack <= 1'b0;
		nxt_data_spi <= 1'b0;
		chk_wip      <= 1'b0;
		set_val <= 1'b0;
		invalid_ack_pipe <= { invalid_ack_pipe[2:0], accepted };
		if ((id_loaded)&&(id_read_request))
		begin
			nxt_data_ack <= 1'b1;
			o_bus_ack  <= 1'b1;
		end
		nxt_data <= idmem[i_addr[2:0]];
		o_spi_wr <= 1'b0; // By default, we send nothing
		case(id_state)
		`ID_IDLE: begin
			o_qspi_req <= 1'b0;
			o_spi_dir <= 1'b0; // Write to SPI
			lcl_id_addr <= 3'h0;
			o_spi_word[23:7] <= 17'h00;
			o_spi_word[6:0] <= { req_addr[4:0], 2'b00 };
			r_data <= i_data;
			o_wip <= 1'b0;
			if (otp_read_request)
			begin
				// o_spi_word <= { 8'h48, 8'h00, 8'h00, 8'h00 };
				id_state <= `ID_WAIT_ON_START_OTP;
				o_bus_ack <= 1'b1;
			end else if (otp_wr_request)
			begin
				o_bus_ack <= 1'b1;
				// o_data_ack <= 1'b1;
				nxt_data_ack <= 1'b1;
				id_state <= `ID_WAIT_ON_START_OTP_WRITE;
			end else if (id_read_device)
			begin
				id_state <= `ID_WAIT_ON_START_ID;
				o_bus_ack <= 1'b0;
				o_spi_word[31:24] <= 8'h9f;
			end end
		`ID_WAIT_ON_START_ID: begin
			o_spi_wr <= 1'b1;
			o_qspi_req <= 1'b1;
			o_spi_len <= 2'b0; // 8 bits
			if (accepted)
				id_state <= `ID_READ_DATA_COMMAND;
			end
		`ID_WAIT_ON_START_OTP: begin
			o_spi_wr <= 1'b1;
			o_spi_word[31:24] <= 8'h4B;
			o_qspi_req <= 1'b1;
			o_spi_len <= 2'b11; // 32 bits
			o_spi_word[6:0] <= { req_addr[4:0], 2'b00 };
			if (accepted) // Read OTP command was just sent
				id_state <= `ID_OTP_SEND_DUMMY;
			end
		`ID_WAIT_ON_START_OTP_WRITE: begin
			o_spi_wr <= 1'b1;
			o_qspi_req <= 1'b1;
			o_wip <= 1'b1;
			o_spi_len <= 2'b11; // 32 bits
			o_spi_word[31:24] <= 8'h42;
			if (accepted) // Read OTP command was just sent
				id_state <= `ID_OTP_WRITE;
			end
		`ID_READ_DATA_COMMAND: begin
			o_spi_len <= 2'b11; // 32-bits
			o_spi_wr <= 1'b1; // Still transmitting
			o_spi_dir <= 1'b1; // Read from SPI
			o_qspi_req <= 1'b1;
			if (accepted)
				id_state <= `ID_GET_DATA;
			end
		`ID_GET_DATA: begin
			o_spi_len <= 2'b11; // 32-bits
			o_spi_wr <= (~last_addr); // Still transmitting
			o_spi_dir <= 1'b1; // Read from SPI
			o_qspi_req <= 1'b1;
			invalid_ack_pipe[0] <= 1'b0;
			if((i_spi_valid)&&(!invalid_ack_pipe[3]))
			begin
				set_val <= 1'b1;
				set_addr <= lcl_id_addr[2:0];
				// idmem[lcl_id_addr[2:0]] <= i_spi_data;
				lcl_id_addr <= lcl_id_addr + 3'h1;
				if (last_addr)
					id_state <= `ID_LOADED;
			end end
		`ID_LOADED: begin
			id_loaded <= 1'b1;
			o_bus_ack  <= 1'b1;
			o_spi_wr   <= 1'b0;
			nxt_data_ack <= 1'b1;
			id_state   <= `ID_LOADED_NEXT;
			end
		`ID_LOADED_NEXT: begin
			o_spi_len <= 2'b11; // 32-bits
			o_bus_ack  <= 1'b0;
			o_spi_wr   <= 1'b0;
			nxt_data_ack <= 1'b1;
			id_state   <= `ID_IDLE;
			end
		`ID_OTP_SEND_DUMMY: begin
			o_spi_len <= 2'b00; // 1 byte
			o_spi_wr  <= 1'b1; // Still writing
			o_spi_dir <= 1'b0; // Write to SPI
			if (accepted) // Wait for the command to be accepted
				id_state <= `ID_OTP_CLEAR;
			end
		`ID_OTP_CLEAR: begin
			o_spi_wr  <= 1'b1; // Still writing
			o_spi_dir <= 1'b1; // Read from SPI
			o_spi_len <= 2'b11; // Read 32 bits
			if (accepted)
				id_state <= `ID_OTP_GET_DATA;
			end
		`ID_OTP_GET_DATA: begin
			invalid_ack_pipe[0] <= 1'b0;
			if ((i_spi_valid)&&(!invalid_ack_pipe[3]))
			begin
				id_state <= `ID_FINAL_STOP;
				nxt_data_ack <= 1'b1;
				nxt_data_spi <= 1'b1;
			end end
		`ID_OTP_WRITE: begin
			o_spi_wr  <= 1'b1;
			o_spi_len <= 2'b11;
			o_spi_dir <= 1'b0; // Write to SPI
			o_spi_word <= r_data;
			// o_bus_ack  <= (otp_wr_request)&&(accepted)&&(i_pipewr);
			// o_data_ack <= (otp_wr_request)&&(accepted);
			if (accepted) // &&(~i_pipewr)
				id_state <= `ID_WAIT_ON_STOP;
			else if(accepted)
			begin
				o_spi_word <= i_data;
				r_data <= i_data;
			end end
		`ID_WAIT_ON_STOP: begin
			o_spi_wr <= 1'b0;
			if (i_spi_stopped)
				id_state <= `ID_REQ_STATUS;
			end
		`ID_REQ_STATUS: begin
			o_spi_wr <= 1'b1;
			o_spi_hold <= 1'b0;
			o_spi_word[31:24] <= 8'h05;
			o_spi_dir <= 1'b0;
			o_spi_len <= 2'b00;
			if (accepted)
				id_state <= `ID_REQ_STATUS_NEXT;
			end
		`ID_REQ_STATUS_NEXT: begin
			o_spi_wr <= 1'b1;
			o_spi_hold <= 1'b0;
			o_spi_dir <= 1'b1; // Read
			o_spi_len <= 2'b00; // 8 bits
			// o_spi_word <= dont care
			if (accepted)
				id_state <= `ID_READ_STATUS;
			end
		`ID_READ_STATUS: begin
			o_spi_wr <= 1'b1;
			o_spi_hold <= 1'b0;
			o_spi_dir <= 1'b1; // Read
			o_spi_len <= 2'b00; // 8 bits
			// o_spi_word <= dont care
			invalid_ack_pipe[0] <= 1'b0;
			if ((i_spi_valid)&&(~invalid_ack_pipe[3]))
				chk_wip <= 1'b1;
			if ((chk_wip)&&(~i_spi_data[0]))
			begin
				o_wip <= 1'b0;
				id_state <= `ID_FINAL_STOP;
			end end
		default: begin // ID_FINAL_STOP
			o_bus_ack <= 1'b0;
			nxt_data_ack <= 1'b0;
			o_qspi_req <= 1'b0;
			o_spi_wr <= 1'b0;
			o_spi_hold <= 1'b0;
			o_spi_dir <= 1'b1; // Read
			o_spi_len <= 2'b00; // 8 bits
			// o_spi_word <= dont care
			if (i_spi_stopped)
				id_state <= `ID_IDLE;
			end
		endcase
	end

	always @(posedge i_clk)
	begin
		if (nxt_data_ack)
			o_data <= (nxt_data_spi)?i_spi_data : nxt_data;
		o_data_ack <= nxt_data_ack;
	end

	always @(posedge i_clk)
		if (set_val)
			idmem[set_addr] <= i_spi_data;

	assign	o_spi_spd = 1'b0; // Slow, 1-bit at a time

endmodule
