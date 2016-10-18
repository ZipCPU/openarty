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
#include <stdlib.h>
#include <unistd.h>
#include <strings.h>
#include <ctype.h>
#include <string.h>
#include <signal.h>
#include <assert.h>

#include "port.h"
#include "regdefs.h"
#include "flashdrvr.h"

const	bool	HIGH_SPEED = false;

#define SETSCOPE m_fpga->writeio(R_QSCOPE, 8180)


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

	printf("EREG before   : %08x\n", m_fpga->readio(R_QSPI_EREG));
	printf("Erasing sector: %08x\n", sector);
	m_fpga->writeio(R_QSPI_EREG, DISABLEWP);
	printf("EREG with WEL : %08x\n", m_fpga->readio(R_QSPI_EREG));
	SETSCOPE;
	m_fpga->writeio(R_QSPI_EREG, ERASEFLAG + sector);
	printf("EREG after    : %08x\n", m_fpga->readio(R_QSPI_EREG));

	// If we're in high speed mode and we want to verify the erase, then
	// we can skip waiting for the erase to complete by issueing a read
	// command immediately.  As soon as the erase completes the read will
	// begin sending commands back.  This allows us to recover the lost 
	// time between the interrupt and the next command being received.
	if  ((!HIGH_SPEED)||(!verify_erase)) {
		flwait();

		printf("@%08x -> %08x\n", R_QSPI_EREG,
				m_fpga->readio(R_QSPI_EREG));
		printf("@%08x -> %08x\n", R_QSPI_STAT,
				m_fpga->readio(R_QSPI_STAT));
		printf("@%08x -> %08x\n", sector,
				m_fpga->readio(sector));
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

bool	FLASHDRVR::write_page(const unsigned addr, const unsigned len,
		const unsigned *data, const bool verify_write) {
	DEVBUS::BUSW	buf[SZPAGEW];

	assert(len > 0);
	assert(len <= PGLENW);
	assert(PAGEOF(addr)==PAGEOF(addr+len-1));

	if (len <= 0)
		return true;

	// Write the page
	m_fpga->writeio(R_ICONTROL, ISPIF_DIS);
	m_fpga->clear();
	m_fpga->writeio(R_ICONTROL, ISPIF_EN);
	printf("Writing page: 0x%08x - 0x%08x\n", addr, addr+len-1);
	m_fpga->writeio(R_QSPI_EREG, DISABLEWP);
	SETSCOPE;
	m_fpga->writei(addr, len, data);

	// If we're in high speed mode and we want to verify the write, then
	// we can skip waiting for the write to complete by issueing a read
	// command immediately.  As soon as the write completes the read will
	// begin sending commands back.  This allows us to recover the lost 
	// time between the interrupt and the next command being received.
	flwait();
	// if ((!HIGH_SPEED)||(!verify_write)) { }
	if (verify_write) {
		// printf("Attempting to verify page\n");
		// NOW VERIFY THE PAGE
		m_fpga->readi(addr, len, buf);
		for(int i=0; i<len; i++) {
			if (buf[i] != data[i]) {
				printf("\nVERIFY FAILS[%d]: %08x\n", i, i+addr);
				printf("\t(Flash[%d]) %08x != %08x (Goal[%08x])\n", 
					i, buf[i], data[i], i+addr);
				return false;
			}
		} // printf("\nVerify success\n");
	} return true;
}

#define	VCONF_VALUE	0x8b

bool	FLASHDRVR::verify_config(void) {
	unsigned cfg = m_fpga->readio(R_QSPI_VCONF);
	// printf("CFG = %02x\n", cfg);
	return (cfg == VCONF_VALUE);
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
		const unsigned *data, const bool verify) {

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

	// m_fpga->writeio(R_QSPI_CREG, 2);
	// m_fpga->readio(R_VERSION);	// Read something innocuous

	// Just to make sure the driver knows that these values are ...
	// m_fpga->readio(R_QSPI_CREG);
	// m_fpga->readio(R_QSPI_SREG);
	// Because the status register may invoke protections here, we
	// void them.
	// m_fpga->writeio(R_QSPI_SREG, 0);
	// m_fpga->readio(R_VERSION);	// Read something innocuous

	for(unsigned s=SECTOROF(addr); s<SECTOROF(addr+len+SECTORSZW-1); s+=SECTORSZW) {
		// printf("IN LOOP, s=%08x\n", s);
		// Do we need to erase?
		bool	need_erase = false;
		unsigned newv = 0; // (s<addr)?addr:s;
		{
			DEVBUS::BUSW	*sbuf = new DEVBUS::BUSW[SECTORSZW];
			const DEVBUS::BUSW *dp;
			unsigned	base,ln;
			base = (addr>s)?addr:s;
			ln=((addr+len>s+SECTORSZW)?(s+SECTORSZW):(addr+len))-base;
			m_fpga->readi(base, ln, sbuf);

			dp = &data[base-addr];
			SETSCOPE;
			for(unsigned i=0; i<ln; i++) {
				if ((sbuf[i]&dp[i]) != dp[i]) {
					printf("\nNEED-ERASE @0x%08x ... %08x != %08x (Goal)\n", 
						i+base-addr, sbuf[i], dp[i]);
					need_erase = true;
					newv = i+base;
					break;
				} else if ((sbuf[i] != dp[i])&&(newv == 0)) {
					// if (newv == 0)
						// printf("MEM[%08x] = %08x (!= %08x (Goal))\n",
							// i+base, sbuf[i], dp[i]);
					newv = i+base;
				}
			}
		}

		if (newv == 0)
			continue; // This sector already matches

		// Just erase anyway
		if (!need_erase)
			printf("NO ERASE NEEDED\n");
		else {
			printf("ERASING SECTOR: %08x\n", s);
			if (!erase_sector(s, verify)) {
				printf("SECTOR ERASE FAILED!\n");
				return false;
			} newv = (s<addr) ? addr : s;
		}
		for(unsigned p=newv; (p<s+SECTORSZW)&&(p<addr+len); p=PAGEOF(p+PGLENW)) {
			unsigned start = p, len = addr+len-start;

			// BUT! if we cross page boundaries, we need to clip
			// our results to the page boundary
			if (PAGEOF(start+len-1)!=PAGEOF(start))
				len = PAGEOF(start+PGLENW)-start;
			if (!write_page(start, len, &data[p-addr], verify)) {
				printf("WRITE-PAGE FAILED!\n");
				return false;
			}
		}
	}

	m_fpga->writeio(R_QSPI_EREG, ENABLEWP); // Re-enable write protection

	return true;
}

