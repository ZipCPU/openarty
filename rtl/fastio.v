////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	fastio.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This file is used to group all of the simple I/O registers
//		together.  These are the I/O registers whose values can be
//	read without requesting it of any submodules, and that are guaranteed
//	not to stall the bus.  In general, these are items that can be read
//	or written in one clock (two, if an extra delay is needed to match
//	timing requirements).
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
		i_gpio, o_gpio,
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
	output	wire	[2:0]	o_clr_led0;
	output	wire	[2:0]	o_clr_led1;
	output	wire	[2:0]	o_clr_led2;
	output	wire	[2:0]	o_clr_led3;
	// Board level PMod I/O
	//
	// GPIO
	input		[(NGPI-1):0]	i_gpio;
	output wire	[(NGPO-1):0]	o_gpio;
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
	input	wire	[11:0]	i_other_ints;
	output	wire		o_bus_int;
	output	wire	[2:0]	o_board_ints; // Button and switch interrupts

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
		gpsrx_int, auxrx_int, auxtx_int,
		gpio_int, flash_int, scop_int,
		sdcard_int, oled_int, zip_int;
	assign { zip_int,
			gpsrx_int, auxtx_int, auxrx_int,
			oled_int, rtc_int, sdcard_int,
			nettx_int, netrx_int, scop_int, flash_int,
			pps_int } = i_other_ints;

	//
	// The BUS Interrupt controller
	//
	icontrol #(15)	buspic(i_clk, 1'b0,
		(w_wb_stb)&&(w_wb_addr==5'h1),
			i_wb_data, pic_data,
		{ zip_int, oled_int, sdcard_int,
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
			pwr_counter[30:0] <= pwr_counter[30:0] + 1'b1;
		else
			pwr_counter[31:0] <= pwr_counter[31:0] + 1'b1;

	//
	// These pwr_counter bits are used for generating a PWM modulated
	// color LED output--allowing us to create multiple different, varied,
	// color LED "colors".  Here, we reverse the bits, to make their
	// transitions and PWM that much *less* noticable.  (a 50%
	// value, thus, is now an on-off-on-off-etc sequence, vice a 
	// sequence of 256 ons followed by a sequence of 256 offs --- it
	// places the transitions into a higher frequency bracket, and costs
	// us no logic to do--only a touch more pain to understand on behalf
	// of the programmer.)
	wire	[8:0]	rev_pwr_counter;
	assign rev_pwr_counter[8:0] = { pwr_counter[0],
			pwr_counter[1], pwr_counter[2],
			pwr_counter[3], pwr_counter[4],
			pwr_counter[5], pwr_counter[6],
			pwr_counter[7], pwr_counter[8] };

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
	wbgpio	#(NGPI, NGPO)
		gpioi(i_clk, 1'b1, (w_wb_stb)&&(w_wb_addr == 5'h6), 1'b1,
			w_wb_data, gpio_data, i_gpio, o_gpio, gpio_int);

	//
	// The Calendar DATE
	//
	wire	[31:0]	date_data;
`define	GET_DATE
`ifdef	GET_DATE
	wire	date_ack, date_stall;
	rtcdate	thedate(i_clk, i_rtc_ppd,
		i_wb_cyc, w_wb_stb, (w_wb_addr==5'h7), w_wb_data,
			date_ack, date_stall, date_data);
`else
	assign	date_data = 32'h20170000;
`endif

	//
	// CLR LEDs
	//
	wire	[31:0]	w_clr_led0, w_clr_led1, w_clr_led2, w_clr_led3;
	clrled	clrled0(i_clk, (w_wb_stb)&&(w_wb_addr==5'h8), w_wb_data,
				pwr_counter[8:0], w_clr_led0, o_clr_led0);
	clrled	clrled1(i_clk, (w_wb_stb)&&(w_wb_addr==5'h9), w_wb_data,
				pwr_counter[8:0], w_clr_led1, o_clr_led1);
	clrled	clrled2(i_clk, (w_wb_stb)&&(w_wb_addr==5'ha), w_wb_data,
				pwr_counter[8:0], w_clr_led2, o_clr_led2);
	clrled	clrled3(i_clk, (w_wb_stb)&&(w_wb_addr==5'hb), w_wb_data,
				pwr_counter[8:0], w_clr_led3, o_clr_led3);

	reg	[32:0]	sec_step;
	initial	sec_step = 33'h1;
	always @(posedge i_clk)
		if ((w_wb_stb)&&(w_wb_addr == 5'h0c))
			sec_step <= { 1'b1, w_wb_data };
		else if (!pps_int)
			sec_step <= 33'h1;

	reg	[31:0]	time_now_secs;
	initial	time_now_secs = 32'h00;
	always @(posedge i_clk)
		if (pps_int)
			time_now_secs <= time_now_secs + sec_step[31:0];
		else if (sec_step[32])
			time_now_secs <= time_now_secs + sec_step[31:0];

	always @(posedge i_clk)
		case(i_wb_addr)
		5'h00: o_wb_data <= `DATESTAMP;
		5'h01: o_wb_data <= pic_data;
		5'h02: o_wb_data <= i_buserr;
		5'h03: o_wb_data <= pwr_counter;
		5'h04: o_wb_data <= w_btnsw;
		5'h05: o_wb_data <= w_ledreg;
		5'h06: o_wb_data <= date_data;
		5'h07: o_wb_data <= gpio_data;
		5'h08: o_wb_data <= w_clr_led0;
		5'h09: o_wb_data <= w_clr_led1;
		5'h0a: o_wb_data <= w_clr_led2;
		5'h0b: o_wb_data <= w_clr_led3;
		5'h0c: o_wb_data <= time_now_secs;
		5'h0d: o_wb_data <= i_gps_sub;
		5'h0e: o_wb_data <= i_gps_step;
		default: o_wb_data <= 32'h00;
		endcase

	assign	o_wb_stall = 1'b0;
	always @(posedge i_clk)
		o_wb_ack <= (i_wb_stb);
	assign	o_board_ints = { gpio_int, sw_int, btn_int };


endmodule
