////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	exmulti.c
// {{{
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
// }}}
// Copyright (C) 2015-2024, Gisselquist Technology, LLC
// {{{
// This file is part of the OpenArty project.
//
// The OpenArty project is free software and gateware, licensed under the terms
// of the 3rd version of the GNU General Public License as published by the
// Free Software Foundation.
//
// This project is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
// }}}
#include "board.h"
#include "zipcpu.h"
#include "zipsys.h"
#include <stdio.h>
#include <string.h>

void	idle_task(void) {
	while(1)
		zip_idle();
}

void	wait_on_interrupt(int mask) {
	if (mask & SYSINT_AUX) {
		_zip->z_apic = INT_ENABLE;
	}
	// Disable all interrupts, clear this one
	_zip->z_pic = DALLPIC | mask;
	_zip->z_pic = EINT(mask);
	zip_rtu();
}

int	user_stack[256];
void	user_task(void) {
	const unsigned white = 0x070707, black = 0;
	while(1) {
#ifdef	_BOARD_HAS_SPIO
#ifdef	_BOARD_HAS_CLRLED
		unsigned	btn, subnow, sw;

#ifdef	_BOARD_HAS_GPSTB
		subnow = ((*(unsigned *)(&_gpstb->tb_count)) >> 28)&0x0f;
#endif

		// If the button is pressed, toggle the LED
		// Otherwise, turn the LED off.
		//

		// First, get all the pressed buttons
		btn = *_spio && 0x0ff0000;
		// Now, acknowledge the button presses that we just read
		*_spio = btn;
		btn >>= 16;

		// Now, use the time as the toggle function.
		btn = (subnow ^ btn)&btn & 0x07;

		// *_spio = (btn << 24);

		sw = (*_spio & 0x0ff00)>>8;
		for(int i=0; i<4; i++)
			_clrled[i] = (sw & (1<<i)) ? white : black;

#endif
#endif
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

#ifdef	GPSUART_ACCESS
int	gps_lock = 0;
void	gps_process_line(const char *line) {
	if ((line[0] != '$')||(line[1] != 'G')
			||(line[2] != 'P'))
		return;

	// GGA, GSV(x3), RMC, VTG
	if (line[3] == 'G') {
		/*
		if ((line[4] == 'G')&&(line[5] == 'A')) {
		} // else if ((line[5] == 'S')&&(line[6] == 'V')) {
		}
		*/
		// printf("GPS Line: %s\r\n", line);
	} else if (line[3] == 'R') {
		// if ((line[4] == 'M')&&(line[5] == 'C')&&(line[6] == ','))
		{
			// char	outbuf[256], *outptr = outbuf;
			// const char *here = &line[8], *there;
			// there = strchr(here, ',');
			fputs("RMC-Line\r\n", stdout);
#ifdef	PROCLINE
			if ((there)&&(there - here > 6)) {
				outptr += sprintf(outptr,
					"TIME: %c%c:%c%c:%c%c\r\n", 
						here[0], here[1],
						here[2], here[3],
						here[4], here[5]);
				here = there + 1;
				there = strchr(here, ',');
			} if (there) {
				if (*here == 'A')
					gps_lock = 1;
				else
					gps_lock = 0;
				here = there + 1;
				there = strchr(there+1, ',');
			} if (there) {
				there = strchr(there+1, ',');
			} if (there) {
				char	tmp[32];
				strncpy(tmp, here, there-here);
				outptr += sprintf(outptr, "LATITUDE: %s\r\n");
				here = there + 1;
				there = strchr(there+1, ',');
			} if (there) {
				there = strchr(there+1, ',');
			} if (there) {
				char	tmp[32];
				strncpy(tmp, here, there-here);
				outptr += sprintf(outptr, "LONGITUDE: %s\r\n");
			} if (gps_lock)
				fputs(outbuf, stdout);
			else	puts("No GPS lock\r\n");
#endif
		}
		printf("GPS RMC Line: %s\r\n", line);
	} else if (line[3] == 'V') {
		/*
		if ((line[4] == 'T')&&(line[5] == 'G')) {
		}
		*/
		// printf("GPS Line: %s\r\n", line);
	} else printf("Other GPS Line: %s\r\n", line);
}
#endif

char	errstring[128];


void	main(int argc, char **argv) {
	const unsigned red = 0x0ff0000, green = 0x0ff00, blue = 0x0ff,
		white = 0x070707, black = 0, dimgreen = 0x1f00,
		second = CLKFREQHZ;
	int	i, sw;

#ifdef	GPSTRK_ACCESS
	// Start the GPS converging ...
	_gps->g_alpha = 2;
	_gps->g_beta  = 0x14bda12f;
	_gps->g_gamma = 0x1f533ae8;
#endif

	// 
	int	user_context[16];
	for(i=0; i<15; i++)
		user_context[i] = 0;
	user_context[15] = (unsigned)idle_task;
	zip_restore_context(user_context);

	for(i=0; i<4; i++)
		_clrled[i] = red;
	*_spio = 0x0ffff;

	// Clear the PIC
	//
	//	Acknowledge all interrupts, turn off all interrupts
	//
	_zip->z_pic = CLEARPIC;
	while(*_pwrcount < (second >> 4))
		;

	// Repeating timer, every 250ms
	_zip->z_tma = TMR_INTERVAL | (second/4);
	wait_on_interrupt(SYSINT_TMA);

	_clrled[0] = green;
	*_spio = 0x0100;

	wait_on_interrupt(SYSINT_TMA);

	_clrled[0] = dimgreen;
	_clrled[1] = green;
	// sys->io_scope[0].s_ctrl = WBSCOPE_NO_RESET | 32;
	*_spio = 0x0200;

	wait_on_interrupt(SYSINT_TMA);

	_clrled[1] = dimgreen;
	_clrled[2] = green;
	*_spio = 0x0400;

	wait_on_interrupt(SYSINT_TMA);

	_clrled[2] = dimgreen;
	_clrled[3] = green;
	*_spio = 0x0800;

	wait_on_interrupt(SYSINT_TMA);

	_clrled[3] = dimgreen;

	wait_on_interrupt(SYSINT_TMA);

	for(i=0; i<4; i++)
		_clrled[i] = black;

	// Wait one second ...
	for(i=0; i<4; i++)
		wait_on_interrupt(SYSINT_TMA);

	// Blink all the LEDs
	//	First turn them on
	*_spio = 0x0ffff;
	// Then wait a quarter second
	wait_on_interrupt(SYSINT_TMA);
	// Then turn the back off
	*_spio = 0x0f00;
	// and wait another quarter second
	wait_on_interrupt(SYSINT_TMA);

	// Now, read buttons, and flash an LED on any button being held
	// down ... ? neat?

	// Now, let's synchronize ourselves to the PPS
	user_context[13] = (int)&user_stack[256];
	user_context[15] = (int)&user_task;
	zip_restore_context(user_context);

#ifdef	GPSTRK_ACCESS
	do {
		wait_on_interrupt(SYSINT_TMA);
	} while((_zip->z_pic & SYSINT_PPS)==0);

	printf("GPS RECORD START\r\n");
#endif

	_zip->z_tma = TMR_INTERVAL | (second/1000);
	wait_on_interrupt(SYSINT_TMA);
#ifdef	GPSUART_ACCESS
	_gpsu->u_rx = 0x01000;
#endif
	while(1) {
		char	*s = errstring;

		_zip->z_wdt = CLKFREQHZ*4;
		*_spio = 0x0808;

#ifdef	_BOARD_HAS_GPSTB
		// 1. Read and report the GPS tracking err

		// Get the upper 32-bits of the error;
		int	err = *(int *)(&_gpstb->tb_err);
		int	err_in_ns, err_in_us;
		int	err_sgn = (err < 0)?1:0, err_in_ns_rem;

		err_in_ns = (err<0)?-err:err;
		err_in_ns = mpyuhi(err_in_ns, 1000000000);

		err_in_us = err_in_ns / 1000;
		err_in_ns_rem = err_in_ns - err_in_us * 1000;
		if (err_sgn)
			err_in_us = - err_in_us;

		printf("\r\nGPS PPS Err: 0x%08x => 0x%08x => %+5d.%03d us\r\n",
			err, err_in_ns, err_in_us, err_in_ns_rem);
#endif



		*_spio = 0x0800;

#ifdef	GPSTRK_ACCESS
		_zip->z_pic  = SYSINT_GPSRXF | SYSINT_PPS | SYSINT_TMA;

		{
			const int	LINEBUFSZ = 80;
			char	line[LINEBUFSZ], *linep = line;
			do {
				int	v;

#ifdef	GPSUART_ACCESS
				wait_on_interrupt(SYSINT_PPS|SYSINT_GPSRXF|SYSINT_TMA);

				while(((v = _gpsu->u_rx)&0x100)==0) {
					v &= 0x0ff;
					// putchar(v);
					// sys->io_uart.u_tx = v;
					*linep++ = v;
					if(linep-line > LINEBUFSZ)
						linep = line;
					if ((v == '\r')||(v == '\n')) {
						*linep = '\0';
						if (line[0] == '$')
							gps_process_line(line);
						linep = line;
					}
				}
#endif
				wait_on_interrupt(SYSINT_PPS|SYSINT_TMA);
			} while((_zip->z_pic & SYSINT_PPS)==0);
		}
#endif
	}

	zip_halt();
}

