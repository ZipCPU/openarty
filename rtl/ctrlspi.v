////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	ctrlspi.v
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
// Copyright (C) 2015-2020, Gisselquist Technology, LLC
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
`define	CT_SAFE
`define	CT_IDLE			3'h0
`define	CT_NEXT			3'h1
`define	CT_GRANTED		3'h2
`define	CT_DATA			3'h3
`define	CT_READ_DATA		3'h4
`define	CT_WAIT_FOR_IDLE	3'h5
//
// CTRL commands:
//	WEL (write-enable latch)
//	Read Status
module	ctrlspi(i_clk, i_req, i_wr, i_addr, i_data, i_sector_address,
				o_spi_req, i_grant,
				o_spi_wr, o_spi_hold, o_spi_word, o_spi_len,
					o_spi_spd, o_spi_dir,
				i_spi_data, i_spi_valid, i_spi_busy,
					i_spi_stopped,
				o_bus_ack, o_data_ack, o_data,
				i_leave_xip, o_xip, o_quad);
	input	wire	i_clk;
	// From the WB bus controller
	input	wire		i_req;
	input	wire		i_wr;
	input	wire	[3:0]	i_addr;
	input	wire	[31:0]	i_data;
	input	wire	[21:0]	i_sector_address;
	// To/from the arbiter
	output	reg		o_spi_req;
	input	wire		i_grant;
	// To/from the low-level SPI driver
	output	reg		o_spi_wr;
	output	wire		o_spi_hold;
	output	reg	[31:0]	o_spi_word;
	output	reg	[1:0]	o_spi_len;
	output	wire		o_spi_spd;
	output	reg		o_spi_dir;
	input	wire	[31:0]	i_spi_data;
	input	wire		i_spi_valid;
	input	wire		i_spi_busy, i_spi_stopped;
	// Return data to the bus controller, and the wishbone bus
	output	reg		o_bus_ack, o_data_ack;
	output	reg	[31:0]	o_data;
	// Configuration items that we may have configured.
	input	wire		i_leave_xip;
	output	reg		o_xip;
	output	wire		o_quad;

	// Command registers
	reg	[1:0]	ctcmd_len;
	reg	[31:0]	ctcmd_word;
	// Data stage registers
	reg		ctdat_skip, // Skip the data phase?
			ctdat_wr;	// Write during data? (or not read)
	wire	[1:0]	ctdat_len;
	reg	[31:0]	ctdat_word;

	reg	[2:0]	ctstate;
	reg		accepted;
	reg	[3:0]	invalid_ack_pipe;


	initial	accepted = 1'b0;
	always @(posedge i_clk)
		accepted <= (~i_spi_busy)&&(i_grant)&&(o_spi_wr)&&(~accepted);

	reg	r_ctdat_len, ctbus_ack;
	assign	ctdat_len = { 1'b0, r_ctdat_len };

	// First step, calculate the values for our state machine
	initial	o_xip = 1'b0;
	// initial o_quad = 1'b0;
	always @(posedge i_clk)
	if (i_req) // A request for us to act from the bus controller
	begin
		ctdat_skip <= 1'b0;
		ctbus_ack  <= 1'b1;
		ctcmd_word[23:0] <= { i_sector_address, 2'b00 };
		ctdat_word <= { i_data[7:0], 24'h00 };
		ctcmd_len <= 2'b00; // 8bit command (for all but Lock regs)
		r_ctdat_len <= 1'b0; // 8bit data (read or write)
		ctdat_wr <= i_wr;
		casez({ i_addr[3:0], i_wr, i_data[30] })
		6'b000010: begin // Write Disable
			ctcmd_word[31:24] <= 8'h04;
			ctdat_skip <= 1'b1;
			ctbus_ack  <= 1'b0;
			end
		6'b000011: begin // Write enable
			ctcmd_word[31:24] <= 8'h06;
			ctdat_skip <= 1'b1;
			ctbus_ack  <= 1'b0;
			end
		// 4'b0010?: begin // Read Status register
		//	Moved to defaults section
		6'b00011?: begin // Write Status register (Requires WEL)
			ctcmd_word[31:24] <= 8'h01;
`ifdef	CT_SAFE
			ctdat_word <= { 6'h00, i_data[1:0], 24'h00 };
`else
			ctdat_word <= { i_data[7:0], 24'h00 };
`endif
			end
		6'b00100?: begin // Read NV-Config register (two bytes)
			ctcmd_word[31:24] <= 8'hB5;
			r_ctdat_len <= 1'b1; // 16-bit data
			end
		6'b00101?: begin // Write NV-Config reg (2 bytes, Requires WEL)
			ctcmd_word[31:24] <= 8'hB1;
			r_ctdat_len <= 1'b1; // 16-bit data
`ifdef	CT_SAFE
			ctdat_word <= { 4'h8, 3'h7, 3'h7, i_data[5:1], 1'b1, 16'h00 };
`else
			ctdat_word <= { i_data[15:0], 16'h00 };
`endif
			end
		6'b00110?: begin // Read V-Config register
			ctcmd_word[31:24] <= 8'h85;
			end
		6'b00111?: begin // Write V-Config register (Requires WEL)
			ctcmd_word[31:24] <= 8'h81;
			r_ctdat_len <= 1'b0; // 8-bit data
// `ifdef	CT_SAFE
//			ctdat_word <= { 4'h8, i_data[3:2], 2'b11, 24'h00 };
// `else
			ctdat_word <= { i_data[7:0], 24'h00 };
// `endif
			o_xip <= ~i_data[3];
			end
		6'b01000?: begin // Read EV-Config register
			ctcmd_word[31:24] <= 8'h65;
			end
		6'b01001?: begin // Write EV-Config register (Requires WEL)
			ctcmd_word[31:24] <= 8'h61;
			// o_quad <= (~i_data[7]);
`ifdef	CT_SAFE
			ctdat_word <= { 1'b1, 3'h5, 4'hf, 24'h00 };
`else
			ctdat_word <= { i_data[7:0], 24'h00 };
`endif
			end
		6'b01010?: begin // Read Lock register
			ctcmd_word[31:0] <= { 8'he8,  i_sector_address, 2'b00 };
			ctcmd_len <= 2'b11;
			ctdat_wr  <= 1'b0;  // Read, not write
			end
		6'b01011?: begin // Write Lock register (Requires WEL)
			ctcmd_word[31:0] <= { 8'he5, i_sector_address, 2'b00 };
			ctcmd_len <= 2'b11;
			ctdat_wr  <= 1'b1;  // Write
			end
		6'b01100?: begin // Read Flag Status register
			ctcmd_word[31:24] <= 8'h70;
			ctdat_wr  <= 1'b0;  // Read, not write
			end
		6'b01101?: begin // Write/Clear Flag Status register (No WEL required)
			ctcmd_word[31:24] <= 8'h50;
			ctdat_skip <= 1'b1;
			end
		6'b11011?: begin // RESET_ENABLE (when written to)
			ctcmd_word[31:24] <= 8'h66;
			ctdat_skip <= 1'b1;
			end
		6'b11101?: begin // RESET_MEMORY (when written to)
			ctcmd_word[31:24] <= 8'h99;
			ctdat_skip <= 1'b1;
			end
		default: begin // Default to reading the status register
			ctcmd_word[31:24] <= 8'h05;
			ctdat_wr  <= 1'b0;  // Read, not write
			r_ctdat_len <= 1'b0; // 8-bit data
			end
		endcase
	end else if (i_leave_xip)
		o_xip <= 1'b0;

	assign	o_quad = 1'b1;

	// Second step, actually drive the state machine
	initial	ctstate = `CT_IDLE;
	always @(posedge i_clk)
	begin
		o_spi_wr <= 1'b1;
		o_bus_ack <= 1'b0;
		o_data_ack <= 1'b0;
		invalid_ack_pipe <= { invalid_ack_pipe[2:0], accepted };
		if (i_spi_valid)
			o_data <= i_spi_data;
		case(ctstate)
		`CT_IDLE: begin
			o_spi_req <= 1'b0;
			o_spi_wr  <= 1'b0;
			if (i_req) // Need a clock to let the digestion
				ctstate <= `CT_NEXT; // process complete
			end
		`CT_NEXT: begin
			o_spi_wr <= 1'b1;
			o_spi_req <= 1'b1;
			o_spi_word <= ctcmd_word;
			o_spi_len <= ctcmd_len;
			o_spi_dir <= 1'b0; // Write
			if (accepted)
			begin
				ctstate <= (ctdat_skip)?`CT_WAIT_FOR_IDLE:`CT_DATA;
				o_bus_ack <= (ctdat_skip);
				o_data_ack <= (ctdat_skip)&&(ctbus_ack);
			end end
		`CT_GRANTED: begin
			o_spi_wr <= 1'b1;
			if ((accepted)&&(ctdat_skip))
				ctstate <= `CT_WAIT_FOR_IDLE;
			else if (accepted)//&&(~ctdat_skip)
				ctstate <= `CT_DATA;
			end
		`CT_DATA: begin
			o_spi_wr   <= 1'b1;
			o_spi_len  <= ctdat_len;
			o_spi_dir  <= ~ctdat_wr;
			o_spi_word <= ctdat_word;
			if (accepted)
				o_bus_ack <= 1'b1;
			if (accepted)
				ctstate <= (ctdat_wr)?`CT_WAIT_FOR_IDLE:`CT_READ_DATA;
			if ((accepted)&&(ctdat_wr))
				o_data_ack <= 1'b1;
			end
		`CT_READ_DATA: begin
			o_spi_wr <= 1'b0; // No more words to go, just to wait
			o_spi_req <= 1'b1;
			invalid_ack_pipe[0] <= 1'b0;
			if ((i_spi_valid)&&(!invalid_ack_pipe[3])) // for a value to read
			begin
				o_data_ack <= 1'b1;
				o_data <= i_spi_data;
				ctstate <= `CT_WAIT_FOR_IDLE;
			end end
		default: begin // `CT_WAIT_FOR_IDLE
			o_spi_wr <= 1'b0;
			o_spi_req <= 1'b0;
			if (i_spi_stopped)
				ctstate <= `CT_IDLE;
			end
		endcase
	end
		
	// All of this is done in straight SPI mode, so our speed will always be zero
	assign	o_spi_hold = 1'b0;
	assign	o_spi_spd  = 1'b0;

	// Make verilator happy
	// verilator lint_off UNUSED
	wire	[22:0]	unused;
	assign	unused = { i_data[31], i_data[29:8] };
	// verilator lint_on  UNUSED
endmodule
