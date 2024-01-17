////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbuexec.v
// {{{
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
// }}}
// Copyright (C) 2015-2024, Gisselquist Technology, LLC
// {{{
// This file is part of the OpenArty project.
//
// The OpenArty project is free software and gateware, licensed under the terms
// of the 3rd version of the GNU General Public License as published by the
// Free Software Foundation.
//
// This project is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
`default_nettype none
// }}}
module	wbuexec #(
		parameter [0:0]	OPT_COUNT_FIFO = 1'b0,
		parameter	LGFIFO = 4,
		parameter	AW = 32, DW = 32
	) (
		// {{{
		input	wire		i_clk, i_reset,
		// The command inputs
		// {{{
		input	wire		i_valid,
		input	wire	[35:0]	i_codword,
		output	wire		o_busy,
		// }}}
		// Wishbone outputs
		// {{{
		output	reg			o_wb_cyc,
		output	reg			o_wb_stb,
		output	reg			o_wb_we,
		output	wire	[AW-1:0]	o_wb_addr,
		output	reg	[DW-1:0]	o_wb_data,
		// }}}
		// Wishbone inputs
		// {{{
		input	wire			i_wb_stall, i_wb_ack,
		input	wire	[DW-1:0]	i_wb_data,
		input	wire			i_wb_err,
		// }}}
		// And our codeword outputs
		// {{{
		output	reg		o_stb,
		output	reg	[35:0]	o_codword,
		// }}}
		input	wire		i_fifo_rd
		// }}}
	);

	// Local declarations
	// {{{
	// localparam [5:0]	END_OF_WRITE = 6'h2e;
	localparam [1:0]	WB_IDLE			= 2'b00,
				WB_READ_REQUEST		= 2'b01,
				WB_WRITE_REQUEST	= 2'b10,
				// WB_WAIT_ON_NEXT_WRITE	= 3'b011,
				WB_FLUSH_WRITE_REQUESTS = 2'b11;
	localparam [1:0]	WRITE_PREFIX = 2'b01;

	wire	[31:0]	w_cod_data;

//	wire	w_accept, w_eow, w_newwr, w_new_err;
//	// wire	w_newad, w_newrd;
//	assign	w_accept = (i_valid)&&(!o_busy);
//	// assign	w_newad  = (w_accept)&&(i_codword[35:34] == 2'b00);
//	assign	w_newwr  = (w_accept)&&(i_codword[35:34] == WRITE_PREFIX);
//	assign	w_eow    = (w_accept)&&(i_codword[35:30] == END_OF_WRITE);
//	// assign	w_newrd  = (w_accept)&&(i_codword[35:34] == 2'b11);
//	assign	w_new_err = ((w_accept)
//				&&(i_codword[35:33] != 3'h3)
//				&&(i_codword[35:30] != END_OF_WRITE));

	reg	[1:0]	wb_state;
	reg	[9:0]	r_acks_needed, r_len;
	reg		r_inc, r_new_addr, last_read_request, last_ack,
			zero_acks, r_busy;
	reg	[31:0]	wide_addr;

	assign	w_cod_data={ i_codword[32:31], i_codword[29:0] };
	//  }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Count the number of items in the FIFO
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	wire	[LGFIFO:0]	fifo_space_available;
	wire			space_available;

	generate if (OPT_COUNT_FIFO)
	begin : GEN_FIFO_SPACE
		// {{{
		reg	[LGFIFO:0]	r_fifo_space_available;
		reg			r_space_available;
		wire	[LGFIFO:0]	wb_space_needed, idl_space_needed;

		initial	r_fifo_space_available = (1<<LGFIFO);
		always @(posedge i_clk)
		if (i_reset)
			r_fifo_space_available <= (1<<LGFIFO);
		else case({ o_stb, i_fifo_rd })
		2'b01:	r_fifo_space_available <= r_fifo_space_available + 1;
		2'b10:	r_fifo_space_available <= r_fifo_space_available - 1;
		default: begin end
		endcase

		// Verilator lint_off WIDTH
		assign	wb_space_needed = (i_wb_err ? 10'h1 : r_acks_needed)
				+ (o_wb_stb ? 1:0) + (o_stb ? 1:0)
				+ ((r_len + (o_wb_stb ? 1:0) > 1) ? 1:0);
		// Verilator lint_on WIDTH

		assign	idl_space_needed = (i_valid ? 1:0) + (r_new_addr ? 1:0)
						+ (o_stb ? 1:0);

		initial	r_space_available = 1'b1;
		always @(posedge i_clk)
		if (i_reset)
			r_space_available <= 1'b1;
		else if (o_wb_cyc)
			r_space_available <= (r_fifo_space_available
					> wb_space_needed);
		else
			r_space_available <= (r_fifo_space_available > idl_space_needed);

		assign	fifo_space_available = r_fifo_space_available;
		assign	space_available = r_space_available;

		// Verilator lint_off UNUSED
		wire	unused_count;
		assign	unused_count = &{ 1'b0, i_fifo_rd, fifo_space_available };
		// Verilator lint_on  UNUSED
		// }}}
	end else begin : NO_FIFO
		// {{{
		assign	fifo_space_available = 0;
		assign	space_available = 1'b1;

		// Verilator lint_off UNUSED
		wire	unused_count;
		assign	unused_count = &{ 1'b0, i_fifo_rd, fifo_space_available };
		// Verilator lint_on  UNUSED
		// }}}
	end endgenerate
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Issue bus requests
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// CYC, STB, wb_state and o_busy
	// {{{
	initial	wb_state = WB_IDLE;
	initial	o_wb_cyc = 1'b0;
	initial	o_wb_stb = 1'b0;
	initial	r_busy = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		// {{{
		wb_state <= WB_IDLE;
		o_wb_cyc <= 1'b0;
		o_wb_stb <= 1'b0;
		r_busy   <= 1'b0;
		// }}}
	end else case(wb_state)
	WB_IDLE: begin
		// {{{
		o_wb_cyc <= 1'b0;
		o_wb_stb <= 1'b0;
		r_busy   <= 1'b0;

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
		// o_wb_data <= w_cod_data;
		//
		if (i_valid && !o_busy)
		begin
			// Default is not to send any codewords
			// Do we need to broadcast a new address?
			//
			casez(i_codword[35:32])
			4'b0000: begin end // Set a new (arbitrary) address
			4'b001?: begin end // Set a new relative address
			4'b01??: begin // Start a write transaction,
				// {{{
				// address must be already set
				wb_state <= WB_WRITE_REQUEST;
				o_wb_cyc <= 1'b1;
				o_wb_stb <= 1'b1;
				r_busy   <= 1'b1;
				end
				// }}}
			4'b11??: begin // Start a vector read
				// {{{
				wb_state <= WB_READ_REQUEST;
				o_wb_cyc <= 1'b1;
				o_wb_stb <= 1'b1;
				r_busy   <= 1'b1;
				end
				// }}}
			default: begin end
			endcase
		end end
		// }}}
	WB_READ_REQUEST: begin
		// {{{
		o_wb_cyc <= 1'b1;
		// o_wb_stb <= 1'b1;

		// if ((r_inc)&&(!i_wb_stall))
		//	o_wb_addr <= o_wb_addr + 32'h001;


		if (!o_wb_stb || !i_wb_stall) // Deal with the strobe line
		begin // Strobe was accepted, busy should be '1' here
			o_wb_stb <= space_available && !last_read_request;
		end

		if (i_wb_ack && last_ack)
		begin
			wb_state <= WB_IDLE;
			o_wb_cyc <= 1'b0;
			r_busy   <= 1'b0;
		end

		if (i_wb_err)
		begin
			o_wb_cyc <= 1'b0;
			o_wb_stb <= 1'b0;
			wb_state <= WB_IDLE;
			r_busy   <= 1'b0;
		end end
		// }}}
	WB_WRITE_REQUEST: begin
		// {{{
		o_wb_cyc <= 1'b1;
		r_busy   <= 1'b1;

		if (!i_wb_stall)
			o_wb_stb <= 1'b0;

		if (!o_wb_stb || !i_wb_stall)
		begin
			if (i_valid && i_codword[35:34] == WRITE_PREFIX)
			begin
				if (!o_busy)
				begin
					o_wb_stb <= 1'b1;
					r_busy   <= 1'b1;
				end else
					r_busy <= 1'b0;
			end else if ((!o_wb_stb && zero_acks)
						|| (i_wb_ack && last_ack))
			begin
				o_wb_cyc <= 1'b0;
				r_busy   <= 1'b0;
				wb_state <= WB_IDLE;
			end
		end

		if (i_wb_err) // Bus returns an error
		begin
			o_wb_cyc <= 1'b0;
			o_wb_stb <= 1'b0;
			wb_state <= WB_FLUSH_WRITE_REQUESTS;
			r_busy   <= 1'b1;
		end end
		// }}}
	WB_FLUSH_WRITE_REQUESTS: begin
		// {{{
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

		r_busy <= 1'b1;
		if (i_valid && i_codword[35:34] != WRITE_PREFIX)
		begin
			wb_state <= WB_IDLE;
			r_busy   <= 1'b0;
		end end
		// }}}
	default: begin
		// {{{
		wb_state <= WB_IDLE;
		o_wb_cyc <= 1'b0;
		o_wb_stb <= 1'b0;
		r_busy   <= 1'b0;
		end
		// }}}
	endcase

	assign	o_busy = r_busy || !space_available;
	// }}}

	always @(posedge i_clk)
	if (!o_busy)
		o_wb_data <= w_cod_data;

	always @(posedge i_clk)
	if (wb_state == WB_IDLE)
		// Will this be a write?
		o_wb_we <= !i_codword[35];

	// o_wb_addr
	// {{{
	always @(posedge i_clk)
	if (i_valid && !o_busy && i_codword[35:32] == 4'h0)
		// Set a new absolute address
		wide_addr <= i_codword[31:0]; //w_cod_data
	else if (i_valid && !o_busy && i_codword[35:33] == 3'h1)
		// Set a new relative address
		wide_addr <= wide_addr // + w_cod_data;
			+ { i_codword[32:31], i_codword[29:0] };
	else if (o_wb_stb && !i_wb_stall && r_inc)
		// Increment
		wide_addr <= wide_addr + 1;

	assign	o_wb_addr = wide_addr[AW-1:0];
	// }}}

	// r_new_addr
	// {{{
	initial	r_new_addr = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		r_new_addr <= 1'b1;
	else if (!o_wb_cyc && i_valid && !o_busy && i_codword[35:34] != 2'b10)
		//  && i_codword[35:33] == 3'b001)
		r_new_addr <= (i_codword[35:32] == 4'h0)
				|| (i_codword[35:33] == 3'b001);
	// }}}

	// r_acks_needed
	// {{{
	initial	r_acks_needed = 0;
	always @(posedge i_clk)
	if (i_reset || !o_wb_cyc || i_wb_err)
		r_acks_needed <= 10'h00; // (i_codword[35])?i_codword[9:0]:10'h00;
	else case ({o_wb_stb && !i_wb_stall, i_wb_ack })
	2'b10: r_acks_needed <= r_acks_needed + 10'h01;
	2'b01: r_acks_needed <= r_acks_needed - 10'h01;
	default: begin end
	endcase
	// }}}

	always @(posedge i_clk)
	if (wb_state == WB_IDLE)
		// Increment addresses?
		r_inc <= i_codword[30];
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Receive and process bus returns
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// last_ack
	// {{{
// last_ack was ...
//	always @(posedge i_clk)
//		last_ack <= (!o_wb_stb)&&(r_acks_needed == 10'h01)
//				||(o_wb_stb)&&(r_acks_needed == 10'h00);

	always @(posedge i_clk)
	if (!o_wb_cyc)
	begin
		last_ack <= 1;
		if (i_valid && i_codword[35:34] == 2'b11)
			last_ack <= (i_codword[9:0] <= 1);
	end else if (o_wb_we)
		last_ack <= ((o_wb_stb ? 1:0) + r_acks_needed
			+ ((i_valid && !o_busy && i_codword[35:34] == WRITE_PREFIX) ? 1:0)
						<= 1 + (i_wb_ack ? 1:0));
	else
		last_ack <= (r_len + r_acks_needed <= 1 + (i_wb_ack ? 1:0));
	// }}}

	// zero_acks
	// {{{
	initial	zero_acks = 1;
	always @(posedge i_clk)
	if (i_reset || !o_wb_cyc || i_wb_err)
		zero_acks <= 1;
	else case({ o_wb_stb && !i_wb_stall, i_wb_ack })
	2'b10: zero_acks <= 1'b0;
	2'b01: zero_acks <= (r_acks_needed == 10'h01);
	default: begin end
	endcase
	// }}}

	// r_len
	// {{{
	initial	r_len = 0;
	always @(posedge i_clk)
	if (i_reset)
		r_len <= 0;
	else if (!o_wb_cyc)
	begin
		r_len <= 0;
		if (i_valid && !o_busy && i_codword[35:34] == 2'b11)
			r_len <= i_codword[9:0];
	end else if (o_wb_cyc && i_wb_err)
		r_len <= 0;
	else if (o_wb_stb && !i_wb_stall &&(|r_len))
		r_len <= r_len - 10'h01;
	// }}}

	// last_read_request
	// {{{
	initial	last_read_request = 1;
	always @(posedge i_clk)
	if (i_reset)
		last_read_request <= 1;
	else if (!o_wb_cyc)
		last_read_request <= !i_valid || o_busy
			|| i_codword[35:34] != 2'b11
			|| (i_codword[9:0] <= 10'h01);
		// When there is one read request left, it will be the last one
		// will be the last one
	else if (i_wb_err)
		last_read_request <= 1;
	else if (o_wb_stb && !i_wb_stall && space_available)
		last_read_request <= (r_len <= 2);
	else if (o_wb_stb && i_wb_stall)
		last_read_request <= (r_len <= 1);
	else if (!o_wb_stb && !space_available)
		last_read_request <= (r_len == 0);
	else
		last_read_request <= (r_len <= 1);
`ifdef	FORMAL
	always @(*)
	if (!i_reset)
	begin
		if (r_len == 0)
			assert(last_read_request);
		else if (o_wb_stb)
			assert(last_read_request == (r_len == 1));
		else
			assert(last_read_request == (r_len == 0));
	end
`endif
	// }}}
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// The outgoing codeword stream
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// o_stb, o_codword
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
		o_stb <= (i_valid && !o_busy &&
				(i_codword[35:34] == 2'b11) && r_new_addr);
		o_codword <= { 4'h2, wide_addr };
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
	// }}}

	// Make Verilator happy
	// {{{
	// Verilator lint_off UNUSED
	// wire	unused;
	// assign	unused = &{ 1'b0 };
	// Verilator lint_on  UNUSED
	// }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal properties
// {{{
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef	FORMAL
// Formal properties for this module are maintained elsewhere
`endif // FORMAL
// }}}
endmodule
