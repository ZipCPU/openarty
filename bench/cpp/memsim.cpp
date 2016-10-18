////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	memsim.h
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This creates a memory like device to act on a WISHBONE bus.
//		It doesn't exercise the bus thoroughly, but does give some
//		exercise to the bus to see whether or not the bus master
//		can control it.
//
//	This particular version differs from the memsim version within the
//	ZipCPU project in that there is a variable delay from request to
//	completion.
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
#include <stdio.h>
#include <assert.h>
#include "memsim.h"

MEMSIM::MEMSIM(const unsigned int nwords, const unsigned int delay) {
	unsigned int	nxt;
	for(nxt=1; nxt < nwords; nxt<<=1)
		;
	m_len = nxt; m_mask = nxt-1;
	m_mem = new BUSW[m_len];

	m_delay = delay;
	for(m_delay_mask=1; m_delay_mask < delay; m_delay_mask<<=1)
		;
	m_fifo_ack  = new int[m_delay_mask];
	m_fifo_data = new BUSW[m_delay_mask];
	for(unsigned i=0; i<m_delay_mask; i++)
		m_fifo_ack[i] = 0;
	m_delay_mask-=1;
	m_head = 0; m_tail = (m_head - delay)&m_delay_mask;
}

MEMSIM::~MEMSIM(void) {
	delete[]	m_mem;
}

void	MEMSIM::load(const char *fname) {
	FILE	*fp;
	unsigned int	nr;

	fp = fopen(fname, "r");
	if (!fp) {
		fprintf(stderr, "Could not open/load file \'%s\'\n",
			fname);
		perror("O/S Err:");
		fprintf(stderr, "\tInitializing memory with zero instead.\n");
		nr = 0;
	} else {
		nr = fread(m_mem, sizeof(BUSW), m_len, fp);
		fclose(fp);

		if (nr != m_len) {
			fprintf(stderr, "Only read %d of %d words\n",
				nr, m_len);
			fprintf(stderr, "\tFilling the rest with zero.\n");
		}
	}

	for(; nr<m_len; nr++)
		m_mem[nr] = 0l;
}

void	MEMSIM::apply(const unsigned char wb_cyc,
			const unsigned char wb_stb, const unsigned char wb_we,
			const BUSW wb_addr, const BUSW wb_data, 
			unsigned char &o_ack, unsigned char &o_stall, BUSW &o_data) {
	m_head++; m_tail = (m_head - m_delay)&m_delay_mask;
	m_head&=m_delay_mask;
	o_ack = m_fifo_ack[m_tail];
	o_data= m_fifo_data[m_tail];

	m_fifo_ack[ m_head] = 0;
	m_fifo_data[m_head] = 0;

	o_stall= 0;
	if ((wb_cyc)&&(wb_stb)) {
		if (wb_we)
			m_mem[wb_addr & m_mask] = wb_data;
		m_fifo_ack[m_head] = 1;
		m_fifo_data[m_head] = m_mem[wb_addr & m_mask];
#ifdef	DEBUG
		printf("MEMBUS %s[%08x] = %08x\n",
			(wb_we)?"W":"R",
			wb_addr&m_mask,
			m_mem[wb_addr&m_mask]);
#endif
		// o_ack  = 1;
	}

#ifdef	DEBUG
	if (o_ack) {
		printf("MEMBUS -- ACK %s 0x%08x - 0x%08x\n",
			(wb_we)?"WRITE":"READ ",
			wb_addr, o_data);
	}
#endif
}


