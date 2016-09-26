////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	fasttop.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This is the top level Verilog file.  It is so named as fasttop,
//		because my purpose will be to run the Arty at 200MHz, just to
//	prove that I can get it up to that frequency.
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
module fasttop(i_clk_100mhz, i_reset_btn,
	i_sw,			// Switches
	i_btn,			// Buttons
	o_led,			// Single color LEDs
	o_clr_led0, o_clr_led1, o_clr_led2, o_clr_led3,	// Color LEDs
	// RS232 UART
	i_uart_rx, o_uart_tx,
	// Quad-SPI Flash control
	o_qspi_sck, o_qspi_cs_n, io_qspi_dat,
	// Missing: Ethernet
	o_eth_mdclk, io_eth_mdio,
	// Memory
	o_ddr_reset_n, o_ddr_cke, o_ddr_ck_p, o_ddr_ck_n,
	o_ddr_cs_n, o_ddr_ras_n, o_ddr_cas_n, o_ddr_we_n,
	io_ddr_dqs_p, io_ddr_dqs_n,
	o_ddr_addr, o_ddr_ba,
	io_ddr_data, o_ddr_dm, o_ddr_odt,
	// SD Card
	o_sd_sck, io_sd_cmd, io_sd, i_sd_cs, i_sd_wp,
	// GPS Pmod
	i_gps_pps, i_gps_3df, i_gps_rx, o_gps_tx,
	// OLED Pmod
	o_oled_sck, o_oled_cs_n, o_oled_mosi, o_oled_dcn, o_oled_reset_n,
		o_oled_vccen, o_oled_pmoden,
	// PMod I/O
	i_aux_rx, i_aux_rts, o_aux_tx, o_aux_cts
	);
	input			i_clk_100mhz, i_reset_btn;
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
	// Ethernet // Not yet implemented
	// Ethernet control (MDIO)
	output	wire		o_eth_mdclk;
	inout	wire		io_eth_mdio;
	// DDR3 SDRAM
	output	wire		o_ddr_reset_n;
	output	wire		o_ddr_cke;
	output	wire		o_ddr_ck_p, o_ddr_ck_n;
	output	wire		o_ddr_cs_n, o_ddr_ras_n, o_ddr_cas_n, o_ddr_we_n;
	inout		[1:0]	io_ddr_dqs_p, io_ddr_dqs_n;
	output	wire	[13:0]	o_ddr_addr;
	output	wire	[2:0]	o_ddr_ba;
	inout		[15:0]	io_ddr_data;
	//
	output	wire	[1:0]	o_ddr_dm;
	output	wire		o_ddr_odt;
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
	input			i_aux_rx, i_aux_rts;
	output	wire		o_aux_tx, o_aux_cts;

`define	FULLCLOCK
	// Build our master clock
	wire	s_clk_pll, s_clk, clk_for_ddr, mem_serial_clk, mem_serial_clk_inv,
		enet_clk, clk_halfspeed, clk_feedback, clk_locked, clk_unused;
	PLLE2_BASE	#(
		.BANDWIDTH("OPTIMIZED"),	// OPTIMIZED, HIGH, LOW
		.CLKFBOUT_PHASE(0.0),	// Phase offset in degrees of CLKFB, (-360-360)
		.CLKIN1_PERIOD(10.0),	// Input clock period in ns resolution
		// CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: divide amount for each CLKOUT(1-128)
		.CLKFBOUT_MULT(8),	// Multiply value for all CLKOUT (2-64)
		.CLKOUT0_DIVIDE(5),	// 160 MHz
		.CLKOUT1_DIVIDE(10),	//  80 MHz	(Unused)
		.CLKOUT2_DIVIDE(16),	//  50 MHz	(Unused)
		.CLKOUT3_DIVIDE(32),	//  25 MHz	(Unused/Ethernet clock)
		.CLKOUT4_DIVIDE(16),	//  50 MHz	(Unused clock?)
		.CLKOUT5_DIVIDE(24),
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
		.CLKOUT0(s_clk_pll),
		.CLKOUT1(mem_clk),
		.CLKOUT2(clk2_unused),
		.CLKOUT3(enet_clk),
		.CLKOUT4(clk4_unused),
		.CLKOUT5(clk5_unused),
		.CLKFBOUT(clk_feedback), // 1-bit output, feedback clock
		.LOCKED(clk_locked),
		.CLKIN1(i_clk_100mhz),
		.PWRDWN(1'b0),
		.RST(1'b0),
		.CLKFBIN(clk_feedback_bufd)	// 1-bit input, feedback clock
	);

	// Help reduce skew ...
	BUFG	sys_clk_buffer( .I(s_clk_pll), .O(s_clk));
	BUFG	feedback_buffer(.I(clk_feedback),.O(clk_feedback_bufd));

	// UART interface
	wire	[29:0]	bus_uart_setup;
	assign		bus_uart_setup = 30'h10000028; // 4MBaud, 7 bits

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
	reg	pwr_reset, pre_reset;
	//
	// Logic description starts with the PRE-reset, so as to make certain
	// we include the reset button
	initial	pre_reset = 1'b0;
	always @(posedge s_clk)
		pre_reset <= ~i_reset_btn;
	//
	// and then continues with the actual reset, now that we've
	// synchronized our reset button wire.
	initial	pwr_reset = 1'b1;
	always @(posedge s_clk)
		pwr_reset <= pre_reset;

	wire	w_ck_uart, w_uart_tx;
	rxuart	rcv(s_clk, pwr_reset, bus_uart_setup, i_uart_rx,
				rx_stb, rx_data, rx_break,
				rx_parity_err, rx_frame_err, w_ck_uart);
	txuart	txv(s_clk, pwr_reset, bus_uart_setup, 1'b0,
				tx_stb, tx_data, o_uart_tx, tx_busy);




`ifdef	SDRAM_ACCESS
///
///
/// The following lines are included from ddr3insert.v.
///
	wire		w_ddr_reset_n, w_ddr_cke, w_ddr_bus_oe;
	wire	[26:0]	w_ddr_cmd_a, w_ddr_cmd_b;
	wire	[63:0]	wi_ddr_data, wo_ddr_data;
	wire	[127:0]	wide_ddr_data;

	//
	//
	// Wires for setting up the DDR3 memory
	//
	//

	// First, let's set up the clock(s)
	xoddrserdesb ddrclk(mem_serial_clk, i_clk, pwr_reset, 8'h66,
		o_ddr_ck_p, o_ddr_ck_n);

	wire	[7:0]	w_udqs_in, w_ldqs_in;

	xioddrserdesb ddrudqs(mem_serial_clk, mem_serial_clk_inv, i_clk,
			~w_ddr_reset_n, w_ddr_cmd_a[0],
			(w_ddr_cmd_b[0])? 8'h66 : 8'h06, 
			w_udqs_in,
			io_ddr_dqs_p[1], io_ddr_dqs_n[1]);

	xioddrserdesb ddrldqs(mem_serial_clk, mem_serial_clk_inv, i_clk,
			~w_ddr_reset_n, w_ddr_cmd_a[0],
			(w_ddr_cmd_b[0])? 8'h66 : 8'h06, 
			w_ldqs_in,
			io_ddr_dqs_p[0], io_ddr_dqs_n[0]);

	// The command wires: CS_N, RAS_N, CAS_N, and WE_N
	xoddrserdes ddrcsn(mem_serial_clk, i_clk, ~w_ddr_reset_n,
		{ w_ddr_cmd_a[26], w_ddr_cmd_a[26],
		  w_ddr_cmd_a[26], w_ddr_cmd_a[26],
		  w_ddr_cmd_b[26], w_ddr_cmd_b[26],
		  w_ddr_cmd_b[26], w_ddr_cmd_b[26] }, o_ddr_cs_n);

	xoddrserdes ddrrasn(mem_serial_clk, i_clk, ~w_ddr_reset_n,
		{ w_ddr_cmd_a[25], w_ddr_cmd_a[25],
		  w_ddr_cmd_a[25], w_ddr_cmd_a[25],
		  w_ddr_cmd_b[25], w_ddr_cmd_b[25],
		  w_ddr_cmd_b[25], w_ddr_cmd_b[25] }, o_ddr_ras_n);

	xoddrserdes ddrcasn(mem_serial_clk, i_clk, ~w_ddr_reset_n,
		{ w_ddr_cmd_a[24], w_ddr_cmd_a[24],
		  w_ddr_cmd_a[24], w_ddr_cmd_a[24],
		  w_ddr_cmd_b[24], w_ddr_cmd_b[24],
		  w_ddr_cmd_b[24], w_ddr_cmd_b[24] }, o_ddr_cas_n);

	xoddrserdes ddrwen(mem_serial_clk, i_clk, ~w_ddr_reset_n,
		{ w_ddr_cmd_a[23], w_ddr_cmd_a[23],
		  w_ddr_cmd_a[23], w_ddr_cmd_a[23],
		  w_ddr_cmd_b[23], w_ddr_cmd_b[23],
		  w_ddr_cmd_b[23], w_ddr_cmd_b[23] }, o_ddr_we_n);

	// Data mask wires, first the upper byte
	xoddrserdes ddrudm(mem_serial_clk, i_clk, ~w_ddr_reset_n,
		{ w_ddr_cmd_a[4], w_ddr_cmd_a[4],
		  w_ddr_cmd_a[2], w_ddr_cmd_a[2],
		  w_ddr_cmd_b[4], w_ddr_cmd_b[4],
		  w_ddr_cmd_b[2], w_ddr_cmd_b[2] }, o_ddr_dm[1]);
	// then the lower byte
	xoddrserdes ddrldm(mem_serial_clk, i_clk, ~w_ddr_reset_n,
		{ w_ddr_cmd_a[3], w_ddr_cmd_a[3],
		  w_ddr_cmd_a[1], w_ddr_cmd_a[1],
		  w_ddr_cmd_b[3], w_ddr_cmd_b[3],
		  w_ddr_cmd_b[1], w_ddr_cmd_b[1] }, o_ddr_dm[0]);

	// and the On-Die termination wire
	xoddrserdes ddrodt(mem_serial_clk, i_clk, ~w_ddr_reset_n,
		{ w_ddr_cmd_a[0], w_ddr_cmd_a[0],
		  w_ddr_cmd_a[0], w_ddr_cmd_a[0],
		  w_ddr_cmd_b[0], w_ddr_cmd_b[0],
		  w_ddr_cmd_b[0], w_ddr_cmd_b[0] }, o_ddr_odt);

	//
	// Now for the data, bank, and address wires
	//
	genvar	k;
	generate begin
	//
	for(k=0; k<16; k=k+1)
		xioddrserdes ddrdata(mem_serial_clk, mem_serial_clk_inv, i_clk, ~w_ddr_reset_n,
				w_ddr_bus_oe,
			{ wo_ddr_data[48+k], wo_ddr_data[48+k],
			  wo_ddr_data[32+k], wo_ddr_data[32+k],
			  wo_ddr_data[16+k], wo_ddr_data[16+k],
			  wo_ddr_data[   k], wo_ddr_data[   k] },
			{ wide_ddr_data[112+k], wide_ddr_data[96+k],
			  wide_ddr_data[ 80+k], wide_ddr_data[64+k],
			  wide_ddr_data[ 48+k], wide_ddr_data[32+k],
			  wide_ddr_data[ 16+k], wide_ddr_data[   k] },
			io_ddr_data[k]);
	//
	for(k=0; k<3; k=k+1)
		xoddrserdes ddrbank(mem_serial_clk, i_clk, ~w_ddr_reset_n,
			{ w_ddr_cmd_a[20+k], w_ddr_cmd_a[20+k],
			  w_ddr_cmd_a[20+k], w_ddr_cmd_a[20+k],
			  w_ddr_cmd_b[20+k], w_ddr_cmd_b[20+k],
			  w_ddr_cmd_b[20+k], w_ddr_cmd_b[20+k] },
			o_ddr_ba[k]);
	//
	for(k=0; k<14; k=k+1)
		xoddrserdes ddraddr(mem_serial_clk, i_clk, ~w_ddr_reset_n,
			{ w_ddr_cmd_a[ 6+k], w_ddr_cmd_a[ 6+k],
			  w_ddr_cmd_a[ 6+k], w_ddr_cmd_a[ 6+k],
			  w_ddr_cmd_b[ 6+k], w_ddr_cmd_b[ 6+k],
			  w_ddr_cmd_b[ 6+k], w_ddr_cmd_b[ 6+k] },
			o_ddr_addr[k]);
	//

	for(k=0; k<64; k=k+1)
		assign wi_ddr_data[k] = (w_ddr_bus_oe) ? wide_ddr_data[2*k+1]
					: wide_ddr_data[2*k];
	end endgenerate

	assign	o_ddr_reset_n = w_ddr_reset_n;
	assign	o_ddr_cke = w_ddr_cke;


///
///
///
///
`else
	wire		w_ddr_reset_n, w_ddr_cke, w_ddr_bus_oe;
	wire	[26:0]	w_ddr_cmd_a, w_ddr_cmd_b;
	wire	[63:0]	wi_ddr_data, wo_ddr_data;
	wire	[127:0]	wide_ddr_data;

	//
	//
	// Wires for setting up the DDR3 memory
	//
	//

	// Leave the SDRAM in a permanent state of reset
	assign	o_ddr_reset_n = 1'b0;
	// Leave the SDRAM clock ... disabled
	assign	o_ddr_cke = 1'b0;

	// Disable the clock(s)
	OBUFDS(.I(1'b0), .O(o_ddr_ck_p), .OB(o_ddr_ck_n));
	// And the data strobe
	OBUFDS(.I(1'b0), .O(io_ddr_dqs_p[0]), .OB(io_ddr_dqs_n[0]));
	OBUFDS(.I(1'b0), .O(io_ddr_dqs_p[1]), .OB(io_ddr_dqs_n[1]));

	// Output ... something, anything, on the address lines
	assign	o_ddr_cs_n  = 1'b1;	// Never enable any commands
	assign	o_ddr_ras_n = 1'b0;
	assign	o_ddr_cas_n = 1'b0;
	assign	o_ddr_we_n  = 1'b0;
	assign	o_ddr_ba    = 3'h0;
	assign	o_ddr_addr  = 14'h0;
	assign	o_ddr_dm    = 2'b00;
	assign	o_ddr_odt   = 1'b0;

	assign	io_ddr_data = 16'bzzzz_zzzz_zzzz_zzzz;
	assign	wi_ddr_data = io_ddr_data;

`endif


	//////
	//
	//
	// The WB bus interconnect, herein called fastmaster, which handles
	// just about ... everything.
	//
	//
	//////
	wire		w_qspi_sck, w_qspi_cs_n;
	wire	[1:0]	qspi_bmod;
	wire	[3:0]	qspi_dat;
	wire	[3:0]	i_qspi_dat;

	//
	wire	[2:0]	w_ddr_dqs;
	wire	[31:0]	wo_ddr_data, wi_ddr_data;
	//
	wire		w_mdio, w_mdwe;
	//
	wire		w_sd_cmd;
	wire	[3:0]	w_sd_data;
	fastmaster	wbbus(s_clk, pwr_reset,
		// External USB-UART bus control
		rx_stb, rx_data, tx_stb, tx_data, tx_busy,
		// Board lights and switches
		i_sw, i_btn, o_led,
		o_clr_led0, o_clr_led1, o_clr_led2, o_clr_led3,
		// Board level PMod I/O
		i_aux_rx, o_aux_tx, o_aux_cts, i_gps_rx, o_gps_tx,
		// Quad SPI flash
		w_qspi_cs_n, w_qspi_sck, qspi_dat, i_qspi_dat, qspi_bmod,
		// DDR3 SDRAM
		w_ddr_reset_n, w_ddr_cke, w_ddr_bus_oe,
		w_ddr_cmd_a, w_ddr_cmd_b, wo_ddr_data, wi_ddr_data,
		// SD Card
		o_sd_sck, w_sd_cmd, w_sd_data, io_sd_cmd, io_sd, i_sd_cs,
		// Ethernet control (MDIO) lines
		o_eth_mdclk, w_mdio, w_mdwe, io_eth_mdio,
		// OLEDRGB PMod wires
		o_oled_sck, o_oled_cs_n, o_oled_mosi, o_oled_dcn,
		o_oled_reset_n, o_oled_vccen, o_oled_pmoden,
		// GPS PMod
		i_gps_pps, i_gps_3df
		);

	//////
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

	xoddr	xqspi_sck( i_clk, { w_qspi_sck,  w_qspi_sck }, o_qspi_sck);
	xoddr	xqspi_csn( i_clk, { w_qspi_cs_n, w_qspi_cs_n },o_qspi_cs_n);
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

	assign	i_qspi_dat = i_qspi_pedge;
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
	// Wires for setting up the DDR3 memory
	//
	//

/*
	wire	w_clk_for_ddr;
	ODDR	#(.DDR_CLK_EDGE("SAME_EDGE"))
		memclkddr(.Q(w_clk_for_ddr), .C(clk_for_ddr), .CE(1'b1),
			.D1(1'b0), .D2(1'b1), .R(1'b0), .S(1'b0));
	OBUFDS	#(.IOSTANDARD("DIFF_SSTL135"), .SLEW("FAST"))
		clkbuf(.O(o_ddr_ck_p), .OB(o_ddr_ck_n), .I(w_clk_for_ddr));
*/

endmodule

