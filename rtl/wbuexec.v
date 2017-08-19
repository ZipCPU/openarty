////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbuexec.v
//
// Project:	FPGA library
//
// Purpose:	This is the part of the USB-JTAG to wishbone conversion that
//		actually conducts a wishbone transaction.  Transactions are
//	requested via codewords that come in, and the results recorded on
//	codewords that are sent out.  Compression and/or decompression, coding
//	etc. all take place external to this routine.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015,2017, Gisselquist Technology, LLC
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
`define	WB_IDLE			3'b000
`define	WB_READ_REQUEST		3'b001
`define	WB_WRITE_REQUEST	3'b010
`define	WB_ACK			3'b011
`define	WB_WAIT_ON_NEXT_WRITE	3'b100
`define	WB_FLUSH_WRITE_REQUESTS	3'b101

module	wbuexec(i_clk, i_rst, i_stb, i_codword, o_busy,
		o_wb_cyc, o_wb_stb, o_wb_we, o_wb_addr, o_wb_data,
			i_wb_ack, i_wb_stall, i_wb_err, i_wb_data,
		o_stb, o_codword);
	input	wire		i_clk, i_rst;
	// The command inputs
	input	wire		i_stb;
	input	wire	[35:0]	i_codword;
	output	wire		o_busy;
	// Wishbone outputs
	output	reg		o_wb_cyc;
	output	reg		o_wb_stb;
	output	reg		o_wb_we;
	output	reg	[31:0]	o_wb_addr, o_wb_data;
	// Wishbone inputs
	input	wire		i_wb_ack, i_wb_stall, i_wb_err;
	input	wire	[31:0]	i_wb_data;
	// And our codeword outputs
	output	reg		o_stb;
	output	reg	[35:0]	o_codword;


	wire	w_accept, w_eow, w_newwr, w_new_err;
	// wire	w_newad, w_newrd;
	assign	w_accept = (i_stb)&&(~o_busy);
	// assign	w_newad  = (w_accept)&&(i_codword[35:34] == 2'b00);
	assign	w_newwr  = (w_accept)&&(i_codword[35:34] == 2'b01);
	assign	w_eow    = (w_accept)&&(i_codword[35:30] == 6'h2e);
	// assign	w_newrd  = (w_accept)&&(i_codword[35:34] == 2'b11);
	wire	[31:0]	w_cod_data;
	assign	w_cod_data={ i_codword[32:31], i_codword[29:0] }; 
	assign	w_new_err = ((w_accept)
				&&(i_codword[35:33] != 3'h3)
				&&(i_codword[35:30] != 6'h2e));

	reg	[2:0]	wb_state;
	reg	[9:0]	r_acks_needed, r_len;
	reg	r_inc, r_new_addr, last_read_request, last_ack, zero_acks;
	reg	single_read_request;

	initial	r_new_addr = 1'b1;
	initial	wb_state = `WB_IDLE;
	initial	o_stb = 1'b0;
	always @(posedge i_clk)
		if (i_rst)
		begin
			wb_state <= `WB_IDLE;
			o_stb <= 1'b1;
			o_codword <= { 6'h3, i_wb_data[29:0] }; // BUS Reset
			o_wb_cyc <= 1'b0;
			o_wb_stb <= 1'b0;
		end else case(wb_state)
		`WB_IDLE: begin
			o_wb_cyc <= 1'b0;
			o_wb_stb <= 1'b0;
			// Now output codewords while we're idle,
			//    ... unless we get an address command (later).
			o_stb    <= 1'b0;

			// The new instruction.  The following
			// don't matter if we're not running,
			// so set them any time in this state,
			// and if we move then they'll still be
			// set right.
			//
			// Increment addresses?
			r_inc <= i_codword[30];
			// Will this be a write?
			o_wb_we <= (~i_codword[35]);
			//
			// Our next codeword will be the new address (if there
			// is one).  Set it here.  The o_stb line will determine
			// if this codeword is actually sent out.
			//
			o_codword <= { 4'h2, o_wb_addr };
			o_wb_we <= (i_codword[35:34] != 2'b11);
			//
			// The output data is a don't care, unless we are
			// starting a write.  Hence, let's always set it as
			// though we were about to start a write.
			//
			o_wb_data <= w_cod_data; 
			//
			if (i_stb)
			begin
				// Default is not to send any codewords
				// Do we need to broadcast a new address?
				// r_new_addr <= 1'b0;
				// 
				casez(i_codword[35:32])
				4'b0000: begin // Set a new (arbitrary) address
					// r_new_addr <= 1'b1;
					o_wb_addr <= i_codword[31:0]; //w_cod_data
					end
				4'b001?: begin // Set a new relative address
					// r_new_addr <= 1'b1;
					o_wb_addr <= o_wb_addr // + w_cod_data;

						+ { i_codword[32:31], i_codword[29:0] };
					end
				4'b01??: begin // Start a write transaction,
					// address is alrdy set
					// r_new_addr <= 1'b1;
					wb_state <= `WB_WRITE_REQUEST;
					o_wb_cyc <= 1'b1;
					o_wb_stb <= 1'b1;
					end
				4'b11??: begin // Start a vector read
					// Address is already set ...
					// This also depends upon the decoder working
					if (r_new_addr)
						o_stb <= 1'b1;
					wb_state <= `WB_READ_REQUEST;
					o_wb_cyc <= 1'b1;
					o_wb_stb <= 1'b1;
					end
				default:
					;
				endcase
			end end
		`WB_READ_REQUEST: begin
			o_wb_cyc <= 1'b1;
			o_wb_stb <= 1'b1;

			if (i_wb_err)
				wb_state <= `WB_IDLE;

			o_stb <= (i_wb_err)||(i_wb_ack);

			if (i_wb_err) // Bus Error
				o_codword <= { 6'h5, i_wb_data[29:0] };
			else // Read data on ack
				o_codword <= { 3'h7, i_wb_data[31:30], r_inc, 
					i_wb_data[29:0] };

			if ((r_inc)&&(~i_wb_stall))
				o_wb_addr <= o_wb_addr + 32'h001;


			if (~i_wb_stall) // Deal with the strobe line
			begin // Strobe was accepted, busy should be '1' here
				if ((single_read_request)||(last_read_request)) // (r_len != 0) // read
				begin
					wb_state <= `WB_ACK;
					o_wb_stb <= 1'b0;
				end
			end end
		`WB_WRITE_REQUEST: begin
			o_wb_cyc <= 1'b1;
			o_wb_stb <= 1'b1;
			//

			if (i_wb_err) // Bus Err
				o_codword <= { 6'h5, i_wb_data[29:0] };
			else // Write acknowledgement
				o_codword <= { 6'h2, i_wb_data[29:0] };

			if ((r_inc)&&(~i_wb_stall))
				o_wb_addr <= o_wb_addr + 32'h001;

			o_stb <= (i_wb_err)||(~i_wb_stall);

			// Don't need to worry about accepting anything new
			// here, since we'll always be busy while in this state.
			// Hence, we cannot accept new write requests.
			//

			if (i_wb_err)
			begin
				wb_state <= `WB_FLUSH_WRITE_REQUESTS;
				//
				o_wb_cyc <= 1'b0;
				o_wb_stb <= 1'b0;
			end else if (~i_wb_stall)
			begin
				wb_state <= `WB_WAIT_ON_NEXT_WRITE;
				o_wb_stb <= 1'b0;
			end end
		`WB_ACK: begin
			o_wb_cyc <= 1'b1;
			o_wb_stb <= 1'b0;
			//
			// No strobes are being sent out.  No further
			// bus transactions are requested.  We only need
			// to finish processing the last one(s) by waiting
			// for (and recording?) their acks.
			//
			// Process acknowledgements
			if (i_wb_err) // Bus error
				o_codword <= { 6'h5, i_wb_data[29:0] };
			else // Read data
				o_codword <= { 3'h7, i_wb_data[31:30], r_inc, 
					i_wb_data[29:0] };

			// Return a read result, or (possibly) an error
			// notification
			o_stb <= (((i_wb_ack)&&(~o_wb_we)) || (i_wb_err));

			if (((last_ack)&&(i_wb_ack))||(zero_acks)||(i_wb_err))
			begin
				o_wb_cyc <= 1'b0;
				wb_state <= `WB_IDLE;
			end end
		`WB_WAIT_ON_NEXT_WRITE: begin

			o_codword <= { 6'h5, i_wb_data[29:0] };
			o_stb <= (i_wb_err)||(w_new_err);

			o_wb_data <= w_cod_data;
			o_wb_cyc <= 1'b1;
			o_wb_stb <= 1'b0;

			if (w_new_err) // Something other than a write or EOW
			begin
				o_wb_cyc <= 1'b0;
				wb_state <= `WB_IDLE;
			end else if (i_wb_err) // Bus returns an error
			begin
				o_wb_cyc <= 1'b0;
				wb_state <= `WB_FLUSH_WRITE_REQUESTS;
			end
			else if (w_newwr) // Need to make a new write request
			begin
				wb_state <= `WB_WRITE_REQUEST;
				o_wb_stb <= 1'b1;
			end
			else if (w_eow) // All done writing, wait for last ack
				wb_state <= `WB_ACK;
			end
		`WB_FLUSH_WRITE_REQUESTS: begin
			// We come in here after an error within a write
			// We need to wait until the command cycle finishes
			// issuing all its write commands before we can go back
			// to idle.
			//
			// In the off chance that we are in here in error, or
			// out of sync, we'll transition to WB_IDLE and just
			// issue a second error token.

			o_wb_cyc <= 1'b0;
			o_wb_stb <= 1'b0;
			o_codword <= { 6'h5, i_wb_data[29:0] };
			o_stb <= (w_new_err);

			if ((w_eow)||(w_new_err))
				wb_state <= `WB_IDLE;
			end
		default: begin
			o_stb <= 1'b1;
			o_codword <= { 6'h3, i_wb_data[29:0] };
			wb_state <= `WB_IDLE;
			o_wb_cyc <= 1'b0;
			o_wb_stb <= 1'b0;
			end
		endcase

	assign o_busy = (wb_state != `WB_IDLE)
			&&(wb_state != `WB_WAIT_ON_NEXT_WRITE)
			&&(wb_state != `WB_FLUSH_WRITE_REQUESTS);
	//assign o_wb_cyc = (wb_state == `WB_READ_REQUEST)
			//||(wb_state == `WB_WRITE_REQUEST)
			//||(wb_state == `WB_ACK)
			//||(wb_state == `WB_WAIT_ON_NEXT_WRITE);
	//assign o_wb_stb = (wb_state == `WB_READ_REQUEST)
	//			||(wb_state == `WB_WRITE_REQUEST);

	always @(posedge i_clk)
		if (i_rst)
			r_new_addr <= 1'b1;
		else if ((~o_wb_cyc)&&(i_stb)&&(~i_codword[35]))
			r_new_addr <= 1'b1;
		else if (o_wb_cyc)
			r_new_addr <= 1'b0;

	always @(posedge i_clk)
		if (~o_wb_cyc)
			r_acks_needed <= 10'h00; // (i_codword[35])?i_codword[9:0]:10'h00;
		else if ((o_wb_stb)&&(~i_wb_stall)&&(~i_wb_ack))
			r_acks_needed <= r_acks_needed + 10'h01;
		else if (((~o_wb_stb)||(i_wb_stall))&&(i_wb_ack))
			r_acks_needed <= r_acks_needed - 10'h01;

	always @(posedge i_clk)
		last_ack <= (~o_wb_stb)&&(r_acks_needed == 10'h01)
				||(o_wb_stb)&&(r_acks_needed == 10'h00);

	always @(posedge i_clk)
		zero_acks <= (~o_wb_stb)&&(r_acks_needed == 10'h00);

	always @(posedge i_clk)
		if (!o_wb_stb) // (!o_wb_cyc)&&(i_codword[35:34] == 2'b11))
			r_len <= i_codword[9:0];
		else if ((o_wb_stb)&&(~i_wb_stall)&&(|r_len))
			r_len <= r_len - 10'h01;

	always @(posedge i_clk)
	begin
		single_read_request <= (~o_wb_cyc)&&(i_codword[9:0] == 10'h01);
		// When there is one read request left, it will be the last one
		// will be the last one
		last_read_request <= (o_wb_stb)&&(r_len[9:2] == 8'h00)
			&&((~r_len[1])
				||((~r_len[0])&&(~i_wb_stall)));
	end

endmodule
