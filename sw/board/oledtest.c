////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	oledtest.c
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To see whether or not we can display an image onto the OLEDrgb
//		PMod.  This program runs on the ZipCPU internal to the FPGA,
//	and commands the OLEDrgb to power on, reset, initialize, and then to
//	display an alternating pair of images onto the display.
//
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

#define	sys	_sys

void	idle_task(void) {
	while(1)
		zip_idle();
}

extern int	splash[], mug[];

#define	OLED_DISPLAYON		0x0af
#define	MICROSECOND		(CLOCKFREQ_HZ/1000000)
#define	OLED_DISPLAY_OFF



/*
 * timer_delay()
 *
 * Using the timer peripheral, delay by a given number of counts.  We'll sleep
 * during this delayed time, and wait on an interrupt to wake us.  As a result,
 * this will only work from supervisor mode.
 */
void	timer_delay(int counts) {
	// Clear the PIC.  We want to exit from here on timer counts alone
	zip->z_pic = CLEARPIC;

	if (counts > 10) {
		// Set our timer to count down the given number of counts
		zip->z_tma = counts;
		zip->z_pic = EINT(SYSINT_TMA);
		zip_rtu();
		zip->z_pic = CLEARPIC;
	} // else anything less has likely already passed
}

void	wait_on_interrupt(int mask) {
	// Clear our interrupt only, but disable all others
	zip->z_pic = DALLPIC|mask;
	zip->z_pic = EINT(mask);
	zip_rtu();
	zip->z_pic = DINT(mask)|mask;
}

void oled_clear(void);

/*
 * The following outlines a series of commands to send to the OLEDrgb as part
 * of an initialization sequence.  The sequence itself was taken from the
 * MPIDE demo.  Single byte numbers in the sequence are just that: commands
 * to send 8-bit values across the port.  17-bit values with the 16th bit
 * set send two bytes (bits 15-0) to the port.  The OLEDrgb treats these as
 * commands (first byte) with an argument (the second byte).
 */
const int	init_sequence[] = {
	//  Unlock commands
	0x01fd12,
	//  Display off
	0x0ae,
	//  Set remap and data format
	0x01a072,
	//  Set the start line
	0x01a100,
	//  Set the display offset
	0x01a200,
	//  Normal display mode
	0x0000a4,
	//  Set multiplex ratio
	0x01a83f,
	//  Set master configuration:
	//	Use External VCC
	0x01ad8e,
	//  Disable power save mode
	0x01b00b,
	//  Set phase length
	0x01b131,
	//  Set clock divide
	0x01b3f0,
	//  Set Second Pre-change Speed For ColorA
	0x018a64,
	//  5l) Set Set Second Pre-charge Speed of Color B
	0x018b78,
	//  5m) Set Second Pre-charge Speed of Color C
	0x018c64,
	//  5n) Set Pre-Charge Voltage
	0x01bb3a,
	//  50) Set VCOMH Deselect Level
	0x01be3e,
	//  5p) Set Master Current
	0x018706,
	//  5q) Set Contrast for Color A
	0x018191,
	//  5r) Set Contrast for Color B
	0x018250,
	//  5s) Set Contrast for Color C
	0x01837D,
	//  disable scrolling
	0x02e
};

const int	num_init_items = sizeof(init_sequence)/sizeof(init_sequence[0]);

/*
 * oled_init()
 *
 * This initializes and starts up the OLED.  While it sounds important, really
 * the majority of the work necessary to do this is really captured in the
 * init_sequence[] above.  This just primarily works to send that sequence to
 * the PMod.
 *
 * We should be able to do all of this with the DMA: wait for an OLEDrgb not
 * busy interrupt, send one value, repeat until done.  For now ... we'll just
 * leave that as an advanced exercise.
 *
 */
void	oled_init(void) {
	int	i;

	for(i=0; i<num_init_items; i++) {
		while(OLED_BUSY(sys->io_oled))
			;
		sys->io_oled.o_ctrl = init_sequence[i];
	}

	oled_clear();

	// Wait 5ms
	timer_delay(CLOCKFREQ_HZ/200);

	// Turn on VCC and wait 100ms
	sys->io_oled.o_data = OLED_VCCEN;
	// Wait 100 ms
	timer_delay(CLOCKFREQ_HZ/10);

	// Send Display On command
	sys->io_oled.o_ctrl = OLED_DISPLAYON;
}

/*
 * oled_clear()
 *
 * This should be fairly self-explanatory: it clears (sets to black) all of the 
 * graphics memory on the OLED.
 *
 * What may not be self-explanatory is that to send any more than three bytes
 * using our interface you need to send the first three bytes in o_ctrl,
 * and set the next bytes (up to four) in o_a.  (Another four can be placed in
 * o_b.)  When the word is written to o_ctrl, the command goes over the wire
 * and o_a and o_b are reset.  Hence we set o_a first, then o_ctrl.  Further,
 * the '4' in the top nibble of o_ctrl indicates that we are sending 5-bytes
 * (4+5), so the OLEDrgb should see: 0x25,0x00,0x00,0x5f,0x3f.
 */
void	oled_clear(void) {
	while(OLED_BUSY(sys->io_oled))
		;
	sys->io_oled.o_a = 0x5f3f0000;
	sys->io_oled.o_ctrl = 0x40250000;
	while(OLED_BUSY(sys->io_oled))
		;
}

/*
 * oled_fill
 *
 * Similar to oled_clear, this fills a rectangle with a given pixel value.
 */
void	oled_fill(int c, int r, int w, int h, int pix) {
	int	ctrl; // We'll send this value out the control/command port

	if (c > 95) c = 95;
	if (c <  0) c =  0;
	if (r > 63) r = 63;
	if (r <  0) r =  0;
	if (w <  0) w = 0;
	if (h <  0) h = 0;
	if (c+w > 95) w = 95-c;
	if (r+h > 63) h = 63-r;

	// Enable the fill rectangle function, rather than just the outline
	while(OLED_BUSY(sys->io_oled))
		;
	sys->io_oled.o_ctrl = 0x12601;

	//
	// Now, let's build the actual copy command
	//
	// This is an 11 byte command, consisting of the 0x22, followed by
	// the top left column and row of our rectangle, and then the bottom
	// right column and row.  That's the first five bytes.  The next six
	// bytes are the color of the border and the color of the fill.
	// Here, we set both colors to be identical.
	// 
	ctrl = 0xa0220000 | ((c&0x07f)<<8) | (r&0x03f);
	sys->io_oled.o_a = (((c+w)&0x07f)<<24) | (((r+h)&0x03f)<<16);
	sys->io_oled.o_a|= ((pix >> 11) & 0x01f)<< 9;
	sys->io_oled.o_a|= ((pix >>  5) & 0x03f)    ;
	sys->io_oled.o_b = ((pix      ) & 0x01f)<<25;
	sys->io_oled.o_b|= ((pix >> 11) & 0x01f)<<17;
	sys->io_oled.o_b|= ((pix >>  5) & 0x03f)<< 8;
	sys->io_oled.o_b|= ((pix      ) & 0x01f)<< 1;

	// Make certain we had finished with the port
	while(OLED_BUSY(sys->io_oled))
		;

	// and send our new command.  Note that o_a and o_b were already set
	// ahead of time, and are only now being sent together with this
	// command.
	sys->io_oled.o_ctrl = ctrl;

	// To be nice to whatever routine follows, we'll wait 'til the port
	// is clear again.
	while(OLED_BUSY(sys->io_oled))
		;
}

/*
 * oled_show_image(int *img)
 *
 * This is a really simply function, for a really simple purpose: it copies
 * a full size image to the device.  You'll notice two versions of the routine
 * below.  They are roughly identical in what they do.  The first version
 * sets up the DMA to transfer the data, one word at a time, from RAM to
 * the OLED.  One byte is transferred every at every OLED interrupt.  The other
 * version works roughly the same way, but first waits for the OLED port to be
 * clear before sending the image.  The biggest difference between the two 
 * approaches is that, when using the DMA, the routine finishes before the 
 * DMA transfer is complete, whereas the second version of the routine
 * returns as soon as the image transfer is complete.
 */
void	oled_show_image(int *img) {
#define	USE_DMA
#ifdef	USE_DMA
		zip->z_dma.d_len= 6144;
		zip->z_dma.d_rd = img;
		zip->z_dma.d_wr = (int *)&sys->io_oled.o_data;
		zip->z_dma.d_ctrl = DMAONEATATIME|DMA_CONSTDST|DMA_ONOLED;
#else
		for(int i=0; i<6144; i++) {
			while(OLED_BUSY(sys->io_oled))
				;
			sys->io_oled.o_data = img[i];
		}
#endif
}

/*
 * entry()
 *
 * In all (current) ZipCPU programs, the programs start with an entry()
 * function that takes no arguments.  The actual bootup entry can be found
 * in the bootstrap.c file, but that calls us here.
 *
 */
void	main(int argc, char **argv) {

	// Since we'll be returning to userspace via zip_rtu() in order to
	// wait for an interrupt, let's at least place a valid program into
	// userspace to run: the idle_task.
	unsigned	user_regs[16];
	for(int i=0; i<15; i++)
		user_regs[i] = 0;
	user_regs[15] = (unsigned int)idle_task;
	zip_restore_context(user_regs);

	// Clear the PIC.  We'll come back and use it later.  We clear it here
	// partly in order to avoid a race condition later.
	zip->z_pic = CLEARPIC;

	// Wait till we've had power for at least a quarter second
	if (0) {
		// While this appears to do the task quite nicely, it leaves
		// the master_ce line high within the CPU, and so it generates
		// a whole lot of debug information in our Verilator simulation,
		// busmaster_tb.
		int pwrcount = sys->io_b.i_pwrcount;
		do {
			pwrcount = sys->io_b.i_pwrcount;
		} while((pwrcount>0)&&(pwrcount < CLOCKFREQ_HZ/4));
	} else {
		// By using the timer and sleeping instead, the simulator can
		// be made to run a *lot* faster, with a *lot* less debugging
		// ... junk.
		int pwrcount = sys->io_b.i_pwrcount;
		if ((pwrcount > 0)&&(pwrcount < CLOCKFREQ_HZ/4)) {
			pwrcount = CLOCKFREQ_HZ/4 - pwrcount;
			timer_delay(pwrcount);
		}
	}
		

	// If the OLED is already powered, such as might be the case if
	// we rebooted but the board was still hot, shut it down
	if (sys->io_oled.o_data & 0x07) {
		sys->io_oled.o_data = OLED_VCC_DISABLE;
		// Wait 100 ms
		timer_delay(CLOCKFREQ_HZ/10);
		// Shutdown the entire devices power
		sys->io_oled.o_data = OLED_POWER_DOWN;
		// Wait 100 ms
		timer_delay(CLOCKFREQ_HZ/10);

		// Now let's try to restart it
	}

	// 1. Power up the OLED by applying power to VCC
	//	This means we need to apply power to both the VCCEN line as well
	//	as the PMODEN line.  We'll also set the reset line low, so the
	//	device starts in a reset condition.
	sys->io_oled.o_data = OLED_PMODEN|OLED_RESET_CLR;
	timer_delay(4*MICROSECOND);
	sys->io_oled.o_data = OLED_RESET;
	timer_delay(4*MICROSECOND);

	// 2. Send the Display OFF command
	//	This isn't necessary, since we already pulled RESET low.
	//
	// sys->io_oled.o_ctrl = OLED_DISPLAY_OFF;
	//

	// However, we must hold the reset line low for at least 3us, as per
	// the spec.  We may also need to wait another 2us after that.  Let's
	// hold reset low for 4us here.
	timer_delay(4*MICROSECOND);

	// Clear the reset condition.
	sys->io_oled.o_data = OLED_RESET_CLR;
	// Wait another 4us.
	timer_delay(4*MICROSECOND);

	// 3. Initialize the display to the default settings
	//	This just took place during the reset cycle we just completed.
	//
	oled_init();

	// 4. Clear screen
	// 5. Apply voltage
	// 6. Turn on display
	// 7. Wait 100ms
	//	We already stuffed this command sequence into the oled_init,
	//	so we're good here.

	while(1) {
		sys->io_b.i_leds = 0x0f0;

		sys->io_oled.o_ctrl = OLED_DISPLAYON;

		oled_clear();

		// Let's start our writes at the top left of the GDDRAM
		// (screen memory)
		while(OLED_BUSY(sys->io_oled))
			;
		sys->io_oled.o_ctrl = 0x2015005f; // Sets column min/max address

		while(OLED_BUSY(sys->io_oled))
			;
		sys->io_oled.o_ctrl = 0x2075003f; // Sets row min/max address
		while(OLED_BUSY(sys->io_oled))
			;

		// Now ... finally ... we can send our image.
		oled_show_image(splash);
		wait_on_interrupt(SYSINT_DMAC);

		// Wait 25 seconds.  The LEDs are for a fun effect.
		sys->io_b.i_leds = 0x0f1;
		timer_delay(CLOCKFREQ_HZ*5);
		sys->io_b.i_leds = 0x0f3;
		timer_delay(CLOCKFREQ_HZ*5);
		sys->io_b.i_leds = 0x0f7;
		timer_delay(CLOCKFREQ_HZ*5);
		sys->io_b.i_leds = 0x0ff;
		timer_delay(CLOCKFREQ_HZ*5);
		sys->io_b.i_leds = 0x0fe;
		timer_delay(CLOCKFREQ_HZ*5);


		// Display a second image.
		sys->io_b.i_leds = 0x0fc;
		oled_show_image(mug);
		wait_on_interrupt(SYSINT_DMAC);

		// Leave this one in effect for 5 seconds only.
		sys->io_b.i_leds = 0x0f8;
		timer_delay(CLOCKFREQ_HZ*5);
	}

	// We'll never get here, so this line is really just for form.
	zip_halt();
}

