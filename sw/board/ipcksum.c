////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	ipsum.c
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To calculate (and return) an IP checksum on a section of data.
//		The data must be contiguous in memory, and the checksum field
//	(which is usually a part of it) must be blank when calling this
//	function.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2019, Gisselquist Technology, LLC
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
#include "ipcksum.h"

#define ASM
unsigned	ipcksum(int len, unsigned *ptr) {
#ifndef	ASM
	unsigned	checksum = 0;

	for(int i=0; i<len; i++)
		checksum = checksum + (ptr[i] & 0x0ffff) + (ptr[i] >> 16);
	while(checksum & ~0x0ffff)
		checksum = (checksum & 0x0ffff) + (checksum >> 16);
	return checksum ^ 0x0ffff;
#else
asm(ASMFNSTR("ipcksum")			// R1 = length (W), R2 = packet pointer
	"\tMOV	R1,R3\n"		// R3 is now the remaining length
	"\tCLR	R1\n"			// R1 will be our checksum accumulator
".Lloop:\n"
	"\tLW	(R2),R4\n"
	"\tADD	R4,R1\n"
	"\tADD.C	1,R1\n"
	"\tADD	4,R2\n"
	"\tSUB	1,R3\n"
	"\tBZ	.Lexit\n"
	"\tBRA	.Lloop\n"
".Lexit:\n"
	"\tMOV	R1,R3\n"
	"\tAND	0x0ffff,R1\n"
	"\tLSR	16,R3\n"
	"\tADD	R3,R1\n"
	"\tTEST	0xffff0000,R1\n"	// The carry bit can only and will only
	"\tADD.NZ 1,R1\n"		// ever be a one here.  Add it in.
	"\tAND	0x0ffff,R1\n"
	"\tXOR	0x0ffff,R1\n"
	"\tRETN");
#endif
}

