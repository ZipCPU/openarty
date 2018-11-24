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
		o_qspi_sck, o_qspi_cs_n, o_qspi_mod, o_qspi_dat, i_qspi_dat);
	//
	parameter	LGFLASHSZ=24;
	parameter [0:0]	OPT_PIPE    = 1'b1;
	parameter [0:0]	OPT_CFG     = 1'b1;
	parameter [0:0]	OPT_STARTUP = 1'b1;
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
	reg	[14:0]	m_counter;
	reg	[1:0]	m_state;
	reg	[1:0]	m_mod;
	reg		m_cs_n;
	reg		m_clk;
	reg	[40:0]	m_data;
	wire	[3:0]	m_dat;

	generate if (OPT_STARTUP)
	begin : GEN_STARTUP

		initial	maintenance = 1'b1;
		initial	m_counter   = 0;
		initial	m_state     = 2'b00;
		initial	m_cs_n      = 1'b1;
		initial	m_clk       = 1'b0;
		always @(posedge i_clk)
		if (i_reset)
		begin
			maintenance <= 1'b1;
			m_counter   <= 0;
			m_state     <= 2'b00;
			m_cs_n <= 1'b1;
			m_clk  <= 1'b0;
			m_data <= 41'h1_ff_ff_ff_ff_ff;
			m_mod  <= NORMAL_SPI; // Normal SPI mode
		end else begin
			if (maintenance)
				m_counter <= m_counter + 1'b1;
			case(m_state)
			2'b00: begin
				// Step one: the device may have just been
				// placed into it's power down mode.  Wait for
				// it to fully enter this mode.
				maintenance <= 1'b1;
				if (m_counter[14:0] == 15'h7fff)
					// 24000 is the limit
					m_state <= 2'b01;
				m_cs_n <= 1'b1;
				m_clk  <= 1'b0;
				m_mod <= NORMAL_SPI;
				end
			2'b01: begin
				// Now that the flash has had a chance to start
				// up, feed it with chip selects with no clocks.
				// This is guaranteed to remove us from any XIP
				// mode we might be in upon startup.  We do this
				// so that we might be placed into a known
				// mode--albeit the wrong one, but a known one.
				maintenance <= 1'b1;
				//
				// 1111 0000 1111 0000 1111 0000 1111 0000
				// 1111 0000 1111 0000 1111 0000 1111 0000
				// 1111 ==> 17 * 4 clocks, or 68 clocks in total
				//
				// 8'hEB is a quad I/O read command
				m_data <= { 2'b11, QIO_READ_CMD,
							28'h00_00_00_a, 3'h0 };
				if (m_counter[14:0] == 15'd138)
					m_state <= 2'b10;
				m_cs_n <= m_counter[2];
				m_clk  <= 1'b0;
				m_mod <= NORMAL_SPI;
				end
			2'b10: begin
				// Rest, before issuing our initial read command
				maintenance <= 1'b1;
				if (m_counter[14:0] == 15'd138 + 15'd48)
					m_state <= 2'b11;
				m_cs_n <= 1'b1;	// Rest the interface
				m_clk  <= 1'b0;
				m_data <= { 2'b11, QIO_READ_CMD, 24'h00,
						4'ha, 3'b0 };
				m_mod <= NORMAL_SPI;
				end
			2'b11: begin
				m_cs_n <= 1'b0;
				if (m_counter[14:0] == 15'd138+15'd48+15'd37)
					maintenance <= 1'b0;
				m_clk  <= 1'b1;
				if (m_counter[14:0] < 15'd138 + 15'd48+15'd10)
					m_mod <= NORMAL_SPI;
				else if (m_counter[14:0] < 15'd138 + 15'd48+15'd26)
					m_mod <= QUAD_WRITE;
				else
					m_mod <= QUAD_READ;
				if (m_mod[1])
					m_data <= {m_data[36:0], 4'h0};
				else
					m_data <= {m_data[39:0], 1'h0};
				if (m_counter[14:0] >= 15'd138+15'd48+15'd33)
				begin
					m_cs_n <= 1'b1;
					m_clk  <= 1'b0;
				end
				// We depend upon the non-maintenance code to
				// provide our first (bogus) address, mode,
				// dummy cycles, and data bits.
				end
			endcase
		end
	end else begin : NO_STARTUP_OPT

		always @(*)
		begin
			maintenance = 0;
			m_counter = 0;
			m_state = 2'b11;
			m_mod = 2'b00;
			m_cs_n = 1'b1;
			m_clk  = 1'b0;
			m_data = 41'h0;
		end

		// verilator lint_off UNUSED
		wire	[55:0] unused_maintenance;
		assign	unused_maintenance = { maintenance, m_counter, m_state,
					m_mod, m_cs_n, m_clk, m_data, m_dat };
		// verilator lint_on  UNUSED
	end endgenerate

	assign	m_dat = (m_mod[1]) ? m_data[40:37] : { (4){m_data[40]} };

	//
	//
	// Data / access portion
	//
	//
	reg	[35:0]	data_pipe;
	initial	data_pipe = 0;
	always @(posedge i_clk)
	begin
		if (!o_wb_stall)
		begin
			data_pipe <= { 4'b00, {(24-LGFLASHSZ){1'b0}},
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
			data_pipe <= { data_pipe[31:0], 4'h0 };

		if (maintenance)
			data_pipe[35:32] <= m_dat;
	end

	assign	o_qspi_dat = data_pipe[35:32];

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
		clk_ctr <= 5'd21;
	else if (bus_request) // && pipe_req
		clk_ctr <= 5'd8;
	else if (cfg_ls_write)
		clk_ctr <= 5'd9;
	else if (cfg_write)
		clk_ctr <= 5'd3;
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
	else if (clk_ctr[4:0] > 5'd2)
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
	else if ((maintenance)||(cfg_write)||(bus_request))
		o_wb_stall <= 1'b1;
	else if ((i_wb_stb)&&(pipe_req)&&(clk_ctr == 5'd2))
		o_wb_stall <= 1'b0;
	else if (clk_ctr > 1)
		o_wb_stall <= 1'b1;
	else
		o_wb_stall <= 1'b0;

	initial	o_wb_ack = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_wb_ack <= 1'b0;
	else if (clk_ctr == 1)
		o_wb_ack <= (i_wb_cyc)&&(pre_ack);
	else if ((i_wb_stb)&&(!o_wb_stall)&&(!bus_request))
		o_wb_ack <= 1'b1;
	else if (cfg_noop)
		o_wb_ack <= 1'b1;
	else
		o_wb_ack <= 1'b0;

	reg	actual_sck;
	initial	actual_sck = 1'b0;
	always @(posedge i_clk)
	if ((i_reset)&&(o_qspi_cs_n))
		actual_sck <= 1'b0;
	else
		actual_sck <= o_qspi_sck;

	always @(posedge i_clk)
	begin
		if (actual_sck)
		begin
			if (!o_qspi_mod[1])
				o_wb_data <= { o_wb_data[30:0], i_qspi_dat[1] };
			else
				o_wb_data <= { o_wb_data[27:0], i_qspi_dat };
		end

		if ((OPT_CFG)&&((cfg_mode)||((i_cfg_stb)&&(!o_wb_stall))))
			o_wb_data[12:8] <= { cfg_mode, cfg_speed, 1'b0,
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

	// verilator lint_off UNUSED
	wire	[20:0]	unused;
	assign	unused = { i_wb_data[31:12], m_data[30] };
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
			.F_MAX_STALL(22),
			.F_MAX_ACK_DELAY(21),
			.F_OPT_RMW_BUS_OPTION(0),
			.F_OPT_CLK2FFLOGIC(1'b0),
			.F_OPT_DISCONTINUOUS(1))
		f_wbm(i_clk, i_reset,
			i_wb_cyc, (i_wb_stb)||(i_cfg_stb), i_wb_we, i_wb_addr,
				i_wb_data, 4'hf,
			o_wb_ack, o_wb_stall, o_wb_data, 1'b0,
			f_nreqs, f_nacks, f_outstanding);

	always @(*)
		assert(f_outstanding <= 2);

	always @(posedge i_clk)
		assert((f_outstanding <= 1)||((o_wb_ack)&&(!o_qspi_cs_n)));

	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_wb_stb))||($past(o_wb_stall)))
		assert(f_outstanding <= 1);

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
	if (m_state == 2'b01)
		assert(m_counter <= 15'd138);
	always @(posedge i_clk)
	if (m_state == 2'b10)
		assert(m_counter <= 15'd138 + 15'd48);
	always @(*)
	if (m_state != 2'b11)
		assert(maintenance);
	always @(*)
	if (m_state == 2'b11)
		assert(m_counter <= 15'd138+15'd48+15'd38);
	always @(*)
	if ((m_state == 2'b11)&&(m_counter == 15'd138+15'd48+15'd38))
		assert(!maintenance);
	else if (maintenance)
		assert((m_state!= 2'b11)||(m_counter != 15'd138+15'd48+15'd38));

	always @(*)
	if (maintenance)
	begin
		assert(clk_ctr == 0);
		assert(!o_wb_ack);
	end

	always @(posedge i_clk)
	if (o_wb_ack)
		assert(clk_ctr[2:0] == 0);

	always @(posedge i_clk)
	if ((f_outstanding > 0)&&(clk_ctr > 0))
		assert(pre_ack);
	always @(posedge i_clk)
	if ((i_wb_cyc)&&(o_wb_ack))
		assert(f_outstanding >= 1);

	always @(posedge i_clk)
	if ((f_past_valid)&&(clk_ctr == 0)&&(!o_wb_ack)
			&&((!$past(i_wb_stb|i_cfg_stb))||($past(o_wb_stall))))
		assert(f_outstanding == 0);

	always @(*)
	if ((i_wb_cyc)&&(pre_ack)&&(!o_qspi_cs_n))
		assert((f_outstanding >= 1)||((OPT_CFG)&&(cfg_mode)));

	always @(*)
	if ((cfg_mode)&&(!o_wb_ack)&&(clk_ctr == 0))
		assert(f_outstanding == 0);

	always @(*)
	if (cfg_mode)
		assert(f_outstanding <= 1);
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
	if (clk_ctr > 5'h9)
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
		assert(o_qspi_dat == 2'b00);
		//
		if (!$past(o_qspi_cs_n))
		begin
			assert(clk_ctr == 5'd8);
			assert(o_qspi_mod == QUAD_READ);
		end else begin
			assert(clk_ctr == 5'd21);
			assert(o_qspi_mod == QUAD_WRITE);
		end
	end

	always @(*)
		assert(clk_ctr <= 5'd21);

	always @(*)
	if ((o_wb_ack)&&(clk_ctr == 0))
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

	// always @(posedge i_clk) cover((o_wb_ack)&&(f_second_ack));

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
		|=> (o_wb_ack)&&($stable(o_qspi_cs_n))&&(!o_qspi_sck));

	// Bus read request during cfg mode ... immediately ack
	assert property (@(posedge i_clk)
		(!i_reset)&&(i_wb_stb)&&(!o_wb_stall)&&(!i_wb_we)&&(cfg_mode)
		|=> (o_wb_ack)&&($stable(o_qspi_cs_n))&&(!o_qspi_sck));

	sequence	READ_REQUEST(ADDR);
		((o_wb_stall)&&(!o_qspi_cs_n)&&(o_qspi_sck)
				&&(o_qspi_mod == QUAD_WRITE)&&(!o_wb_ack))
			throughout
			(o_qspi_dat == 4'h0)&&(clk_ctr==5'd21)
			##1 (o_qspi_dat == ADDR[21:18])&&(clk_ctr==5'd20)
			##1 (o_qspi_dat == ADDR[17:14])&&(clk_ctr==5'd19)
			##1 (o_qspi_dat == ADDR[13:10])&&(clk_ctr==5'd18)
			##1 (o_qspi_dat == ADDR[ 9: 6])&&(clk_ctr==6'd17)
			##1 (o_qspi_dat == ADDR[ 5: 2])&&(clk_ctr==5'd16)
			##1 (o_qspi_dat =={ADDR[1:0],2'b00})&&(clk_ctr==5'd15);
	endsequence;

	sequence	MODE_BYTE;
		((o_wb_stall)&&(!o_qspi_cs_n)&&(o_qspi_sck)
				&&(o_qspi_mod == QUAD_WRITE)&&(!o_wb_ack))
			throughout
			// Mode nibble 1
			(o_qspi_dat == 4'ha)&&(clk_ctr == 5'd14)
			// Mode nibble 2
			##1 (o_qspi_dat == 4'h0)&&(clk_ctr == 5'd13);
	endsequence

	sequence	DUMMY_BYTES;
		((o_wb_stall)&&(!o_qspi_cs_n)&&(o_qspi_sck)
				&&(o_qspi_mod == QUAD_WRITE)&&(!o_wb_ack))
			throughout
			// (o_qspi_dat == 4'h0) [*4];
			(o_qspi_dat == 4'h0)&&(clk_ctr == 5'd12)
			##1 (o_qspi_dat == 4'h0)&&(clk_ctr == 5'd11)
			##1 (o_qspi_dat == 4'h0)&&(clk_ctr == 5'd10)
			##1 (o_qspi_dat == 4'h0)&&(clk_ctr == 5'd9);
	endsequence;

	sequence	READ_WORD;
		((!o_qspi_cs_n)&&(!o_wb_ack)
			&&(o_qspi_mod == QUAD_READ)) throughout
		(o_wb_stall)&&(o_qspi_sck)&&(clk_ctr == 5'h8)
		##1 ((o_wb_stall)&&(o_qspi_sck)) [*6]
		##1 (o_qspi_sck==(i_wb_stb && !o_wb_stall))&&(clk_ctr==5'd1)
			&&((OPT_PIPE)||((!o_qspi_sck)&&(o_wb_stall)));
	endsequence;

	sequence	ACK_WORD;
		((o_wb_ack)||(!$past(pre_ack))||($past(!i_wb_cyc)))
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
		disable iff (i_reset)
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
				&&(o_wb_ack))
				&&((f_outstanding == 2)||(!i_wb_cyc))
				&&(clk_ctr == 5'd8))
		##1 ((!o_wb_ack)
			&&((f_outstanding== 1)||(!pre_ack)||(!i_wb_cyc)))
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
		disable iff (i_reset)
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
		((o_qspi_dat[0] == 1'b0)&&(clk_ctr == 5'd9))
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
		((o_qspi_dat[3:0] == 4'b00)&&(clk_ctr == 5'd3)&&(o_qspi_sck))
		##1 ((o_qspi_dat[3:0]==$past(i_wb_data[7:4],2))
				&&(clk_ctr== 5'd2)
				&&(o_qspi_sck))
		##1 ((o_qspi_dat[3:0]==$past(i_wb_data[3:0],3))
				&&(clk_ctr== 5'd1)
				&&(!o_qspi_sck)&&(actual_sck));
	endsequence

	sequence	QSPI_CFG_READ_SEQ;
		((o_wb_stall)&&(!o_qspi_cs_n)
			&&(o_qspi_mod == QUAD_READ)&&(!o_wb_ack)
			&&(cfg_mode)&&(cfg_speed)&&(!cfg_dir))
			throughout
		((clk_ctr == 5'd3)&&(o_qspi_sck))
		##1 ((clk_ctr== 5'd2)&&(o_qspi_sck))
		##1 ((clk_ctr== 5'd1)&&(!o_qspi_sck)&&(actual_sck));
	endsequence

	// Config write request (low speed)
	property SPI_CFG_WRITE;
		disable iff (i_reset)
		(cfg_ls_write)
		|=> SPI_CFG_WRITE_SEQ
		##1 ((o_wb_ack)||(!$past(pre_ack))||($past(!i_wb_cyc)))
			&&(o_wb_data[7]==$past(i_qspi_dat[1],8))
			&&(o_wb_data[6]==$past(i_qspi_dat[1],7))
			&&(o_wb_data[5]==$past(i_qspi_dat[1],6))
			&&(o_wb_data[4]==$past(i_qspi_dat[1],5))
			&&(o_wb_data[3]==$past(i_qspi_dat[1],4))
			&&(o_wb_data[2]==$past(i_qspi_dat[1],3))
			&&(o_wb_data[1]==$past(i_qspi_dat[1],2))
			&&(o_wb_data[0]==$past(i_qspi_dat[1]))
			&&(o_wb_data[12:10]==3'b100)&&(o_wb_data[8]);
	endproperty

	// Config read-HS  request
	property QSPI_CFG_READ;
		disable iff (i_reset)
		(cfg_hs_read)
		|=> QSPI_CFG_READ_SEQ
		##1 ((o_wb_ack)||(!$past(pre_ack))||($past(!i_wb_cyc)))
			&&(o_wb_data[12:8]==5'b11001)
			&&(o_wb_data[7:4]==$past(i_qspi_dat,2))
			&&(o_wb_data[3:0]==$past(i_qspi_dat));
	endproperty

	// Config write-HS request
	property QSPI_CFG_WRITE;
		disable iff (i_reset)
		(cfg_hs_write)
		|=> QSPI_CFG_WRITE_SEQ
		##1((o_wb_ack)||(!$past(pre_ack))||(!$past(i_wb_cyc)))
			&&(o_wb_data[12:8]==5'b11011);
	endproperty

	// Config release request
	property CFG_RELEASE;
		(OPT_CFG)&&(!i_reset)&&(i_cfg_stb)&&(!o_wb_stall)&&(i_wb_we)
				&&(i_wb_data[USER_CS_n])
		|=> (o_wb_ack)&&(o_qspi_cs_n)&&(!cfg_cs)
			&&(clk_ctr == 0)
			&&(cfg_mode==$past(i_wb_data[CFG_MODE]));
	endproperty

	property CFG_READBUS_NOOP;
		(OPT_CFG)&&(!i_reset)&&(i_cfg_stb)&&(!o_wb_stall)&&(!i_wb_we)
		|=> (o_wb_ack)&&(o_qspi_cs_n==$past(o_qspi_cs_n))
			&&(clk_ctr==0);
	endproperty

	// Non-config responses from the config port
	property NOCFG_NOOP;
		(!OPT_CFG)&&(!i_reset)&&(i_cfg_stb)&&(!o_wb_stall)
		|=> (o_wb_ack)&&(o_qspi_cs_n==$past(o_qspi_cs_n))&&(clk_ctr==0);
	endproperty

	assert	property (@(posedge i_clk) SPI_CFG_WRITE);
	assert	property (@(posedge i_clk) QSPI_CFG_READ);
	assert	property (@(posedge i_clk) QSPI_CFG_WRITE);
	assert	property (@(posedge i_clk) CFG_RELEASE);
	assert	property (@(posedge i_clk) CFG_READBUS_NOOP);
	assert	property (@(posedge i_clk) NOCFG_NOOP);

`endif
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
