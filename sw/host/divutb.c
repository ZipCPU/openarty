////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	divutb.c
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To test the logic of the ZipCPU unsigned, 64-bit divide 
//		function in an easier-to-debug fashion.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2017-2024, Gisselquist Technology, LLC
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
#include <stdio.h>
#include <stdint.h>
#include <assert.h>

#ifndef	EOL
#ifdef	__ZIPCPU__
#define	EOL	"\r\n"
#else
#define	EOL	"\n"
#endif
#endif

#define	__udivdi3	udivdi3
#include "../zlib/udiv.c"


void	divtest(unsigned long a, unsigned long b) {
	unsigned long	r = udivdi3(a,b), h;

	printf("[a = %016lx] / [b = %016lx] =? %016lx" EOL, a, b, r);
	h = a / b;
	printf("\t%lx -> %lx\n", h, h-r);
	fflush(stdout);
	assert(h-r == 0);
}

int main(int argc, char **argv) {
	printf("\r\n");
	printf("Division test" EOL);
	printf("-----------------------" EOL);

	divtest(0xd7fffffffffff4c7l, 0x0al);
	divtest(0x0ffffffffl, 0x0al);

	for(int i=0; i<32; i++) {
		uint32_t	ci = i << (32-5);
		uint64_t	li = ci;
		divtest(0x063d2e99l+li, 0x0al);
	}

	divtest(0x10l, 0x02l);
	divtest(0x100l, 0x02l);
	divtest(0x1000l, 0x02l);
	divtest(0x10000l, 0x02l);
	divtest(0x100000l, 0x02l);
	divtest(0x1000000l, 0x02l);
	divtest(0x10000000l, 0x02l);
	divtest(0x100000000l, 0x02l);
	divtest(0x1000000000l, 0x02l);
	divtest(0x10000000000l, 0x02l);
	divtest(0x100000000000l, 0x02l);
	divtest(0x1000000000000l, 0x02l);
	divtest(0x10000000000000l, 0x02l);
	divtest(0x100000000000000l, 0x02l);
	divtest(0x1000000000000000l, 0x02l);
	divtest(0x1000000000000000l, 0x03l);
	divtest(0x1000000000000000l, 0x030l);
	divtest(0x1000000000000000l, 0x0300l);
	divtest(0x1000000000000000l, 0x03000l);
	divtest(0x1000000000000000l, 0x030000l);
	divtest(0x1000000000000000l, 0x0300000l);
	divtest(0x1000000000000000l, 0x03000000l);
	divtest(0x1000000000000000l, 0x030000000l);
	divtest(0x1000000000000000l, 0x0300000000l);
	divtest(0x1000000000000000l, 0x03000000000l);
	divtest(0x1000000000000000l, 0x030000000000l);
	divtest(0x1000000000000000l, 0x0300000000000l);

	printf("SUCCESS!\n");
}

