////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	flashdrvr.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Flash driver.  Encapsulates the erasing and programming (i.e.
//		writing) necessary to set the values in a flash device.
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
#include <stdint.h>
#include <unistd.h>
#include <strings.h>
#include <ctype.h>
#include <string.h>
#include <signal.h>
#include <assert.h>

#include "port.h"
#include "regdefs.h"
#include "flashdrvr.h"
#include "byteswap.h"

const	bool	HIGH_SPEED = false;

#define	SETSCOPE
// #define SETSCOPE m_fpga->writeio(R_QSCOPE, 8180)


void	FLASHDRVR::flwait(void) {
	DEVBUS::BUSW	v;

	v = m_fpga->readio(R_QSPI_EREG);
	if ((v&ERASEFLAG)==0)
		return;
	m_fpga->writeio(R_ICONTROL, ISPIF_DIS);
	m_fpga->clear();
	m_fpga->writeio(R_ICONTROL, ISPIF_EN);

	do {
		// Start by checking that we are still erasing.  The interrupt
		// may have been generated while we were setting things up and
		// disabling things, so this just double checks for us.  If
		// the interrupt was tripped, we're done.  If not, we can now
		// wait for an interrupt.
		v = m_fpga->readio(R_QSPI_EREG);
		if (v&ERASEFLAG) {
			m_fpga->usleep(400);
			if (m_fpga->poll()) {
				m_fpga->clear();
				m_fpga->writeio(R_ICONTROL, ISPIF_EN);
			}
		}
	} while(v & ERASEFLAG);
}

bool	FLASHDRVR::erase_sector(const unsigned sector, const bool verify_erase) {
	DEVBUS::BUSW	page[SZPAGEW];

	if (m_debug) printf("EREG before   : %08x\n", m_fpga->readio(R_QSPI_EREG));
	if (m_debug) printf("Erasing sector: %08x\n", sector);
	m_fpga->writeio(R_QSPI_EREG, DISABLEWP);
	if (m_debug) printf("EREG with WEL : %08x\n", m_fpga->readio(R_QSPI_EREG));
	SETSCOPE;
	m_fpga->writeio(R_QSPI_EREG, ERASEFLAG + (sector>>2));
	if (m_debug) printf("EREG after    : %08x\n", m_fpga->readio(R_QSPI_EREG));

	// If we're in high speed mode and we want to verify the erase, then
	// we can skip waiting for the erase to complete by issueing a read
	// command immediately.  As soon as the erase completes the read will
	// begin sending commands back.  This allows us to recover the lost 
	// time between the interrupt and the next command being received.
	if  ((!HIGH_SPEED)||(!verify_erase)) {
		flwait();

		if (m_debug) {
			printf("@%08x -> %08x\n", R_QSPI_EREG,
				m_fpga->readio(R_QSPI_EREG));
			printf("@%08x -> %08x\n", R_QSPI_STAT,
				m_fpga->readio(R_QSPI_STAT));
			printf("@%08x -> %08x\n", sector,
				m_fpga->readio(sector));
		}
	}

	// Now, let's verify that we erased the sector properly
	if (verify_erase) {
		for(int i=0; i<NPAGES; i++) {
			m_fpga->readi(sector+i*SZPAGEW, SZPAGEW, page);
			for(int i=0; i<SZPAGEW; i++)
				if (page[i] != 0xffffffff)
					return false;
		}
	}

	return true;
}

bool	FLASHDRVR::page_program(const unsigned addr, const unsigned len,
		const char *data, const bool verify_write) {
	DEVBUS::BUSW	buf[SZPAGEW], bswapd[SZPAGEW];

	assert(len > 0);
	assert(len <= PGLENB);
	assert(PAGEOF(addr)==PAGEOF(addr+len-1));

	if (len <= 0)
		return true;

	bool	empty_page = true;
	for(unsigned i=0; i<len; i+=4) {
		DEVBUS::BUSW v;
		v = buildword((const unsigned char *)&data[i]);
		bswapd[(i>>2)] = v;
		if (v != 0xffffffff)
			empty_page = false;
	}

	if (!empty_page) {
		// Write the page
		m_fpga->writeio(R_ICONTROL, ISPIF_DIS);
		m_fpga->clear();
		m_fpga->writeio(R_ICONTROL, ISPIF_EN);
		printf("Writing page: 0x%08x - 0x%08x\r", addr, addr+len-1);
		m_fpga->writeio(R_QSPI_EREG, DISABLEWP);
		SETSCOPE;
		m_fpga->writei(addr, (len>>2), bswapd);
		fflush(stdout);

		// If we're in high speed mode and we want to verify the write,
		// then we can skip waiting for the write to complete by
		// issueing a read command immediately.  As soon as the write
		// completes the read will begin sending commands back.  This
		// allows us to recover the lost time between the interrupt and
		// the next command being received.
		flwait();
	}
	// if ((!HIGH_SPEED)||(!verify_write)) { }
	if (verify_write) {
		// printf("Attempting to verify page\n");
		// NOW VERIFY THE PAGE
		m_fpga->readi(addr, len>>2, buf);
		for(unsigned i=0; i<(len>>2); i++) {
			if (buf[i] != bswapd[i]) {
				printf("\nVERIFY FAILS[%d]: %08x\n", i, (i<<2)+addr);
				printf("\t(Flash[%d]) %08x != %08x (Goal[%08x])\n", 
					(i<<2), buf[i], bswapd[i], (i<<2)+addr);
				return false;
			}
		} // printf("\nVerify success\n");
	} return true;
}

#define	VCONF_VALUE	0x8b
#define	VCONF_VALUE_ALT	0x83

bool	FLASHDRVR::verify_config(void) {
	unsigned cfg = m_fpga->readio(R_QSPI_VCONF);
	if (cfg != VCONF_VALUE)
		printf("Unexpected volatile configuration = %02x\n", cfg);
	return ((cfg == VCONF_VALUE)||(cfg == VCONF_VALUE_ALT));
}

void	FLASHDRVR::set_config(void) {
	// There is some delay associated with these commands, but it should
	// be dwarfed by the communication delay.  If you wish to do this on the
	// device itself, you may need to use some timers.
	//
	// Set the write-enable latch
	m_fpga->writeio(R_QSPI_EREG, DISABLEWP);
	// Set the volatile configuration register
	m_fpga->writeio(R_QSPI_VCONF, VCONF_VALUE);
	// Clear the write-enable latch, since it didn't clear automatically
	printf("EREG = %08x\n", m_fpga->readio(R_QSPI_EREG));
	m_fpga->writeio(R_QSPI_EREG, ENABLEWP);
}

bool	FLASHDRVR::write(const unsigned addr, const unsigned len,
		const char *data, const bool verify) {

	assert(addr >= EQSPIFLASH);
	assert(addr+len <= EQSPIFLASH + FLASHLEN);

	if (!verify_config()) {
		set_config();
		if (!verify_config()) {
			printf("Invalid configuration, cannot program flash\n");
			return false;
		}
	}

	// Work through this one sector at a time.
	// If this buffer is equal to the sector value(s), go on
	// If not, erase the sector

	for(unsigned s=SECTOROF(addr); s<SECTOROF(addr+len+SECTORSZB-1);
			s+=SECTORSZB) {
		// Do we need to erase?
		bool	need_erase = false, need_program = false;
		unsigned newv = 0; // (s<addr)?addr:s;
		{
			char *sbuf = new char[SECTORSZB];
			const char *dp;	// pointer to our "desired" buffer
			unsigned	base,ln;

			base = (addr>s)?addr:s;
			ln=((addr+len>s+SECTORSZB)?(s+SECTORSZB):(addr+len))-base;
			m_fpga->readi(base, ln>>2, (uint32_t *)sbuf);
			byteswapbuf(ln>>2, (uint32_t *)sbuf);

			dp = &data[base-addr];
			SETSCOPE;
			for(unsigned i=0; i<ln; i++) {
				if ((sbuf[i]&dp[i]) != dp[i]) {
					if (m_debug) {
						printf("\nNEED-ERASE @0x%08x ... %08x != %08x (Goal)\n", 
							i+base-addr, sbuf[i], dp[i]);
					}
					need_erase = true;
					newv = (i&-4)+base;
					break;
				} else if ((sbuf[i] != dp[i])&&(newv == 0))
					newv = (i&-4)+base;
			}
		}

		if (newv == 0)
			continue; // This sector already matches

		// Erase the sector if necessary
		if (!need_erase) {
			if (m_debug) printf("NO ERASE NEEDED\n");
		} else {
			printf("ERASING SECTOR: %08x\n", s);
			if (!erase_sector(s, verify)) {
				printf("SECTOR ERASE FAILED!\n");
				return false;
			} newv = (s<addr) ? addr : s;
		}

		// Now walk through all of our pages in this sector and write
		// to them.
		for(unsigned p=newv; (p<s+SECTORSZB)&&(p<addr+len); p=PAGEOF(p+PGLENB)) {
			unsigned start = p, len = addr+len-start;

			// BUT! if we cross page boundaries, we need to clip
			// our results to the page boundary
			if (PAGEOF(start+len-1)!=PAGEOF(start))
				len = PAGEOF(start+PGLENB)-start;
			if (!page_program(start, len, &data[p-addr], verify)) {
				printf("WRITE-PAGE FAILED!\n");
				return false;
			}
		} if ((need_erase)||(need_program))
			printf("Sector 0x%08x: DONE%15s\n", s, "");
	}

	m_fpga->writeio(R_QSPI_EREG, ENABLEWP); // Re-enable write protection

	return true;
}

