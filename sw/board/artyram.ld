/*******************************************************************************
*
* Filename:	arty.ld
*
* Project:	OpenArty, an entirely open SoC based upon the Arty platform
*
* Purpose:	This script provides a description of the memory on the Arty,
*		for the purposes of where to place programs in memory during
*		linking.
*
* Creator:	Dan Gisselquist, Ph.D.
*		Gisselquist Technology, LLC
*
********************************************************************************
*
* Copyright (C) 2016, Gisselquist Technology, LLC
*
* This program is free software (firmware): you can redistribute it and/or
* modify it under the terms of  the GNU General Public License as published
* by the Free Software Foundation, either version 3 of the License, or (at
* your option) any later version.
*
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
* FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
* for more details.
*
* License:	GPL, v3, as defined and found on www.gnu.org,
*		http://www.gnu.org/licenses/gpl.html
*
*
*******************************************************************************/

ENTRY(_start)

MEMORY
{
	blkram (wx) : ORIGIN = 0x0008000, LENGTH = 0x0008000
	flash  (rx) : ORIGIN = 0x0400000, LENGTH = 0x0400000
	sdram  (wx) : ORIGIN = 0x4000000, LENGTH = 0x4000000
}

_flash	= ORIGIN(flash);
_blkram	= ORIGIN(blkram);
_sdram	= ORIGIN(sdram);
_top_of_stack = ORIGIN(blkram) + LENGTH(blkram) - 1;

SECTIONS
{
	.rocode ORIGIN(blkram) : {
		_boot_address = .;
		*(.start) *(.boot)
		_kernel_image_start = . ;
		*(.kernel)
		*(.text)
		*(.rodata*) *(.strings)
		*(.data) *(COMMON) *(.bss)
		}> blkram
	_sdram_image_start = . ;
	_sdram_image_end = . ;
	.bss : {
		*(.bss)
		_bss_image_end = . ;
		} > blkram
	_top_of_heap = .;
}
