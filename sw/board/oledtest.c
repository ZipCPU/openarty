#include "artyboard.h"
#include "zipsys.h"

void	idle_task(void) {
	while(1)
		zip_idle();
}

extern int	splash[], mug[];

#define	OLED_PMODEN		0x0010001
#define	OLED_PMODEN_OFF		0x0010000
#define	OLED_IOPWR		OLED_PMODEN
#define	OLED_VCCEN		0x0020002
#define	OLED_VCC_DISABLE	0x0020000
#define	OLED_RESET		0x0040000
#define	OLED_RESET_CLR		0x0040004
#define	OLED_PWRRESET		(OLED_PMODEN|OLED_RESET) // 5
#define	OLED_FULLPOWER		(OLED_PMODEN|OLED_VCCEN|OLED_RESET_CLR) // 3->7
#define	OLED_POWER_DOWN		(OLED_PMODEN_OFF|OLED_VCC_DISABLE)
#define	OLED_BUSY		1
#define	OLED_DISPLAYON		0x0af


#define	MICROSECOND		(CLOCKFREQ_HZ/1000000)

#define	OLED_DISPLAY_OFF

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
		0x02e };

void	timer_delay(int counts) {
	// Clear the PIC.  We want to exit from here on timer counts alone
	zip->pic = CLEARPIC;

	if (counts > 10) {
		// Set our timer to count down the given number of counts
		zip->tma = counts;
		zip->pic = EINT(SYSINT_TMA);
		zip_rtu();
		zip->pic = CLEARPIC;
	} // else anything less has likely already passed
}

void oled_clear(void);

void	oled_init(void) {
	int	i;

	for(i=0; i<sizeof(init_sequence); i++) {
		while(sys->io_oled.o_ctrl & OLED_BUSY)
			;
		sys->io_oled.o_ctrl = init_sequence[i];
	}

	// 5u) Clear Screen
	oled_clear();

	zip->tma = (CLOCKFREQ_HZ/200);
	zip->pic = EINT(SYSINT_TMA);
	zip_rtu();
	zip->pic = CLEARPIC;


	// Turn on VCC and wait 100ms
	sys->io_oled.o_data = OLED_VCCEN;
	// Wait 100 ms
	timer_delay(CLOCKFREQ_HZ/10);

	// Send Display On command
	sys->io_oled.o_ctrl = 0xaf;
}	

void	oled_clear(void) {
	while(sys->io_oled.o_ctrl & OLED_BUSY)
		;
	sys->io_oled.o_a = 0x5f3f0000;
	sys->io_oled.o_ctrl = 0x40250000;
	while(sys->io_oled.o_ctrl & OLED_BUSY)
		;
}

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

	// Enable a rectangle to fill
	while(sys->io_oled.o_ctrl & OLED_BUSY)
		;
	sys->io_oled.o_ctrl = 0x12601;

	// Now, let's build the actual copy command
	ctrl = 0xa0220000 | ((c&0x07f)<<8) | (r&0x03f);
	sys->io_oled.o_a = (((c+w)&0x07f)<<24) | (((r+h)&0x03f)<<16);
	sys->io_oled.o_a|= ((pix >> 11) & 0x01f)<< 9;
	sys->io_oled.o_a|= ((pix >>  5) & 0x03f)    ;
	sys->io_oled.o_b = ((pix >> 11) & 0x01f)<<17;
	sys->io_oled.o_b|= ((pix >>  5) & 0x03f)<< 8;
	sys->io_oled.o_b|= ((pix      ) & 0x01f)<< 1;

	// Make certain we had finished with the port (should've ...)
	while(sys->io_oled.o_ctrl & OLED_BUSY)
		;

	// and send our new command
	sys->io_oled.o_ctrl = ctrl;

	// To be nice to whatever routine follows, we'll wait 'til the port
	// is clear again.
	while(sys->io_oled.o_ctrl & OLED_BUSY)
		;
}

void	entry(void) {
	unsigned	user_regs[16];
	for(int i=0; i<15; i++)
		user_regs[i] = 0;
	user_regs[15] = (unsigned int)idle_task;
	zip_restore_context(user_regs);

	// Clear the PIC.  We'll come back and use it later.
	zip->pic = CLEARPIC;

	if (0) { // Wait till we've had power for at least a quarter second
		int pwrcount = sys->io_pwrcount;
		do {
			pwrcount = sys->io_pwrcount;
		} while((pwrcount>0)&&(pwrcount < CLOCKFREQ_HZ/4));
	} else {
		int pwrcount = sys->io_pwrcount;
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
	// sys->io_oled.o_ctrl = OLED_CLEAR_SCREEN;

	// Wait for the command to complete
	while(sys->io_oled.o_ctrl & OLED_BUSY)
		;

	// 5. Apply power to VCCEN
	sys->io_oled.o_data = OLED_FULLPOWER;
	
	// 6. Delay 100ms
	timer_delay(CLOCKFREQ_HZ/10);

	while(1) {
	// 7. Send Display On command
	// sys->io_oled.o_ctrl = OLED_CLEAR_SCREEN; // ?? What command is this?
		sys->io_ledctrl = 0x0ff;

		sys->io_oled.o_ctrl = OLED_DISPLAYON;

		oled_clear();

		while(sys->io_oled.o_ctrl & OLED_BUSY)
			;
		sys->io_oled.o_ctrl = 0x2015005f;

		while(sys->io_oled.o_ctrl & OLED_BUSY)
			;
		sys->io_oled.o_ctrl = 0x2075003f;

		sys->io_ledctrl = 0x0fe;
		// Now ... finally ... we can send our image.
		for(int i=0; i<6144; i++) {
			while(sys->io_oled.o_ctrl & OLED_BUSY)
				;
			sys->io_oled.o_data = splash[i];
		}
		sys->io_ledctrl = 0x0fc;
		timer_delay(CLOCKFREQ_HZ*5);
		timer_delay(CLOCKFREQ_HZ*5);
		timer_delay(CLOCKFREQ_HZ*5);
		timer_delay(CLOCKFREQ_HZ*5);
		timer_delay(CLOCKFREQ_HZ*5);


		for(int i=0; i<6144; i++) {
			while(sys->io_oled.o_ctrl & OLED_BUSY)
				;
			sys->io_oled.o_data = mug[i];
		}

		sys->io_ledctrl = 0x0f0;
		timer_delay(CLOCKFREQ_HZ*5);
	}

	zip_halt();
}

