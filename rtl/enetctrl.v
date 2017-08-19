////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	enetctrl
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This module translates wishbone commands, whether they be read
//		or write commands, to MIO commands operating on an Ethernet
//	controller, such as the TI DP83848 controller on the Artix-7 Arty
//	development boarod (used by this project).  As designed, the bus
//	*will* stall until the command has been completed.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2016, Gisselquist Technology, LLC
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
`define	ECTRL_RESET	3'h0
`define	ECTRL_IDLE	3'h1
`define	ECTRL_ADDRESS	3'h2
`define	ECTRL_READ	3'h3
`define	ECTRL_WRITE	3'h4
module	enetctrl(i_clk, i_rst,
		i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data,
			o_wb_ack, o_wb_stall, o_wb_data,
		o_mdclk, o_mdio, i_mdio, o_mdwe,
		o_debug);
	parameter	CLKBITS=3, // = 3 for 200MHz source clock, 2 for 100 MHz
			PHYADDR = 5'h01;
	input	wire	i_clk, i_rst;
	input	wire		i_wb_cyc, i_wb_stb, i_wb_we;
	input	wire	[4:0]	i_wb_addr;
	input	wire	[15:0]	i_wb_data;
	output	reg		o_wb_ack, o_wb_stall;
	output	wire	[31:0]	o_wb_data;
	//
	input	wire		i_mdio;
	output	wire		o_mdclk;
	output	reg		o_mdio, o_mdwe;
	//
	output	wire	[31:0]	o_debug;
	//

	reg		read_pending, write_pending;
	reg	[4:0]	r_addr;
	reg	[15:0]	read_reg, write_reg, r_data;
	reg	[2:0]	ctrl_state;
	reg	[5:0]	reg_pos;
	reg		zreg_pos;
	reg	[15:0]	r_wb_data;


	// Step 1: Generate our clock
	reg	[(CLKBITS-1):0]	clk_counter;
	initial		clk_counter = 0;
	always @(posedge i_clk)
		clk_counter <= clk_counter + 1;
	assign	o_mdclk = clk_counter[(CLKBITS-1)];

	// Step 2: Generate strobes for when to move, given the clock
	reg	rclk, zclk;
	initial	zclk = 0;
	always @(posedge i_clk)
		zclk <= (&clk_counter[(CLKBITS-1):1])&&(!clk_counter[0]);
	initial	rclk = 0;
	always @(posedge i_clk)
		rclk <= (~clk_counter[(CLKBITS-1)])&&(&clk_counter[(CLKBITS-2):0]);

	// Step 3: Read from our input port
	// 	Note: I read on the falling edge, he changes on the rising edge
	reg	in_idle;
	always @(posedge i_clk)
		if (zclk)
			read_reg <= { read_reg[14:0], i_mdio };
	always @(posedge i_clk)
		zreg_pos <= (reg_pos == 0);

	always @(posedge i_clk)
		if (rclk)
			r_wb_data <= read_reg;
	assign	o_wb_data = { 16'h00, r_wb_data };

	// Step 4: Write to our output port
	// 	Note: I change on the falling edge,
	always @(posedge i_clk)
		if (zclk)
			o_mdio <= write_reg[15];

	initial	in_idle = 1'b0;
	always @(posedge i_clk)
		in_idle <= (ctrl_state == `ECTRL_IDLE);
	initial	o_wb_stall = 1'b0;
	always @(posedge i_clk)
		if (ctrl_state != `ECTRL_IDLE)
			o_wb_stall <= 1'b1;
		else if (o_wb_ack)
			o_wb_stall <= 1'b0;
		else if (((i_wb_stb)&&(in_idle))||(read_pending)||(write_pending))
			o_wb_stall <= 1'b1;
		else	o_wb_stall <= 1'b0;

	initial	read_pending  = 1'b0;	
	initial	write_pending = 1'b0;	
	always @(posedge i_clk)
	begin
		r_addr <= i_wb_addr;
		if ((i_wb_stb)&&(~o_wb_stall))
			r_data <= i_wb_data;
		if ((i_rst)||(ctrl_state == `ECTRL_READ)||(ctrl_state == `ECTRL_WRITE))
		begin
			read_pending  <= 1'b0;
			write_pending <= 1'b0;
		end else if ((i_wb_stb)&&(~o_wb_stall))
		begin
			read_pending <= (~i_wb_we);
			write_pending <= (i_wb_we);
		end
	end

	initial	reg_pos = 6'h3f;
	initial	ctrl_state = `ECTRL_RESET;
	initial	write_reg = 16'hffff;
	always @(posedge i_clk)
	begin
		o_wb_ack <= 1'b0;
		if ((zclk)&&(!zreg_pos))
			reg_pos <= reg_pos - 1;
		if (zclk)
			write_reg <= { write_reg[14:0], 1'b1 };
		if (i_rst)
		begin // Must go for 167 ms before our 32 clocks
			ctrl_state <= `ECTRL_RESET;
			reg_pos <= 6'h3f;
			write_reg[15:0] <= 16'hffff;
		end else case(ctrl_state)
		`ECTRL_RESET: begin
			o_mdwe <= 1'b1; // Write
			write_reg[15:0] <= 16'hffff;
			if ((zclk)&&(zreg_pos))
				ctrl_state <= `ECTRL_IDLE;
			end
		`ECTRL_IDLE: begin
			o_mdwe <= 1'b1; // Write
			write_reg <= { 4'he, PHYADDR, r_addr, 2'b11 };
			if (write_pending)
			begin
				write_reg[15:12] <= { 4'h5 };
				write_reg[0] <= 1'b0;
			end else if (read_pending)
				write_reg[15:12] <= { 4'h6 };
			if (!zclk)
				write_reg[15] <= 1'b1;
			reg_pos <= 6'h0f;
			if ((zclk)&&(read_pending || write_pending))
			begin
				ctrl_state <= `ECTRL_ADDRESS;
			end end
		`ECTRL_ADDRESS: begin
			o_mdwe <= 1'b1; // Write
			if ((zreg_pos)&&(zclk))
			begin
				reg_pos <= 6'h10;
				if (read_pending)
					ctrl_state <= `ECTRL_READ;
				else
					ctrl_state <= `ECTRL_WRITE;
				write_reg <= r_data;
			end end
		`ECTRL_READ: begin
			o_mdwe <= 1'b0; // Read
			if ((zreg_pos)&&(zclk))
			begin
				ctrl_state <= `ECTRL_IDLE;
				o_wb_ack <= 1'b1;
			end end
		`ECTRL_WRITE: begin
			o_mdwe <= 1'b1; // Write
			if ((zreg_pos)&&(zclk))
			begin
				ctrl_state <= `ECTRL_IDLE;
				o_wb_ack <= 1'b1;
			end end
		default: begin
			o_mdwe <= 1'b0; // Read
			reg_pos <= 6'h3f;
			ctrl_state <= `ECTRL_RESET;
			end
		endcase
	end

	assign	o_debug = {
			o_wb_stall,i_wb_stb,i_wb_we, i_wb_addr,	// 8 bits
			o_wb_ack, rclk, o_wb_data[5:0],		// 8 bits
			zreg_pos, zclk, reg_pos,		// 8 bits
			read_pending, ctrl_state,		// 4 bits
			o_mdclk, o_mdwe, o_mdio, i_mdio		// 4 bits
		};

endmodule
