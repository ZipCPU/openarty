////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbicapetwo.v
//
// Project:	Wishbone to ICAPE2 interface conversion
//
// Purpose:	This routine maps the configuration registers of a 7-series
//		Xilinx part onto register addresses on a wishbone bus interface
//		via the ICAPE2 access port to those parts.  The big thing this
//		captures is the timing and handshaking required to read and
//		write registers from the configuration interface.
//
//		As an example of what can be done, writing a 32'h00f to
//		local address 5'h4 sends the IPROG command to the FPGA, causing
//		it to immediately reconfigure itself.
//
//		As another example, the warm boot start address is located
//		in register 5'h10.  Writing to this address, followed by
//		issuing the IPROG command just mentioned will cause the
//		FPGA to configure from that warm boot start address.
// 
//		For more details on the configuration interface, the registers
//		in question, their meanings and what they do, please see
//		User's Guide 470, the "7 Series FPGAs Configuration" User
//		Guide.
//
// Notes:	This module supports both reads and writes from the ICAPE2
//		interface.  These follow the following pattern.
//
//	For writes:
//		(Idle)	0xffffffff	(Dummy)
//		(CS/W)	0x20000000	NOOP
//		(CS/W)	0xaa995566	SYNC WORD
//		(CS/W)	0x20000000	NOOP
//		(CS/W)	0x20000000	NOOP
//		(CS/W)	...		Write command
//		(CS/W)	...		Write value, from Wishbone bus
//		(CS/W)	0x20000000	NOOP
//		(CS/W)	0x20000000	NOOP
//		(CS/W)	0x30008001	Write to CMD register (address 4)
//		(CS/W)	0x0000000d	DESYNC command
//		(CS/W)	0x20000000	NOOP
//		(CS/W)	0x20000000	NOOP
//		(Idle)
//
//	and for reads:
//		(Idle)	0xffffffff	(Dummy)
//		(CS/W)	0x20000000	NOOP
//		(CS/W)	0xaa995566	SYNC WORD
//		(CS/W)	0x20000000	NOOP
//		(CS/W)	0x20000000	NOOP
//		(CS/W)	...		Read command
//		(CS/W)	0x20000000	NOOP
//		(CS/W)	0x20000000	NOOP
//		(Idle)	0x20000000	(Idle the interface again, so we can rd)
//		(CS/R)	0x20000000	(Wait)
//		(CS/R)	0x20000000	(Wait)
//		(CS/R)	0x20000000	(Wait)
//		(CS/R)	0x20000000	(Wait)
//		(Idle)	0x20000000	(Idle the interface before writing)
//		(CS/W)	0x20000000	NOOP
//		(CS/W)	0x20000000	NOOP
//		(CS/W)	0x30008001	Write to CMD register (address 4)
//		(CS/W)	0x0000000d	DESYNC command
//		(CS/W)	0x20000000	NOOP
//		(CS/W)	0x20000000	NOOP
//		(Idle)
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
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
`define	MBOOT_IDLE	5'h00
`define	MBOOT_START	5'h01
`define	MBOOT_READ	5'h06
`define	MBOOT_WRITE	5'h0f
`define	MBOOT_DESYNC	5'h11
module	wbicapetwo(i_clk,
		i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data,
			o_wb_ack, o_wb_stall, o_wb_data, o_dbg);
	parameter	LGDIV = 3; /// Log of the clock divide
	input	wire		i_clk;
	// Wishbone inputs
	input	wire		i_wb_cyc, i_wb_stb, i_wb_we;
	input	wire	[4:0]	i_wb_addr;
	input	wire	[31:0]	i_wb_data;
	// Wishbone outputs
	output	reg		o_wb_ack, o_wb_stall;
	output	reg	[31:0]	o_wb_data;
	// Debugging output
	output	wire	[31:0]	o_dbg;
	// ICAPE2 interface signals
	//	These are kept internal to this block ...

	reg		wb_req, r_we;
	reg	[31:0]	r_data;
	reg	[4:0]	r_addr;


	reg		clk_stb, clk_stall;
	wire		slow_clk;

	generate
	if (LGDIV <= 1)
	begin
		reg		r_slow_clk;
		always @(posedge i_clk)
		begin
			r_slow_clk  <= (slow_clk + 1'b1);
			// We'll move on the positive edge of the clock,
			// so therefore clk_stb must be true one clock before
			// that, so we test for it one clock before that.
			clk_stb   <= (slow_clk == 1'b1);
			// CLK_STALL is set to true two clocks before any
			// cycle that will, by necessity, stall.
			clk_stall <= (slow_clk != 1'b0); //True all but 1ckcycle
		end

		assign	slow_clk = r_slow_clk;
	end else begin
		reg	[(LGDIV-1):0]	slow_clk_counter;

		always @(posedge i_clk)
		begin
			slow_clk_counter  <= slow_clk_counter + 1'b1;
			// We'll move on the positive edge of the clock, so therefore
			// clk_stb must be true one clock before that, so we test for
			// it one clock before that.
			clk_stb   <= (slow_clk_counter=={{(LGDIV){1'b1}},1'b0});
			// CLK_STALL is set to true two clocks before any cycle that
			// will, by necessity, stall.
			clk_stall <= (slow_clk_counter!={{(LGDIV){1'b0}},1'b1});
		end

		assign	slow_clk = slow_clk_counter[(LGDIV-1)];
	end endgenerate

	reg	[31:0]	cfg_in;
	reg		cfg_cs_n, cfg_rdwrn;
	wire	[31:0]	cfg_out;
	reg	[4:0]	state;
	initial	state = `MBOOT_IDLE;
	initial	cfg_cs_n = 1'b1;
	always @(posedge i_clk)
	begin
		// In general, o_wb_ack is always zero.  The exceptions to this
		// will be handled individually below.
		o_wb_ack <= 1'b0;
		// We can simplify our logic a touch by always setting
		// o_wb_data.  It will only be examined if o_wb_ack
		// is also true, so this is okay.
		o_wb_data <= cfg_out;

		// Turn any request "off", so that it will not be ack'd, if
		// the wb_cyc line is ever lowered.
		wb_req <= wb_req & i_wb_cyc;
		o_wb_stall <= (state != `MBOOT_IDLE)||(clk_stall);
		if (clk_stb)
		begin
			state <= state + 5'h01;
			case(state)
			`MBOOT_IDLE: begin
				cfg_cs_n <= 1'b1;
				cfg_rdwrn <= 1'b1;
				cfg_in <= 32'hffffffff;	// Dummy word

				state <= `MBOOT_IDLE;

				o_wb_ack <= 1'b0;

				r_addr <= i_wb_addr;
				r_data <= i_wb_data;
				r_we   <= i_wb_we;
				if(i_wb_stb) // &&(!o_wb_stall)
				begin
					state <= `MBOOT_START;
					wb_req <= 1'b1;
					//
					o_wb_ack <= 1'b0;
				end end
			`MBOOT_START: begin
				cfg_in <= 32'hffffffff; // NOOP
				cfg_cs_n <= 1'b1;
				end
			5'h02: begin
				cfg_cs_n <= 1'b0; // Activate interface
				cfg_rdwrn <= 1'b0;
				cfg_in <= 32'h20000000;	// NOOP
				end
			5'h03: begin
				cfg_in <= 32'haa995566;	// Sync word
				cfg_cs_n <= 1'b0;
				end
			5'h04: begin
				cfg_in <= 32'h20000000; // NOOP
				cfg_cs_n <= 1'b0;
				end
			5'h05: begin
				cfg_in <= 32'h20000000;	// NOOP
				state <= (r_we) ? `MBOOT_WRITE : `MBOOT_READ;
				cfg_cs_n <= 1'b0;
				end
			`MBOOT_READ: begin
				cfg_cs_n <= 1'b0;
				cfg_in <= { 8'h28, 6'h0, r_addr, 13'h001 };
				end
			5'h07: begin
				cfg_cs_n <= 1'b0;
				cfg_in <= 32'h20000000; // NOOP
				end
			5'h08: begin
				cfg_cs_n <= 1'b0;
				cfg_in <= 32'h20000000; // NOOP
				end
			5'h09: begin // Idle the interface before the read cycle
				cfg_cs_n <= 1'b1;
				cfg_rdwrn <= 1'b1;
				cfg_in <= 32'h20000000; // NOOP
				end
			5'h0a: begin // Re-activate the interface and wait 3 cycles
				cfg_cs_n <= 1'b0;
				cfg_rdwrn <= 1'b1;
				cfg_in <= 32'h20000000; // NOOP
				end
			5'h0b: begin // ... still waiting, cycle two
				cfg_in <= 32'h20000000; // NOOP
				cfg_cs_n <= 1'b0;
				end
			5'h0c: begin // ... still waiting, cycle three
				cfg_in <= 32'h20000000; // NOOP
				cfg_cs_n <= 1'b0;
				end
			5'h0d: begin // ... still waiting, cycle four
				cfg_in <= 32'h20000000; // NOOP
				cfg_cs_n <= 1'b0;
				end
			5'h0e: begin // and now our answer is there
				cfg_cs_n <= 1'b1;
				cfg_rdwrn <= 1'b1;
				cfg_in <= 32'h20000000; // NOOP
				//
				// Wishbone return
				o_wb_ack <= wb_req;
				// o_wb_data <= cfg_out; // Independent of state
				wb_req <= 1'b0;
				//
				state <= `MBOOT_DESYNC;
				end
			`MBOOT_WRITE: begin
				// Issue a write command to the given address
				cfg_in <= { 8'h30, 6'h0, r_addr, 13'h001 };
				cfg_cs_n <= 1'b0;
				end
			5'h10: begin
				cfg_in <= r_data;	// Write the value
				cfg_cs_n <= 1'b0;
				end
			`MBOOT_DESYNC: begin
				cfg_cs_n <= 1'b0;
				cfg_rdwrn <= 1'b0;
				cfg_in <= 32'h20000000;	// 1st NOOP
				end
			5'h12: begin
				cfg_cs_n <= 1'b0;
				cfg_in <= 32'h20000000;	// 2nd NOOP
				end
			5'h13: begin
				cfg_cs_n <= 1'b0;
				cfg_in <= 32'h30008001;	// Write to CMD register
				end
			5'h14: begin
				cfg_cs_n <= 1'b0;
				cfg_in <= 32'h0000000d;	// DESYNC command
				end
			5'h15: begin
				cfg_cs_n <= 1'b0;
				cfg_in <= 32'h20000000;	// NOOP
				end
			5'h16: begin
				cfg_cs_n <= 1'b0;
				cfg_in <= 32'h20000000;	// NOOP
				end
			5'h17: begin
				// Acknowledge the bus transaction, it is now complete
				o_wb_ack <= wb_req;
				wb_req <= 1'b0;
				//
				cfg_cs_n <= 1'b1;
				cfg_rdwrn <= 1'b0;
				cfg_in <= 32'hffffffff;	// DUMMY
				//
				state <= `MBOOT_IDLE;
				end
			default: begin
				wb_req <= 1'b0;
				cfg_cs_n <= 1'b1;
				cfg_rdwrn <= 1'b0;
				state <= `MBOOT_IDLE;
				cfg_in <= 32'hffffffff;	// DUMMY WORD
				end
			endcase
		end
	end

	genvar	k;
	//
	// The data registers to the ICAPE2 interface are bit swapped within
	// each byte.  Thus, in order to read from or write to the interface,
	// we need to bit swap the bits in each byte.  These next lines
	// accomplish that for both the input and output ports.
	//
	wire	[31:0]	bit_swapped_cfg_in;
	generate
	for(k=0; k<8; k=k+1)
	begin
		assign bit_swapped_cfg_in[   k] = cfg_in[   7-k];
		assign bit_swapped_cfg_in[ 8+k] = cfg_in[ 8+7-k];
		assign bit_swapped_cfg_in[16+k] = cfg_in[16+7-k];
		assign bit_swapped_cfg_in[24+k] = cfg_in[24+7-k];
	end endgenerate

	wire	[31:0]	bit_swapped_cfg_out;
	generate
	for(k=0; k<8; k=k+1)
	begin
		assign cfg_out[   k] = bit_swapped_cfg_out[   7-k];
		assign cfg_out[ 8+k] = bit_swapped_cfg_out[ 8+7-k];
		assign cfg_out[16+k] = bit_swapped_cfg_out[16+7-k];
		assign cfg_out[24+k] = bit_swapped_cfg_out[24+7-k];
	end endgenerate

	ICAPE2 #(.ICAP_WIDTH("X32")) reconfig(.CLK(slow_clk),
			.CSIB(cfg_cs_n), .RDWRB(cfg_rdwrn),
			.I(bit_swapped_cfg_in), .O(bit_swapped_cfg_out));

	assign o_dbg = {
`ifdef	DIVIDE_BY_FOUR
		slow_clk_counter, clk_stb, clk_stall,
`else
		1'b0, slow_clk, clk_stb, clk_stall,
`endif
		i_wb_stb, o_wb_ack, cfg_cs_n, cfg_rdwrn,
		o_wb_stall, state, 2'h0,
			cfg_in[7:0],
			cfg_out[7:0] };

endmodule
