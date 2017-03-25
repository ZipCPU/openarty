////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	toplevel.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This is the top level Verilog file.  It is to be contrasted
//		with the other top level Verilog file in this same project in
//	that *this* top level is designed to create a *safe*, low-speed
//	(80MHz), configuration that can be used to test peripherals and other
//	things on the way to building a full featured high speed (160MHz)
//	configuration.
//
//	Differences between this file and fasttop.v should be limited to speed
//	related differences (such as the number of counts per UART baud), and
//	the different daughter module: fastmaster.v (for 200MHz designs) vs
//	busmaster.v (for 100MHz designs).
//
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
module toplevel(sys_clk_i, i_reset_btn,
	i_sw,			// Switches
	i_btn,			// Buttons
	o_led,			// Single color LEDs
	o_clr_led0, o_clr_led1, o_clr_led2, o_clr_led3,	// Color LEDs
	// RS232 UART
	i_uart_rx, o_uart_tx,
	// Quad-SPI Flash control
	o_qspi_sck, o_qspi_cs_n, io_qspi_dat,
	// Ethernet
	o_eth_rstn, o_eth_ref_clk,
	i_eth_rx_clk, i_eth_col, i_eth_crs, i_eth_rx_dv, i_eth_rxd, i_eth_rxerr,
	i_eth_tx_clk, o_eth_tx_en, o_eth_txd,
	// Ethernet (MDIO)
	o_eth_mdclk, io_eth_mdio,
	// Memory
	ddr3_reset_n, ddr3_cke, ddr3_ck_p, ddr3_ck_n,
	ddr3_cs_n, ddr3_ras_n, ddr3_cas_n, ddr3_we_n,
	ddr3_dqs_p, ddr3_dqs_n,
	ddr3_addr, ddr3_ba,
	ddr3_dq, ddr3_dm, ddr3_odt,
	// SD Card
	o_sd_sck, io_sd_cmd, io_sd, i_sd_cs, i_sd_wp,
	// GPS Pmod
	i_gps_pps, i_gps_3df, i_gps_rx, o_gps_tx,
	// OLED Pmod
	o_oled_sck, o_oled_cs_n, o_oled_mosi, o_oled_dcn, o_oled_reset_n,
		o_oled_vccen, o_oled_pmoden,
	// PMod I/O
	i_aux_rx, i_aux_cts_n, o_aux_tx, o_aux_rts_n,
	// Chip-kit SPI port
	o_ck_csn, o_ck_sck, o_ck_mosi
	);
	input		[0:0]	sys_clk_i;
	input			i_reset_btn;
	input		[3:0]	i_sw;	// Switches
	input		[3:0]	i_btn;	// Buttons
	output	wire	[3:0]	o_led;	// LED
	output	wire	[2:0]	o_clr_led0, o_clr_led1, o_clr_led2, o_clr_led3;
	// UARTs
	input			i_uart_rx;
	output	wire		o_uart_tx;
	// Quad SPI flash
	output	wire		o_qspi_sck, o_qspi_cs_n;
	inout	[3:0]		io_qspi_dat;
	// Ethernet
	output	wire		o_eth_rstn, o_eth_ref_clk;
	input			i_eth_rx_clk, i_eth_col, i_eth_crs, i_eth_rx_dv;
	input	[3:0]		i_eth_rxd;
	input			i_eth_rxerr;
	input			i_eth_tx_clk;
	output	wire		o_eth_tx_en;
	output	[3:0]		o_eth_txd;
	// Ethernet control (MDIO)
	output	wire		o_eth_mdclk;
	inout	wire		io_eth_mdio;
	// DDR3 SDRAM
	output	wire		ddr3_reset_n;
	output	wire	[0:0]	ddr3_cke;
	output	wire	[0:0]	ddr3_ck_p, ddr3_ck_n;
	output	wire	[0:0]	ddr3_cs_n;
	output	wire		ddr3_ras_n, ddr3_cas_n, ddr3_we_n;
	output	wire	[2:0]	ddr3_ba;
	output	wire	[13:0]	ddr3_addr;
	output	wire	[0:0]	ddr3_odt;
	output	wire	[1:0]	ddr3_dm;
	inout		[1:0]	ddr3_dqs_p, ddr3_dqs_n;
	inout		[15:0]	ddr3_dq;
	//
	// SD Card
	output	wire		o_sd_sck;
	inout			io_sd_cmd;
	inout		[3:0]	io_sd;
	input			i_sd_cs;
	input			i_sd_wp;
	// GPS PMod
	input			i_gps_pps, i_gps_3df, i_gps_rx;
	output	wire		o_gps_tx;
	// OLEDRGB PMod
	output	wire		o_oled_sck, o_oled_cs_n, o_oled_mosi,
				o_oled_dcn, o_oled_reset_n, o_oled_vccen,
				o_oled_pmoden;
	// Aux UART
	input			i_aux_rx, i_aux_cts_n;
	output	wire		o_aux_tx, o_aux_rts_n;
	output	wire		o_ck_csn, o_ck_sck, o_ck_mosi;

	wire	eth_tx_clk, eth_rx_clk;
`ifdef	VERILATOR
	wire	s_clk, s_reset;
	assign	s_clk = sys_clk_i;

	assign	eth_tx_clk = i_eth_tx_clk;
	assign	eth_rx_clk = i_eth_rx_clk;

`else
	// Build our master clock
	wire	s_clk, sys_clk, mem_clk_200mhz,
		clk1_unused, clk2_unused, enet_clk, clk4_unnused,
		clk5_unused, clk_feedback, clk_locked, mem_clk_200mhz_nobuf;
	PLLE2_BASE	#(
		.BANDWIDTH("OPTIMIZED"),	// OPTIMIZED, HIGH, LOW
		.CLKFBOUT_PHASE(0.0),	// Phase offset in degrees of CLKFB, (-360-360)
		.CLKIN1_PERIOD(10.0),	// Input clock period in ns resolution
		// CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: divide amount for each CLKOUT(1-128)
		.CLKFBOUT_MULT(8),	// Multiply value for all CLKOUT (2-64)
		.CLKOUT0_DIVIDE(8),	// 100 MHz	(Clock for MIG)
		.CLKOUT1_DIVIDE(4),	// 200 MHz	(MIG Reference clock)
		.CLKOUT2_DIVIDE(16),	//  50 MHz	(Unused)
		.CLKOUT3_DIVIDE(32),	//  25 MHz	(Ethernet reference clk)
		.CLKOUT4_DIVIDE(32),	//  50 MHz	(Unused clock?)
		.CLKOUT5_DIVIDE(24),	//  66 MHz
		// CLKOUT0_DUTY_CYCLE -- Duty cycle for each CLKOUT
		.CLKOUT0_DUTY_CYCLE(0.5),
		.CLKOUT1_DUTY_CYCLE(0.5),
		.CLKOUT2_DUTY_CYCLE(0.5),
		.CLKOUT3_DUTY_CYCLE(0.5),
		.CLKOUT4_DUTY_CYCLE(0.5),
		.CLKOUT5_DUTY_CYCLE(0.5),
		// CLKOUT0_PHASE -- phase offset for each CLKOUT
		.CLKOUT0_PHASE(0.0),
		.CLKOUT1_PHASE(0.0),
		.CLKOUT2_PHASE(0.0),
		.CLKOUT3_PHASE(0.0),
		.CLKOUT4_PHASE(0.0),
		.CLKOUT5_PHASE(0.0),
		.DIVCLK_DIVIDE(1),	// Master division value , (1-56)
		.REF_JITTER1(0.0),	// Ref. input jitter in UI (0.000-0.999)
		.STARTUP_WAIT("TRUE")	// Delay DONE until PLL Locks, ("TRUE"/"FALSE")
	) genclock(
		// Clock outputs: 1-bit (each) output
		.CLKOUT0(mem_clk_nobuf),
		.CLKOUT1(mem_clk_200mhz_nobuf),
		.CLKOUT2(clk2_unused),
		.CLKOUT3(enet_clk),
		.CLKOUT4(clk4_unused),
		.CLKOUT5(clk5_unused),
		.CLKFBOUT(clk_feedback), // 1-bit output, feedback clock
		.LOCKED(clk_locked),
		.CLKIN1(sys_clk),
		.PWRDWN(1'b0),
		.RST(1'b0),
		.CLKFBIN(clk_feedback_bufd)	// 1-bit input, feedback clock
	);

	BUFH	feedback_buffer(.I(clk_feedback),.O(clk_feedback_bufd));
	// BUFG	memref_buffer(.I(mem_clk_200mhz_nobuf),.O(mem_clk_200mhz));
	IBUF	sysclk_buf(.I(sys_clk_i[0]), .O(sys_clk));

	BUFG	eth_rx(.I(i_eth_rx_clk), .O(eth_rx_clk));
	// assign	eth_rx_clk = i_eth_rx_clk;


	BUFG	eth_tx(.I(i_eth_tx_clk), .O(eth_tx_clk));
	// assign	eth_tx_clk = i_eth_tx_clk;
`endif

	//
	//
	// UART interface
	//
	//
	// localparam	BUSUART = 30'h50000014; // ~4MBaud, 7 bits, no flwctrl
	localparam	BUSUART = 31'h50000051;	// ~1MBaud, 7 bits, no flwctrl
	wire	[30:0]	bus_uart_setup;
	assign		bus_uart_setup = BUSUART;

	wire	[7:0]	rx_data, tx_data;
	wire		rx_break, rx_parity_err, rx_frame_err, rx_stb;
	wire		tx_stb, tx_busy;

	//
	// RESET LOGIC
	//
	// Okay, so this looks bad at a first read--but it's not really that
	// bad.  If you look close, there are two parts to the reset logic.
	// The first is the "PRE"-reset.  This is a wire, set from the external
	// reset button.  In good old-fashioned asynch-logic to synchronous
	// logic fashion, we synchronize this wire by registering it first
	// to pre_reset, and then to pwr_reset (the actual reset wire).
	//
	wire		s_reset;		// Ultimate system reset wire
	reg	[7:0]	pre_reset;
	reg		pwr_reset;
	// Since all our stuff is synchronous to the clock that comes out of 
	// the memory controller, sys_reset must needs come out of the memory
	// controller.
	//
	// Logic description starts with the PRE-reset, so as to make certain
	// we include the reset button.  The memory controller wants an active
	// low reset here, so we provide such.
	initial	pre_reset = 1'b0;
	always @(posedge sys_clk)
		pre_reset <= ((!i_reset_btn)||(!clk_locked))
					? 8'h00 : {pre_reset[6:0], 1'b1};
	//
	// and then continues with the actual reset, now that we've
	// synchronized our reset button wire.  This is an active LOW reset.
	initial	pwr_reset = 1'b0;
	always @(posedge sys_clk)
		pwr_reset <= pre_reset[7];
`ifdef	VERILATOR
	assign	s_reset = pwr_reset;
`else
	//
	// Of course, this only goes into the memory controller.  The true
	// device reset comes out of that memory controller, synchronized to
	// our memory generator provided clock(s)
`endif

	wire	w_ck_uart, w_uart_tx;
	rxuart	#(BUSUART) rcv(s_clk, s_reset, bus_uart_setup, i_uart_rx,
				rx_stb, rx_data, rx_break,
				rx_parity_err, rx_frame_err, w_ck_uart);
	txuart	#(BUSUART) txv(s_clk, s_reset, bus_uart_setup, 1'b0,
				tx_stb, tx_data, 1'b1, o_uart_tx, tx_busy);




	//////
	//
	//
	// The WB bus interconnect, herein called busmaster, which handles
	// just about ... everything.  It is in contrast to the other WB bus
	// interconnect, fastmaster, in that the busmaster build permits
	// peripherals that can *only* operate at 80MHz, no faster, no slower.
	//
	//
	//////
	wire		w_qspi_sck, w_qspi_cs_n;
	wire	[1:0]	qspi_bmod;
	wire	[3:0]	qspi_dat;
	wire	[3:0]	i_qspi_dat;


	wire	[1:0]	i_gpio;
	wire	[3:0]	o_gpio;
	assign	i_gpio = { o_aux_rts_n, i_aux_cts_n };

	//
	// The SDRAM interface wires
	//
	wire		ram_cyc, ram_stb, ram_we;
	wire	[25:0]	ram_addr;
	wire	[31:0]	ram_rdata, ram_wdata;
	wire	[3:0]	ram_sel;
	wire		ram_ack, ram_stall, ram_err;
	wire	[31:0]	ram_dbg;
	//
	wire		w_mdio, w_mdwe;
	//
	wire		w_sd_cmd;
	wire	[3:0]	w_sd_data;
	busmaster
		#(
		.NGPI(2), .NGPO(4)
		) wbbus(s_clk, s_reset,
		// External USB-UART bus control
		rx_stb, rx_data, tx_stb, tx_data, tx_busy,
		// Board lights and switches
		i_sw, i_btn, o_led,
		o_clr_led0, o_clr_led1, o_clr_led2, o_clr_led3,
		// Board level PMod I/O
		i_aux_rx, o_aux_tx, i_aux_cts_n, o_aux_rts_n,i_gps_rx, o_gps_tx,
		// Quad SPI flash
		w_qspi_cs_n, w_qspi_sck, qspi_dat, i_qspi_dat, qspi_bmod,
		// DDR3 SDRAM
		// o_ddr_reset_n, o_ddr_cke, o_ddr_ck_p, o_ddr_ck_n,
		// o_ddr_cs_n, o_ddr_ras_n, o_ddr_cas_n, o_ddr_we_n,
		// o_ddr_ba, o_ddr_addr, o_ddr_odt, o_ddr_dm,
		// io_ddr_dqs_p, io_ddr_dqs_n, io_ddr_data,
		ram_cyc, ram_stb, ram_we, ram_addr, ram_wdata, ram_sel,
			ram_ack, ram_stall, ram_rdata, ram_err,
			ram_dbg,
		// SD Card
		o_sd_sck, w_sd_cmd, w_sd_data, io_sd_cmd, io_sd, i_sd_cs,
		// Ethernet
		o_eth_rstn,
		eth_rx_clk, i_eth_col, i_eth_crs, i_eth_rx_dv,
			i_eth_rxd, i_eth_rxerr,
		eth_tx_clk, o_eth_tx_en, o_eth_txd,
		// Ethernet control (MDIO) lines
		o_eth_mdclk, w_mdio, w_mdwe, io_eth_mdio,
		// OLEDRGB PMod wires
		o_oled_sck, o_oled_cs_n, o_oled_mosi, o_oled_dcn,
		o_oled_reset_n, o_oled_vccen, o_oled_pmoden,
		// GPS PMod
		i_gps_pps, i_gps_3df,
		// Other GPIO wires
		i_gpio, o_gpio
		);

	//////
	//
	//
	// The rest of this file *should* be identical to fasttop.v.  Any
	// differences should be worked out with meld or some such program
	// to keep them to a minimum.
	//
	//
	// Some wires need special treatment, and so are not quite completely
	// handled by the bus master.  These are handled below.
	//
	//
	//////

	//
	//
	// QSPI)BMOD, Quad SPI bus mode, Bus modes are:
	//	0?	Normal serial mode, one bit in one bit out
	//	10	Quad SPI mode, going out
	//	11	Quad SPI mode coming from the device (read mode)
	//
	//	??	Dual mode in  (not yet)
	//	??	Dual mode out (not yet)
	//
	//
	wire	[3:0]	i_qspi_pedge, i_qspi_nedge;

`ifdef	VERILATOR
	assign	o_qspi_sck  = w_qspi_sck;
	assign	o_qspi_cs_n = w_qspi_cs_n;
;
();
[*];
`else
	xoddr	xqspi_sck( s_clk, { w_qspi_sck,  w_qspi_sck }, o_qspi_sck);
	xoddr	xqspi_csn( s_clk, { w_qspi_cs_n, w_qspi_cs_n },o_qspi_cs_n);
	//
	xioddr	xqspi_d0(  s_clk, (qspi_bmod != 2'b11),
		{ qspi_dat[0], qspi_dat[0] },
		{ i_qspi_pedge[0], i_qspi_nedge[0] }, io_qspi_dat[0]);
	xioddr	xqspi_d1(  s_clk, (qspi_bmod==2'b10),
		{ qspi_dat[1], qspi_dat[1] },
		{ i_qspi_pedge[1], i_qspi_nedge[1] }, io_qspi_dat[1]);
	xioddr	xqspi_d2(  s_clk, (qspi_bmod!=2'b11),
		(qspi_bmod[1])?{ qspi_dat[2], qspi_dat[2] }:2'b11,
		{ i_qspi_pedge[2], i_qspi_nedge[2] }, io_qspi_dat[2]);
	xioddr	xqspi_d3(  s_clk, (qspi_bmod!=2'b11),
		(qspi_bmod[1])?{ qspi_dat[3], qspi_dat[3] }:2'b11,
		{ i_qspi_pedge[3], i_qspi_nedge[3] }, io_qspi_dat[3]);
`endif
	reg	[3:0]	r_qspi_dat;
	always @(posedge s_clk)
		r_qspi_dat <= i_qspi_pedge;
	assign	i_qspi_dat = r_qspi_dat;

	//
	// Proposed QSPI mode select, to allow dual I/O mode
	//	000	Normal SPI mode
	//	001	Dual mode input
	//	010	Dual mode, output
	//	101	Quad I/O mode input
	//	110	Quad I/O mode output
	//
	//


	//
	//
	// Generate a reference clock for the network
	//
	//
`ifdef	VERILATOR
	assign	o_eth_ref_clk = i_eth_tx_clk;
`else
	xoddr	e_ref_clk( enet_clk, { 1'b1,  1'b0 }, o_eth_ref_clk );
`endif

	//
	//
	// Wires for setting up the SD Card Controller
	//
	//
	assign io_sd_cmd = w_sd_cmd ? 1'bz:1'b0;
	assign io_sd[0] = w_sd_data[0]? 1'bz:1'b0;
	assign io_sd[1] = w_sd_data[1]? 1'bz:1'b0;
	assign io_sd[2] = w_sd_data[2]? 1'bz:1'b0;
	assign io_sd[3] = w_sd_data[3]? 1'bz:1'b0;


	//
	//
	// Wire(s) for setting up the MDIO ethernet control structure
	//
	//
	assign	io_eth_mdio = (w_mdwe)?w_mdio : 1'bz;

	//
	//
	// Now, to set up our memory ...
	//
	//
	migsdram #(.AXIDWIDTH(5)) rami(
		.i_clk(mem_clk_nobuf), .i_clk_200mhz(mem_clk_200mhz_nobuf),
		.o_sys_clk(s_clk), .i_rst(pwr_reset), .o_sys_reset(s_reset),
		.i_wb_cyc(ram_cyc), .i_wb_stb(ram_stb), .i_wb_we(ram_we),
			.i_wb_addr(ram_addr), .i_wb_data(ram_wdata),
			.i_wb_sel(ram_sel),
		.o_wb_ack(ram_ack), .o_wb_stall(ram_stall),
			.o_wb_data(ram_rdata), .o_wb_err(ram_err),
		.o_ddr_ck_p(ddr3_ck_p),		.o_ddr_ck_n(ddr3_ck_n),
		.o_ddr_reset_n(ddr3_reset_n), 	.o_ddr_cke(ddr3_cke),
		.o_ddr_cs_n(ddr3_cs_n),		.o_ddr_ras_n(ddr3_ras_n),
			.o_ddr_cas_n(ddr3_cas_n), .o_ddr_we_n(ddr3_we_n),
		.o_ddr_ba(ddr3_ba),		.o_ddr_addr(ddr3_addr),
			.o_ddr_odt(ddr3_odt),	.o_ddr_dm(ddr3_dm),
		.io_ddr_dqs_p(ddr3_dqs_p),	.io_ddr_dqs_n(ddr3_dqs_n),
		.io_ddr_data(ddr3_dq),
	//
		.o_ram_dbg(ram_dbg)
	);

endmodule

