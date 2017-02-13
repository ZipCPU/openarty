////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	exstartup.c
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	A fun example program that runs on the Arty, just to show
//		that the minimum set of peripherals (LEDs, color LEDs, buttons,
//	switches, etc.) work.
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
#include "zipcpu.h"
#include "zipsys.h"
#include "artyboard.h"

#define	sys	_sys

void	idle_task(void) {
	while(1)
		zip_idle();
}

void	wait_on_interrupt(int mask) {
	zip->z_pic = DALLPIC|mask;
	zip->z_pic = EINT(mask);
	zip_rtu();
}


void	main(int argc, char **argv) {
	const unsigned red = 0x0ff0000, green = 0x0ff00, blue = 0x0ff,
		white = 0x070707, black = 0, dimgreen = 0x1f00,
		second = CLOCKFREQHZ;
	int	i, sw;

	int	user_context[16];
	for(i=0; i<15; i++)
		user_context[i] = 0;
	user_context[15] = (unsigned)idle_task;
	zip_restore_context(user_context);

	for(i=0; i<4; i++)
		_sys->io_b.i_clrled[i] = red;
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

	sw = sys->io_b.i_btnsw & 0x0f;
	for(int i=0; i<4; i++)
		sys->io_b.i_clrled[i] = (sw & (1<<i)) ? white : black;


	// Wait another two seconds ...
	for(i=0; i<8; i++)
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

	while(1) {
		unsigned	btn, ledc;

		zip_rtu();
		zip->z_pic = EINT(SYSINT_TMA)|SYSINT_TMA;
		// If the button is pressed, toggle the LED
		// Otherwise, turn the LED off.
		//
		// First, get all the pressed buttons
		btn = (sys->io_b.i_btnsw >> 4) & 0x0f;
		// Now, acknowledge the button presses that we just read
		sys->io_b.i_btnsw = (btn<<4);

		// Of any LEDs that are on, or buttons on, toggle their values
		ledc = (sys->io_b.i_leds)&0x0f;
		ledc = (ledc | btn)&0x0f ^ ledc;
		// Make sure we set everything
		ledc |= 0x0f0;
		// Now issue the command
		sys->io_b.i_leds = ledc;
		// That way, at the end, the toggle will leave them in the
		// off position.
		// sys->io_b.i_leds = 0xf0 | ((sys->io_b.i_leds&1)^1);

		sw = sys->io_b.i_btnsw & 0x0f;
		for(int i=0; i<4; i++)
			sys->io_b.i_clrled[i] = (sw & (1<<i)) ? white : black;

	}

	zip_halt();
}

