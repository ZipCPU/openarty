////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbuexec.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
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
`default_nettype none
//
module	wbuexec(i_clk, i_reset, i_stb, i_codword, o_busy,
		o_wb_cyc, o_wb_stb, o_wb_we, o_wb_addr, o_wb_data,
			i_wb_stall, i_wb_ack, i_wb_err, i_wb_data,
		o_stb, o_codword);
	parameter	AW = 32, DW = 32;
	//
	//
	localparam [5:0]	END_OF_WRITE = 6'h2e;
	localparam [1:0]	WB_IDLE			= 2'b00,
				WB_READ_REQUEST		= 2'b01,
				WB_WRITE_REQUEST	= 2'b10,
				// WB_WAIT_ON_NEXT_WRITE	= 3'b011,
				WB_FLUSH_WRITE_REQUESTS = 2'b11;
	localparam [1:0]	WRITE_PREFIX = 2'b01;

	//
	input	wire		i_clk, i_reset;
	// The command inputs
	input	wire		i_stb;
	input	wire	[35:0]	i_codword;
	output	reg		o_busy;
	// Wishbone outputs
	output	reg		o_wb_cyc;
	output	reg		o_wb_stb;
	output	reg		o_wb_we;
	output	reg	[31:0]	o_wb_addr, o_wb_data;
	// Wishbone inputs
	input	wire		i_wb_stall, i_wb_ack, i_wb_err;
	input	wire	[31:0]	i_wb_data;
	// And our codeword outputs
	output	reg		o_stb;
	output	reg	[35:0]	o_codword;


//	wire	w_accept, w_eow, w_newwr, w_new_err;
//	// wire	w_newad, w_newrd;
//	assign	w_accept = (i_stb)&&(!o_busy);
//	// assign	w_newad  = (w_accept)&&(i_codword[35:34] == 2'b00);
//	assign	w_newwr  = (w_accept)&&(i_codword[35:34] == WRITE_PREFIX);
//	assign	w_eow    = (w_accept)&&(i_codword[35:30] == END_OF_WRITE);
//	// assign	w_newrd  = (w_accept)&&(i_codword[35:34] == 2'b11);
	wire	[31:0]	w_cod_data;
	assign	w_cod_data={ i_codword[32:31], i_codword[29:0] };
//	assign	w_new_err = ((w_accept)
//				&&(i_codword[35:33] != 3'h3)
//				&&(i_codword[35:30] != END_OF_WRITE));

	reg	[1:0]	wb_state;
	reg	[9:0]	r_acks_needed, r_len;
	reg	r_inc, r_new_addr, last_read_request, last_ack, zero_acks;
	reg	single_read_request;

	initial	wb_state = WB_IDLE;
	initial	o_wb_cyc = 1'b0;
	initial	o_wb_stb = 1'b0;
	initial	o_busy = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		wb_state <= WB_IDLE;
		o_wb_cyc <= 1'b0;
		o_wb_stb <= 1'b0;
		o_busy   <= 1'b0;
	end else case(wb_state)
	WB_IDLE: begin
		o_wb_cyc <= 1'b0;
		o_wb_stb <= 1'b0;

		// The new instruction.  The following
		// don't matter if we're not running,
		// so set them any time in this state,
		// and if we move then they'll still be
		// set right.
		//
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
			//	o_wb_addr <= i_codword[31:0]; //w_cod_data
				end
			4'b001?: begin // Set a new relative address
				// r_new_addr <= 1'b1;
			//	o_wb_addr <= o_wb_addr // + w_cod_data;
			//		+ { i_codword[32:31], i_codword[29:0] };
				end
			4'b01??: begin // Start a write transaction,
				// address is alrdy set
				// r_new_addr <= 1'b1;
				wb_state <= WB_WRITE_REQUEST;
				o_wb_cyc <= 1'b1;
				o_wb_stb <= 1'b1;
				o_busy   <= 1'b1;
				end
			4'b11??: begin // Start a vector read
				wb_state <= WB_READ_REQUEST;
				o_wb_cyc <= 1'b1;
				o_wb_stb <= 1'b1;
				o_busy   <= 1'b1;
				end
			default:
				;
			endcase
		end end
	WB_READ_REQUEST: begin
		o_wb_cyc <= 1'b1;
		// o_wb_stb <= 1'b1;

		// if ((r_inc)&&(!i_wb_stall))
		//	o_wb_addr <= o_wb_addr + 32'h001;


		if (!i_wb_stall) // Deal with the strobe line
		begin // Strobe was accepted, busy should be '1' here
			if ((single_read_request)||(last_read_request))
				o_wb_stb <= 1'b0;
		end

		if (i_wb_ack && last_ack)
		begin
			wb_state <= WB_IDLE;
			o_wb_cyc <= 1'b0;
			o_busy   <= 1'b0;
		end

		if (i_wb_err)
		begin
			o_wb_cyc <= 1'b0;
			o_wb_stb <= 1'b0;
			wb_state <= WB_IDLE;
			o_busy   <= 1'b0;
		end end
	WB_WRITE_REQUEST: begin
		o_wb_cyc <= 1'b1;
		// o_wb_stb <= 1'b1;
		o_busy   <= 1'b1;
		//

		// Don't need to worry about accepting anything new
		// here, since we'll always be busy while in this state.
		// Hence, we cannot accept new write requests.
		//

		if (!i_wb_stall)
			o_wb_stb <= 1'b0;

		if (!o_busy)
			o_wb_data <= w_cod_data;

		if (i_stb && !o_wb_stb)
		begin
			if (o_busy && (i_codword[35:34] != WRITE_PREFIX)
				&& zero_acks)
			begin
				o_wb_cyc <= 1'b0;
				o_busy   <= 1'b0;
				wb_state <= WB_IDLE;
			end else if (!o_busy) // && w_newwr must be true
			begin
				o_wb_stb <= 1'b1;
				o_busy <= 1'b1;
			end else if ((i_codword[35:34] == WRITE_PREFIX)
				||zero_acks)
				// (r_acks_needed == (i_wb_ack ? 1:0)))
				o_busy <= 1'b0;
		end

		if (i_wb_err) // Bus returns an error
		begin
			o_wb_cyc <= 1'b0;
			o_wb_stb <= 1'b0;
			wb_state <= WB_FLUSH_WRITE_REQUESTS;
			o_busy   <= 1'b1;
		end end
	WB_FLUSH_WRITE_REQUESTS: begin
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

		o_busy <= 1'b1;
		if (i_stb && i_codword[35:34] != WRITE_PREFIX)
		begin
			wb_state <= WB_IDLE;
			o_busy   <= 1'b0;
		end end
	default: begin
		wb_state <= WB_IDLE;
		o_wb_cyc <= 1'b0;
		o_wb_stb <= 1'b0;
		o_busy   <= 1'b0;
		end
	endcase

	always @(posedge i_clk)
	if (wb_state == WB_IDLE)
		// Will this be a write?
		o_wb_we <= !i_codword[35];

	always @(posedge i_clk)
	if (i_stb && !o_busy && i_codword[35:32] == 4'h0)
		// Set a new absolute address
		o_wb_addr <= i_codword[31:0]; //w_cod_data
	else if (i_stb && !o_busy && i_codword[35:33] == 3'h1)
		// Set a new relative address
		o_wb_addr <= o_wb_addr // + w_cod_data;
			+ { i_codword[32:31], i_codword[29:0] };
	else if (o_wb_stb && !i_wb_stall && r_inc)
		// Increment
		o_wb_addr <= o_wb_addr + 1;

	initial	r_new_addr = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		r_new_addr <= 1'b1;
	else if ((!o_wb_cyc)&&(i_stb)&&(!i_codword[35]))
		r_new_addr <= 1'b1;
	else if (o_wb_cyc)
		r_new_addr <= 1'b0;

	initial	o_stb = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		// Send a bus reset indication
		o_stb <= 1'b1;
		o_codword <= { 6'h3, i_wb_data[29:0] };
	end else if (!o_wb_cyc)
	begin
		// Send a new address confirmation at the beginning of any
		// read
		o_stb <= (i_stb && !o_busy &&
				(i_codword[35:34] == 2'b11) && r_new_addr);
		o_codword <= { 4'h2, o_wb_addr };
	end else begin
		// Otherwise, while the  bus is active, we send either a
		// bus error indication, read return, or write ack
		o_stb <= (i_wb_err)||(i_wb_ack);

		o_codword <= { 3'h7, i_wb_data[31:30], r_inc, i_wb_data[29:0] };
		if (i_wb_err) // Bus Error
			o_codword[35:30] <= 6'h5;
		else if (o_wb_we) // Write ack
			o_codword[35:30] <= 6'h2;
		else // Read data on ack
			o_codword[35:33] <= 3'h7;
	end

	initial	r_acks_needed = 0;
	always @(posedge i_clk)
	if (i_reset || !o_wb_cyc)
		r_acks_needed <= 10'h00; // (i_codword[35])?i_codword[9:0]:10'h00;
	else case ({o_wb_stb && !i_wb_stall, i_wb_ack })
	2'b10: r_acks_needed <= r_acks_needed + 10'h01;
	2'b01: r_acks_needed <= r_acks_needed - 10'h01;
	default: begin end
	endcase

	always @(posedge i_clk)
	if (wb_state == WB_IDLE)
		// Increment addresses?
		r_inc <= i_codword[30];

// last_ack was ...
//	always @(posedge i_clk)
//		last_ack <= (!o_wb_stb)&&(r_acks_needed == 10'h01)
//				||(o_wb_stb)&&(r_acks_needed == 10'h00);

	always @(posedge i_clk)
	if (!o_wb_cyc)
		last_ack <= (i_codword[35:34] == 2'b11)&&(i_codword[9:0] <= 1);
	else
		last_ack <= (!o_wb_we)
			&&(r_len + r_acks_needed <= 1 + (i_wb_ack ? 1:0));

	initial	zero_acks = 1;
	always @(posedge i_clk)
	if (i_reset || !o_wb_cyc)
		zero_acks <= 1;
	else case({ o_wb_stb && !i_wb_stall, i_wb_ack })
	2'b10: zero_acks <= 1'b0;
	2'b01: zero_acks <= (r_acks_needed == 10'h01);
	default: begin end
	endcase
`ifdef	FORMAL
	always @(*)
		assert(zero_acks == (r_acks_needed == 0));
`endif

	always @(posedge i_clk)
	if (!o_wb_cyc) // (!o_wb_cyc)&&(i_codword[35:34] == 2'b11))
		r_len <= i_codword[9:0];
	else if ((o_wb_stb)&&(!i_wb_stall)&&(|r_len))
		r_len <= r_len - 10'h01;

// single_read_request and last_read_request used to be ...
//	always @(posedge i_clk)
//	begin
//		single_read_request <= (!o_wb_cyc)&&(i_codword[9:0] <= 10'h01);
//		// When there is one read request left, it will be the last one
//		// will be the last one
//		last_read_request <= (o_wb_stb)&&(r_len[9:2] == 8'h00)
//			&&((!r_len[1])
//				||((!r_len[0])&&(!i_wb_stall)));
//	end

	always @(posedge i_clk)
	begin
		if (!o_wb_cyc)
			single_read_request <= (i_codword[9:0] <= 10'h01);
		// When there is one read request left, it will be the last one
		// will be the last one
		if (!o_wb_cyc)
			last_read_request <= (i_codword[9:0] <= 10'h01);
		else if (o_wb_stb && !i_wb_stall)
			last_read_request <= (r_len <= 10'h02);
		else
			last_read_request <= (r_len <= 10'h01);
	end

`ifdef	FORMAL
// Formal properties for this module are maintained elsewhere
`endif // FORMAL
endmodule
