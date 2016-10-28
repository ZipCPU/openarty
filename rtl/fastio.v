////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	fastio.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	
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
`include "builddate.v"
//
module	fastio(i_clk,
		// Board level I/O
		i_sw, i_btn, o_led,
		o_clr_led0, o_clr_led1, o_clr_led2, o_clr_led3,
		// Board level PMod I/O
		i_aux_rx, o_aux_tx, o_aux_cts, i_gps_rx, o_gps_tx,
`ifdef	USE_GPIO
		i_gpio, o_gpio,
`endif
		// Wishbone control
		i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr,
			i_wb_data, o_wb_ack, o_wb_stall, o_wb_data,
		// Cross-board I/O
		i_rtc_ppd, i_buserr, i_gps_sub, i_gps_step, i_other_ints, o_bus_int, o_board_ints);
	parameter	AUXUART_SETUP = 30'd1736, // 115200 baud from 200MHz clk
			GPSUART_SETUP = 30'd20833, // 9600 baud from 200MHz clk
			EXTRACLOCK = 1, // Do we need an extra clock to process?
			NGPI=0, NGPO=0; // Number of GPIO in and out wires
	input			i_clk;
	// Board level I/O
	input		[3:0]	i_sw;
	input		[3:0]	i_btn;
	output	wire	[3:0]	o_led;
	output	reg	[2:0]	o_clr_led0;
	output	reg	[2:0]	o_clr_led1;
	output	reg	[2:0]	o_clr_led2;
	output	reg	[2:0]	o_clr_led3;
	// Board level PMod I/O
	//
	// Auxilliary UART I/O
	input		i_aux_rx;
	output	wire	o_aux_tx, o_aux_cts;
	//
	// GPS UART I/O
	input		i_gps_rx;
	output	wire	o_gps_tx;
	//
`ifdef	USE_GPIO
	// GPIO
	input		[(NGPI-1):0]	i_gpio;
	output reg	[(NGPO-1):0]	o_gpio;
`endif
	//
	// Wishbone inputs
	input			i_wb_cyc, i_wb_stb, i_wb_we;
	input		[4:0]	i_wb_addr;
	input		[31:0]	i_wb_data;
	// Wishbone outputs
	output	reg		o_wb_ack;
	output	wire		o_wb_stall;
	output	reg	[31:0]	o_wb_data;
	// A strobe at midnight, to keep the calendar on "time"
	input			i_rtc_ppd;
	// Address of the last bus error
	input		[31:0]	i_buserr;
	// The current time, as produced by the GPS tracking processor
	input		[31:0]	i_gps_sub, i_gps_step;
	//
	// Interrupts -- both the output bus interrupt, as well as those
	//	internally generated interrupts which may be used elsewhere
	// 	in the design
	input	wire	[8:0]	i_other_ints;
	output	wire		o_bus_int;
	output	wire	[6:0]	o_board_ints; // Button and switch interrupts

	wire	[31:0]	w_wb_data;
	wire	[4:0]	w_wb_addr;
	wire		w_wb_stb;

	generate
	if (EXTRACLOCK == 0)
	begin
		assign	w_wb_data = i_wb_data;
		assign	w_wb_addr = i_wb_addr;
		assign	w_wb_stb = (i_wb_stb)&&(i_wb_we);
	end else begin
		reg		last_wb_stb;
		reg	[4:0]	last_wb_addr;
		reg	[31:0]	last_wb_data;
		initial	last_wb_stb = 1'b0;
		always @(posedge i_clk)
		begin
			last_wb_addr <= i_wb_addr;
			last_wb_data <= i_wb_data;
			last_wb_stb  <= (i_wb_stb)&&(i_wb_we);
		end

		assign	w_wb_data = last_wb_data;
		assign	w_wb_addr = last_wb_addr;
		assign	w_wb_stb  = last_wb_stb;
	end endgenerate

	wire	[31:0]	pic_data;
	reg	sw_int, btn_int;
	wire	pps_int, rtc_int, netrx_int, nettx_int,
		auxrx_int, auxtx_int, gpio_int, flash_int, scop_int,
		gpsrx_int, gpstx_int, sd_int, oled_int, zip_int;
	assign { zip_int, oled_int, rtc_int, sd_int,
			nettx_int, netrx_int, scop_int, flash_int,
			pps_int } = i_other_ints;

	//
	// The BUS Interrupt controller
	//
	icontrol #(15)	buspic(i_clk, 1'b0,
		(w_wb_stb)&&(w_wb_addr==5'h1),
			i_wb_data, pic_data,
		{ zip_int, oled_int, sd_int,
			gpsrx_int, scop_int, flash_int, gpio_int,
			auxtx_int, auxrx_int, nettx_int, netrx_int,
			rtc_int, pps_int, sw_int, btn_int },
			o_bus_int);

	// 
	// PWR Count
	// 
	// A 32-bit counter that starts at power up and never resets.  It's a
	// read only counter if you will.
	reg	[31:0]	pwr_counter;
	initial	pwr_counter = 32'h00;
	always @(posedge i_clk)
		if (pwr_counter[31])
			pwr_counter[30:0] <= pwr_counter[30:0] + 31'h001;
		else
			pwr_counter[31:0] <= pwr_counter[31:0] + 31'h001;

	//
	// BTNSW
	//
	// The button and switch control register
	wire	[31:0]	w_btnsw;
	reg	[3:0]	r_sw,  swcfg,  swnow,  swlast;
	reg	[3:0]	r_btn, btncfg, btnnow, btnlast, btnstate;
	initial	btn_int = 1'b0;
	initial	sw_int  = 1'b0;
	always @(posedge i_clk)
	begin
		r_sw <= i_sw;
		swnow <= r_sw;
		swlast<= swnow;
		sw_int <= |((swnow^swlast)|swcfg);

		if ((w_wb_stb)&&(w_wb_addr == 5'h4))
			swcfg <= ((w_wb_data[3:0])&(w_wb_data[11:8]))
					|((~w_wb_data[3:0])&(swcfg));

		r_btn <= i_btn;
		btnnow <= r_btn;
		btn_int <= |(btnnow&btncfg);
		if ((w_wb_stb)&&(w_wb_addr == 5'h4))
		begin
			btncfg <= ((w_wb_data[7:4])&(w_wb_data[15:12]))
					|((~w_wb_data[7:4])&(btncfg));
			btnstate<= (btnnow)|((btnstate)&(~w_wb_data[7:4]));
		end else
			btnstate <= (btnstate)|(btnnow);
	end
	assign	w_btnsw = { 8'h00, btnnow, 4'h0, btncfg, swcfg, btnstate, swnow };

	//
	// LEDCTRL
	//
	reg	[3:0]	r_leds;
	wire	[31:0]	w_ledreg;
	initial	r_leds = 4'h0;
	always @(posedge i_clk)
		if ((w_wb_stb)&&(w_wb_addr == 5'h5))
			r_leds <= ((w_wb_data[7:4])&(w_wb_data[3:0]))
				|((~w_wb_data[7:4])&(r_leds));
	assign	o_led = r_leds;
	assign	w_ledreg = { 28'h0, r_leds  };

	//
	// GPIO
	//
	// Not used (yet), but this interface should allow us to control up to
	// 16 GPIO inputs, and another 16 GPIO outputs.  The interrupt trips
	// when any of the inputs changes.  (Sorry, which input isn't (yet)
	// selectable.)
	//
	wire	[31:0]	gpio_data;
`ifdef	USE_GPIO
	wbgpio	#(NIN, NOUT)
		gpioi(i_clk, w_wb_cyc, (w_wb_stb)&&(w_wb_addr == 5'hd), 1'b1,
			w_wb_data, gpio_data, i_gpio, o_gpio, gpio_int);
`else
	assign	gpio_data = 32'h00;
	assign	gpio_int = 1'b0;
`endif

	//
	// AUX (UART) SETUP
	//
	// Set us up for 4Mbaud, 8 data bits, no stop bits.
	reg	[29:0]	aux_setup;
	initial	aux_setup = AUXUART_SETUP;
	always @(posedge i_clk)
		if ((w_wb_stb)&&(w_wb_addr == 5'h6))
			aux_setup[29:0] <= w_wb_data[29:0];

	//
	// GPSSETUP
	//
	// Set us up for 9600 kbaud, 8 data bits, no stop bits.
	reg	[29:0]	gps_setup;
	initial	gps_setup = GPSUART_SETUP;
	always @(posedge i_clk)
		if ((w_wb_stb)&&(w_wb_addr == 5'h7))
			gps_setup[29:0] <= w_wb_data[29:0];

	//
	// CLR LEDs
	//

	// CLR LED 0
	wire	[31:0]	w_clr_led0;
	reg	[8:0]	r_clr_led0_r, r_clr_led0_g, r_clr_led0_b;
	initial	r_clr_led0_r = 9'h003; // Color LED on the far right
	initial	r_clr_led0_g = 9'h000;
	initial	r_clr_led0_b = 9'h000;
	always @(posedge i_clk)
		if ((w_wb_stb)&&(w_wb_addr == 5'h8))
		begin
			r_clr_led0_r <= { w_wb_data[26], w_wb_data[23:16] };
			r_clr_led0_g <= { w_wb_data[25], w_wb_data[15: 8] };
			r_clr_led0_b <= { w_wb_data[24], w_wb_data[ 7: 0] };
		end
	assign	w_clr_led0 = { 5'h0,
			r_clr_led0_r[8], r_clr_led0_g[8], r_clr_led0_b[8],
			r_clr_led0_r[7:0], r_clr_led0_g[7:0], r_clr_led0_b[7:0]
		};
	always @(posedge i_clk)
		o_clr_led0 <= {	(pwr_counter[8:0] < r_clr_led0_r),
				(pwr_counter[8:0] < r_clr_led0_g),
				(pwr_counter[8:0] < r_clr_led0_b) };

	// CLR LED 1
	wire	[31:0]	w_clr_led1;
	reg	[8:0]	r_clr_led1_r, r_clr_led1_g, r_clr_led1_b;
	initial	r_clr_led1_r = 9'h007;
	initial	r_clr_led1_g = 9'h000;
	initial	r_clr_led1_b = 9'h000;
	always @(posedge i_clk)
		if ((w_wb_stb)&&(w_wb_addr == 5'h9))
		begin
			r_clr_led1_r <= { w_wb_data[26], w_wb_data[23:16] };
			r_clr_led1_g <= { w_wb_data[25], w_wb_data[15: 8] };
			r_clr_led1_b <= { w_wb_data[24], w_wb_data[ 7: 0] };
		end
	assign	w_clr_led1 = { 5'h0,
			r_clr_led1_r[8], r_clr_led1_g[8], r_clr_led1_b[8],
			r_clr_led1_r[7:0], r_clr_led1_g[7:0], r_clr_led1_b[7:0]
		};
	always @(posedge i_clk)
		o_clr_led1 <= {	(pwr_counter[8:0] < r_clr_led1_r),
				(pwr_counter[8:0] < r_clr_led1_g),
				(pwr_counter[8:0] < r_clr_led1_b) };
	// CLR LED 0
	wire	[31:0]	w_clr_led2;
	reg	[8:0]	r_clr_led2_r, r_clr_led2_g, r_clr_led2_b;
	initial	r_clr_led2_r = 9'h00f;
	initial	r_clr_led2_g = 9'h000;
	initial	r_clr_led2_b = 9'h000;
	always @(posedge i_clk)
		if ((w_wb_stb)&&(w_wb_addr == 5'ha))
		begin
			r_clr_led2_r <= { w_wb_data[26], w_wb_data[23:16] };
			r_clr_led2_g <= { w_wb_data[25], w_wb_data[15: 8] };
			r_clr_led2_b <= { w_wb_data[24], w_wb_data[ 7: 0] };
		end
	assign	w_clr_led2 = { 5'h0,
			r_clr_led2_r[8], r_clr_led2_g[8], r_clr_led2_b[8],
			r_clr_led2_r[7:0], r_clr_led2_g[7:0], r_clr_led2_b[7:0]
		};
	always @(posedge i_clk)
		o_clr_led2 <= {	(pwr_counter[8:0] < r_clr_led2_r),
				(pwr_counter[8:0] < r_clr_led2_g),
				(pwr_counter[8:0] < r_clr_led2_b) };
	// CLR LED 3
	wire	[31:0]	w_clr_led3;
	reg	[8:0]	r_clr_led3_r, r_clr_led3_g, r_clr_led3_b;
	initial	r_clr_led3_r = 9'h01f; // LED is on far left
	initial	r_clr_led3_g = 9'h000;
	initial	r_clr_led3_b = 9'h000;
	always @(posedge i_clk)
		if ((w_wb_stb)&&(w_wb_addr == 5'hb))
		begin
			r_clr_led3_r <= { w_wb_data[26], w_wb_data[23:16] };
			r_clr_led3_g <= { w_wb_data[25], w_wb_data[15: 8] };
			r_clr_led3_b <= { w_wb_data[24], w_wb_data[ 7: 0] };
		end
	assign	w_clr_led3 = { 5'h0,
			r_clr_led3_r[8], r_clr_led3_g[8], r_clr_led3_b[8],
			r_clr_led3_r[7:0], r_clr_led3_g[7:0], r_clr_led3_b[7:0]
		};
	always @(posedge i_clk)
		o_clr_led3 <= {	(pwr_counter[8:0] < r_clr_led3_r),
				(pwr_counter[8:0] < r_clr_led3_g),
				(pwr_counter[8:0] < r_clr_led3_b) };

	//
	// The Calendar DATE
	//
	wire	[31:0]	date_data;
`define	GET_DATE
`ifdef	GET_DATE
	wire	date_ack, date_stall;
	rtcdate	thedate(i_clk, i_rtc_ppd,
		i_wb_cyc, w_wb_stb, (w_wb_addr==5'hc), w_wb_data,
			date_ack, date_stall, date_data);
`else
	assign	date_data = 32'h20160000;
`endif

	//////
	//
	// The auxilliary UART
	//
	//////

	//
	// First the Auxilliary UART receiver
	//
	wire	auxrx_stb, auxrx_break, auxrx_perr, auxrx_ferr, auxck_uart;
	wire	[7:0]	rx_data_aux_port;
	rxuart	auxrx(i_clk, 1'b0, aux_setup, i_aux_rx,
			auxrx_stb, rx_data_aux_port, auxrx_break,
			auxrx_perr, auxrx_ferr, auxck_uart);

	wire	[31:0]	auxrx_data;
	reg	[11:0]	r_auxrx_data;
	always @(posedge i_clk)
		if (auxrx_stb)
		begin
			r_auxrx_data[11] <= auxrx_break;
			r_auxrx_data[10] <= auxrx_ferr;
			r_auxrx_data[ 9] <= auxrx_perr;
			r_auxrx_data[7:0]<= rx_data_aux_port;
		end
	always @(posedge i_clk)
		if(((i_wb_stb)&&(~i_wb_we)&&(i_wb_addr == 5'h0e))||(auxrx_stb))
			r_auxrx_data[8] <= !auxrx_stb;
	assign	o_aux_cts = auxrx_stb;
	assign	auxrx_data = { 20'h00, r_auxrx_data };
	assign	auxrx_int = !r_auxrx_data[8];

	//
	// Then the auxilliary UART transmitter
	//
	wire	auxtx_busy;
	reg	[7:0]	r_auxtx_data;
	reg		r_auxtx_stb, r_auxtx_break;
	wire	[31:0]	auxtx_data;
	txuart	auxtx(i_clk, 1'b0, aux_setup,
			r_auxtx_break, r_auxtx_stb, r_auxtx_data,
			o_aux_tx, auxtx_busy);
	always @(posedge i_clk)
		if ((w_wb_stb)&&(w_wb_addr == 5'h0f))
		begin
			r_auxtx_stb <= (!r_auxtx_break)&&(!w_wb_data[9]);
			r_auxtx_data <= w_wb_data[7:0];
			r_auxtx_break<= w_wb_data[9];
		end else if (~auxtx_busy)
		begin
			r_auxtx_stb <= 1'b0;
			r_auxtx_data <= 8'h0;
		end
	assign	auxtx_data = { 20'h00,
		1'b0, o_aux_tx, r_auxtx_break, auxtx_busy,
		r_auxtx_data };
	assign	auxtx_int = ~auxtx_busy;

	//////
	//
	// The GPS UART
	//
	//////

	// First the receiver
	wire	gpsrx_stb, gpsrx_break, gpsrx_perr, gpsrx_ferr, gpsck_uart;
	wire	[7:0]	rx_data_gps_port;
	rxuart	gpsrx(i_clk, 1'b0, gps_setup, i_gps_rx,
			gpsrx_stb, rx_data_gps_port, gpsrx_break,
			gpsrx_perr, gpsrx_ferr, gpsck_uart);

	wire	[31:0]	gpsrx_data;
	reg	[11:0]	r_gpsrx_data;
	always @(posedge i_clk)
		if (gpsrx_stb)
		begin
			r_gpsrx_data[11] <= gpsrx_break;
			r_gpsrx_data[10] <= gpsrx_ferr;
			r_gpsrx_data[ 9] <= gpsrx_perr;
			r_gpsrx_data[7:0]<= rx_data_gps_port;
		end
	always @(posedge i_clk)
		if(((i_wb_stb)&&(~i_wb_we)&&(i_wb_addr == 5'h10))||(gpsrx_stb))
			r_gpsrx_data[8] <= !gpsrx_stb;
	assign	gpsrx_data = { 20'h00, r_gpsrx_data };
	assign	gpsrx_int = !r_gpsrx_data[8];


	// Then the transmitter
	reg		r_gpstx_break, r_gpstx_stb;
	reg	[7:0]	r_gpstx_data;
	wire		gpstx_busy;
	wire	[31:0]	gpstx_data;
	txuart	gpstx(i_clk, 1'b0, gps_setup,
			r_gpstx_break, r_gpstx_stb, r_gpstx_data,
			o_gps_tx, gpstx_busy);
	always @(posedge i_clk)
		if ((w_wb_stb)&&(w_wb_addr == 5'h11))
		begin
			r_gpstx_stb <= 1'b1;
			r_gpstx_data <= w_wb_data[7:0];
			r_gpstx_break<= w_wb_data[9];
		end else if (~gpstx_busy)
		begin
			r_gpstx_stb <= 1'b0;
			r_gpstx_data <= 8'h0;
		end
	assign	gpstx_data = { 20'h00,
		gpsck_uart, o_gps_tx, r_gpstx_break, gpstx_busy,
		r_gpstx_data };
	assign	gpstx_int = !gpstx_busy;

	always @(posedge i_clk)
		case(i_wb_addr)
		5'h00: o_wb_data <= `DATESTAMP;
		5'h01: o_wb_data <= pic_data;
		5'h02: o_wb_data <= i_buserr;
		5'h03: o_wb_data <= pwr_counter;
		5'h04: o_wb_data <= w_btnsw;
		5'h05: o_wb_data <= w_ledreg;
		5'h06: o_wb_data <= { 2'b00, aux_setup };
		5'h07: o_wb_data <= { 2'b00, gps_setup };
		5'h08: o_wb_data <= w_clr_led0;
		5'h09: o_wb_data <= w_clr_led1;
		5'h0a: o_wb_data <= w_clr_led2;
		5'h0b: o_wb_data <= w_clr_led3;
		5'h0c: o_wb_data <= date_data;
		5'h0d: o_wb_data <= gpio_data;
		5'h0e: o_wb_data <= auxrx_data;
		5'h0f: o_wb_data <= auxtx_data;
		5'h10: o_wb_data <= gpsrx_data;
		5'h11: o_wb_data <= gpstx_data;
		// 5'h12: o_wb_data <= i_gps_secs;
		5'h13: o_wb_data <= i_gps_sub;
		5'h14: o_wb_data <= i_gps_step;
		// 5'hf: UART_SETUP
		// 4'h6: GPIO
		// ?? : GPS-UARTRX
		// ?? : GPS-UARTTX
		default: o_wb_data <= 32'h00;
		endcase

	assign	o_wb_stall = 1'b0;
	always @(posedge i_clk)
		o_wb_ack <= (i_wb_stb);
	assign	o_board_ints = { gpio_int, auxrx_int, auxtx_int,
			gpsrx_int, gpstx_int, sw_int, btn_int };


endmodule
