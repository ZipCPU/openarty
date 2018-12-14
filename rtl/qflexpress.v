////////////////////////////////////////////////////////////////////////////////
//
// Filename:	qflexpress.v
//
// Project:	Wishbone Controlled Quad SPI Flash Controller
//
// Purpose:	To provide wishbone controlled read access (and read access
//		*only*) to the QSPI flash, using a flash clock equal to the
//	system clock, and nothing more.  Indeed, this is designed to be a
//	*very* stripped down version of a flash driver, with the goal of
//	providing 1) very fast access for 2) very low logic count.
//
//	Three modes/states of operation:
//	1. Startup/maintenance, places the device in the Quad XIP mode
//	2. Normal operations, takes 33 clocks to read a value
//	   - 16 subsequent clocks will read a piped value
//	3. Configuration--useful to allow an external controller issue erase
//		or program commands (or other) without requiring us to
//		clutter up the logic with a giant state machine
//
//	STARTUP
//	 1. Waits for the flash to come on line
//		Start out idle for 300 uS
//	 2. Sends a signal to remove the flash from any DSPI read mode.  In our
//		case, we'll send several clocks of an empty command.  In SPI
//		mode, it'll get ignored.  In QSPI mode, it'll remove us from
//		DSPI mode.
//	 3. Explicitly places and leaves the flash into DSPI mode
//		0xEB 3(0xa0) 0xa0 0xa0 0xa0 4(0x00)
//	 4. All done
//
//	NORMAL-OPS
//	ODATA <- ?, 3xADDR, 0xa0, 0x00, 0x00 | 0x00, 0x00, 0x00, 0x00 ? (22nibs)
//	STALL <- TRUE until closed at the end
//	MODE  <- 2'b10 for 4 clks, then 2'b11
//	CLK   <- 2'b10 before starting, then 2'b01 until the end
//	CSN   <- 0 any time CLK != 2'b11
//
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2018, Gisselquist Technology, LLC
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
// 290 raw, 372 w/ pipe, 410 cfg, 499 cfg w/pipe
module	qflexpress(i_clk, i_reset,
		i_wb_cyc, i_wb_stb, i_cfg_stb, i_wb_we, i_wb_addr, i_wb_data,
			o_wb_ack, o_wb_stall, o_wb_data,
		o_qspi_sck, o_qspi_cs_n, o_qspi_mod, o_qspi_dat, i_qspi_dat,
		o_dbg_trigger, o_debug);
	//
	// LGFLASHSZ is the size of the flash memory.  It defines the number
	// of bits in the address register and more.  This controller will only
	// support flashes with 24-bit or less addresses--it doesn't support
	// the 32-bit address flash chips.
	parameter	LGFLASHSZ=24;
	//
	// OPT_STARTUP enables the configuration logic port, and hence the
	// ability to erase and program the flash, as well as the ability
	// to perform other commands such as read-manufacturer ID, adjust
	// configuration registers, etc.
	parameter [0:0]	OPT_PIPE    = 1'b1;
	//
	// OPT_STARTUP enables the configuration logic port, and hence the
	// ability to erase and program the flash, as well as the ability
	// to perform other commands such as read-manufacturer ID, adjust
	// configuration registers, etc.
	parameter [0:0]	OPT_CFG     = 1'b1;
	//
	// OPT_STARTUP enables the startup logic
	parameter [0:0]	OPT_STARTUP = 1'b0;
	//
	// CKDELAY is the number of clock delays from when o_qspi_sck is set
	// until the actual clock takes place.  Values of 0 and 1 have been
	// verified.  CKDELAY = 2 isn't fully supported.
	parameter	CKDELAY = 0;
	//
	// RDDELAY is the number of clock cycles from when o_qspi_dat is valid
	// until i_qspi_dat is valid.  Read delays from 0-4 have been verified
	parameter	RDDELAY = 3;
	//
	// NDUMMY is the number of "dummy" clock cycles between the 24-bits of
	// the Quad I/O address and the first data bits.  This includes the
	// two clocks of the Quad output mode byte, 0xa0
	// 
	parameter	NDUMMY = 10;
	//
	//
	//
	//
	//
	localparam [4:0]	CFG_MODE =	12;
	localparam [4:0]	QSPEED_BIT = 	11;
	localparam [4:0]	DSPEED_BIT = 	10; // Not supported
	localparam [4:0]	DIR_BIT	= 	 9;
	localparam [4:0]	USER_CS_n = 	 8;
	//
	localparam [1:0]	NORMAL_SPI = 	2'b00;
	localparam [1:0]	QUAD_WRITE = 	2'b10;
	localparam [1:0]	QUAD_READ = 	2'b11;
	// localparam [7:0] DIO_READ_CMD = 8'hbb;
	localparam [7:0] QIO_READ_CMD = 8'heb;
	//
	localparam	AW=LGFLASHSZ-2;
	localparam	DW=32;
	//
`ifdef	FORMAL
	localparam	F_LGDEPTH=$clog2(3+RDDELAY);
`endif
	//
	//
	input	wire			i_clk, i_reset;
	//
	input	wire			i_wb_cyc, i_wb_stb, i_cfg_stb, i_wb_we;
	input	wire	[(AW-1):0]	i_wb_addr;
	input	wire	[(DW-1):0]	i_wb_data;
	//
	output	reg			o_wb_ack, o_wb_stall;
	output	reg	[(DW-1):0]	o_wb_data;
	//
	output	reg		o_qspi_sck;
	output	reg		o_qspi_cs_n;
	output	reg	[1:0]	o_qspi_mod;
	output	wire	[3:0]	o_qspi_dat;
	input	wire	[3:0]	i_qspi_dat;
	//
	// Debugging port
	output	wire		o_dbg_trigger;
	output	wire	[31:0]	o_debug;

	reg		dly_ack, read_sck, xtra_stall;
	// clk_ctr must have enough bits for ...
	//	CKDELAY clocks before the clock starts on the interface
	//	6		address clocks, 4-bits each
	//	NDUMMY		dummy clocks, including two mode bytes
	//	8		data clocks
	//	(RDDELAY clocks not counted here)
	reg	[4:0]	clk_ctr;

	//
	// User override logic
	//
	reg	cfg_mode, cfg_speed, cfg_dir, cfg_cs;
	wire	cfg_write, cfg_hs_write, cfg_ls_write, cfg_hs_read,
		user_request, bus_request, pipe_req, cfg_noop, cfg_stb;
	//
	assign	bus_request  = (i_wb_stb)&&(!o_wb_stall)
					&&(!i_wb_we)&&(!cfg_mode);
	assign	cfg_stb      = (OPT_CFG)&&(i_cfg_stb)&&(!o_wb_stall);
	assign	cfg_noop     = (cfg_stb)&&((!i_wb_we)||(!i_wb_data[CFG_MODE])
					||(i_wb_data[USER_CS_n]));
	assign	user_request = (cfg_stb)&&(i_wb_we)&&(i_wb_data[CFG_MODE]);

	assign	cfg_write    = (user_request)&&(!i_wb_data[USER_CS_n]);
	assign	cfg_hs_write = (cfg_write)&&(i_wb_data[QSPEED_BIT])
					&&(i_wb_data[DIR_BIT]);
	assign	cfg_hs_read  = (cfg_write)&&(i_wb_data[QSPEED_BIT])
					&&(!i_wb_data[DIR_BIT]);
	assign	cfg_ls_write = (cfg_write)&&(!i_wb_data[QSPEED_BIT]);


	//
	//
	// Maintenance / startup portion
	//
	//
	reg		maintenance;
	reg	[1:0]	m_mod;
	reg		m_cs_n;
	reg		m_clk;
	reg	[3:0]	m_dat;

	generate if (OPT_STARTUP)
	begin : GEN_STARTUP

		reg	[6:0]	m_this_word;
		reg	[6:0]	m_cmd_word	[0:127];
		reg	[6:0]	m_cmd_index;

		reg	[5:0]	m_counter;
		reg		m_midcount;

		// Let's script our startup with a series of commands.
		// These commands are specific to the Micron Serial NOR flash
		// memory that was on the original Arty A7 board.  Switching
		// from one memory to another should only require adjustments
		// to this startup sequence, and to the flashdrvr.cpp module
		// found in sw/host.
		//
		// The format of the data words is ...
		//	1'bit (MSB) to indicate this is a counter word.
		//		Counter words count a number of idle cycles,
		//		in which the port is unused (CSN is high)
		//
		//	2'bit mode.  This is either ...
		//	    NORMAL_SPI, for a normal SPI interaction:
		//			MOSI, MISO, WPn and HOLD
		//	    QUAD_READ, all four pins set as inputs.  In this
		//			startup, the input values will be
		//			ignored.
		//	or  QUAD_WRITE, all four pins are outputs.  This is
		//			important for getting the flash into
		//			an XIP mode that we can then use for
		//			all reads following.
		//
		//
		integer k;
		initial begin
		for(k=0; k<128; k=k+1)
			m_cmd_word[k] = 7'h1ff;
		// cmd_word= m_ctr_flag, m_mod[1:0],
		//			m_cs_n, m_clk, m_data[3:0]
		// Start off idle
		//	This is really redundant since all of our commands are
		//	idle's.
		m_cmd_word[7'h35] = { 1'b1, 6'h3f };
		m_cmd_word[7'h36] = { 1'b1, 6'h3f };
		//
		// Since we don't know what mode we started in, whether the
		// device was left in XIP mode or some other mode, we'll start
		// by exiting any mode we might have been in.
		//
		// The key to doing this is to issue a non-command, that can
		// also be interpreted as an XIP address with an incorrect
		// mode bit.  That will get us out of any XIP mode, and back
		// into a SPI mode we might use.  The command is issued in
		// NORMAL_SPI mode, however, since we don't know if the device
		// is initially in XIP or not.
		//
		// Exit any QSPI mode we might've been in
		m_cmd_word[7'h37] = { 1'b0, NORMAL_SPI, 4'hf }; // Addr 1
		m_cmd_word[7'h38] = { 1'b0, NORMAL_SPI, 4'hf }; // Addr 2
		m_cmd_word[7'h39] = { 1'b0, NORMAL_SPI, 4'hf }; // Addr 3
		m_cmd_word[7'h3a] = { 1'b0, NORMAL_SPI, 4'hf }; // Mode byte
		m_cmd_word[7'h3b] = { 1'b0, NORMAL_SPI, 4'hf };
		m_cmd_word[7'h3c] = { 1'b0, NORMAL_SPI, 4'hf };
		m_cmd_word[7'h3d] = { 1'b0, NORMAL_SPI, 4'hf };
		m_cmd_word[7'h3e] = { 1'b0, NORMAL_SPI, 4'hf };
		m_cmd_word[7'h3f] = { 1'b0, NORMAL_SPI, 4'hf };
		m_cmd_word[7'h40] = { 1'b0, NORMAL_SPI, 4'hf };
		m_cmd_word[7'h41] = { 1'b0, NORMAL_SPI, 4'hf };
		m_cmd_word[7'h42] = { 1'b0, NORMAL_SPI, 4'hf };
		m_cmd_word[7'h43] = { 1'b0, NORMAL_SPI, 4'hf };
		m_cmd_word[7'h44] = { 1'b0, NORMAL_SPI, 4'hf };
		m_cmd_word[7'h45] = { 1'b0, NORMAL_SPI, 4'hf };
		m_cmd_word[7'h46] = { 1'b0, NORMAL_SPI, 4'hf };
		// Idle
		m_cmd_word[7'h47] = { 1'b1, 6'h3f };
		// Write enhanced configuration register
		// The write enable must come first: 06
		m_cmd_word[7'h48] = { 1'b0, NORMAL_SPI, 4'h0 };
		m_cmd_word[7'h49] = { 1'b0, NORMAL_SPI, 4'h0 };
		m_cmd_word[7'h4a] = { 1'b0, NORMAL_SPI, 4'h0 };
		m_cmd_word[7'h4b] = { 1'b0, NORMAL_SPI, 4'h0 };
		m_cmd_word[7'h4c] = { 1'b0, NORMAL_SPI, 4'h0 };
		m_cmd_word[7'h4d] = { 1'b0, NORMAL_SPI, 4'h1 };
		m_cmd_word[7'h4e] = { 1'b0, NORMAL_SPI, 4'h1 };
		m_cmd_word[7'h4f] = { 1'b0, NORMAL_SPI, 4'h0 };
		// Idle
		m_cmd_word[7'h50] = { 1'b1, 6'h3f };
		// Write enhanced configuration register, 0x81, 0xfb
		m_cmd_word[7'h51] = { 1'b0, NORMAL_SPI, 4'h1 };	// 0x81
		m_cmd_word[7'h52] = { 1'b0, NORMAL_SPI, 4'h0 };
		m_cmd_word[7'h53] = { 1'b0, NORMAL_SPI, 4'h0 };
		m_cmd_word[7'h54] = { 1'b0, NORMAL_SPI, 4'h0 };
		m_cmd_word[7'h55] = { 1'b0, NORMAL_SPI, 4'h0 };
		m_cmd_word[7'h56] = { 1'b0, NORMAL_SPI, 4'h0 };
		m_cmd_word[7'h57] = { 1'b0, NORMAL_SPI, 4'h0 };
		m_cmd_word[7'h58] = { 1'b0, NORMAL_SPI, 4'h1 };
		//
		m_cmd_word[7'h59] = { 1'b0, NORMAL_SPI, 4'h1 };
		m_cmd_word[7'h5a] = { 1'b0, NORMAL_SPI, 4'h1 };
		m_cmd_word[7'h5b] = { 1'b0, NORMAL_SPI, 4'h1 };
		m_cmd_word[7'h5c] = { 1'b0, NORMAL_SPI, 4'h1 };
		m_cmd_word[7'h5d] = { 1'b0, NORMAL_SPI, 4'h0 };
		m_cmd_word[7'h5e] = { 1'b0, NORMAL_SPI, 4'h0 };
		m_cmd_word[7'h5f] = { 1'b0, NORMAL_SPI, 4'h1 };
		m_cmd_word[7'h60] = { 1'b0, NORMAL_SPI, 4'h1 };
		// Idle
		m_cmd_word[7'h61] = { 1'b1, 6'h3f };
		// Enter into QSPI mode, 0xeb, 0,0,0
		// 0xeb
		m_cmd_word[7'h62] = { 1'b0, NORMAL_SPI, 4'h1 };
		m_cmd_word[7'h63] = { 1'b0, NORMAL_SPI, 4'h1 };
		m_cmd_word[7'h64] = { 1'b0, NORMAL_SPI, 4'h1 };
		m_cmd_word[7'h65] = { 1'b0, NORMAL_SPI, 4'h0 };
		m_cmd_word[7'h66] = { 1'b0, NORMAL_SPI, 4'h1 };
		m_cmd_word[7'h67] = { 1'b0, NORMAL_SPI, 4'h0 };
		m_cmd_word[7'h68] = { 1'b0, NORMAL_SPI, 4'h1 };
		m_cmd_word[7'h69] = { 1'b0, NORMAL_SPI, 4'h1 };
		// Addr #1
		m_cmd_word[7'h6a] = { 1'b0, QUAD_WRITE, 4'h0 };
		m_cmd_word[7'h6b] = { 1'b0, QUAD_WRITE, 4'h0 };
		// Addr #2
		m_cmd_word[7'h6c] = { 1'b0, QUAD_WRITE, 4'h0 };
		m_cmd_word[7'h6d] = { 1'b0, QUAD_WRITE, 4'h0 };
		// Addr #3
		m_cmd_word[7'h6e] = { 1'b0, QUAD_WRITE, 4'h0 };
		m_cmd_word[7'h6f] = { 1'b0, QUAD_WRITE, 4'h0 };
		// Mode byte
		m_cmd_word[7'h70] = { 1'b0, QUAD_WRITE, 4'ha };
		m_cmd_word[7'h71] = { 1'b0, QUAD_WRITE, 4'h0 };
		// Dummy clocks, x10 for this flash
		m_cmd_word[7'h72] = { 1'b0, QUAD_WRITE, 4'h0 };
		m_cmd_word[7'h73] = { 1'b0, QUAD_WRITE, 4'h0 };
		m_cmd_word[7'h74] = { 1'b0, QUAD_WRITE, 4'h0 };
		m_cmd_word[7'h75] = { 1'b0, QUAD_WRITE, 4'h0 };
		m_cmd_word[7'h76] = { 1'b0, QUAD_WRITE, 4'h0 };
		m_cmd_word[7'h77] = { 1'b0, QUAD_WRITE, 4'h0 };
		m_cmd_word[7'h78] = { 1'b0, QUAD_WRITE, 4'h0 };
		m_cmd_word[7'h79] = { 1'b0, QUAD_WRITE, 4'h0 };
		m_cmd_word[7'h7a] = { 1'b0, QUAD_WRITE, 4'h0 };
		m_cmd_word[7'h7b] = { 1'b0, QUAD_WRITE, 4'h0 };
		// Now read a byte for form
		m_cmd_word[7'h7c] = { 1'b0, QUAD_READ, 4'h0 };
		m_cmd_word[7'h7d] = { 1'b0, QUAD_READ, 4'h0 };
		// Idle
		m_cmd_word[7'h7e] = { 1'b1, 6'h3f };
		m_cmd_word[7'h7f] = { 1'b1, 6'h3f };
		// Then we are in business!
		end


		//
		initial	maintenance = 1'b1;

		always @(posedge i_clk)
		if (i_reset)
		begin
			m_cmd_index <= 0;
			maintenance <= 1'b1;
		end else if (!m_midcount)
		begin
			maintenance <= (maintenance)&& !(&m_cmd_index);
			m_cmd_index <= m_cmd_index + 1'b1;
		end

		always @(posedge i_clk)
		if (!m_midcount)
			m_this_word <= m_cmd_word[m_cmd_index];

		initial	m_midcount = 1;
		initial	m_counter   = -1;
		always @(posedge i_clk)
		if (i_reset)
		begin
			m_midcount <= 1'b1;
			m_counter <= -1;
		end else if (!m_midcount)
		begin
			m_midcount <= m_this_word[6];
			if (m_this_word[6])
				m_counter <= m_this_word[5:0];
		end else begin
			m_midcount <= (m_counter > 0);
			if (m_counter > 0)
				m_counter <= m_counter - 1'b1;
		end

		initial	m_cs_n      = 1'b1;
		initial	m_mod       = NORMAL_SPI;
		always @(posedge i_clk)
		if (i_reset)
		begin
			m_cs_n <= 1'b1;
			m_mod  <= NORMAL_SPI;
			m_dat  <= 4'h0;
		end else if ((m_midcount)||(m_this_word[6]))
		begin
			m_cs_n <= 1'b1;
			m_mod  <= NORMAL_SPI;
			m_dat  <= 4'h0;
		end else begin
			m_cs_n <= 1'b0;
			m_mod  <= m_this_word[5:4];
			m_dat  <= m_this_word[3:0];
		end

		always @(*)
			m_clk = !m_cs_n;
	end else begin : NO_STARTUP_OPT

		always @(*)
		begin
			maintenance = 0;
			m_mod       = 2'b00;
			m_cs_n      = 1'b1;
			m_clk       = 1'b0;
			m_dat       = 4'h0;
		end

		// verilator lint_off UNUSED
		wire	[8:0] unused_maintenance;
		assign	unused_maintenance = { maintenance,
					m_mod, m_cs_n, m_clk, m_dat };
		// verilator lint_on  UNUSED
	end endgenerate


	//
	//
	// Data / access portion
	//
	//
	reg	[(32+4*CKDELAY)-1:0]	data_pipe;
	initial	data_pipe = 0;
	always @(posedge i_clk)
	begin
		if (!o_wb_stall)
		begin
			// Set the high bits to zero initially
			data_pipe[(32+4*CKDELAY)-1:0] <= 0;

			data_pipe[31:0] <= { {(24-LGFLASHSZ){1'b0}},
					i_wb_addr, 2'b00, 4'ha, 4'h0 };

			if (cfg_write)
				data_pipe[31:24] <= i_wb_data[7:0];

			if ((cfg_write)&&(!i_wb_data[QSPEED_BIT]))
			begin
				data_pipe[28] <= i_wb_data[7];
				data_pipe[24] <= i_wb_data[6];
				data_pipe[20] <= i_wb_data[5];
				data_pipe[16] <= i_wb_data[4];
				data_pipe[12] <= i_wb_data[3];
				data_pipe[ 8] <= i_wb_data[2];
				data_pipe[ 4] <= i_wb_data[1];
				data_pipe[ 0] <= i_wb_data[0];
			end
		end else // if (o_wb_stall)
			data_pipe <= { data_pipe[(32+4*(CKDELAY-1))-1:0], 4'h0 };

		if (maintenance)
			data_pipe[(32+4*CKDELAY-1):(28+4*CKDELAY)] <= m_dat;
	end

	assign	o_qspi_dat = data_pipe[(32+4*CKDELAY-1):(28+4*CKDELAY)];

	// Since we can't abort any transaction once started, without
	// risking losing XIP mode or any other mode we might be in, we'll
	// keep track of whether this operation should be ack'd upon
	// completion
	reg	pre_ack = 1'b0;
	always @(posedge i_clk)
	if ((i_reset)||(!i_wb_cyc))
		pre_ack <= 1'b0;
	else if ((bus_request)||(cfg_write))
		pre_ack <= 1'b1;

	generate
	if (OPT_PIPE)
	begin : OPT_PIPE_BLOCK
		reg	r_pipe_req;
		wire	w_pipe_condition;

		reg	[(AW-1):0]	next_addr;
		always  @(posedge i_clk)
		if (!o_wb_stall)
			next_addr <= i_wb_addr + 1'b1;

		assign	w_pipe_condition = (i_wb_stb)&&(pre_ack)
				&&(!maintenance)
				&&(!cfg_mode)
				&&(!o_qspi_cs_n)
				&&(|clk_ctr[2:1])
				&&(next_addr == i_wb_addr);

		initial	r_pipe_req = 1'b0;
		always @(posedge i_clk)
			r_pipe_req <= w_pipe_condition;

		assign	pipe_req = r_pipe_req;
	end else begin
		assign	pipe_req = 1'b0;
	end endgenerate


	initial	clk_ctr = 0;
	always @(posedge i_clk)
	if ((i_reset)||(maintenance))
		clk_ctr <= 0;
	else if ((bus_request)&&(!pipe_req))
		clk_ctr <= 5'd14 + CKDELAY + NDUMMY;
	else if (bus_request) // && pipe_req
		clk_ctr <= 5'd8;
	else if (cfg_ls_write)
		clk_ctr <= 5'd8 + CKDELAY;
	else if (cfg_write)
		clk_ctr <= 5'd2 + CKDELAY;
	else if (|clk_ctr)
		clk_ctr <= clk_ctr - 1'b1;

	initial	o_qspi_sck = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_qspi_sck <= 1'b0;
	else if (maintenance)
		o_qspi_sck <= m_clk;
	else if ((bus_request)||(cfg_write))
		o_qspi_sck <= 1'b1;
	else if ((cfg_mode)&&(clk_ctr <= CKDELAY+1))
		// Config mode has no pipe instructions
		o_qspi_sck <= 1'b0;
	else if (clk_ctr[4:0] > 5'd1 + CKDELAY)
		o_qspi_sck <= 1'b1;
	else if ((clk_ctr[4:0] == 5'd2)&&(pipe_req))
		o_qspi_sck <= 1'b1;
	else
		o_qspi_sck <= 1'b0;

	initial	o_qspi_cs_n = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		o_qspi_cs_n <= 1'b1;
	else if (maintenance)
		o_qspi_cs_n <= m_cs_n;
	else if ((cfg_stb)&&(i_wb_we))
		o_qspi_cs_n <= (!i_wb_data[CFG_MODE])||(i_wb_data[USER_CS_n]);
	else if ((OPT_CFG)&&(cfg_cs))
		o_qspi_cs_n <= 1'b0;
	else if ((bus_request)||(cfg_write))
		o_qspi_cs_n <= 1'b0;
	else
		o_qspi_cs_n <= (clk_ctr <= 1);

	// Control the mode of the external pins
	// 	NORMAL_SPI: i_miso is an input,  o_mosi is an output
	// 	QUAD_READ:  i_miso is an input,  o_mosi is an input
	// 	QUAD_WRITE: i_miso is an output, o_mosi is an output
	initial	o_qspi_mod =  NORMAL_SPI;
	always @(posedge i_clk)
	if (i_reset)
		o_qspi_mod <= NORMAL_SPI;
	else if (maintenance)
		o_qspi_mod <= m_mod;
	else if ((bus_request)&&(!pipe_req))
		o_qspi_mod <= QUAD_WRITE;
	else if ((bus_request)||(cfg_hs_read))
		o_qspi_mod <= QUAD_READ;
	else if (cfg_hs_write)
		o_qspi_mod <= QUAD_WRITE;
	else if ((cfg_ls_write)||((cfg_mode)&&(!cfg_speed)))
		o_qspi_mod <= NORMAL_SPI;
	else if ((clk_ctr <= 5'd9)&&((!cfg_mode)||(!cfg_dir)))
		o_qspi_mod <= QUAD_READ;

	initial	o_wb_stall = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		o_wb_stall <= 1'b1;
	else if (maintenance)
		o_wb_stall <= 1'b1;
	else if ((RDDELAY > 0)&&((i_cfg_stb)||(i_wb_stb))&&(!o_wb_stall))
		o_wb_stall <= 1'b1;
	else if ((RDDELAY == 0)&&((cfg_write)||(bus_request)))
		o_wb_stall <= 1'b1;
	else if ((i_wb_stb)&&(pipe_req)&&(clk_ctr == 5'd2))
		o_wb_stall <= 1'b0;
	else if ((clk_ctr > 1)||(xtra_stall))
		o_wb_stall <= 1'b1;
	else
		o_wb_stall <= 1'b0;

	initial	dly_ack = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		dly_ack <= 1'b0;
	else if (clk_ctr == 1)
		dly_ack <= (i_wb_cyc)&&(pre_ack);
	else if ((i_wb_stb)&&(!o_wb_stall)&&(!bus_request))
		dly_ack <= 1'b1;
	else if (cfg_noop)
		dly_ack <= 1'b1;
	else
		dly_ack <= 1'b0;

	reg	actual_sck;
	generate if (CKDELAY == 0)
	begin

		always @(*)
			actual_sck = o_qspi_sck;

	end else if (CKDELAY == 1)
	begin

		initial	actual_sck = 1'b0;
		always @(posedge i_clk)
		if ((i_reset)&&(o_qspi_cs_n))
			actual_sck <= 1'b0;
		else
			actual_sck <= o_qspi_sck;

	end else begin

		reg	[CKDELAY-2:0] sck_delay;

		initial	actual_sck = 1'b0;
		always @(posedge i_clk)
		if ((i_reset)&&(o_qspi_cs_n))
			{ actual_sck, sck_delay } <= 0;
		else
			{ actual_sck, sck_delay } <= { sck_delay, o_qspi_sck };

	end endgenerate

	generate if (RDDELAY == 0)
	begin

		always @(*)
		begin
			read_sck = actual_sck;
			o_wb_ack = dly_ack;
			xtra_stall = 1'b0;
		end

	end else if (RDDELAY == 1)
	begin

		initial	read_sck   = 1'b0;
		initial	o_wb_ack   = 1'b0;
		always @(posedge i_clk)
		begin
			read_sck <= actual_sck;
			o_wb_ack <= (!i_reset)&&(i_wb_cyc)&&(dly_ack);
			xtra_stall <= (clk_ctr > 1);
		end

	end else begin
		// RDDELAY > 2 not (yet) supported
		reg	[RDDELAY-2:0] ack_pipe, read_sck_pipe;

		initial	{ o_wb_ack, ack_pipe } = 0;
		always @(posedge i_clk)
		if ((i_reset)||(!i_wb_cyc))
			{ o_wb_ack, ack_pipe } <= 0;
		else
			{ o_wb_ack, ack_pipe } <= { ack_pipe, dly_ack };

		initial	{ read_sck, read_sck_pipe } = 0;
		always @(posedge i_clk)
			{ read_sck, read_sck_pipe } <= { read_sck_pipe, actual_sck };

		wire	xtra_pipe_stall;
		if (RDDELAY > 3)
			assign xtra_pipe_stall = (|ack_pipe[RDDELAY-4:0]);
		else
			assign xtra_pipe_stall = 1'b0;

		always @(posedge i_clk)
		if ((i_reset)||(!i_wb_cyc))
			xtra_stall <= 1'b0;
		else begin
			xtra_stall <= dly_ack;
			if ((i_wb_stb||i_cfg_stb)&&(!o_wb_stall))
				xtra_stall <= 1'b1;;
			if (clk_ctr > 0)
				xtra_stall <= 1'b1;
			if (xtra_pipe_stall)
				xtra_stall <= 1'b1;
		end


	end endgenerate

	always @(posedge i_clk)
	begin
		if (read_sck)
		begin
			if (!o_qspi_mod[1])
				o_wb_data <= { o_wb_data[30:0], i_qspi_dat[1] };
			else
				o_wb_data <= { o_wb_data[27:0], i_qspi_dat };
		end

		if ((OPT_CFG)&&((cfg_mode)||((i_cfg_stb)&&(!o_wb_stall))))
			o_wb_data[16:8] <= { 4'b0, cfg_mode, cfg_speed, 1'b0,
				cfg_dir, cfg_cs };
	end


	//
	//
	//  User override access
	//
	//
	initial	cfg_mode = 1'b0;
	always @(posedge i_clk)
	if ((i_reset)||(!OPT_CFG))
		cfg_mode <= 1'b0;
	else if ((i_cfg_stb)&&(!o_wb_stall)&&(i_wb_we))
		cfg_mode <= i_wb_data[CFG_MODE];

	initial	cfg_cs = 1'b0;
	always @(posedge i_clk)
	if ((i_reset)||(!OPT_CFG))
		cfg_cs <= 1'b0;
	else if ((i_cfg_stb)&&(!o_wb_stall)&&(i_wb_we))
		cfg_cs    <= (!i_wb_data[USER_CS_n])&&(i_wb_data[CFG_MODE]);

	initial	cfg_speed = 1'b0;
	initial	cfg_dir   = 1'b0;
	always @(posedge i_clk)
	if (!OPT_CFG)
	begin
		cfg_speed <= 1'b0;
		cfg_dir   <= 1'b0;
	end else if ((i_cfg_stb)&&(!o_wb_stall)&&(i_wb_we))
	begin
		cfg_speed <= i_wb_data[QSPEED_BIT];
		cfg_dir   <= i_wb_data[DIR_BIT];
	end

	reg	r_last_cfg;
	initial	r_last_cfg = 1'b0;
	always @(posedge i_clk)
		r_last_cfg <= cfg_mode;
	assign	o_dbg_trigger = (!cfg_mode)&&(r_last_cfg);
	assign	o_debug = { o_dbg_trigger,
			i_wb_cyc, i_cfg_stb, i_wb_stb, o_wb_ack, o_wb_stall,//6
			o_qspi_cs_n, o_qspi_sck, o_qspi_dat, o_qspi_mod,// 8
			i_qspi_dat, cfg_mode, cfg_cs, cfg_speed, cfg_dir,// 8
			actual_sck, i_wb_we,
			(((i_wb_stb)||(i_cfg_stb))
				&&(i_wb_we)&&(!o_wb_stall)&&(!o_wb_ack))
				? i_wb_data[7:0] : o_wb_data[7:0]
			};

	// verilator lint_off UNUSED
	wire	[19:0]	unused;
	assign	unused = { i_wb_data[31:12] };
	// verilator lint_on  UNUSED

`ifdef	FORMAL
	localparam	F_LGDEPTH=2;
	reg	f_past_valid;
	wire	[(F_LGDEPTH-1):0]	f_nreqs, f_nacks,
					f_outstanding;
	reg	[(AW-1):0]	f_req_addr;
//
//
// Generic setup
//
//
`ifdef	QFLEXPRESS
`define	ASSUME	assume
`else
`define	ASSUME	assert
`endif

	// Keep track of a flag telling us whether or not $past()
	// will return valid results
	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid = 1'b1;

	always @(*)
	if (!f_past_valid)
       		`ASSUME(i_reset);

	/////////////////////////////////////////////////
	//
	//
	// Assumptions about our inputs
	//
	//
	/////////////////////////////////////////////////

	always @(*)
		`ASSUME((!i_wb_stb)||(!i_cfg_stb));

	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_reset))
			&&($past(i_wb_stb))&&($past(o_wb_stall)))
		`ASSUME(i_wb_stb);

	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_reset))
			&&($past(i_cfg_stb))&&($past(o_wb_stall)))
		`ASSUME(i_cfg_stb);

	fwb_slave #(.AW(AW), .DW(DW),.F_LGDEPTH(F_LGDEPTH),
			.F_MAX_STALL(15+CKDELAY+NDUMMY+RDDELAY),
			.F_MAX_ACK_DELAY(14+CKDELAY+NDUMMY+RDDELAY),
			.F_OPT_RMW_BUS_OPTION(0),
			.F_OPT_CLK2FFLOGIC(1'b0),
			.F_OPT_DISCONTINUOUS(1))
		f_wbm(i_clk, i_reset,
			i_wb_cyc, (i_wb_stb)||(i_cfg_stb), i_wb_we, i_wb_addr,
				i_wb_data, 4'hf,
			o_wb_ack, o_wb_stall, o_wb_data, 1'b0,
			f_nreqs, f_nacks, f_outstanding);

	always @(*)
		assert(f_outstanding <= 2 + f_extra);

	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_wb_stb))||($past(o_wb_stall)))
		assert(f_outstanding <= 1 + f_extra);

	always @(*)
	if (maintenance)
	begin
		assume((!i_wb_stb)&&(!i_cfg_stb));

		assert(f_outstanding == 0);

		assert(o_wb_stall);
		//
		assert(clk_ctr == 0);
		assert(cfg_mode == 1'b0);
	end

	always @(*)
	if (maintenance)
	begin
		assert(clk_ctr == 0);
		assert(!o_wb_ack);
	end

	always @(posedge i_clk)
	if (dly_ack)
		assert(clk_ctr[2:0] == 0);

	// Zero cycle requests
	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_reset))&&(($past(cfg_noop))
			||($past(i_wb_stb && i_wb_we && !o_wb_stall))))
		assert((dly_ack)&&((!i_wb_cyc)
			||(f_outstanding == 1 + f_extra)));

	always @(posedge i_clk)
	if ((f_outstanding > 0)&&(clk_ctr > 0))
		assert(pre_ack);

	always @(posedge i_clk)
	if ((i_wb_cyc)&&(dly_ack))
		assert(f_outstanding >= 1 + f_extra);

	always @(posedge i_clk)
	if ((f_past_valid)&&(clk_ctr == 0)&&(!dly_ack)
			&&((!$past(i_wb_stb|i_cfg_stb))||($past(o_wb_stall))))
		assert(f_outstanding == f_extra);

	always @(*)
	if ((i_wb_cyc)&&(pre_ack)&&(!o_qspi_cs_n))
		assert((f_outstanding >= 1 + f_extra)||((OPT_CFG)&&(cfg_mode)));

	always @(*)
	if ((cfg_mode)&&(!dly_ack)&&(clk_ctr == 0))
		assert(f_outstanding == f_extra);

	always @(*)
	if (cfg_mode)
		assert(f_outstanding <= 1 + f_extra);

	/////////////////
	//
	// Idle channel
	//
	//
	/////////////////
	always @(*)
	if ((o_qspi_cs_n)&&(!maintenance))
	begin
		assert(clk_ctr == 0);
		assert(o_qspi_sck  == 1'b0);
		//assert((o_qspi_mod == NORMAL_SPI)||(o_qspi_mod == QUAD_READ));
	end

	always @(*)
		assert(o_qspi_mod != 2'b01);

	always @(*)
	if (clk_ctr > 5'h8+CKDELAY)
	begin
		assert(!cfg_mode);
		assert(!cfg_cs);
	end


	/////////////////
	//
	//  Read requests
	//
	/////////////////
	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_reset))&&($past(bus_request)))
	begin
		assert(!o_qspi_cs_n);
		assert(o_qspi_sck == 1'b1);
		if (CKDELAY > 0)
		begin
			assert(o_qspi_dat == 2'b00);
		end
		//
		if (!$past(o_qspi_cs_n))
		begin
			assert(clk_ctr == 5'd8);
			assert(o_qspi_mod == QUAD_READ);
		end else begin
			assert(clk_ctr == 5'd14+CKDELAY + NDUMMY);
			assert(o_qspi_mod == QUAD_WRITE);
		end
	end

	always @(*)
		assert(clk_ctr <= 5'd18+CKDELAY + NDUMMY);

	always @(*)
	if (!o_qspi_cs_n)
		assert((o_qspi_sck)||(actual_sck)||(cfg_mode)||(maintenance));
	// else if (cfg_mode)
	//	assert((!o_qspi_sck)&&(!actual_sck));

	always @(*)
	if ((RDDELAY == 0)&&((dly_ack)&&(clk_ctr == 0)))
		assert(!o_wb_stall);

	always @(*)
	if (!maintenance)
	begin
		if (cfg_mode)
		begin
			if (!cfg_cs)
				assert(o_qspi_cs_n);
			else if (!cfg_speed)
				assert(o_qspi_mod == NORMAL_SPI);
			else if ((cfg_dir)&&(clk_ctr > 0))
				assert(o_qspi_mod == QUAD_WRITE);
			// else
			//	assert(o_qspi_mod == QUAD_READ);
		end else if (clk_ctr > 5'd8)
			assert(o_qspi_mod == QUAD_WRITE);
		else if (clk_ctr > 0)
			assert(o_qspi_mod == QUAD_READ);
	end

	always @(posedge i_clk)
	if (((!OPT_PIPE)&&(clk_ctr != 0))||(clk_ctr > 5'd1))
		assert(o_wb_stall);

	/////////////////
	//
	//  User mode
	//
	/////////////////
	always @(*)
	if ((maintenance)||(!OPT_CFG))
		assert(!cfg_mode);
	always @(*)
	if ((OPT_CFG)&&(cfg_mode))
		assert(o_qspi_cs_n == !cfg_cs);
	else
		assert(!cfg_cs);

	//
	//
	//
	//
	always @(posedge i_clk)
		cover((f_past_valid)&&(o_wb_ack));

	// always @(posedge i_clk) cover((dly_ack)&&(f_second_ack));

`ifdef	VERIFIC

	reg	[21:0]	fv_addr;
	always @(posedge i_clk)
	if (bus_request)
		fv_addr <= i_wb_addr;

	reg	[7:0]	fv_data;
	always @(posedge i_clk)
	if (cfg_write)
		fv_data <= i_wb_data[7:0];

	// Bus write request ... immediately ack
	assert property (@(posedge i_clk)
		(!i_reset)&&(i_wb_stb)&&(!o_wb_stall)&&(i_wb_we)
		|=> (dly_ack)&&($stable(o_qspi_cs_n))&&(!o_qspi_sck));

	// Bus read request during cfg mode ... immediately ack
	assert property (@(posedge i_clk)
		(!i_reset)&&(i_wb_stb)&&(!o_wb_stall)&&(!i_wb_we)&&(cfg_mode)
		|=> (dly_ack)&&($stable(o_qspi_cs_n))&&(!o_qspi_sck));

	sequence	READ_REQUEST(ADDR);
		((o_wb_stall)&&(!o_qspi_cs_n)&&(o_qspi_sck)
				&&(o_qspi_mod == QUAD_WRITE)&&(!dly_ack))
			throughout
			(o_qspi_dat == 4'h0) [*CKDELAY]
			##1 (o_qspi_dat == ADDR[21:18])&&(clk_ctr==5'd14+NDUMMY)
			##1 (o_qspi_dat == ADDR[17:14])&&(clk_ctr==5'd13+NDUMMY)
			##1 (o_qspi_dat == ADDR[13:10])&&(clk_ctr==5'd12+NDUMMY)
			##1 (o_qspi_dat == ADDR[ 9: 6])&&(clk_ctr==6'd11+NDUMMY)
			##1 (o_qspi_dat == ADDR[ 5: 2])&&(clk_ctr==5'd10+NDUMMY)
			##1 (o_qspi_dat =={ADDR[1:0],2'b00})&&(clk_ctr==5'd9+NDUMMY);
	endsequence;

	sequence	MODE_BYTE;
		((o_wb_stall)&&(!o_qspi_cs_n)&&(o_qspi_sck)
				&&(o_qspi_mod == QUAD_WRITE)&&(!dly_ack))
			throughout
			// Mode nibble 1
			(o_qspi_dat == 4'ha)&&(clk_ctr == 5'd8+NDUMMY)
			// Mode nibble 2
			##1 (o_qspi_dat == 4'h0)&&(clk_ctr == 5'd7+NDUMMY);
	endsequence

	sequence	DUMMY_BYTES;
		((o_wb_stall)&&(!o_qspi_cs_n)&&(o_qspi_sck)
				&&(o_qspi_mod == QUAD_WRITE)&&(!dly_ack))
			throughout
			// (o_qspi_dat == 4'h0) [*4];
			(o_qspi_dat == 4'h0) [*NDUMMY-3]
			##1 (o_qspi_dat == 4'h0)&&(clk_ctr == 5'd9);
	endsequence;

	sequence	READ_WORD;
		((!o_qspi_cs_n)&&(!dly_ack)
			&&(o_qspi_mod == QUAD_READ)) throughout
		(o_wb_stall)&&(o_qspi_sck)&&(clk_ctr == 5'h8)
		##1 ((o_wb_stall)&&(o_qspi_sck)) [*6]
		##1 ((OPT_PIPE)||(o_wb_stall))&&(clk_ctr == 5'd1)
		    &&(((CKDELAY == 0)&&(o_qspi_sck))
			||((CKDELAY > 0)&&((OPT_PIPE)||(!o_qspi_sck))));
	endsequence;

	sequence	ACK_WORD;
		1'b1 [*RDDELAY]
		##1 (o_wb_ack)
			&&(o_wb_data[31:28] == $past(i_qspi_dat,8))
			&&(o_wb_data[27:24] == $past(i_qspi_dat,7))
			&&(o_wb_data[23:20] == $past(i_qspi_dat,6))
			&&(o_wb_data[19:16] == $past(i_qspi_dat,5))
			&&(o_wb_data[15:12] == $past(i_qspi_dat,4))
			&&(o_wb_data[11: 8] == $past(i_qspi_dat,3))
			&&(o_wb_data[ 7: 4] == $past(i_qspi_dat,2))
			&&(o_wb_data[ 3: 0] == $past(i_qspi_dat));
	endsequence;

	// Proper Bus read request
	property BUS_READ;
		disable iff ((i_reset)||(!i_wb_cyc))
		(i_wb_stb)&&(!o_wb_stall)&&(!i_wb_we)&&(!cfg_mode)
			&&(o_qspi_cs_n)
		|=> READ_REQUEST(fv_addr)
		##1 MODE_BYTE
		##1 DUMMY_BYTES
		##1 READ_WORD
		##1 ACK_WORD;
	endproperty

	sequence PIPED_READ_SEQUENCE;
		(!o_qspi_cs_n)&&(o_qspi_mod == QUAD_READ)&&(!cfg_mode)
			throughout
		(((o_wb_stall)&&(o_qspi_sck)
				&&(dly_ack))
				&&((f_outstanding == 2 + f_extra)||(!i_wb_cyc))
				&&(clk_ctr == 5'd8))
		##1 ((!dly_ack)&&(f_outstanding == 1 + f_extra))
			throughout
		((o_wb_stall)&&(o_qspi_sck)
				&&(clk_ctr > 1)&&(clk_ctr < 5'd8)
			       		&&(!cfg_mode)) [*6]
		##1 (((!o_qspi_sck)&&(!i_wb_stb)||( o_wb_stall))
			  ||((o_qspi_sck)&&( i_wb_stb)&&(!o_wb_stall)))
				&&(clk_ctr == 1);
	endsequence

	// Bus pipe-read request
	property PIPED_READ;
		disable iff ((i_reset)||(!i_wb_cyc))
		(i_wb_stb)&&(!o_wb_stall)&&(!i_wb_we)&&(!cfg_mode)
			&&(!o_qspi_cs_n)&&(OPT_PIPE)
		|=> PIPED_READ_SEQUENCE
		##1 ACK_WORD;
	endproperty

	// Proper Bus read request
	assert property (@(posedge i_clk) BUS_READ);
	// Bus pipe-read request
	assert property (@(posedge i_clk) PIPED_READ);


	//
	//
	//
	// Configuration registers
	//
	//
	//
	sequence	SPI_CFG_WRITE_SEQ;
		((o_wb_stall)&&(!o_qspi_cs_n)
			&&(o_qspi_mod == NORMAL_SPI)&&(!o_wb_ack)
			&&(cfg_mode)&&(!cfg_speed))
			throughout
		((o_qspi_sck) throughout
		(o_qspi_dat[0] == 1'b0) [*CKDELAY]
		##1 ((o_qspi_dat[0] == fv_data[7])&&(clk_ctr == 5'd8))
		##1 ((o_qspi_dat[0] == fv_data[6])&&(clk_ctr == 5'd7))
		##1 ((o_qspi_dat[0] == fv_data[5])&&(clk_ctr == 5'd6))
		##1 ((o_qspi_dat[0] == fv_data[4])&&(clk_ctr == 5'd5))
		##1 ((o_qspi_dat[0] == fv_data[3])&&(clk_ctr == 5'd4))
		##1 ((o_qspi_dat[0] == fv_data[2])&&(clk_ctr == 5'd3))
		##1 ((o_qspi_dat[0] == fv_data[1])&&(clk_ctr == 5'd2)))
		//
		##1 ((o_qspi_dat[0] == fv_data[0])&&(clk_ctr == 5'd1)
				&&(!o_qspi_sck)&&(actual_sck));
	endsequence

	sequence	QSPI_CFG_WRITE_SEQ;
		((o_wb_stall)&&(!o_qspi_cs_n)
			&&(o_qspi_mod == QUAD_WRITE)&&(!o_wb_ack)
			&&(cfg_mode)&&(cfg_speed)&&(cfg_dir))
			throughout
		(o_qspi_dat[3:0] == 4'b00)&&(o_qspi_sck) [*CKDELAY]
		##1 (o_qspi_dat[3:0]==$past(i_wb_data[7:4],2))
				&&(clk_ctr== 5'd2)
		##1 (o_qspi_dat[3:0]==$past(i_wb_data[3:0],3))
				&&(clk_ctr== 5'd1)
				&&(actual_sck);
	endsequence

	sequence	QSPI_CFG_READ_SEQ;
		((o_wb_stall)&&(!o_qspi_cs_n)
			&&(o_qspi_mod == QUAD_READ)&&(!o_wb_ack)
			&&(cfg_mode)&&(cfg_speed)&&(!cfg_dir))
			throughout
		(o_qspi_sck) [*CKDELAY]
		##1 ((clk_ctr== 5'd2)&&(o_qspi_sck))
		##1 ((clk_ctr== 5'd1)&&(!o_qspi_sck)&&(actual_sck));
	endsequence

	// Config write request (low speed)
	property SPI_CFG_WRITE;
		disable iff ((i_reset)||(!i_wb_cyc))
		(cfg_ls_write)
		|=> SPI_CFG_WRITE_SEQ
		##1 ( (((dly_ack)||(!$past(pre_ack))||($past(!i_wb_cyc)))
			&&(o_wb_data[12:10]==3'b100)&&(o_wb_data[8]))
		and 1'b1 [*RDDELAY]
		##1 ((o_wb_ack)
				&&(o_wb_data[7]==$past(i_qspi_dat[1],8))
				&&(o_wb_data[6]==$past(i_qspi_dat[1],7))
				&&(o_wb_data[5]==$past(i_qspi_dat[1],6))
				&&(o_wb_data[4]==$past(i_qspi_dat[1],5))
				&&(o_wb_data[3]==$past(i_qspi_dat[1],4))
				&&(o_wb_data[2]==$past(i_qspi_dat[1],3))
				&&(o_wb_data[1]==$past(i_qspi_dat[1],2))
				&&(o_wb_data[0]==$past(i_qspi_dat[1])))
		);
	endproperty

	// Config read-HS  request
	property QSPI_CFG_READ;
		disable iff (i_reset)
		(cfg_hs_read)
		|=> QSPI_CFG_READ_SEQ
		##1 ((dly_ack)||(!$past(pre_ack))||($past(!i_wb_cyc)))
			&&(o_wb_data[12:8]==5'b11001);
	endproperty

	// Config write-HS request
	property QSPI_CFG_WRITE;
		disable iff ((i_reset)||(!i_wb_cyc))
		(cfg_hs_write)
		|=> ((pre_ack) throughout QSPI_CFG_WRITE_SEQ)
		##1 ((o_wb_data[12:8] == 5'b11011)
			and 1'b1 [*RDDELAY]
			##1 (o_wb_ack));
	endproperty

	// Config release request
	property CFG_RELEASE;
		disable iff ((i_reset)||(!i_wb_cyc))
		(OPT_CFG)&&(!i_reset)&&(i_cfg_stb)&&(!o_wb_stall)&&(i_wb_we)
				&&(i_wb_data[USER_CS_n])
		|=> ( ((dly_ack)&&(o_qspi_cs_n)&&(!cfg_cs)&&(clk_ctr == 0)
			&&(cfg_mode == $past(i_wb_data[CFG_MODE])))
		and (o_wb_stall) [*(RDDELAY)] ##1 (o_wb_ack) );
	endproperty

	property CFG_READBUS_NOOP;
		disable iff ((i_reset)||(!i_wb_cyc))
		(OPT_CFG)&&(!i_reset)&&(i_cfg_stb)&&(!o_wb_stall)&&(!i_wb_we)
		|=> (o_qspi_cs_n==$past(o_qspi_cs_n))
			&&(clk_ctr==0)
		##1 1'b1 [*(RDDELAY-1)]
		##1 (o_wb_ack);
	endproperty

	// Non-config responses from the config port
	property NOCFG_NOOP;
		disable iff ((i_reset)||(!i_wb_cyc))
		(!OPT_CFG)&&(!i_reset)&&(i_cfg_stb)&&(!o_wb_stall)
		|=> (o_qspi_cs_n==$past(o_qspi_cs_n))&&(clk_ctr==0)
		##1 1'b1 [*(RDDELAY-1)]
		##1 (o_wb_ack);
	endproperty

	assert	property (@(posedge i_clk) SPI_CFG_WRITE);
	assert	property (@(posedge i_clk) QSPI_CFG_READ);
	assert	property (@(posedge i_clk) QSPI_CFG_WRITE);
	assert	property (@(posedge i_clk) CFG_RELEASE);
	assert	property (@(posedge i_clk) CFG_READBUS_NOOP);
	assert	property (@(posedge i_clk) NOCFG_NOOP);
`else // VERIFIC

	// Lowspeed config write
	reg	[CKDELAY+8:0]	f_cfglswrite;
	wire	[8:0]		fw_cfglswrite;

	initial	f_cfglswrite = 0;
	always @(posedge i_clk)
	if (i_reset)
		f_cfglswrite <= 0;
	else begin
		f_cfglswrite <= { f_cfglswrite[CKDELAY+6:0], 1'b0 };
		f_cfglswrite[0] <= (cfg_ls_write);
	end

	always @(*)
	if (|f_cfglswrite[7:0])
		assert(o_qspi_sck);
	else if (|f_cfglswrite)
		assert(!o_qspi_sck);

	assign	fw_cfglswrite = f_cfglswrite[CKDELAY+8:CKDELAY];

	always @(posedge i_clk)
	if (fw_cfglswrite[8])
	begin
		if (RDDELAY == 0)
		begin
			assert((o_wb_ack)||(!$past(pre_ack))||(!$past(i_wb_cyc)));
			assert(o_wb_data[7] == $past(i_qspi_dat[1],8));
			assert(o_wb_data[6] == $past(i_qspi_dat[1],7));
			assert(o_wb_data[5] == $past(i_qspi_dat[1],6));
			assert(o_wb_data[4] == $past(i_qspi_dat[1],5));
			assert(o_wb_data[3] == $past(i_qspi_dat[1],4));
			assert(o_wb_data[2] == $past(i_qspi_dat[1],3));
			assert(o_wb_data[1] == $past(i_qspi_dat[1],2));
			assert(o_wb_data[0] == $past(i_qspi_dat[1],1));
			assert(o_qspi_mod == NORMAL_SPI);
		end
	end else if (|fw_cfglswrite)
	begin
		assert(!dly_ack);
		assert(!o_qspi_cs_n);
		assert(o_qspi_mod == NORMAL_SPI);
		if (fw_cfglswrite[0])
			assert(o_qspi_dat[0] == $past(i_wb_data[7],CKDELAY+1));
		if (fw_cfglswrite[1])
			assert(o_qspi_dat[0] == $past(i_wb_data[6],CKDELAY+2));
		if (fw_cfglswrite[2])
			assert(o_qspi_dat[0] == $past(i_wb_data[5],CKDELAY+3));
		if (fw_cfglswrite[3])
			assert(o_qspi_dat[0] == $past(i_wb_data[4],CKDELAY+4));
		if (fw_cfglswrite[4])
			assert(o_qspi_dat[0] == $past(i_wb_data[3],CKDELAY+5));
		if (fw_cfglswrite[5])
			assert(o_qspi_dat[0] == $past(i_wb_data[2],CKDELAY+6));
		if (fw_cfglswrite[6])
			assert(o_qspi_dat[0] == $past(i_wb_data[1],CKDELAY+7));
		if (fw_cfglswrite[7])
			assert(o_qspi_dat[0] == $past(i_wb_data[0],CKDELAY+8));
	end


	//
	//
	// High speed config write
	reg	[CKDELAY+2:0]	f_cfghswrite;
	wire	[2:0]		fw_cfghswrite;

	initial	f_cfghswrite = 0;
	always @(posedge i_clk)
	if (i_reset)
		f_cfghswrite <= 0;
	else begin
		f_cfghswrite <= { f_cfghswrite[CKDELAY+1:0], 1'b0 };
		f_cfghswrite[0] <= (cfg_hs_write);
	end

	always @(*)
	if (|f_cfghswrite[1:0])
		assert(o_qspi_sck);
	else if (|f_cfghswrite)
		assert(!o_qspi_sck);

	assign	fw_cfghswrite = f_cfghswrite[CKDELAY+2:CKDELAY];

	always @(posedge i_clk)
	if (fw_cfghswrite[2])
	begin
		if (RDDELAY == 0)
		begin
			assert((o_wb_ack)||(!$past(pre_ack))||(!$past(i_wb_cyc)));
			assert(o_qspi_mod == QUAD_WRITE);
			assert(!o_wb_stall);
		end
	end else if (|fw_cfghswrite)
	begin
		if (fw_cfghswrite[0])
			assert(o_qspi_dat == $past(i_wb_data[7:4],CKDELAY+1));
		if (fw_cfghswrite[1])
			assert(o_qspi_dat == $past(i_wb_data[3:0],CKDELAY+2));
		assert(!dly_ack);
		assert(!o_qspi_cs_n);
		assert(o_qspi_mod == QUAD_WRITE);
		assert(o_wb_stall);
	end


	// High speed config read
	reg	[CKDELAY+2:0]	f_cfghsread;
	wire	[2:0]		fw_cfghsread;

	initial	f_cfghsread = 0;
	always @(posedge i_clk)
	if (i_reset)
		f_cfghsread <= 0;
	else begin
		f_cfghsread <= { f_cfghsread[CKDELAY+1:0], 1'b0 };
		f_cfghsread[0] <= (cfg_hs_read);
	end

	always @(*)
	if (|f_cfghsread[1:0])
		assert(o_qspi_sck);
	else if (|f_cfghsread)
		assert(!o_qspi_sck);

	assign	fw_cfghsread = f_cfghsread[CKDELAY+2:CKDELAY];

	always @(*)
	if ((!maintenance)&&(o_qspi_cs_n))
		assert(!actual_sck);

	always @(posedge i_clk)
	if (fw_cfghsread[2])
	begin
		if (RDDELAY == 0)
		begin
			assert((o_wb_ack)||(!$past(pre_ack))||(!$past(i_wb_cyc)));
			assert(o_wb_data[7:4] == $past(i_qspi_dat[3:0],2));
			assert(o_wb_data[3:0] == $past(i_qspi_dat[3:0],1));
			assert(o_qspi_mod == QUAD_READ);
			assert(!o_wb_stall);
		end
	end else if (|fw_cfghsread)
	begin
		assert(!dly_ack);
		assert(!o_qspi_cs_n);
		assert(o_qspi_mod == QUAD_READ);
		assert(o_wb_stall);
	end

`endif // VERIFIC
	////////////////////////////////////////////////////////////////////////
	//
	// Cover Properties
	//
	////////////////////////////////////////////////////////////////////////
	//
	// Due to the way the chip starts up, requiring 32k+ maintenance clocks,
	// these cover statements are not likely to be hit

	generate if (!OPT_STARTUP)
	begin
		always @(posedge i_clk)
			cover((o_wb_ack)&&(!cfg_mode));
		always @(posedge i_clk)
			cover((o_wb_ack)&&(!cfg_mode)&&(!$past(o_qspi_cs_n)));
		always @(posedge i_clk)
			cover((o_wb_ack)&&(!cfg_mode)&&(!o_qspi_cs_n));
		always @(posedge i_clk)
			cover((o_wb_ack)&&(cfg_mode)&&(cfg_speed));
		always @(posedge i_clk)
			cover((o_wb_ack)&&(cfg_mode)&&(!cfg_speed)&&(cfg_dir));
		always @(posedge i_clk)
			cover((o_wb_ack)&&(cfg_mode)&&(!cfg_speed)&&(!cfg_dir));
	end endgenerate

`endif
endmodule
