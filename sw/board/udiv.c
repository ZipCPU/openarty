////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	udiv.c
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This is a temporary file--a crutch if you will--until a similar
//		capability is merged into GCC.  Right now, GCC has no way of
//	dividing two 64-bit numbers, and this routine provides that capability.
//	__udivdi3 is actually the name GCC wants, so if you'd like to include
//	this into your program, do a ...
//
//	#define	udivdi3	__udivdi3
//	#include "udiv.c"
//
//	Once gcc is properly patched, this will be removed from the 
//	repository.
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
#include <stdint.h>
#ifdef	__ZIPCPU__
#include "zipcpu.h"
#else
uint32_t zip_bitrev(const uint32_t a) {
	uint32_t	r, b = a;
	r = 0;
	for(int i=0; i<32; i++) {
		r = (r<<1) | (b&1);
		b >>= 1;
	} return r;
}
#endif

extern	int	cltz(unsigned long);

#ifdef	__ZIPCPU__
#define	ASMCLTZ
#endif

#ifdef	ASMCLTZ
asm("\t.section\t.text\n\t.global\tcltz\n"
"\t.type\tcltz,@function\n"
"cltz:\n"
	"\tMOV	R1,R3\n"
	"\tCLR	R1\n"
	"\tCMP	0,R3\n"
	"\tMOV.Z R2,R3\n"
	"\tADD.Z 32,R1\n"
	"\tBREV	R3\n"
	"\tTEST	0x0ffff,R3\n"
	"\tADD.Z 16,R1\n"
	"\tLSR.Z 16,R3\n"
	"\tTEST	0x0ff,R3\n"
	"\tADD.Z 8,R1\n"
	"\tLSR.Z 8,R3\n"
	"\tTEST	0x0f,R3\n"
	"\tADD.Z 4,R1\n"
	"\tLSR.Z 4,R3\n"
	"\tTEST	0x03,R3\n"
	"\tADD.Z 2,R1\n"
	"\tLSR.Z 2,R3\n"
	"\tTEST	0x01,R3\n"
	"\tADD.Z 1,R1\n"
	"\tRETN\n");
#else
int	__attribute__((nolinline))
cltz(unsigned long v) {
	uint32_t	hv;
	int		cnt = 0;

	hv = v >> 32;
	if (hv == 0) {
		cnt += 32;
		hv = v & 0x0ffffffff;
	}

	hv = zip_bitrev(hv);
	if ((hv & 0x0ffff)==0) {
		cnt += 16;
		hv = hv >> 16;
	}
	if ((hv & 0x0ff)==0) {
		cnt += 8;
		hv = hv >> 8;
	}
	if ((hv & 0x0f)==0) {
		cnt += 4;
		hv = hv >> 4;
	}
	if ((hv & 0x03)==0) {
		cnt += 2;
		hv = hv >> 2;
	}
	if ((hv & 0x01)==0)
		cnt ++;
	return cnt;
}
#endif

#ifdef	__ZIPCPU__
#include <sys/unistd.h>
#include <stdio.h>
#include <string.h>

int _write_r(void *, int fd, const char *bf, size_t ln);

void	__attribute__((noinline))
sdump(const char *a) {
	int ln = strlen(a);
	_write_r(0, STDOUT_FILENO, a, ln);
}

void	__attribute__((noinline))
dump(unsigned long v) {
	char	s[24];

	for(int i=0; i<16; i++) {
		int d = (v>>(i*4)) & 0x0f;
		if (d < 10)
			s[15-i] = '0'+d;
		else
			s[15-i] = 'a'+d-10;
	} s[16] = ' '; s[17] = '\0';
	_write_r(0, STDOUT_FILENO, s, 17);
}
#else

#define	sdump(A)
#define	dump(A)

#endif

unsigned long udivdi3(unsigned long a, unsigned long b) {
	unsigned long	r;

	if (a < b)
		return 0;
	sdump("UD: ");
	dump(a); dump(b); sdump(" -- ");
	if (((b>>32)==0)&&((a>>32)==0)) {
		uint32_t	ia, ib, ir;

		ia = (uint32_t) a;
		ib = (uint32_t) b;
		ir = ia / ib;
		r = (unsigned long)ir;
		dump(r); sdump(" (A)\r\n");
		return r;
	}

	int	la = cltz(a), lb = cltz(b);
	a <<= la;
	unsigned long	m;
	if ((lb - la < 32)&&(((b<<la)&0x0ffffffff)==0)) {
		// Problem is now to divide
		//	[a * 2^(la-32)] / [b * 2^(la-32)] * 2^(la-la)
		//
		uint32_t	ia, ib, ir;
		b <<= la;
		ia = (uint32_t)(a>>32);
		ib = (uint32_t)(b>>32);
		ir = ia / ib;
		r = ir;
		dump(r); sdump(" (B)\r\n");
		return r;
	} else {
		// Problem is now to divide
		//	[a * 2^(la)] / [b * 2^(lb)] * 2^(lb-la)
		//
		b <<= lb;
		m = (1ul<<(lb-la));
		while(m > 0) {
			if (a >= b) {
				r |= m;
				a -= b;
			} m>>= 1;
			b >>= 1;
		}

		dump(r); sdump(" (C)\r\n");
		return r;
	}
}

