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
	"\tMOV\t_kernel_exit(PC),R0\n"
	"\tBRA\tentry\n"
"_kernel_exit:\n"
	"\tHALT\n"
	"\tBRA\t_kernel_exit\n"
	"\t.section\t.text");

extern void	*_sdram_image_end, *_sdram_image_start, *_sdram,
	*_blkram, *_flash, *_bss_image_end,
	*_kernel_image_start, *_kernel_image_end;

extern	void	bootloader(void) __attribute__ ((section (".boot")));

void	bootloader(void) {
	int	zero = 0;

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

	zip->dma.len = _sdram_image_end - _sdram;
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
}

void	idle_task(void) {
	while(1)
		zip_idle();
}

void	entry(void) {
	const unsigned red = 0x0ff0000, green = 0x0ff00, blue = 0x0ff,
		white = 0x070707, black = 0, dimgreen = 0x1f00,
		second = 80000000;
	int	i, sw;

	int	user_context[16];
	for(i=0; i<15; i++)
		user_context[i] = 0;
	user_context[15] = (unsigned)idle_task;

	for(i=0; i<4; i++) {
		sys->io_clrled[0] = red;
		sys->io_clrled[1] = red;
		sys->io_clrled[2] = red;
		sys->io_clrled[3] = red;
	} sys->io_ledctrl = 0x0ff;

	// Clear the PIC
	//
	//	Acknowledge all interrupts, turn off all interrupts
	//
	zip->pic = 0x7fff7fff;
	while(sys->io_pwrcount < (second >> 4))
		;

	// Repeating timer, every 25ms
	zip->tma = 20000000 | 0x80000000;
	// Restart the PIC -- listening for SYSINT_TMA only
	zip->pic = EINT(SYSINT_TMA);
	zip_rtu();

	sys->io_clrled[0] = green;
	sys->io_ledctrl = 0x010;

	zip->pic = EINT(SYSINT_TMA);
	zip_rtu();

	sys->io_clrled[0] = dimgreen;
	sys->io_clrled[1] = green;
	sys->io_ledctrl = 0x020;

	zip->pic = EINT(SYSINT_TMA);
	zip_rtu();

	sys->io_clrled[1] = dimgreen;
	sys->io_clrled[2] = green;
	sys->io_ledctrl = 0x040;

	zip->pic = EINT(SYSINT_TMA);
	zip_rtu();

	sys->io_clrled[2] = dimgreen;
	sys->io_clrled[3] = green;
	sys->io_ledctrl = 0x080;

	zip->pic = EINT(SYSINT_TMA);
	zip_rtu();

	sys->io_clrled[3] = dimgreen;

	zip->pic = EINT(SYSINT_TMA);
	zip_rtu();

	for(i=0; i<4; i++)
		sys->io_clrled[i] = black;

	// Wait one second ...
	for(i=0; i<4; i++) {
		zip->pic = EINT(SYSINT_TMA);
		zip_rtu();
	}

	sw = sys->io_btnsw & 0x0f;
	for(int i=0; i<4; i++)
		sys->io_clrled[i] = (sw & (1<<i)) ? white : black;

	// Wait another two second ...
	for(i=0; i<8; i++) {
		zip->pic = EINT(SYSINT_TMA);
		zip_rtu();
	}

	// Blink all the LEDs
	//	First turn them on
	sys->io_ledctrl = 0x0ff;
	// Then wait a quarter second
	zip->pic = EINT(SYSINT_TMA);
	zip_rtu();
	// Then turn the back off
	sys->io_ledctrl = 0x0f0;
	// and wait another quarter second
	zip->pic = EINT(SYSINT_TMA);
	zip_rtu();

	// Now, read buttons, and flash an LED on any button being held
	// down ... ? neat?

	// zip->tma = 20000000; // 1/4 second -- already set
	while(1) {
		unsigned	btn;

		zip->pic = EINT(SYSINT_TMA);
		zip_rtu();
		btn = (sys->io_btnsw > 4) & 0x0f;
		btn |= (btn << 4);
		btn ^= sys->io_ledctrl;
		sys->io_ledctrl = 0xf0; // Turn all LEDs off
		sys->io_ledctrl = btn;	// And turn back on the ones toggling
		// That way, at the end, the toggle will leave them in the
		// off position.
	}

	zip_halt();
}

