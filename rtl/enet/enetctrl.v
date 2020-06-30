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
// Copyright (C) 2016,2020, Gisselquist Technology, LLC
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
`default_nettype	none
//
module	enetctrl(i_clk, i_reset,
		i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data, i_wb_sel,
			o_wb_stall, o_wb_ack, o_wb_data,
		o_mdclk, o_mdio, i_mdio, o_mdwe,
		o_debug);
	parameter	CLKBITS=2; // = 3 for 200MHz source clock, 2 for 100 MHz
	parameter [4:0]	PHYADDR = 5'h01;
`ifdef	FORMAL
	parameter [0:0]		F_OPT_COVER =  1'b0;
`else
	localparam [0:0]	F_OPT_COVER =  1'b0;
`endif
	localparam	[2:0]	ECTRL_RESET   = 3'h0;
	localparam	[2:0]	ECTRL_IDLE    = 3'h1;
	localparam	[2:0]	ECTRL_ADDRESS = 3'h2;
	localparam	[2:0]	ECTRL_READ    = 3'h3;
	localparam	[2:0]	ECTRL_WRITE   = 3'h4;
	input	wire		i_clk, i_reset;
	input	wire		i_wb_cyc, i_wb_stb, i_wb_we;
	input	wire	[4:0]	i_wb_addr;
	input	wire	[31:0]	i_wb_data;
	input	wire	[3:0]	i_wb_sel;
	output	reg		o_wb_stall, o_wb_ack;
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

	reg	[(CLKBITS-1):0]	clk_counter;
	reg	rclk, zclk;
	reg	in_idle, pre_ack;

	// Step 1: Generate our clock
	initial		clk_counter = 0;
	always @(posedge i_clk)
	if (i_reset)
		clk_counter <= 0;
	else
		clk_counter <= clk_counter + 1;
	assign	o_mdclk = clk_counter[(CLKBITS-1)];

	// Step 2: Generate strobes for when to move, given the clock
	initial	zclk = 0;
	always @(posedge i_clk)
	if (i_reset)
		zclk <= 1'b0;
	else
		zclk <= (&clk_counter[(CLKBITS-1):1])&&(!clk_counter[0]);
	initial	rclk = 0;
	always @(posedge i_clk)
	if (i_reset)
		rclk <= 1'b0;
	else
		rclk <= (!clk_counter[(CLKBITS-1)])&&(&clk_counter[(CLKBITS-2):0]);

	// Step 3: Read from our input port
	// 	Note: I read on the falling edge, he changes on the rising edge
	always @(posedge i_clk)
	if (zclk && !zreg_pos)
		read_reg <= { read_reg[14:0], i_mdio };
	always @(posedge i_clk)
		zreg_pos <= (reg_pos == 0);

	always @(*)
		r_wb_data = read_reg;
	assign	o_wb_data = { 16'h00, r_wb_data };

	// Step 4: Write to our output port
	// 	Note: I change on the falling edge,
	always @(posedge i_clk)
	if (zclk)
		o_mdio <= write_reg[15];

	initial	in_idle = 1'b0;
	always @(posedge i_clk)
		in_idle <= (ctrl_state == ECTRL_IDLE);
	initial	o_wb_stall = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		o_wb_stall <= 1'b1;
	else if (ctrl_state != ECTRL_IDLE)
		o_wb_stall <= 1'b1;
	else if (o_wb_ack)
		o_wb_stall <= 1'b0;
	else if (((i_wb_stb)&&(in_idle))||(read_pending)||(write_pending))
		o_wb_stall <= 1'b1;
	else
		o_wb_stall <= 1'b0;

	initial	read_pending  = 1'b0;	
	initial	write_pending = 1'b0;	
	always @(posedge i_clk)
	begin
		if (!o_wb_stall)
			r_addr <= i_wb_addr;
		if (!o_wb_stall)
			r_data <= i_wb_data[15:0];
		if ((i_reset)||(ctrl_state == ECTRL_READ)||(ctrl_state == ECTRL_WRITE))
		begin
			read_pending  <= 1'b0;
			write_pending <= 1'b0;
		end else if ((i_wb_stb)&&(!o_wb_stall))
		begin
			read_pending  <= (!i_wb_we);
			write_pending <= (i_wb_we);
		end
	end

	initial	pre_ack = 1'b0;
	always @(posedge i_clk)
	if ((i_reset)||(!i_wb_cyc))
		pre_ack <= 1'b0;
	else if ((i_wb_stb)&&(!o_wb_stall))
		pre_ack <= 1'b1;
	else if (o_wb_ack)
		pre_ack <= 1'b0;

	initial	reg_pos = 6'h3f;
	initial	ctrl_state = ECTRL_RESET;
	initial	write_reg = 16'hffff;
	initial	o_wb_ack = 1'b0;
	always @(posedge i_clk)
	begin
		o_wb_ack <= 1'b0;
		if ((zclk)&&(!zreg_pos))
			reg_pos <= reg_pos - 1;
		if (zclk)
			write_reg <= { write_reg[14:0], 1'b1 };
		if (i_reset)
		begin // Must go for 167 ms before our 32 clocks
			ctrl_state <= ECTRL_RESET;
			reg_pos <= (F_OPT_COVER) ? 6'h2 : 6'h3f;
			write_reg[15:0] <= 16'hffff;
			o_mdwe <= 1'b1; // Write
		end else case(ctrl_state)
		ECTRL_RESET: begin
			o_mdwe <= 1'b1; // Write
			write_reg[15:0] <= 16'hffff;
			if ((zclk)&&(zreg_pos))
				ctrl_state <= ECTRL_IDLE;
			end
		ECTRL_IDLE: begin
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
				ctrl_state <= ECTRL_ADDRESS;
			end
		ECTRL_ADDRESS: begin
			if (zclk)
				o_mdwe <= (write_pending)||(reg_pos > 6'h1); // Write
			if ((zreg_pos)&&(zclk))
			begin
				reg_pos <= 6'h10;
				if (read_pending)
					ctrl_state <= ECTRL_READ;
				else
					ctrl_state <= ECTRL_WRITE;
				write_reg <= r_data;
			end end
		ECTRL_READ: begin
			o_mdwe <= 1'b0; // Read
			if ((zreg_pos)&&(zclk))
			begin
				ctrl_state <= ECTRL_IDLE;
				o_wb_ack <= (pre_ack)&&(i_wb_cyc);
			end end
		ECTRL_WRITE: begin
			o_mdwe <= 1'b1; // Write
			if ((zreg_pos)&&(zclk))
			begin
				ctrl_state <= ECTRL_IDLE;
				o_wb_ack <= (pre_ack)&&(i_wb_cyc);
			end end
		default: begin
			o_mdwe <= 1'b0; // Read
			reg_pos <= 6'h3f;
			ctrl_state <= ECTRL_RESET;
			end
		endcase

		if (i_reset)
			o_wb_ack <= 1'b0;
	end

	assign	o_debug = {
			o_wb_stall,i_wb_stb,i_wb_we, i_wb_addr,	// 8 bits
			o_wb_ack, rclk, o_wb_data[5:0],		// 8 bits
			zreg_pos, zclk, reg_pos,		// 8 bits
			read_pending, ctrl_state,		// 4 bits
			o_mdclk, o_mdwe, o_mdio, i_mdio		// 4 bits
		};

	// Make Verilator happy
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, i_wb_sel, i_wb_data[31:16] };
	// verilator lint_on  UNUSED
`ifdef	FORMAL
`define	ASSUME	assume
`define	ASSERT	assert
	localparam	F_LGDEPTH = 3;

	wire	[F_LGDEPTH-1:0]	f_nreqs, f_nacks, f_outstanding;
	reg	[4:0]	f_addr;
	reg	[15:0]	f_data;

	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;

	always @(*)
	if (!f_past_valid)
		`ASSUME(i_reset);

	always @(*)
	if (o_mdwe)
		assume(i_mdio == o_mdio);
	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(o_mdwe))&&(!o_mdwe)&&(!$rose(o_mdclk)))
		assume($stable(i_mdio));

	always @(posedge i_clk)
	if ((f_past_valid)&&(!$fell(o_mdclk)))
		`ASSERT($stable(o_mdio));

	always @(*)
		`ASSERT(zclk == ((&clk_counter) ? 1 : 0));
	always @(*)
		`ASSERT(rclk == (clk_counter == {1'b1,{(CLKBITS-1){1'b0}}}));
	always @(*)
		`ASSERT(ctrl_state <= ECTRL_WRITE);
	always @(posedge i_clk)
		cover(o_wb_ack);
	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_reset)))
		cover(o_wb_ack);
	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_reset)))
		cover($fell(o_wb_stall));
	always @(posedge i_clk)
		cover(ctrl_state == ECTRL_IDLE);


	fwb_slave #(.AW(5), .DW(32), .F_MAX_STALL(0), .F_MAX_ACK_DELAY(0),
			.F_LGDEPTH(F_LGDEPTH), .F_MAX_REQUESTS(0))
	  fwb(i_clk, i_reset, i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr,
			i_wb_data, i_wb_sel,
		o_wb_ack, o_wb_stall, o_wb_data, 1'b0,
		f_nreqs, f_nacks, f_outstanding);

	always @(*)
		`ASSERT(f_outstanding <= 1);
	always @(*)
	if (i_wb_cyc)
		`ASSERT(f_outstanding == (pre_ack ? 1 : 0));
	// always @(*)
	// if (in_idle)
	//	`ASSERT(f_outstanding == 0);

	always @(posedge i_clk)
	if ((i_wb_stb)&&(!o_wb_stall))
	begin
		f_addr <= i_wb_addr;
		f_data <= i_wb_data[15:0];
	end

	always @(*)
	if ((ctrl_state != ECTRL_RESET)
		&&((ctrl_state != ECTRL_IDLE)||(read_pending)||(write_pending)))
	begin
		assert(f_addr == r_addr);
		assert(f_data == r_data);
	end

	always @(*)
		`ASSERT(!write_pending || !read_pending);
	always @(*)
	if (ctrl_state == ECTRL_RESET)
	begin
		`ASSERT(!pre_ack && !o_wb_ack && o_wb_stall);
		`ASSERT(!read_pending);
		`ASSERT(!write_pending);
	end

	always @(*)
	if (ctrl_state != ECTRL_IDLE)
		`ASSERT(!o_wb_ack);
	else if ((read_pending)||(write_pending))
		`ASSERT(!o_wb_ack && o_wb_stall);
	else // if (ctrl_state == ECTRL_IDLE)
		`ASSERT(o_wb_ack || !pre_ack);

`ifdef VERIFIC
	sequence	BITPERIOD;
		(!zclk) [*] ##1 (zclk);
	endsequence

	sequence	SENDBIT(MSG,SHIFT);
		((o_mdwe)&&(o_wb_stall)&&(o_mdio == MSG[15-SHIFT])
			&&(write_reg == { MSG[14-SHIFT:0], {(SHIFT+1){1'b1} }})
			&&(reg_pos==6'h0e-SHIFT))
		throughout BITPERIOD;
	endsequence

	sequence	HIZBIT(POS);
		((!o_mdwe)&&(o_wb_stall)&&(reg_pos==POS))
		throughout BITPERIOD;
	endsequence


	sequence	DATABIT(BIT, WREG, RPOS);
		((o_mdwe)&&(o_wb_stall)&&(o_mdio == BIT)&&(reg_pos == RPOS)
		&&(write_reg == WREG)) throughout BITPERIOD;
	endsequence

	// These properties aren't yet ... written or working
	// Use them at your own risk
	`ASSERT property (@(posedge i_clk)
		disable iff (i_reset)
		((f_past_valid)&&($past(i_reset))&&(!F_OPT_COVER))
		|=> (((!read_pending)&&(!write_pending)&&(o_wb_stall)
			&&(ctrl_state == ECTRL_RESET)
			&&(write_reg[15:0] <= 16'hffff)&&(o_mdwe))
			throughout
			((reg_pos == 6'h3f) throughout BITPERIOD)
			##1 ((reg_pos == 6'h3e) throughout BITPERIOD)
			##1 ((reg_pos == 6'h3d) throughout BITPERIOD)
			##1 ((reg_pos == 6'h3c) throughout BITPERIOD)
			##1 ((reg_pos == 6'h3b) throughout BITPERIOD)
			##1 ((reg_pos == 6'h3a) throughout BITPERIOD)
			##1 ((reg_pos == 6'h39) throughout BITPERIOD)
			##1 ((reg_pos == 6'h38) throughout BITPERIOD)
			##1 ((reg_pos == 6'h37) throughout BITPERIOD)
			##1 ((reg_pos == 6'h36) throughout BITPERIOD)
			##1 ((reg_pos == 6'h35) throughout BITPERIOD)
			##1 ((reg_pos == 6'h34) throughout BITPERIOD)
			##1 ((reg_pos == 6'h33) throughout BITPERIOD)
			##1 ((reg_pos == 6'h32) throughout BITPERIOD)
			##1 ((reg_pos == 6'h31) throughout BITPERIOD)
			##1 ((reg_pos == 6'h30) throughout BITPERIOD)
			##1 ((reg_pos == 6'h2f) throughout BITPERIOD)
			##1 ((reg_pos == 6'h2e) throughout BITPERIOD)
			##1 ((reg_pos == 6'h2d) throughout BITPERIOD)
			##1 ((reg_pos == 6'h2c) throughout BITPERIOD)
			##1 ((reg_pos == 6'h2b) throughout BITPERIOD)
			##1 ((reg_pos == 6'h2a) throughout BITPERIOD)
			##1 ((reg_pos == 6'h29) throughout BITPERIOD)
			##1 ((reg_pos == 6'h28) throughout BITPERIOD)
			##1 ((reg_pos == 6'h27) throughout BITPERIOD)
			##1 ((reg_pos == 6'h26) throughout BITPERIOD)
			##1 ((reg_pos == 6'h25) throughout BITPERIOD)
			##1 ((reg_pos == 6'h24) throughout BITPERIOD)
			##1 ((reg_pos == 6'h23) throughout BITPERIOD)
			##1 ((reg_pos == 6'h22) throughout BITPERIOD)
			##1 ((reg_pos == 6'h21) throughout BITPERIOD)
			##1 ((reg_pos == 6'h20) throughout BITPERIOD)
			##1 ((reg_pos == 6'h1f) throughout BITPERIOD)
			##1 ((reg_pos == 6'h1e) throughout BITPERIOD)
			##1 ((reg_pos == 6'h1d) throughout BITPERIOD)
			##1 ((reg_pos == 6'h1c) throughout BITPERIOD)
			##1 ((reg_pos == 6'h1b) throughout BITPERIOD)
			##1 ((reg_pos == 6'h1a) throughout BITPERIOD)
			##1 ((reg_pos == 6'h19) throughout BITPERIOD)
			##1 ((reg_pos == 6'h18) throughout BITPERIOD)
			##1 ((reg_pos == 6'h17) throughout BITPERIOD)
			##1 ((reg_pos == 6'h16) throughout BITPERIOD)
			##1 ((reg_pos == 6'h15) throughout BITPERIOD)
			##1 ((reg_pos == 6'h14) throughout BITPERIOD)
			##1 ((reg_pos == 6'h13) throughout BITPERIOD)
			##1 ((reg_pos == 6'h12) throughout BITPERIOD)
			##1 ((reg_pos == 6'h11) throughout BITPERIOD)
			##1 ((reg_pos == 6'h10) throughout BITPERIOD)
			##1 ((reg_pos == 6'h0f) throughout BITPERIOD)
			##1 ((reg_pos == 6'h0e) throughout BITPERIOD)
			##1 ((reg_pos == 6'h0d) throughout BITPERIOD)
			##1 ((reg_pos == 6'h0c) throughout BITPERIOD)
			##1 ((reg_pos == 6'h0b) throughout BITPERIOD)
			##1 ((reg_pos == 6'h0a) throughout BITPERIOD)
			##1 ((reg_pos == 6'h09) throughout BITPERIOD)
			##1 ((reg_pos == 6'h08) throughout BITPERIOD)
			##1 ((reg_pos == 6'h07) throughout BITPERIOD)
			##1 ((reg_pos == 6'h06) throughout BITPERIOD)
			##1 ((reg_pos == 6'h05) throughout BITPERIOD)
			##1 ((reg_pos == 6'h04) throughout BITPERIOD)
			##1 ((reg_pos == 6'h03) throughout BITPERIOD)
			##1 ((reg_pos == 6'h02) throughout BITPERIOD)
			##1 ((reg_pos == 6'h01) throughout BITPERIOD)
			##1 ((reg_pos == 6'h00) throughout BITPERIOD))
		##1 (ctrl_state == ECTRL_IDLE)
		);

	`ASSERT property (@(posedge i_clk)
		disable iff (i_reset)
		((i_wb_stb)&&(!o_wb_stall)&&(!i_wb_we))
		|=> (o_mdwe)&&(read_pending)&&(o_wb_stall)
		##1 (!zclk)&&(o_mdwe)&&(read_pending) [*0:32]
		##1 (zclk)&&(write_reg == { 4'h6, PHYADDR, f_addr, 2'b11 })
			&&(o_mdio == 1'b1)&&(reg_pos == 6'h0f)
		##1 ((o_wb_stall)&&(o_mdwe && read_pending && (ctrl_state == ECTRL_ADDRESS))
			throughout
		SENDBIT({ 4'h6, PHYADDR, f_addr, 2'b11 },  0)
		##1 SENDBIT({ 4'h6, PHYADDR, f_addr, 2'b11 },  1)
		##1 SENDBIT({ 4'h6, PHYADDR, f_addr, 2'b11 },  2)
		##1 SENDBIT({ 4'h6, PHYADDR, f_addr, 2'b11 },  3)
		##1 SENDBIT({ 4'h6, PHYADDR, f_addr, 2'b11 },  4)
		##1 SENDBIT({ 4'h6, PHYADDR, f_addr, 2'b11 },  5)
		##1 SENDBIT({ 4'h6, PHYADDR, f_addr, 2'b11 },  6)
		##1 SENDBIT({ 4'h6, PHYADDR, f_addr, 2'b11 },  7)
		##1 SENDBIT({ 4'h6, PHYADDR, f_addr, 2'b11 },  8)
		##1 SENDBIT({ 4'h6, PHYADDR, f_addr, 2'b11 },  9)
		##1 SENDBIT({ 4'h6, PHYADDR, f_addr, 2'b11 }, 10)
		##1 SENDBIT({ 4'h6, PHYADDR, f_addr, 2'b11 }, 11)
		##1 SENDBIT({ 4'h6, PHYADDR, f_addr, 2'b11 }, 12)
		##1 SENDBIT({ 4'h6, PHYADDR, f_addr, 2'b11 }, 13)
		##1 SENDBIT({ 4'h6, PHYADDR, f_addr, 2'b11 }, 14))
		##1 ((!o_mdwe)&&(ctrl_state == ECTRL_READ) throughout
		##1 HIZBIT(6'h01)
		##1 HIZBIT(6'h00))
		##1 ((ctrl_state == ECTRL_READ) throughout
			HIZBIT(6'h10)
			##1 HIZBIT(6'h0f)
			##1 HIZBIT(6'h0e)
			##1 HIZBIT(6'h0d)
			##1 HIZBIT(6'h0c)
			##1 HIZBIT(6'h0b)
			##1 HIZBIT(6'h0a)
			##1 HIZBIT(6'h09)
			##1 HIZBIT(6'h08)
			##1 HIZBIT(6'h07)
			##1 HIZBIT(6'h06)
			##1 HIZBIT(6'h05)
			##1 HIZBIT(6'h04)
			##1 HIZBIT(6'h03)
			##1 HIZBIT(6'h02)
			##1 HIZBIT(6'h01)
			##1 ((o_wb_stall)&&((!pre_ack)||(o_wb_ack))))
		);

	`ASSERT property (@(posedge i_clk)
		disable iff (i_reset)
		((i_wb_stb)&&(!o_wb_stall)&&(i_wb_we))
		|=> (o_mdwe)&&(write_pending)
		##1 (!zclk)&&(o_mdwe)&&(write_pending) [*0:32]
		##1 (zclk)&&(write_reg == { 4'h5, PHYADDR, f_addr, 2'b11 })
			&&(o_mdio == 1'b1)&&(reg_pos == 6'h0f)
		##1 ((o_wb_stall)&&(o_mdwe && write_pending
				&& (ctrl_state == ECTRL_ADDRESS))
			throughout
		SENDBIT({ 4'h5, PHYADDR, f_addr, 2'b11 },  0)
		##1 SENDBIT({ 4'h5, PHYADDR, f_addr, 2'b11 },  1)
		##1 SENDBIT({ 4'h5, PHYADDR, f_addr, 2'b11 },  2)
		##1 SENDBIT({ 4'h5, PHYADDR, f_addr, 2'b11 },  3)
		##1 SENDBIT({ 4'h5, PHYADDR, f_addr, 2'b11 },  4)
		##1 SENDBIT({ 4'h5, PHYADDR, f_addr, 2'b11 },  5)
		##1 SENDBIT({ 4'h5, PHYADDR, f_addr, 2'b11 },  6)
		##1 SENDBIT({ 4'h5, PHYADDR, f_addr, 2'b11 },  7)
		##1 SENDBIT({ 4'h5, PHYADDR, f_addr, 2'b11 },  8)
		##1 SENDBIT({ 4'h5, PHYADDR, f_addr, 2'b11 },  9)
		##1 SENDBIT({ 4'h5, PHYADDR, f_addr, 2'b11 }, 10)
		##1 SENDBIT({ 4'h5, PHYADDR, f_addr, 2'b11 }, 11)
		##1 SENDBIT({ 4'h5, PHYADDR, f_addr, 2'b11 }, 12)
		##1 SENDBIT({ 4'h5, PHYADDR, f_addr, 2'b11 }, 13)
		##1 SENDBIT({ 4'h5, PHYADDR, f_addr, 2'b11 }, 14))
		##1 ((o_mdwe)&&(ctrl_state == ECTRL_WRITE) throughout
		  ##1 DATABIT(1'b1, 16'hffff, 6'h01)
		  ##1 DATABIT(1'b0, f_data, 6'h10)
		  ##1 DATABIT(f_data[15],{f_data[14:0],{(1){1'b1}}},6'h0f)
		  ##1 DATABIT(f_data[14],{f_data[13:0],{(2){1'b1}}},6'h0e)
		  ##1 DATABIT(f_data[13],{f_data[12:0],{(3){1'b1}}},6'h0d)
		  ##1 DATABIT(f_data[12],{f_data[11:0],{(4){1'b1}}},6'h0c)
		  ##1 DATABIT(f_data[11],{f_data[10:0],{(5){1'b1}}},6'h0b)
		  ##1 DATABIT(f_data[10],{f_data[ 9:0],{(6){1'b1}}},6'h0a)
		  ##1 DATABIT(f_data[ 9],{f_data[ 8:0],{(7){1'b1}}},6'h09)
		  ##1 DATABIT(f_data[ 8],{f_data[ 7:0],{(8){1'b1}}},6'h08)
		  ##1 DATABIT(f_data[ 7],{f_data[ 6:0],{(9){1'b1}}},6'h07)
		  ##1 DATABIT(f_data[ 6],{f_data[ 5:0],{(10){1'b1}}},6'h06)
		  ##1 DATABIT(f_data[ 5],{f_data[ 4:0],{(11){1'b1}}},6'h05)
		  ##1 DATABIT(f_data[ 4],{f_data[ 3:0],{(12){1'b1}}},6'h04)
		  ##1 DATABIT(f_data[ 3],{f_data[ 2:0],{(13){1'b1}}},6'h03)
		  ##1 DATABIT(f_data[ 2],{f_data[ 1:0],{(14){1'b1}}},6'h02)
		  ##1 DATABIT(f_data[ 1],{f_data[ 0:0],{(15){1'b1}}},6'h01)
		  ##1 DATABIT(f_data[ 0],{(16){1'b1}},6'h00)
		  ##1 ((o_wb_stall)&&((!pre_ack)||(o_wb_ack))))
		);

`else // VERIFIC
	//
	// These properties do the same thing as the verific properties above
	// would do.  They should also be complete and totally functional.
	//
	reg	[33:0]	f_read_steps;

	initial	f_read_steps = 0;
	always @(posedge i_clk)
	if (i_reset)
		f_read_steps <= 0;
	else begin
		if (zclk)
			f_read_steps <= { f_read_steps[32:0], 1'b0 };
		if ((i_wb_stb)&&(!i_wb_we)&&(!o_wb_stall))
			f_read_steps[0] <= 1'b1;
	end

	always @(*)
	begin
		if(f_read_steps[1])
		begin
			assert(write_reg == { 4'h6, PHYADDR, f_addr, 2'b11 });
			assert(o_mdio == 1'b1);
			assert(reg_pos == 6'h0f);
		end
		if(f_read_steps[2])
		begin
			assert(write_reg == { 3'h6, PHYADDR, f_addr, 3'b111 });
			assert(o_mdio == 1'b0);
			assert(reg_pos == 6'h0e);
		end
		if(f_read_steps[3])
		begin
			assert(write_reg == { 2'h2, PHYADDR, f_addr, 4'hf });
			assert(o_mdio == 1'b1);
			assert(reg_pos == 6'h0d);
		end
		if(f_read_steps[4])
		begin
			assert(write_reg == { 1'b0, PHYADDR, f_addr, 5'h1f });
			assert(o_mdio == 1'b1);
			assert(reg_pos == 6'h0c);
		end
		if(f_read_steps[5])
		begin
			assert(write_reg == { PHYADDR, f_addr, 6'h3f });
			assert(o_mdio == 1'b0);
			assert(reg_pos == 6'h0b);
		end
		if(f_read_steps[6])
		begin
			assert(write_reg == { PHYADDR[3:0], f_addr, 7'h7f });
			assert(o_mdio == PHYADDR[4]);
			assert(reg_pos == 6'h0a);
		end
		if(f_read_steps[7])
		begin
			assert(write_reg == { PHYADDR[2:0], f_addr, 8'hff });
			assert(o_mdio == PHYADDR[3]);
			assert(reg_pos == 6'h09);
		end
		if(f_read_steps[8])
		begin
			assert(write_reg == { PHYADDR[1:0], f_addr, 9'h1ff });
			assert(o_mdio == PHYADDR[2]);
			assert(reg_pos == 6'h08);
		end
		if(f_read_steps[9])
		begin
			assert(write_reg == { PHYADDR[0], f_addr, 10'h3ff });
			assert(o_mdio == PHYADDR[1]);
			assert(reg_pos == 6'h07);
		end
		if(f_read_steps[10])
		begin
			assert(write_reg == { f_addr, 11'h7ff });
			assert(o_mdio == PHYADDR[0]);
			assert(reg_pos == 6'h06);
		end
		if(f_read_steps[11])
		begin
			assert(write_reg == { f_addr[3:0], 12'hfff });
			assert(o_mdio == f_addr[4]);
			assert(reg_pos == 6'h05);
		end
		if(f_read_steps[12])
		begin
			assert(write_reg == { f_addr[2:0], 13'h1fff });
			assert(o_mdio == f_addr[3]);
			assert(reg_pos == 6'h04);
		end
		if(f_read_steps[13])
		begin
			assert(write_reg == { f_addr[1:0], 14'h3fff });
			assert(o_mdio == f_addr[2]);
			assert(reg_pos == 6'h03);
		end
		if(f_read_steps[14])
		begin
			assert(write_reg == { f_addr[0],   15'h7fff });
			assert(o_mdio == f_addr[1]);
			assert(reg_pos == 6'h02);
		end
		if(f_read_steps[15])
		begin
			assert(o_mdio == f_addr[0]);
			assert(reg_pos == 6'h01);
		end
		if(f_read_steps[16])
			assert(reg_pos == 6'h00);
		if (f_read_steps[17])
			assert(reg_pos == 6'h10);
		if (f_read_steps[18])
			assert(reg_pos == 6'h0f);
		if (f_read_steps[19])
			assert(reg_pos == 6'h0e);
		if (f_read_steps[20]) assert(reg_pos == 6'h0d);
		if (f_read_steps[21]) assert(reg_pos == 6'h0c);
		if (f_read_steps[22]) assert(reg_pos == 6'h0b);
		if (f_read_steps[23]) assert(reg_pos == 6'h0a);
		if (f_read_steps[24]) assert(reg_pos == 6'h09);
		if (f_read_steps[25]) assert(reg_pos == 6'h08);
		if (f_read_steps[26]) assert(reg_pos == 6'h07);
		if (f_read_steps[27]) assert(reg_pos == 6'h06);
		if (f_read_steps[28]) assert(reg_pos == 6'h05);
		if (f_read_steps[29]) assert(reg_pos == 6'h04);
		if (f_read_steps[30]) assert(reg_pos == 6'h03);
		if (f_read_steps[31]) assert(reg_pos == 6'h02);
		if (f_read_steps[32]) assert(reg_pos == 6'h01);
		if (f_read_steps[33]) assert(reg_pos == 6'h00);
		if (|f_read_steps[16:1])
			assert((ctrl_state == ECTRL_ADDRESS)&&(read_pending));
		if (|f_read_steps[32:17])
			assert(ctrl_state == ECTRL_READ);
		if (|f_read_steps[16:15])
			assert(&write_reg);
		if (|f_read_steps[15:0])
			assert(o_mdwe);
		if (|f_read_steps[33:16])
			assert(!o_mdwe);

		if (|f_read_steps)
			assert(o_wb_stall);
		if (|f_read_steps)
			assert(!o_wb_ack);
	end

	always @(*)
	if (|f_read_steps[33:17])
		assert(ctrl_state == ECTRL_READ);
	else
		assert(ctrl_state != ECTRL_READ);


	reg	f_read_steps_onehot;
	always @(*)
	if (f_read_steps != 0)
	begin
		assert(f_write_steps == 0);
		assert(write_pending == 0);
		assert(ctrl_state != ECTRL_RESET);
		assert(ctrl_state != ECTRL_WRITE);


		f_read_steps_onehot = 1'b0;
		case(f_read_steps)
		34'h0000_0001: f_read_steps_onehot = 1'b1;
		34'h0000_0002: f_read_steps_onehot = 1'b1;
		34'h0000_0004: f_read_steps_onehot = 1'b1;
		34'h0000_0008: f_read_steps_onehot = 1'b1;
		34'h0000_0010: f_read_steps_onehot = 1'b1;
		34'h0000_0020: f_read_steps_onehot = 1'b1;
		34'h0000_0040: f_read_steps_onehot = 1'b1;
		34'h0000_0080: f_read_steps_onehot = 1'b1;
		34'h0000_0100: f_read_steps_onehot = 1'b1;
		34'h0000_0200: f_read_steps_onehot = 1'b1;
		34'h0000_0400: f_read_steps_onehot = 1'b1;
		34'h0000_0800: f_read_steps_onehot = 1'b1;
		34'h0000_1000: f_read_steps_onehot = 1'b1;
		34'h0000_2000: f_read_steps_onehot = 1'b1;
		34'h0000_4000: f_read_steps_onehot = 1'b1;
		34'h0000_8000: f_read_steps_onehot = 1'b1;
		34'h0001_0000: f_read_steps_onehot = 1'b1;
		34'h0002_0000: f_read_steps_onehot = 1'b1;
		34'h0004_0000: f_read_steps_onehot = 1'b1;
		34'h0008_0000: f_read_steps_onehot = 1'b1;
		34'h0010_0000: f_read_steps_onehot = 1'b1;
		34'h0020_0000: f_read_steps_onehot = 1'b1;
		34'h0040_0000: f_read_steps_onehot = 1'b1;
		34'h0080_0000: f_read_steps_onehot = 1'b1;
		34'h0100_0000: f_read_steps_onehot = 1'b1;
		34'h0200_0000: f_read_steps_onehot = 1'b1;
		34'h0400_0000: f_read_steps_onehot = 1'b1;
		34'h0800_0000: f_read_steps_onehot = 1'b1;
		34'h1000_0000: f_read_steps_onehot = 1'b1;
		34'h2000_0000: f_read_steps_onehot = 1'b1;
		34'h4000_0000: f_read_steps_onehot = 1'b1;
		34'h8000_0000: f_read_steps_onehot = 1'b1;
		34'h10000_0000: f_read_steps_onehot = 1'b1;
		34'h20000_0000: f_read_steps_onehot = 1'b1;
		default: begin end
		endcase

		assert(f_read_steps_onehot);
	end

	(* anyconst *) reg	[15:0]	f_const_data;
	reg	[15:0]	f_known_read;

	initial	f_known_read = 0;
	always @(posedge i_clk)
	if (i_reset)
		f_known_read = 0;
	else if (zclk)
	begin
		f_known_read <= {f_known_read[14:0], 1'b0};
		if(f_read_steps[18] && (i_mdio == f_const_data[15]))
			f_known_read[0] <= 1'b1;

		if (i_mdio != f_const_data[14]) f_known_read[ 1] <= 1'b0;
		if (i_mdio != f_const_data[13]) f_known_read[ 2] <= 1'b0;
		if (i_mdio != f_const_data[12]) f_known_read[ 3] <= 1'b0;
		if (i_mdio != f_const_data[11]) f_known_read[ 4] <= 1'b0;
		if (i_mdio != f_const_data[10]) f_known_read[ 5] <= 1'b0;
		if (i_mdio != f_const_data[ 9]) f_known_read[ 6] <= 1'b0;
		if (i_mdio != f_const_data[ 8]) f_known_read[ 7] <= 1'b0;
		if (i_mdio != f_const_data[ 7]) f_known_read[ 8] <= 1'b0;
		if (i_mdio != f_const_data[ 6]) f_known_read[ 9] <= 1'b0;
		if (i_mdio != f_const_data[ 5]) f_known_read[10] <= 1'b0;
		if (i_mdio != f_const_data[ 4]) f_known_read[11] <= 1'b0;
		if (i_mdio != f_const_data[ 3]) f_known_read[12] <= 1'b0;
		if (i_mdio != f_const_data[ 2]) f_known_read[13] <= 1'b0;
		if (i_mdio != f_const_data[ 1]) f_known_read[14] <= 1'b0;
		if (i_mdio != f_const_data[ 0]) f_known_read[15] <= 1'b0;
	end


	always @(*)
	begin
		if (f_known_read[0])
			assert(read_reg[0] == f_const_data[15]);
		if (f_known_read[1])
			assert(read_reg[1:0] == f_const_data[15:14]);
		if (f_known_read[2])
			assert(read_reg[2:0] == f_const_data[15:13]);
		if (f_known_read[3])
			assert(read_reg[3:0] == f_const_data[15:12]);
		if (f_known_read[4])
			assert(read_reg[4:0] == f_const_data[15:11]);
		if (f_known_read[5])
			assert(read_reg[5:0] == f_const_data[15:10]);
		if (f_known_read[6])
			assert(read_reg[6:0] == f_const_data[15:9]);
		if (f_known_read[7])
			assert(read_reg[7:0] == f_const_data[15:8]);
		if (f_known_read[8])
			assert(read_reg[8:0] == f_const_data[15:7]);
		if (f_known_read[9])
			assert(read_reg[9:0] == f_const_data[15:6]);
		if (f_known_read[10])
			assert(read_reg[10:0] == f_const_data[15:5]);
		if (f_known_read[11])
			assert(read_reg[11:0] == f_const_data[15:4]);
		if (f_known_read[12])
			assert(read_reg[12:0] == f_const_data[15:3]);
		if (f_known_read[13])
			assert(read_reg[13:0] == f_const_data[15:2]);
		if (f_known_read[14])
			assert(read_reg[14:0] == f_const_data[15:1]);
		if (f_known_read[15])
			assert(read_reg[15:0] == f_const_data[15:0]);
	end

	always @(*)
	if (|f_read_steps[33:19])
		assert((f_known_read[14:0] & (~f_read_steps[33:19])) == 0);
	else
		assert(f_known_read[14:0] == 0);

	always @(posedge i_clk)
	if ((o_wb_ack)&&(f_known_read[15]))
		assert(o_wb_data == { 16'h0, f_const_data });

	always @(posedge i_clk)
		cover(o_wb_ack && f_known_read[15]);

	reg	[33:0]	f_write_steps;

	initial	f_write_steps = 0;
	always @(posedge i_clk)
	if (i_reset)
		f_write_steps <= 0;
	else begin
		if (zclk)
			f_write_steps <= { f_write_steps[32:0], 1'b0 };
		if ((i_wb_stb)&&(i_wb_we)&&(!o_wb_stall))
			f_write_steps[0] <= 1'b1;
	end

	always @(*)
	begin
		if(f_write_steps[1])
		begin
			assert(write_reg == { 4'h5, PHYADDR, f_addr, 2'b10 });
			assert(o_mdio == 1'b1);
			assert(reg_pos == 6'h0f);
		end
		if(f_write_steps[2])
		begin
			assert(write_reg == { 3'h5, PHYADDR, f_addr, 3'b101 });
			assert(o_mdio == 1'b0);
			assert(reg_pos == 6'h0e);
		end
		if(f_write_steps[3])
		begin
			assert(write_reg == { 2'h1, PHYADDR, f_addr, 4'hb });
			assert(o_mdio == 1'b1);
			assert(reg_pos == 6'h0d);
		end
		if(f_write_steps[4])
		begin
			assert(write_reg == { 1'b1, PHYADDR, f_addr, 5'h17 });
			assert(o_mdio == 1'b0);
			assert(reg_pos == 6'h0c);
		end
		if(f_write_steps[5])
		begin
			assert(write_reg == { PHYADDR, f_addr, 6'h2f });
			assert(o_mdio == 1'b1);
			assert(reg_pos == 6'h0b);
		end
		if(f_write_steps[6])
		begin
			assert(write_reg == { PHYADDR[3:0], f_addr, 7'h5f });
			assert(o_mdio == PHYADDR[4]);
			assert(reg_pos == 6'h0a);
		end
		if(f_write_steps[7])
		begin
			assert(write_reg == { PHYADDR[2:0], f_addr, 8'hbf });
			assert(o_mdio == PHYADDR[3]);
			assert(reg_pos == 6'h09);
		end
		if(f_write_steps[8])
		begin
			assert(write_reg == { PHYADDR[1:0], f_addr, 9'h17f });
			assert(o_mdio == PHYADDR[2]);
			assert(reg_pos == 6'h08);
		end
		if(f_write_steps[9])
		begin
			assert(write_reg == { PHYADDR[0], f_addr, 10'h2ff });
			assert(o_mdio == PHYADDR[1]);
			assert(reg_pos == 6'h07);
		end
		if(f_write_steps[10])
		begin
			assert(write_reg == { f_addr, 11'h5ff });
			assert(o_mdio == PHYADDR[0]);
			assert(reg_pos == 6'h06);
		end
		if(f_write_steps[11])
		begin
			assert(write_reg == { f_addr[3:0], 12'hbff });
			assert(o_mdio == f_addr[4]);
			assert(reg_pos == 6'h05);
		end
		if(f_write_steps[12])
		begin
			assert(write_reg == { f_addr[2:0], 13'h17ff });
			assert(o_mdio == f_addr[3]);
			assert(reg_pos == 6'h04);
		end
		if(f_write_steps[13])
		begin
			assert(write_reg == { f_addr[1:0], 14'h2fff });
			assert(o_mdio == f_addr[2]);
			assert(reg_pos == 6'h03);
		end
		if(f_write_steps[14])
		begin
			assert(write_reg == { f_addr[0],   15'h5fff });
			assert(o_mdio == f_addr[1]);
			assert(reg_pos == 6'h02);
		end
		if(f_write_steps[15])
		begin
			assert(write_reg == { 16'hbfff });
			assert(o_mdio == f_addr[0]);
			assert(reg_pos == 6'h01);
		end
		if(f_write_steps[16])
		begin
			assert(write_reg == { 16'h7fff });
			assert(o_mdio == 1'b1);
			assert(reg_pos == 6'h00);
		end
		if(f_write_steps[17])
		begin
			assert(write_reg == f_data);
			assert(o_mdio == 1'b0);
			assert(reg_pos == 6'h10);
		end
		if(f_write_steps[18])
		begin
			assert(write_reg[15:1] == f_data[14:0]);
			assert(o_mdio == f_data[15]);
			assert(reg_pos == 6'h0f);
		end
		if(f_write_steps[19])
		begin
			assert(write_reg[15:2] == f_data[13:0]);
			assert(o_mdio == f_data[14]);
			assert(reg_pos == 6'h0e);
		end
		if(f_write_steps[20])
		begin
			assert(write_reg[15:3] == f_data[12:0]);
			assert(o_mdio == f_data[13]);
			assert(reg_pos == 6'h0d);
		end
		if(f_write_steps[21])
		begin
			assert(write_reg[15:4] == f_data[11:0]);
			assert(o_mdio == f_data[12]);
			assert(reg_pos == 6'h0c);
		end
		if(f_write_steps[22])
		begin
			assert(write_reg[15:5] == f_data[10:0]);
			assert(o_mdio == f_data[11]);
			assert(reg_pos == 6'h0b);
		end
		if(f_write_steps[23])
		begin
			assert(write_reg[15:6] == f_data[9:0]);
			assert(o_mdio == f_data[10]);
			assert(reg_pos == 6'h0a);
		end
		if(f_write_steps[24])
		begin
			assert(write_reg[15:7] == f_data[8:0]);
			assert(o_mdio == f_data[9]);
			assert(reg_pos == 6'h09);
		end
		if(f_write_steps[25])
		begin
			assert(write_reg[15:8] == f_data[7:0]);
			assert(o_mdio == f_data[8]);
			assert(reg_pos == 6'h08);
		end
		if(f_write_steps[26])
		begin
			assert(write_reg[15:9] == f_data[6:0]);
			assert(o_mdio == f_data[7]);
			assert(reg_pos == 6'h07);
		end
		if(f_write_steps[27])
		begin
			assert(write_reg[15:10] == f_data[5:0]);
			assert(o_mdio == f_data[6]);
			assert(reg_pos == 6'h06);
		end
		if(f_write_steps[28])
		begin
			assert(write_reg[15:11] == f_data[4:0]);
			assert(o_mdio == f_data[5]);
			assert(reg_pos == 6'h05);
		end
		if(f_write_steps[29])
		begin
			assert(write_reg[15:12] == f_data[3:0]);
			assert(o_mdio == f_data[4]);
			assert(reg_pos == 6'h04);
		end
		if(f_write_steps[30])
		begin
			assert(write_reg[15:13] == f_data[2:0]);
			assert(o_mdio == f_data[3]);
			assert(reg_pos == 6'h03);
		end
		if(f_write_steps[31])
		begin
			assert(write_reg[15:14] == f_data[1:0]);
			assert(o_mdio == f_data[2]);
			assert(reg_pos == 6'h02);
		end
		if(f_write_steps[32])
		begin
			assert(write_reg[15] == f_data[0]);
			assert(o_mdio == f_data[1]);
			assert(reg_pos == 6'h01);
		end
		if(f_write_steps[33])
		begin
			assert(o_mdio == f_data[0]);
			assert(reg_pos == 6'h00);
		end
		if (|f_write_steps[16:1])
			assert((ctrl_state == ECTRL_ADDRESS)&&(write_pending));
		if (|f_write_steps[32:17])
			assert(ctrl_state == ECTRL_WRITE);
		if (|f_write_steps[32:18])
			assert(!write_pending);
		if (|f_write_steps)
			assert(o_mdwe);

		if (|f_write_steps)
			assert(o_wb_stall);
		if (|f_write_steps)
			assert(!o_wb_ack);
	end

	always @(*)
	if (|f_write_steps[33:17])
		assert(ctrl_state == ECTRL_WRITE);
	else
		assert(ctrl_state != ECTRL_WRITE);

	reg	f_write_steps_onehot;
	always @(*)
	if (f_write_steps != 0)
	begin
		assert(f_read_steps == 0);
		assert(read_pending == 0);
		assert(ctrl_state != ECTRL_RESET);
		assert(ctrl_state != ECTRL_READ);

		f_write_steps_onehot = 1'b0;
		case(f_write_steps)
		34'h0000_0001: f_write_steps_onehot = 1'b1;
		34'h0000_0002: f_write_steps_onehot = 1'b1;
		34'h0000_0004: f_write_steps_onehot = 1'b1;
		34'h0000_0008: f_write_steps_onehot = 1'b1;
		34'h0000_0010: f_write_steps_onehot = 1'b1;
		34'h0000_0020: f_write_steps_onehot = 1'b1;
		34'h0000_0040: f_write_steps_onehot = 1'b1;
		34'h0000_0080: f_write_steps_onehot = 1'b1;
		34'h0000_0100: f_write_steps_onehot = 1'b1;
		34'h0000_0200: f_write_steps_onehot = 1'b1;
		34'h0000_0400: f_write_steps_onehot = 1'b1;
		34'h0000_0800: f_write_steps_onehot = 1'b1;
		34'h0000_1000: f_write_steps_onehot = 1'b1;
		34'h0000_2000: f_write_steps_onehot = 1'b1;
		34'h0000_4000: f_write_steps_onehot = 1'b1;
		34'h0000_8000: f_write_steps_onehot = 1'b1;
		34'h0001_0000: f_write_steps_onehot = 1'b1;
		34'h0002_0000: f_write_steps_onehot = 1'b1;
		34'h0004_0000: f_write_steps_onehot = 1'b1;
		34'h0008_0000: f_write_steps_onehot = 1'b1;
		34'h0010_0000: f_write_steps_onehot = 1'b1;
		34'h0020_0000: f_write_steps_onehot = 1'b1;
		34'h0040_0000: f_write_steps_onehot = 1'b1;
		34'h0080_0000: f_write_steps_onehot = 1'b1;
		34'h0100_0000: f_write_steps_onehot = 1'b1;
		34'h0200_0000: f_write_steps_onehot = 1'b1;
		34'h0400_0000: f_write_steps_onehot = 1'b1;
		34'h0800_0000: f_write_steps_onehot = 1'b1;
		34'h1000_0000: f_write_steps_onehot = 1'b1;
		34'h2000_0000: f_write_steps_onehot = 1'b1;
		34'h4000_0000: f_write_steps_onehot = 1'b1;
		34'h8000_0000: f_write_steps_onehot = 1'b1;
		34'h10000_0000: f_write_steps_onehot = 1'b1;
		34'h20000_0000: f_write_steps_onehot = 1'b1;
		default: begin end
		endcase

		assert(f_write_steps_onehot);
	end

	always @(*)
	if ((f_write_steps == 0)&&(f_read_steps == 0))
		`ASSERT((ctrl_state == ECTRL_RESET)
			||(ctrl_state == ECTRL_IDLE));
`endif // VERIFIC
`endif
endmodule
