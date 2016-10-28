////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	bootloader.c
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To start a program from flash, loading its various components
//		into on-chip block RAM, or off-chip DDR3 SDRAM, as indicated
//	by the symbols/pointers within the program itself.  As you will notice
//	by the names of the symbols, it is assumed that a kernel will be placed
//	into block RAM.
//
//	This particular implementation depends upon the following symbols
//	being defined:
//
//	void entry(void)
//		The location where your program will start from, once fully
//		loaded.
//
//	_top_of_stack:
//		A pointer to a location in memory which we can use for a stack.
//		The bootloader doesn't use much of this memory, although it does
//		use it.  It then resets the stack to this location and calls
//		your program.
//
//	_top_of_heap:
//		While not used by this program, this is assumed to be defined
//		by the linker as the lowest memory address in a space that can
//		be used by a malloc/free restore capability.
//
//	_flash:
//		The address of the beginning of physical FLASH device.  This is
//		not the first usable address on that device, as that is often
//		reserved for the first two FPGA configurations.
//
//	_blkram:
//		The first address of the block RAM memory within the FPGA.
//
//	_sdram:
//		The address of the beginning of physical SDRAM.
//
//	_kernel_image_start:
//		The address of that location within FLASH where the sections
//		needing to be moved begin at.
//
//	_kernel_image_end:
//		The last address within block RAM that needs to be filled in.
//
//	_sdram_image_start:
//		This address is more confusing.  This is equal to one past the
//		last used block RAM address, or the last used flash address if
//		no block RAM is used.  It is used for determining whether or not
//		block RAM was used at all.
//
//	_sdram_image_end:
//		This is one past the last address in SDRAM that needs to be
//		set with valid data.
//
//	_bss_image_end:
//		This is the last address of memory that must be cleared upon
//		startup, for which the program is assuming that it is zero.
//		While it may not be necessary to clear the BSS memory, since
//		BSS memory is always zero on power up, this bootloader does so
//		anyway--since we might be starting from a reset instead of power
//		up.
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
#include "zipsys.h"

// A bootloader is about nothing more than copying memory from a couple
// particular locations (Flash/ROM) to other locations in memory (BLKRAM
// and SDRAM).  Our DMA is a hardware accelerator that does nothing but
// copy memory from one location to another.  Why not use the DMA for this
// purpose then?
//
// Here, we have a USE_DMA #define.  When this is defined, the memory copy
// will be done using the DMA hardware accelerator.  This is a good thing,
// and this should be defined.  There are two problems with defining this
// however: 1) It obscures for any readers of this code what is actually
// happening, and 2) it makes the code dependent upon yet another piece of the
// hardware design working.  For these reasons, we allow you to turn it off.
#define	USE_DMA

//
// _start:
//
// Every computer needs to start processing from somewhere on reboot, and every
// program needs some entry point.  For the ZipCPU, that starting place is the
// routine with the _start symbol.  It is important that this start symbol be
// placed at the boot address for the CPU.  This is the very first address of
// program memory, and (currently) on the Arty board it is placed in Flash at
// _start = 0x4e0000.  To make certain this routine goes into the very first
// address in flash, we place it into it's own special section, the .start
// section, and then tell the linker that the .start section is the first
// section where it needs to start placing code.
//
// If you read through this short assembly routine below, you'll find that it
// does only a small number of tasks.  It sets the stack pointer to point to
// the top of the stack (a symbol defined in the linker file), calls the 
// bootloader, resets the stack pointer, clears any data cache, and then calls
// the kernel entry function.  It also sets up a return address for the kernel
// entry function so that, should the kernel ever exit, it wouldn't exit on 
// any error but rather it would exit by halting the CPU.
//
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

//
// We need to insist that the bootloader be kept in Flash, else it would depend
// upon running a routine from memory that ... wasn't in memory yet.  For this
// purpose, we place the bootloader in a special .boot section.  We'll also tell
// the linker, via the arty.ld file, that thsi .boot section needs to be placed
// into flash.
//
extern	void	bootloader(void) __attribute__ ((section (".boot")));

//
// bootloader()
//
// Here's the actual boot loader itself.  It copies three areas from flash:
//	1. An area from flash to block RAM
//	2. A second area from flash to SDRAM
//	3. The third area isn't copied from flash, but rather it is just set to
//		zero.  This is sometimes called the BSS segment.
//
void	bootloader(void) {
	int	zero = 0;

#ifdef	USE_DMA
	zip->dma.ctrl= DMACLEAR;
	zip->dma.rd = &_kernel_image_start;
	if (&_kernel_image_end != &_sdram_image_start) {
		zip->dma.len = &_kernel_image_end - &_blkram;
		zip->dma.wr  = &_blkram;
		zip->dma.ctrl= DMACCOPY;

		zip->pic = SYSINT_DMAC;
		while((zip->pic & SYSINT_DMAC)==0)
			;
	}

	// zip->dma.rd // Keeps the same value
	zip->dma.wr  = &_sdram;
	if (&_sdram_image_end != &_sdram) {
		zip->dma.len = &_sdram_image_end - &_sdram;
		zip->dma.ctrl= DMACCOPY;
	}

	zip->pic = SYSINT_DMAC;
	while((zip->pic & SYSINT_DMAC)==0)
		;

	if (&_bss_image_end != &_sdram_image_end) {
		zip->dma.len = &_bss_image_end - &_sdram_image_end;
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

