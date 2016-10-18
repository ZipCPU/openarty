#include "artyboard.h"
#include "zipsys.h"

asm("\t.section\t.start\n"
	"\t.global\t_start\n"
"_start:\n"
	"\tLDI\t_top_of_stack,SP\n"
	"\tMOV\t_after_bootloader(PC),R0\n"
	"\tBRA\tbootloader\n"
"_after_bootloader:\n"
	"\tLDI\t_top_of_stack,SP\n"
	"\tOR\t0x4000,CC\n"	// Clear the data cache
	"\tMOV\t_kernel_exit(PC),R0\n"
	"\tBRA\tentry\n"
"_kernel_exit:\n"
	"\tHALT\n"
	"\tBRA\t_kernel_exit\n"
	"\t.section\t.text");

extern int	_sdram_image_end, _sdram_image_start, _sdram,
	_blkram, _flash, _bss_image_end,
	_kernel_image_start, _kernel_image_end;

extern	void	bootloader(void) __attribute__ ((section (".boot")));

// #define	USE_DMA
void	bootloader(void) {
	int	zero = 0;

#ifdef	USE_DMA
	zip->dma.ctrl= DMACLEAR;
	zip->dma.rd = _kernel_image_start;
	if (_kernel_image_end != _sdram_image_start) {
		zip->dma.len = _kernel_image_end - _blkram;
		zip->dma.wr  = _blkram;
		zip->dma.ctrl= DMACCOPY;

		zip->pic = SYSINT_DMAC;
		while((zip->pic & SYSINT_DMAC)==0)
			;
	}

	zip->dma.len = &_sdram_image_end - _sdram;
	zip->dma.wr  = _sdram;
	zip->dma.ctrl= DMACCOPY;

	zip->pic = SYSINT_DMAC;
	while((zip->pic & SYSINT_DMAC)==0)
		;

	if (_bss_image_end != _sdram_image_end) {
		zip->dma.len = _bss_image_end - _sdram_image_end;
		zip->dma.rd  = &zero;
		// zip->dma.wr // Keeps the same value
		zip->dma.ctrl = DMACCOPY;

		zip->pic = SYSINT_DMAC;
		while((zip->pic & SYSINT_DMAC)==0)
			;
	}
#else
	int	*rdp = &_kernel_image_start, *wrp = &_blkram;

	//
	// Load any part of the image into block RAM, but *only* if there's a
	// block RAM section in the image.  Based upon our LD script, the
	// block RAM should be filled from _blkram to _kernel_image_end.
	// It starts at _kernel_image_start --- our last valid address within
	// the flash address region.
	//
	if (&_kernel_image_end != &_sdram_image_start) {
		for(int i=0; i< &_kernel_image_end - &_blkram; i++)
			*wrp++ = *rdp++;
	}

	//
	// Now, we move on to the SDRAM image.  We'll here load into SDRAM
	// memory up to the end of the SDRAM image, _sdram_image_end.
	// As with the last pointer, this one is also created for us by the
	// linker.
	// 
	wrp = &_sdram;
	for(int i=0; i< &_sdram_image_end - &_sdram; i++)
		*wrp++ = *rdp++;

	//
	// Finally, we load BSS.  This is the segment that only needs to be
	// cleared to zero.  It is available for global variables, but some
	// initialization is expected within it.  We start writing where
	// the valid SDRAM context, i.e. the non-zero contents, end.
	//
	for(int i=0; i<&_bss_image_end - &_sdram_image_end; i++)
		*wrp++ = 0;
#endif
}

void	idle_task(void) {
	while(1)
		zip_idle();
}

void	entry(void) {
	const unsigned red = 0x0ff0000, green = 0x0ff00, blue = 0x0ff,
		white = 0x070707, black = 0, dimgreen = 0x1f00,
		second = 81250000;
	int	i, sw;

	int	user_context[16];
	for(i=0; i<15; i++)
		user_context[i] = 0;
	user_context[15] = (unsigned)idle_task;
	zip_restore_context(user_context);

	for(i=0; i<4; i++)
		sys->io_clrled[i] = red;
	sys->io_ledctrl = 0x0ff;

	// Clear the PIC
	//
	//	Acknowledge all interrupts, turn off all interrupts
	//
	zip->pic = 0x7fff7fff;
	while(sys->io_pwrcount < (second >> 4))
		;

	// Repeating timer, every 250ms
	zip->tma = (second/4) | 0x80000000;
	// zip->tma = 1024 | 0x80000000;
	// Restart the PIC -- listening for SYSINT_TMA only
	zip->pic = EINT(SYSINT_TMA)|SYSINT_TMA;
	zip_rtu();
	zip->pic = EINT(SYSINT_TMA)|SYSINT_TMA;

	sys->io_clrled[0] = green;
	sys->io_ledctrl = 0x010;

	zip_rtu();
	zip->pic = EINT(SYSINT_TMA)|SYSINT_TMA;

	sys->io_clrled[0] = dimgreen;
	sys->io_clrled[1] = green;
	sys->io_scope[0].s_ctrl = 32 | 0x80000000; // SCOPE_TRIGGER;
	sys->io_ledctrl = 0x020;

	zip_rtu();
	zip->pic = EINT(SYSINT_TMA)|SYSINT_TMA;

	sys->io_clrled[1] = dimgreen;
	sys->io_clrled[2] = green;
	sys->io_ledctrl = 0x040;

	zip_rtu();
	zip->pic = EINT(SYSINT_TMA)|SYSINT_TMA;

	sys->io_clrled[2] = dimgreen;
	sys->io_clrled[3] = green;
	sys->io_ledctrl = 0x080;

	zip_rtu();
	zip->pic = EINT(SYSINT_TMA)|SYSINT_TMA;

	sys->io_clrled[3] = dimgreen;

	zip_rtu();
	zip->pic = EINT(SYSINT_TMA)|SYSINT_TMA;

	for(i=0; i<4; i++)
		sys->io_clrled[i] = black;

	// Wait one second ...
	for(i=0; i<4; i++) {
		zip_rtu();
		zip->pic = EINT(SYSINT_TMA)|SYSINT_TMA;
	}

	sw = sys->io_btnsw & 0x0f;
	for(int i=0; i<4; i++)
		sys->io_clrled[i] = (sw & (1<<i)) ? white : black;


	// Wait another two second ...
	for(i=0; i<8; i++) {
		zip_rtu();
		zip->pic = EINT(SYSINT_TMA)|SYSINT_TMA;
	}

	// Blink all the LEDs
	//	First turn them on
	sys->io_ledctrl = 0x0ff;
	// Then wait a quarter second
	zip_rtu();
	zip->pic = EINT(SYSINT_TMA)|SYSINT_TMA;
	// Then turn the back off
	sys->io_ledctrl = 0x0f0;
	// and wait another quarter second
	zip_rtu();
	zip->pic = EINT(SYSINT_TMA)|SYSINT_TMA;

	// Now, read buttons, and flash an LED on any button being held
	// down ... ? neat?

	// zip->tma = 20000000; // 1/4 second -- already set
	while(1) {
		unsigned	btn, ledc;

		zip_rtu();
		zip->pic = EINT(SYSINT_TMA)|SYSINT_TMA;
		// If the button is pressed, toggle the LED
		// Otherwise, turn the LED off.
		//
		// First, get all the pressed buttons
		btn = (sys->io_btnsw >> 4) & 0x0f;
		// Now, acknowledge the button presses that we just read
		sys->io_btnsw = (btn<<4);

		// Of any LEDs that are on, or buttons on, toggle their values
		ledc = (sys->io_ledctrl)&0x0f;
		ledc = (ledc | btn)&0x0f ^ ledc;
		// Make sure we set everything
		ledc |= 0x0f0;
		// Now issue the command
		sys->io_ledctrl = ledc;
		// That way, at the end, the toggle will leave them in the
		// off position.
		// sys->io_ledctrl = 0xf0 | ((sys->io_ledctrl&1)^1);

		sw = sys->io_btnsw & 0x0f;
		for(int i=0; i<4; i++)
			sys->io_clrled[i] = (sw & (1<<i)) ? white : black;

	}

	zip_halt();
}

