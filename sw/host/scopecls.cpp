////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	scopecls.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	After rebuilding the same code over and over again for every
//		"scope" I tried to interact with, I thought it would be simpler
//	to try to make a more generic interface, that other things could plug
//	into.  This is that more generic interface.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2017, Gisselquist Technology, LLC
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
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
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
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <strings.h>
#include <ctype.h>
#include <string.h>
#include <signal.h>
#include <assert.h>

#include "devbus.h"
#include "scopecls.h"

bool	SCOPE::ready() {
	unsigned v;
	v = m_fpga->readio(m_addr);
	if (m_scoplen == 0) {
		m_scoplen = (1<<((v>>20)&0x01f));
	} v = (v>>28)&6;
	return (v==6);
}

void	SCOPE::decode_control(void) {
	unsigned	v;

	v = m_fpga->readio(m_addr);
	printf("\t31. RESET:\t%s\n", (v&0x80000000)?"Ongoing":"Complete");
	printf("\t30. STOPPED:\t%s\n", (v&0x40000000)?"Yes":"No");
	printf("\t29. TRIGGERED:\t%s\n", (v&0x20000000)?"Yes":"No");
	printf("\t28. PRIMED:\t%s\n", (v&0x10000000)?"Yes":"No");
	printf("\t27. MANUAL:\t%s\n", (v&0x08000000)?"Yes":"No");
	printf("\t26. DISABLED:\t%s\n", (v&0x04000000)?"Yes":"No");
	printf("\t25. ZERO:\t%s\n", (v&0x02000000)?"Yes":"No");
	printf("\tSCOPLEN:\t%08x (%d)\n", m_scoplen, m_scoplen);
	printf("\tHOLDOFF:\t%08x\n", (v&0x0fffff));
	printf("\tTRIGLOC:\t%d\n", m_scoplen-(v&0x0fffff));
}

int	SCOPE::scoplen(void) {
	if (m_scoplen == 0) {
		int	lgln = (m_fpga->readio(m_addr)>>20)&0x01f;
		m_scoplen = (1<<lgln);
	} return m_scoplen;
}

void	SCOPE::read(void) {
	DEVBUS::BUSW	addrv = 0;

	scoplen();
	if (m_scoplen <= 4) {
		printf("Not a scope?\n");
	}

	DEVBUS::BUSW	*buf;

	buf = new DEVBUS::BUSW[m_scoplen];

	if (m_vector_read) {
		m_fpga->readz(m_addr+4, m_scoplen, buf);
	} else {
		for(unsigned int i=0; i<m_scoplen; i++)
			buf[i] = m_fpga->readio(m_addr+4);
	}

	if(m_compressed) {
		for(int i=0; i<(int)m_scoplen; i++) {
			if ((buf[i]>>31)&1) {
				addrv += (buf[i]&0x7fffffff);
				printf(" ** (+0x%08x = %8d)\n",
					(buf[i]&0x07fffffff),
					(buf[i]&0x07fffffff));
				continue;
			}
			printf("%10d %08x: ", addrv++, buf[i]);
			decode(buf[i]);
			printf("\n");
		}
	} else {
		for(int i=0; i<(int)m_scoplen; i++) {
			if ((i>0)&&(buf[i] == buf[i-1])&&(i<(int)(m_scoplen-1))) {
				if ((i>2)&&(buf[i] != buf[i-2]))
					printf(" **** ****\n");
				continue;
			} printf("%9d %08x: ", i, buf[i]);
			decode(buf[i]);
			printf("\n");
		}
	}

	delete[] buf;
}

