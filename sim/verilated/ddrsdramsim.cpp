////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	ddrsdramsim.cpp
//
// Project:	A wishbone controlled DDR3 SDRAM memory controller.
//
// Purpose:	
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2020, Gisselquist Technology, LLC
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

#define	PREFIX 	"DDR3-SDRAM"
const unsigned ckCL = 11,
		ckRP = 11,
		ckRC = 10,
		ckRAS = 7,
		ckRFC = 320, // Clocks from refresh to activate
		ckREFI = 1560, // 7.8us @ 200MHz = 7.8e-6 * 200e6 = 1560
		DDR_MR2 = 0x040 | (((ckCL-5)&7)<<3),
		DDR_MR1 = 0x0844,
		DDR_MR0 = 0x0200 | (((ckCL-4)&0x07)<<4) | ((ckCL>11)?0x4:0);
/*
const unsigned	nREF = 4,
		ckREFIn = nREF*ckREFI - (nREF-1) * ckRFC;
*/
const unsigned	nREF = 1,
		ckREFIn = ckREFI;

#include "ddrsdramsim.h"

BANKINFO::BANKINFO(void) {
	m_state = 0; m_row = 0; m_wcounter = 0; m_min_time_before_precharge=0;
}

void	BANKINFO::tick(int cmd, unsigned addr) {
	if (m_wcounter)
		m_wcounter--;
	switch(cmd) {
		case DDR_REFRESH:
			assert(m_state == 0);
			break;
		case DDR_PRECHARGE:
			// assert((m_state&((1<<ckRP)-1)) == ((1<<ckRP)-1));
			m_state &= -2;
			// While the specification allows precharging an already
			// precharged bank, we can keep that from happening
			// here:
			// assert(m_state&7);
			// Only problem is, this will currently break our
			// refresh logic.
			/*
			if (m_min_time_before_precharge != 0) {
				printf("BANK-FAIL: TIME-BEFORE-PRECHARGE = %d (should be zero)\n", m_min_time_before_precharge);
				assert(m_min_time_before_precharge == 0);
			} if (m_min_time_before_activate != 0) {
				printf("BANK-FAIL: TIME-BEFORE-ACTIVATE = %d (should be zero)\n", m_min_time_before_activate);
				assert(m_min_time_before_activate==0);
			}
			*/
			break;
		case DDR_ACTIVATE:
			assert((m_state&((1<<ckRP)-1)) == 0);
			if (((m_state&7)!=0)&&((addr&0x7fff) != m_row)) {
				printf("BANK-FAIL: Attempt to Activate an already active bank without closing it first (m_state = %x)\n", m_state);
				assert((m_state&7)==0);
			}

			/*
			if (m_wcounter != 0) {
				printf("BANK-FAIL: ACTIVATE too soon after write (wcounter = %d)\n", m_wcounter);
				assert(m_wcounter == 0);
			} if (m_min_time_before_activate!=0) {
				printf("BANK-FAIL: ACTIVATE too soon after last activate, (ctr=%d)\n", m_min_time_before_activate);
				assert(m_min_time_before_activate==0);
			}
			*/
			m_state = 1;
			m_row = addr & 0x7fff;
			m_min_time_before_precharge = ckRAS;
			m_min_time_before_activate = ckRC;
			break;
		case DDR_READ: case DDR_WRITE:
			if (DDR_READ)
				assert(m_wcounter == 0);
			else
				m_wcounter = 3+4+4;
			if ((m_state&((1<<ckRP)-1)) != ((1<<ckRP)-1)) {
				printf(PREFIX "::R/W Error: m_state = %08x, ckRP = %d (%08x)\n",
					m_state, ckRP, ((1<<ckRP)-1));
				assert((m_state&((1<<ckRP)-1)) == ((1<<ckRP)-1));
			}
			if (m_min_time_before_precharge)
				m_min_time_before_precharge--;
			if (m_min_time_before_activate)
				m_min_time_before_activate--;
			break;
		case DDR_ZQS:
			assert((m_state&((1<<ckRP)-1)) == 0);
			if (m_min_time_before_precharge)
				m_min_time_before_precharge--;
			if (m_min_time_before_activate)
				m_min_time_before_activate--;
			break;
		case DDR_NOOP:
			m_state <<= 1;
			m_state |= (m_state&2)>>1;
			m_state &= ((1<<ckRP)-1);
			if (m_min_time_before_precharge)
				m_min_time_before_precharge--;
			if (m_min_time_before_activate)
				m_min_time_before_activate--;
			break;
		default:
			break;
	}
}
	
int gbl_state, gbl_counts;

DDRSDRAMSIM::DDRSDRAMSIM(int lglen) {
	m_memlen = (1<<(lglen-2));
	m_mem = new unsigned[m_memlen];
	m_reset_state = 0;
	m_reset_counts= 0;
	assert(NTIMESLOTS > ckCL+3);
	m_bus = new BUSTIMESLOT[NTIMESLOTS];
	for(int i=0; i<NTIMESLOTS; i++)
		m_bus[i].m_used = 0;
	for(int i=0; i<NTIMESLOTS; i++)
		m_bus[i].m_rtt = 0;
	m_busloc = 0;
}

unsigned DDRSDRAMSIM::operator()(int reset_n, int cke,
		int csn, int rasn, int casn, int wen,
		int dqs, int dm, int odt, int busoe,
		int addr, int ba, int data) {
	BUSTIMESLOT	*ts, *nxtts;
	int	cmd = (reset_n?0:32)|(cke?0:16)|(csn?8:0)
			|(rasn?4:0)|(casn?2:0)|(wen?1:0);

	if ((m_reset_state!=0)&&(reset_n==0)) {
		m_reset_state = 0;
		m_reset_counts = 0;
	} else if (m_reset_state < 16) {
		switch(m_reset_state) {
		case 0: 
			m_reset_counts++;
			if (reset_n) {
				assert(m_reset_counts > 40000);
				m_reset_counts = 0;
				m_reset_state = 1;
			} break;
		case 1:
			m_reset_counts++;
			if (cke) {
				assert(m_reset_counts > 100000);
				m_reset_counts = 0;
				m_reset_state = 2;
			} break;
		case 2:
			m_reset_counts++;
			assert(cke);
			if (cmd != DDR_NOOP) {
				assert(m_reset_counts > 147);
				m_reset_counts = 0;
				m_reset_state = 3;
				assert(cmd == DDR_MRSET);
				// Set MR2
				assert(ba == 2);
				assert(addr == DDR_MR2);
			} break;
		case 3:
			m_reset_counts++;
			assert(cke);
			if (cmd != DDR_NOOP) {
				// assert(m_reset_counts > 3);
				m_reset_counts = 0;
				m_reset_state = 4;
				assert(cmd == DDR_MRSET);
				// Set MR1
				assert(ba == 1);
				assert(addr == DDR_MR1);
			} break;
		case 4:
			m_reset_counts++;
			assert(cke);
			if (cmd != DDR_NOOP) {
				printf(PREFIX "::RESET-CMD[4]: %d:%08x[%d]@0x%04x\n", cmd, m_reset_counts, ba, addr);
				assert(m_reset_counts > 3);
				m_reset_counts = 0;
				m_reset_state = 5;
				assert(cmd == DDR_MRSET);
				// Set MR0
				assert(ba == 0);
				assert(addr == DDR_MR0);
			} break;
		case 5:
			m_reset_counts++;
			assert(cke);
			if (cmd != DDR_NOOP) {
				printf(PREFIX "::RESET-CMD[5]: %d:%08x[%d]@0x%04x\n", cmd, m_reset_counts, ba, addr);
				assert(m_reset_counts > 11);
				m_reset_counts = 0;
				m_reset_state = 6;
				assert(cmd == DDR_ZQS);
				assert(addr == 0x400);
			} break;
		case 6:
			m_reset_counts++;
			assert(cke);
			if (cmd != DDR_NOOP) {
				printf(PREFIX "::RESET-CMD[6]: %d:%08x[%d]@0x%04x\n", cmd, m_reset_counts, ba, addr);
				assert(m_reset_counts > 512);
				m_reset_counts = 0;
				m_reset_state = 7;
				assert(cmd == DDR_PRECHARGE);
				assert(addr == 0x400);
			} break;
		case 7:
			m_reset_counts++;
			assert(cke);
			if (cmd != DDR_NOOP) {
				printf(PREFIX "::RESET-CMD[7]: %d:%08x[%d]@0x%04x\n", cmd, m_reset_counts, ba, addr);
				assert(m_reset_counts > 3);
				m_reset_counts = 0;
				m_reset_state = 8;
				assert(cmd == DDR_REFRESH);
				m_clocks_since_refresh = 0;
			} break;
		case 8:
			m_reset_counts++;
			assert(cke);
			assert(cmd == DDR_NOOP);
			if (m_reset_counts > 140) {
				m_reset_state = 16;
				printf(PREFIX ": Leaving reset state\n");
			}
			break;
		default:
			break;
		}

		gbl_state = m_reset_state;
		gbl_counts= m_reset_counts;
		m_nrefresh_issued = nREF;
		m_clocks_since_refresh++;
		for(int i=0; i<NBANKS; i++)
			m_bank[i].tick(cmd, 0);
	} else if (!cke) {
		assert(0&&"Clock not enabled!");
	} else if ((cmd == DDR_REFRESH)||(m_nrefresh_issued < (int)nREF)) {
		if (DDR_REFRESH == cmd) {
			m_clocks_since_refresh = 0;
			if (m_nrefresh_issued >= (int)nREF)
				m_nrefresh_issued = 1;
			else
				m_nrefresh_issued++;
		} else {
			m_clocks_since_refresh++;
			assert(DDR_NOOP == cmd);
		}
		for(int i=0; i<NBANKS; i++)
			m_bank[i].tick(cmd,0);

		if (m_nrefresh_issued == nREF)
			printf(PREFIX "::Refresh cycle complete\n");
	} else {
		// In operational mode!!

		m_clocks_since_refresh++;
		assert(m_clocks_since_refresh < (int)ckREFIn);
		switch(cmd) {
		case DDR_MRSET:
			assert(0&&"Modes should only be set in reset startup");
			for(int i=0; i<NBANKS; i++)
				m_bank[i].tick(DDR_MRSET,0);
			break;
		case DDR_REFRESH:
			for(int i=0; i<NBANKS; i++)
				m_bank[i].tick(DDR_REFRESH,0);
			m_clocks_since_refresh = 0;
			assert(0 && "Internal err: Refresh should be handled above");
			break;
		case DDR_PRECHARGE:
			if (addr & 0x400) {
				// Precharge all
				for(int i=0; i<NBANKS; i++)
					m_bank[i].tick(DDR_PRECHARGE,0);
			} else {
				m_bank[ba].tick(DDR_PRECHARGE,0);
				for(int i=0; i<NBANKS; i++)
					if (ba != i)
						m_bank[i].tick(DDR_NOOP,0);
			}
			break;
		case DDR_ACTIVATE:
			if (m_clocks_since_refresh < (int)ckRFC) {
				printf(PREFIX "::ACTIVATE -- not enough clocks since refresh, %d < %d should be true\n", m_clocks_since_refresh, ckRFC);
				assert(m_clocks_since_refresh >= (int)ckRFC);
			}
			printf(PREFIX "::Activating bank %d, address %08x\n", ba, addr);
			m_bank[ba].tick(DDR_ACTIVATE,addr);
			for(int i=0; i<NBANKS; i++)
				if (i!=ba) m_bank[i].tick(DDR_NOOP,0);
			break;
		case DDR_WRITE:
			{
				// This SIM doesn't handle out of order writes
				assert((addr&7)==0);
				m_bank[ba].tick(DDR_WRITE, addr);
				for(int i=0; i<NBANKS; i++)
					if (i!=ba)m_bank[i].tick(DDR_NOOP,addr);
				unsigned caddr = m_bank[ba].m_row;
				caddr <<= 3;
				caddr |= ba;
				caddr <<= 10;
				caddr |= addr;
				caddr &= ~7;
				caddr >>= 1;

				BUSTIMESLOT *tp;
				int	offset = m_busloc+ckCL+1;

				tp = &m_bus[(offset+0)&(NTIMESLOTS-1)];
				// printf("Setting bus timeslots from (now=%d)+%d=%d to now+%d+3\n", m_busloc, ckCL,(m_busloc+ckCL)&(NTIMESLOTS-1), ckCL);
				tp->m_addr = caddr  ;
				tp->m_used = 1;
				tp->m_read = 0;

				tp = &m_bus[(offset+1)&(NTIMESLOTS-1)];
				tp->m_addr = caddr+1;
				tp->m_used = 1;
				tp->m_read = 0;

				tp = &m_bus[(offset+2)&(NTIMESLOTS-1)];
				tp->m_addr = caddr+2;
				tp->m_used = 1;
				tp->m_read = 0;

				tp = &m_bus[(offset+3)&(NTIMESLOTS-1)];
				tp->m_addr = caddr+3;
				tp->m_used = 1;
				tp->m_read = 0;
			} break;
		case DDR_READ:
			{
				// This SIM doesn't handle out of order reads
				assert((addr&7)==0);
				m_bank[ba].tick(DDR_READ, addr);
				for(int i=0; i<NBANKS; i++)
					if (i!=ba)m_bank[i].tick(DDR_NOOP,addr);
				unsigned caddr = m_bank[ba].m_row;
				caddr <<= 3;
				caddr |= ba;
				caddr <<= 10;
				caddr |= addr;
				caddr &= ~7;
				caddr >>= 1;

				BUSTIMESLOT *tp;
	
				int offset = (m_busloc+ckCL+1)&(NTIMESLOTS-1);
				tp = &m_bus[(offset)&(NTIMESLOTS-1)];
				tp->m_data = m_mem[caddr];
				tp->m_addr = caddr;
				tp->m_used = 1;
				tp->m_read = 1;
	
				tp = &m_bus[(offset+1)&(NTIMESLOTS-1)];
				tp->m_data = m_mem[caddr+1];
				tp->m_addr = caddr+1;
				tp->m_used = 1;
				tp->m_read = 1;

				tp = &m_bus[(offset+2)&(NTIMESLOTS-1)];
				tp->m_data = m_mem[caddr+2];
				tp->m_addr = caddr+2;
				tp->m_used = 1;
				tp->m_read = 1;

				tp = &m_bus[(offset+3)&(NTIMESLOTS-1)];
				tp->m_data = m_mem[caddr+3];
				tp->m_addr = caddr+3;
				tp->m_used = 1;
				tp->m_read = 1;
			} break;
		case DDR_ZQS:
			assert(0&&"Sim does not support ZQS outside of startup");
			break;
		case DDR_NOOP:
			for(int i=0; i<NBANKS; i++)
				m_bank[i].tick(DDR_NOOP,addr);
			break;
		default: // We are deselecteda
			for(int i=0; i<NBANKS; i++)
				m_bank[i].tick(DDR_NOOP,addr);
			break;
		}

		if (false) {
			bool flag = false;
			for(int i=0; i<5; i++) {
				int bl = (m_busloc+1+i)&(NTIMESLOTS-1);
				nxtts = &m_bus[bl];
				if (nxtts->m_used) {
					flag = true;
					break;
				}
			} if (flag) {
			printf("DQS = %d BUSLOC = %d\n", dqs, (m_busloc+1)&(NTIMESLOTS-1));
			for(int i=0; i<5; i++) {
				int bl = (m_busloc+1+i)&(NTIMESLOTS-1);
				nxtts = &m_bus[bl];
				printf("BUS[%2d] ", bl);
				if (nxtts->m_used)
					printf(" USED");
				if (nxtts->m_read)
					printf(" READ");
				if (nxtts->m_rtt)
					printf(" RTT");
				printf("\n");
			}}
		}

		ts = &m_bus[(m_busloc+1)&(NTIMESLOTS-1)];
		if (dqs)
			assert((ts->m_rtt)&&(m_last_rtt));
		else if (!m_last_dqs)
			assert(!m_last_rtt);
	}

	m_busloc = (m_busloc+1)&(NTIMESLOTS-1);

	ts = &m_bus[m_busloc];
	nxtts = &m_bus[(m_busloc+1)&(NTIMESLOTS-1)];
	unsigned vl = ts->m_data;
	assert( ((!ts->m_used)||(busoe))
		|| ((ts->m_used)&&(ts->m_read)&&(!busoe))
		|| ((ts->m_used)&&(!ts->m_read)&&(busoe))
		);

	m_last_dqs = dqs;
	m_last_rtt = ts->m_rtt;

	if (ts->m_used) {
		if (ts->m_read)
			assert((!dqs)&&(!m_last_dqs));
		else
			assert((dqs) && (m_last_dqs));
	} else if (!nxtts->m_used)
		assert(!dqs);

	assert((!ts->m_used)||(ts->m_addr < (unsigned)m_memlen));
	if ((ts->m_used)&&(!ts->m_read)&&(!dm)) {
		printf(PREFIX "::Setting MEM[%08x] = %08x\n", ts->m_addr, data);
		m_mem[ts->m_addr] = data;
	}

	m_bus[(m_busloc+3)&(NTIMESLOTS-1)].m_rtt = (odt)&&(reset_n);
	ts->m_used = 0;
	ts->m_read = 0;
	ts->m_addr = -1;
	ts->m_rtt  = 0;
	return (!busoe)?vl:data;
}

