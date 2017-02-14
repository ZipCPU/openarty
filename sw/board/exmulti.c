////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	exmulti.c
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Very similar to exstartup.c, the purpose of this program is to
//		demonstrate several working peripherals.  To the exstartup
//	peripherals, we'll add the GPS and the GPS PPS tracking.
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
#include "artyboard.h"
#include "zipcpu.h"
#include "zipsys.h"
#include <stdio.h>

#define	sys	_sys

#define	udivdi3	__udivdi3
#include "udiv.c"

void	idle_task(void) {
	while(1)
		zip_idle();
}

void	wait_on_interrupt(int mask) {
	if (mask & SYSINT_AUX) {
		zip->z_apic = INT_ENABLE;
	}
	zip->z_pic = DALLPIC|mask;
	zip->z_pic = EINT(mask);
	zip_rtu();
}

int	user_stack[256];
void	user_task(void) {
	const unsigned white = 0x070707, black = 0;
	while(1) {
		unsigned	btn, subnow, sw;

		subnow = (sys->io_b.i_tim.sub >> 28)&0x0f;

		// If the button is pressed, toggle the LED
		// Otherwise, turn the LED off.
		//

		// First, get all the pressed buttons
		btn = (sys->io_b.i_btnsw) & 0x0f0;
		// Now, acknowledge the button presses that we just read
		sys->io_b.i_btnsw = btn;
		btn >>= 4;

		// Now, use the time as the toggle function.
		btn = (subnow ^ btn)&btn & 0x07;

		sys->io_b.i_leds = btn | 0x070;

		sw = sys->io_b.i_btnsw & 0x0f;
		for(int i=0; i<4; i++)
			sys->io_b.i_clrled[i] = (sw & (1<<i)) ? white : black;

	}
}

int	mpyuhi(int a, int b) {
	// err_in_ns = mpyuhi(err_in_ns, err);
	// __asm__("MPYUHI %1,%0" :"+r"(a):"r"(b));
	unsigned alo, blo, ahi, bhi, f, o, i, l, rhi;

	alo = (a & 0x0ffff);
	ahi = (a >> 16)&0x0ffff;
	blo = (b & 0x0ffff);
	bhi = (b >> 16)&0x0ffff;

	l = alo * blo;
	o = ahi * blo;
	i = alo * bhi;
	f = ahi * bhi;

	rhi = o + i + (l >> 16);
	return (rhi >> 16) + f;
	// return f;
	// return ahi;
}

char	errstring[128];


void	main(int argc, char **argv) {
	const unsigned red = 0x0ff0000, green = 0x0ff00, blue = 0x0ff,
		white = 0x070707, black = 0, dimgreen = 0x1f00,
		second = CLOCKFREQHZ;
	int	i, sw;

	// Start the GPS converging ...
	sys->io_gps.g_alpha = 2;
	sys->io_gps.g_beta  = 0x14bda12f;
	sys->io_gps.g_gamma = 0x1f533ae8;

	// 
	sys->io_uart.u_setup = 82;

	int	user_context[16];
	for(i=0; i<15; i++)
		user_context[i] = 0;
	user_context[15] = (unsigned)idle_task;
	zip_restore_context(user_context);

	for(i=0; i<4; i++)
		sys->io_b.i_clrled[i] = red;
	sys->io_b.i_leds = 0x0ff;

	// Clear the PIC
	//
	//	Acknowledge all interrupts, turn off all interrupts
	//
	zip->z_pic = CLEARPIC;
	while(sys->io_b.i_pwrcount < (second >> 4))
		;

	// Repeating timer, every 250ms
	zip->z_tma = TMR_INTERVAL | (second/4);
	wait_on_interrupt(SYSINT_TMA);

	sys->io_b.i_clrled[0] = green;
	sys->io_b.i_leds = 0x010;

	wait_on_interrupt(SYSINT_TMA);

	sys->io_b.i_clrled[0] = dimgreen;
	sys->io_b.i_clrled[1] = green;
	sys->io_scope[0].s_ctrl = WBSCOPE_NO_RESET | 32;
	sys->io_b.i_leds = 0x020;

	wait_on_interrupt(SYSINT_TMA);

	sys->io_b.i_clrled[1] = dimgreen;
	sys->io_b.i_clrled[2] = green;
	sys->io_b.i_leds = 0x040;

	wait_on_interrupt(SYSINT_TMA);

	sys->io_b.i_clrled[2] = dimgreen;
	sys->io_b.i_clrled[3] = green;
	sys->io_b.i_leds = 0x080;

	wait_on_interrupt(SYSINT_TMA);

	sys->io_b.i_clrled[3] = dimgreen;

	wait_on_interrupt(SYSINT_TMA);

	for(i=0; i<4; i++)
		sys->io_b.i_clrled[i] = black;

	// Wait one second ...
	for(i=0; i<4; i++)
		wait_on_interrupt(SYSINT_TMA);

	// Blink all the LEDs
	//	First turn them on
	sys->io_b.i_leds = 0x0ff;
	// Then wait a quarter second
	wait_on_interrupt(SYSINT_TMA);
	// Then turn the back off
	sys->io_b.i_leds = 0x0f0;
	// and wait another quarter second
	wait_on_interrupt(SYSINT_TMA);

	// Now, read buttons, and flash an LED on any button being held
	// down ... ? neat?

	// Now, let's synchronize ourselves to the PPS
	user_context[13] = (int)&user_stack[256];
	user_context[15] = (int)&user_task;
	zip_restore_context(user_context);

	do {
		wait_on_interrupt(SYSINT_PPS|SYSINT_TMA);
	} while((zip->z_pic & SYSINT_PPS)==0);
	
	while(1) {
		char	*s = errstring;

		zip->z_wdt = CLOCKFREQ_HZ*4;
		sys->io_b.i_leds = 0x088;

		// 1. Read and report the GPS tracking err

		// Get the upper 32-bits of the error;
		int	err = *(int *)(&sys->io_gpstb.tb_err);
		int	err_in_ns, err_in_us;
		/*
		long	err_in_ns_long = err;
		err_in_ns_long *= 1000000000l;
		err_in_ns_long >>= 32;
		int	err_in_ns = (int)(err_in_ns_long);
		*/
		int	err_sgn = (err < 0)?1:0, err_in_ns_rem;
		err_in_ns = (err<0)?-err:err;
		err_in_ns = mpyuhi(err_in_ns, 1000000000);

		err_in_us = err_in_ns / 1000;
		err_in_ns_rem = err_in_ns - err_in_us * 1000;
		if (err_sgn)
			err_in_us = - err_in_us;

		printf("\r\nTmp (%s) %d\n", (err == 0) ? "Z":".", err);
		printf("\r\nGPS PPS Err: 0x%08x => 0x%08x => %+5d.%03d us\r\n",
			err, err_in_ns, err_in_us, err_in_ns_rem);
		printf("\r\n        Err: 0x%08x => 0x%08x\r\n",
			err_in_us, err_in_ns_rem);



		sys->io_b.i_leds = 0x080;

		zip->z_pic  = SYSINT_GPSRXF | SYSINT_PPS;
		do {
			int	v;
			wait_on_interrupt(SYSINT_PPS|SYSINT_GPSRXF);

			while(((v = sys->io_gpsu.u_rx)&0x100)==0)
				sys->io_uart.u_tx = v & 0x0ff;
			/*
			while((sys->io_gpsu.u_fifo & 1)==0) {
				int	v = sys->io_gpsu.u_rx;
				if ((v & 0x100)==0)
					sys->io_uart.u_tx = v & 0x0ff;
			}
			*/
		} while((zip->z_pic & SYSINT_PPS)==0);

		// wait_on_interrupt(SYSINT_PPS);
		// zip->z_dma.d_ctrl= DMACLEAR;
	}

	zip_halt();
}

