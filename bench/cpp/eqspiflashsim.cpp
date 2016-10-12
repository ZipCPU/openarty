////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	eqspiflashsim.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This library simulates the operation of a Quad-SPI commanded
//		flash, such as the Micron N25Q128A used on the Arty development
//		board by Digilent.  As such, it is defined by 16 MBytes of
//		memory (4 MWord).
//
//		This simulator is useful for testing in a Verilator/C++
//		environment, where this simulator can be used in place of
//		the actual hardware.
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
#include <string.h>
#include <assert.h>
#include <stdlib.h>

#include "eqspiflashsim.h"

#define	MEMBYTES	(1<<24)

static	const unsigned
	DEVESD = 0x014,
	// MICROSECONDS = 200,
	// MILLISECONDS = MICROSECONDS * 1000,
	// SECONDS = MILLISECONDS * 1000,
	MICROSECONDS = 20,
	MILLISECONDS = MICROSECONDS * 10,
	SECONDS = MILLISECONDS * 10,
	tSHSL1 =    4, // S# deselect time after a read command
	tSHSL2 =   10, // S# deselect time after a non-read command
	tW     =   1300 * MICROSECONDS, // write config cycle time
	tWNVCR =    200 * MILLISECONDS, // write nonvolatile-config cycle time
	tWVECR =    8, // write volatile enhanced config cycle time
	tBE    =   32 * SECONDS,	// Bulk erase time
	tDP    =   10 * SECONDS,	// Deep power down
	tRES   =   30 * SECONDS,
// Shall we artificially speed up this process?
// These numbers are the "typical" times
	tPP    = 500 * MICROSECONDS,	// Page program time
	tSE    = 700 * MILLISECONDS,	// Sector erase time
	tSS    = 250 * MILLISECONDS;	// Subsector erase time
// These are the maximum times
	// tW     = 8300 * MICROSECONDS, // write config cycle time
	// tWNVCR = 3000 * MILLISECONDS, // write nonvolatile-config cycle time
	// tWVECR =    8, // write volatile enhanced config cycle time
	// tPP    = 5000 * MICROSECONDS,
	// tSE    = 3000 * MILLISECONDS;
	// tSS    =  800 * MILLISECONDS;

static	const	char	IDSTR[20]= {
		0x20,		// Micron's ID, assigned by JEDEC
		(char)0xba, (char)0x18,	// Memory type and capacity
		(char)0x10,		// Length of data to follow
		(char)0xfe, (char)0xfd,	// Extended device ID and device config info
		(char)0xfc, (char)0xfb, (char)0xfa, (char)0xf9,
		(char)0xf8, (char)0xf7, (char)0xf6, (char)0xf5,
		(char)0xf4, (char)0xf3, (char)0xf2, (char)0xf1,
		(char)0xf0, (char)0xef 
	};

EQSPIFLASHSIM::EQSPIFLASHSIM(void) {
	const	int	NSECTORS = MEMBYTES>>16;
	m_mem = new char[MEMBYTES];
	m_pmem = new char[256];
	m_otp  = new char[65];
	for(int i=0; i<65; i++)
		m_otp[i] = 0x0ff;
	m_otp[64] = 1;
	m_otp_wp = false;
	m_lockregs = new char[NSECTORS];
	for(int i=0; i<NSECTORS; i++)
		m_lockregs[i] = 0;

	m_state = EQSPIF_IDLE;
	m_last_sck = 1;
	m_write_count = 0;
	m_ireg = m_oreg = 0;
	m_sreg = 0x01c;
	m_creg = 0x001;	// Initial creg on delivery
	m_vconfig   = 0x7; // Volatile configuration register
	m_nvconfig = 0x0fff; // Nonvolatile configuration register
	m_quad_mode = false;
	m_mode_byte = 0;
	m_flagreg = 0x0a5;

	m_debug = true;

	memset(m_mem, 0x0ff, MEMBYTES);
}

void	EQSPIFLASHSIM::load(const unsigned addr, const char *fname) {
	FILE	*fp;
	size_t	len;

	if (addr >= MEMBYTES)
		return; // return void
	len = MEMBYTES-addr*4;

	if (NULL != (fp = fopen(fname, "r"))) {
		int	nr = 0;
		nr = fread(&m_mem[addr*4], sizeof(char), len, fp);
		fclose(fp);
		if (nr == 0) {
			fprintf(stderr, "SPI-FLASH: Could not read %s\n", fname);
			perror("O/S Err:");
		}
	} else {
		fprintf(stderr, "SPI-FLASH: Could not open %s\n", fname);
		perror("O/S Err:");
	}
}

#define	QOREG(A)	m_oreg = ((m_oreg & (~0x0ff))|(A&0x0ff))

int	EQSPIFLASHSIM::operator()(const int csn, const int sck, const int dat) {
	// Keep track of a timer to determine when page program and erase
	// cycles complete.

	if (m_write_count > 0) {
		if (0 == (--m_write_count)) {// When done with erase/page pgm,
			// Clear the write in progress bit, together with the
			// write enable bit.
			m_sreg &= 0x0fc;
			if (m_debug) printf("Write complete, clearing WIP (inside SIM)\n");
		}
	}

	if (csn) {
		m_last_sck = 1;
		m_ireg = 0; m_oreg = 0;

		if ((EQSPIF_PP == m_state)||(EQSPIF_QPP == m_state)) {
			// Start a page program
			if (m_debug) printf("EQSPI: Page Program write cycle begins\n");
			if (m_debug) printf("CK = %d & 7 = %d\n", m_count, m_count & 0x07);
			if (m_debug) printf("EQSPI: pmem = %08lx\n", (unsigned long)m_pmem);
			assert((m_lockregs[(m_addr>>16)&0x0ff]&0x1)==0);
			assert((m_count & 7)==0);
			m_write_count = tPP;
			m_state = EQSPIF_IDLE;
			m_sreg &= (~EQSPIF_WEL_FLAG);
			m_sreg |= (EQSPIF_WIP_FLAG);
			for(int i=0; i<256; i++) {
				/*
				if (m_debug) printf("%02x: m_mem[%02x] = %02x &= %02x = %02x\n",
					i, (m_addr&(~0x0ff))+i,
					m_mem[(m_addr&(~0x0ff))+i]&0x0ff, m_pmem[i]&0x0ff,
					m_mem[(m_addr&(~0x0ff))+i]& m_pmem[i]&0x0ff);
				*/
				m_mem[(m_addr&(~0x0ff))+i] &= m_pmem[i];
			}
			m_quad_mode = false;
		} else if (EQSPIF_WRCR == m_state) {
			if (m_debug) printf("Actually writing volatile config register\n");
			if (m_debug) printf("CK = %d & 7 = %d\n", m_count, m_count & 0x07);
			m_state = EQSPIF_IDLE;
		} else if (EQSPIF_WRNVCONFIG == m_state) {
			if (m_debug) printf("Actually writing nonvolatile config register\n");
			m_write_count = tWNVCR;
			m_state = EQSPIF_IDLE;
		} else if (EQSPIF_WREVCONFIG == m_state) {
			if (m_debug) printf("Actually writing Enhanced volatile config register\n");
			m_state = EQSPIF_IDLE;
		} else if (EQSPIF_WRSR == m_state) {
			if (m_debug) printf("Actually writing status register\n");
			m_write_count = tW;
			m_state = EQSPIF_IDLE;
			m_sreg &= (~EQSPIF_WEL_FLAG);
			m_sreg |= (EQSPIF_WIP_FLAG);
		} else if (EQSPIF_WRLOCK == m_state) {
			if (m_debug) printf("Actually writing lock register\n");
			m_write_count = tW;
			m_state = EQSPIF_IDLE;
		} else if (EQSPIF_CLRFLAGS == m_state) {
			if (m_debug) printf("Actually clearing the flags register bits\n");
			m_state = EQSPIF_IDLE;
			m_flagreg &= 0x09f;
		} else if (m_state == EQSPIF_SUBSECTOR_ERASE) {
			if (m_debug) printf("Actually Erasing subsector, from %08x\n", m_addr);
			if (m_debug) printf("CK = %d & 7 = %d\n", m_count, m_count & 0x07);
			assert(((m_count & 7)==0)&&(m_count == 32));
			assert((m_lockregs[(m_addr>>16)&0x0ff]&0x1)==0);
			m_write_count = tSS;
			m_state = EQSPIF_IDLE;
			m_sreg &= (~EQSPIF_WEL_FLAG);
			m_sreg |= (EQSPIF_WIP_FLAG);
			m_addr &= (-1<<12);
			for(int i=0; i<(1<<12); i++)
				m_mem[m_addr + i] = 0x0ff;
			if (m_debug) printf("Now waiting %d ticks delay\n", m_write_count);
		} else if (m_state == EQSPIF_SECTOR_ERASE) {
			if (m_debug) printf("Actually Erasing sector, from %08x\n", m_addr);
			m_write_count = tSE;
			if (m_debug) printf("CK = %d & 7 = %d\n", m_count, m_count & 0x07);
			assert(((m_count & 7)==0)&&(m_count == 32));
			assert((m_lockregs[(m_addr>>16)&0x0ff]&0x1)==0);
			m_state = EQSPIF_IDLE;
			m_sreg &= (~EQSPIF_WEL_FLAG);
			m_sreg |= (EQSPIF_WIP_FLAG);
			m_addr &= (-1<<16);
			for(int i=0; i<(1<<16); i++)
				m_mem[m_addr + i] = 0x0ff;
			if (m_debug) printf("Now waiting %d ticks delay\n", m_write_count);
		} else if (m_state == EQSPIF_BULK_ERASE) {
			m_write_count = tBE;
			m_state = EQSPIF_IDLE;
			m_sreg &= (~EQSPIF_WEL_FLAG);
			m_sreg |= (EQSPIF_WIP_FLAG);
			// Should I be checking the lock register(s) here?
			for(int i=0; i<MEMBYTES; i++)
				m_mem[i] = 0x0ff;
		} else if (m_state == EQSPIF_PROGRAM_OTP) {
			// Program the One-Time Programmable (OTP memory
			if (m_debug) printf("EQSPI: OTP Program write cycle begins\n");
			if (m_debug) printf("CK = %d & 7 = %d\n", m_count, m_count & 0x07);
			// assert((m_lockregs[(m_addr>>16)&0x0ff]&0x1)==0);
			assert((m_count & 7)==0);
			m_write_count = tPP; // OTP cycle time as well
			m_state = EQSPIF_IDLE;
			m_sreg &= (~EQSPIF_WEL_FLAG);
			m_sreg |= (EQSPIF_WIP_FLAG);
			for(int i=0; i<65; i++)
				m_otp[i] &= m_pmem[i];
			m_otp_wp = ((m_otp[64]&1)==0);
		/*
		} else if (m_state == EQSPIF_DEEP_POWER_DOWN) {
			m_write_count = tDP;
			m_state = EQSPIF_IDLE;
		} else if (m_state == EQSPIF_RELEASE) {
			m_write_count = tRES;
			m_state = EQSPIF_IDLE;
		*/
		} else if (m_state == EQSPIF_QUAD_READ_CMD) {
			m_state = EQSPIF_IDLE;
			if (m_mode_byte!=0)
				m_quad_mode = false;
			else
				m_state = EQSPIF_XIP;
		} else if (m_state == EQSPIF_QUAD_READ) {
			m_state = EQSPIF_IDLE;
			if (m_mode_byte!=0)
				m_quad_mode = false;
			else
				m_state = EQSPIF_XIP;
		// } else if (m_state == EQSPIF_XIP) {
		}

		m_oreg = 0x0fe;
		m_count= 0;
		int out = m_nxtout[3];
		m_nxtout[3] = m_nxtout[2];
		m_nxtout[2] = m_nxtout[1];
		m_nxtout[1] = m_nxtout[0];
		m_nxtout[0] = dat;
		return out;
	} else if ((!m_last_sck)||(sck == m_last_sck)) {
		// Only change on the falling clock edge
		// printf("SFLASH-SKIP, CLK=%d -> %d\n", m_last_sck, sck);
		m_last_sck = sck;
		int out = m_nxtout[3];
		m_nxtout[3] = m_nxtout[2];
		m_nxtout[2] = m_nxtout[1];
		m_nxtout[1] = m_nxtout[0];
		if (m_quad_mode)
			m_nxtout[0] = (m_oreg>>8)&0x0f;
		else
			// return ((m_oreg & 0x0100)?2:0) | (dat & 0x0d);
			m_nxtout[0] = (m_oreg & 0x0100)?2:0;
		return out;
	}

	// We'll only get here if ...
	//	last_sck = 1, and sck = 0, thus transitioning on the
	//	negative edge as with everything else in this interface
	if (m_quad_mode) {
		m_ireg = (m_ireg << 4) | (dat & 0x0f);
		m_count+=4;
		m_oreg <<= 4;
	} else {
		m_ireg = (m_ireg << 1) | (dat & 1);
		m_count++;
		m_oreg <<= 1;
	}


	// printf("PROCESS, COUNT = %d, IREG = %02x\n", m_count, m_ireg);
	if (m_state == EQSPIF_XIP) {
		assert(m_quad_mode);
		if (m_count == 24) {
			if (m_debug) printf("EQSPI: Entering from Quad-Read Idle to Quad-Read\n");
			if (m_debug) printf("EQSPI: QI/O Idle Addr = %02x\n", m_ireg&0x0ffffff);
			m_addr = (m_ireg) & 0x0ffffff;
			assert((m_addr & 0xfc00000)==0);
			m_state = EQSPIF_QUAD_READ;
		} m_oreg = 0;
	} else if (m_count == 8) {
		QOREG(0x0a5);
		// printf("SFLASH-CMD = %02x\n", m_ireg & 0x0ff);
		// Figure out what command we've been given
		if (m_debug) printf("SPI FLASH CMD %02x\n", m_ireg&0x0ff);
		switch(m_ireg & 0x0ff) {
		case 0x01: // Write status register
			if (2 !=(m_sreg & 0x203)) {
				if (m_debug) printf("EQSPI: WEL not set, cannot write status reg\n");
				m_state = EQSPIF_INVALID;
			} else
				m_state = EQSPIF_WRSR;
			break;
		case 0x02: // Normal speed (normal SPI, 1wire MOSI) Page program
			if (2 != (m_sreg & 0x203)) {
				if (m_debug) printf("EQSPI: Cannot program at this time, SREG = %x\n", m_sreg);
				m_state = EQSPIF_INVALID;
			} else {
				m_state = EQSPIF_PP;
				if (m_debug) printf("PAGE-PROGRAM COMMAND ACCEPTED\n");
			}
			break;
		case 0x03: // Read data bytes
			// Our clock won't support this command, so go
			// to an invalid state
			if (m_debug) printf("EQSPI INVALID: This sim does not support slow reading\n");
			m_state = EQSPIF_INVALID;
			break;
		case 0x04: // Write disable
			m_state = EQSPIF_IDLE;
			m_sreg &= (~EQSPIF_WEL_FLAG);
			break;
		case 0x05: // Read status register
			m_state = EQSPIF_RDSR;
			if (m_debug) printf("EQSPI: READING STATUS REGISTER: %02x\n", m_sreg);
			QOREG(m_sreg);
			break;
		case 0x06: // Write enable
			m_state = EQSPIF_IDLE;
			m_sreg |= EQSPIF_WEL_FLAG;
			if (m_debug) printf("EQSPI: WRITE-ENABLE COMMAND ACCEPTED\n");
			break;
		case 0x0b: // Here's the read that we support
			if (m_debug) printf("EQSPI: FAST-READ (single-bit)\n");
			m_state = EQSPIF_FAST_READ;
			break;
		case 0x20: // Subsector Erase
			if (2 != (m_sreg & 0x203)) {
				if (m_debug) printf("EQSPI: WEL not set, cannot do a subsector erase\n");
				m_state = EQSPIF_INVALID;
				assert(0&&"WEL not set");
			} else
				m_state = EQSPIF_SUBSECTOR_ERASE;
			break;
		case 0x32: // QUAD Page program, 4 bits at a time
			if (2 != (m_sreg & 0x203)) {
				if (m_debug) printf("EQSPI: Cannot program at this time, SREG = %x\n", m_sreg);
				m_state = EQSPIF_INVALID;
				assert(0&&"WEL not set");
			} else {
				m_state = EQSPIF_QPP;
				if (m_debug) printf("EQSPI: QUAD-PAGE-PROGRAM COMMAND ACCEPTED\n");
				if (m_debug) printf("EQSPI: pmem = %08lx\n", (unsigned long)m_pmem);
			}
			break;
		case 0x42: // Program OTP array
			if (2 != (m_sreg & 0x203)) {
				if (m_debug) printf("EQSPI: WEL not set, cannot program OTP\n");
				m_state = EQSPIF_INVALID;
			} else if (m_otp_wp) {
				if (m_debug) printf("EQSPI: OTP Write protect is set, cannot program OTP ever again\n");
				m_state = EQSPIF_INVALID;
			} else
				m_state = EQSPIF_PROGRAM_OTP;
			break;
		case 0x4b: // Read OTP array
			m_state = EQSPIF_READ_OTP;
			QOREG(0);
			if (m_debug) printf("EQSPI: Read OTP array command\n");
			break;
		case 0x50: // Clear flag status register
			m_state = EQSPIF_CLRFLAGS;
			if (m_debug) printf("EQSPI: Clearing FLAGSTATUS REGISTER: %02x\n", m_flagreg);
			QOREG(m_flagreg);
			break;
		case 0x61: // WRITE Enhanced volatile config register
			m_state = EQSPIF_WREVCONFIG;
			if (m_debug) printf("EQSPI: WRITING EVCONFIG REGISTER\n");
			break;
		case 0x65: // Read Enhanced volatile config register
			m_state = EQSPIF_RDEVCONFIG;
			if (m_debug) printf("EQSPI: READING EVCONFIG REGISTER: %02x\n", m_evconfig);
			QOREG(m_evconfig);
			break;
		case 0x06b:
			m_state = EQSPIF_QUAD_READ_CMD;
			// m_quad_mode = true; // Not yet, need to wait past dummy registers
			break;
		case 0x70: // Read flag status register
			m_state = EQSPIF_RDFLAGS;
			if (m_debug) printf("EQSPI: READING FLAGSTATUS REGISTER: %02x\n", m_flagreg);
			QOREG(m_flagreg);
			break;
		case 0x81: // Write volatile config register
			m_state = EQSPIF_WRCR;
			if (m_debug) printf("EQSPI: WRITING VOLATILE CONFIG REGISTER: %02x\n", m_vconfig);
			break;
		case 0x85: // Read volatile config register
			m_state = EQSPIF_RDCR;
			if (m_debug) printf("EQSPI: READING VOLATILE CONFIG REGISTER: %02x\n", m_vconfig);
			QOREG(m_vconfig);
			break;
		case 0x9e: // Read ID (fall through)
		case 0x9f: // Read ID
			m_state = EQSPIF_RDID; m_addr = 0;
			if (m_debug) printf("EQSPI: READING ID\n");
			QOREG(IDSTR[0]);
			break;
		case 0xb1: // Write nonvolatile config register
			m_state = EQSPIF_WRNVCONFIG;
			if (m_debug) printf("EQSPI: WRITING NVCONFIG REGISTER: %02x\n", m_nvconfig);
			break;
		case 0xb5: // Read nonvolatile config register
			m_state = EQSPIF_RDNVCONFIG;
			if (m_debug) printf("EQSPI: READING NVCONFIG REGISTER: %02x\n", m_nvconfig);
			QOREG(m_nvconfig>>8);
			break;
		case 0xc7: // Bulk Erase
			if (2 != (m_sreg & 0x203)) {
				if (m_debug) printf("EQSPI: WEL not set, cannot erase device\n");
				m_state = EQSPIF_INVALID;
			} else
				m_state = EQSPIF_BULK_ERASE;
			break;
		case 0xd8: // Sector Erase
			if (2 != (m_sreg & 0x203)) {
				if (m_debug) printf("EQSPI: WEL not set, cannot erase sector\n");
				m_state = EQSPIF_INVALID;
				assert(0&&"WEL not set");
			} else {
				m_state = EQSPIF_SECTOR_ERASE;
				if (m_debug) printf("EQSPI: SECTOR_ERASE COMMAND\n");
			}
			break;
		case 0xe5: // Write lock register
			m_state = EQSPIF_WRLOCK;
			if (m_debug) printf("EQSPI: WRITING LOCK REGISTER\n");
			break;
		case 0xe8: // Read lock register
			m_state = EQSPIF_RDLOCK;
			if (m_debug) printf("EQSPI: READ LOCK REGISTER (Waiting on address)\n");
			break;
		case 0x0eb: // Here's the (other) read that we support
			// printf("EQSPI: QUAD-I/O-READ\n");
			// m_state = EQSPIF_QUAD_READ_CMD;
			// m_quad_mode = true;
			assert(0 && "Quad Input/Output fast read not supported");
			break;
		default:
			printf("EQSPI: UNRECOGNIZED SPI FLASH CMD: %02x\n", m_ireg&0x0ff);
			m_state = EQSPIF_INVALID;
			assert(0 && "Unrecognized command\n");
			break;
		}
	} else if ((0 == (m_count&0x07))&&(m_count != 0)) {
		QOREG(0);
		switch(m_state) {
		case EQSPIF_IDLE:
			printf("TOO MANY CLOCKS, SPIF in IDLE\n");
			break;
		case EQSPIF_WRSR:
			if (m_count == 16) {
				m_sreg = (m_sreg & 0x07c) | (m_ireg & 0x07c);
				if (m_debug) printf("Request to set sreg to 0x%02x\n",
					m_ireg&0x0ff);
			} else {
				printf("TOO MANY CLOCKS FOR WRR!!!\n");
				exit(-2);
				m_state = EQSPIF_IDLE;
			}
			break;
		case EQSPIF_WRCR: // Write volatile config register, 0x81
			if (m_count == 8+8) {
				m_vconfig = m_ireg & 0x0ff;
				printf("Setting volatile config register to %08x\n", m_vconfig);
				assert((m_vconfig & 0xfb)==0x8b);
			} break;
		case EQSPIF_WRNVCONFIG: // Write nonvolatile config register
			if (m_count == 8+8) {
				m_nvconfig = m_ireg & 0x0ffdf;
				printf("Setting nonvolatile config register to %08x\n", m_nvconfig);
				assert((m_nvconfig & 0xffc5)==0x8fc5);
			} break;
		case EQSPIF_WREVCONFIG: // Write enhanced volatile config reg
			if (m_count == 8+8) {
				m_evconfig = m_ireg & 0x0ff;
				printf("Setting enhanced volatile config register to %08x\n", m_evconfig);
				assert((m_evconfig & 0x0d7)==0xd7);
			} break;
		case EQSPIF_WRLOCK:
			if (m_count == 32) {
				m_addr = (m_ireg>>24)&0x0ff;
				if ((m_lockregs[m_addr]&2)==0)
					m_lockregs[m_addr] = m_ireg&3;
				printf("Setting lock register[%02x] to %d\n", m_addr, m_lockregs[m_addr]);
			} break;
		case EQSPIF_RDLOCK:
			if (m_count == 24) {
				m_addr = (m_ireg>>16)&0x0ff;
				QOREG(m_lockregs[m_addr]);
				printf("Reading lock register[%02x]: %d\n", m_addr, m_lockregs[m_addr]);
			} else
				QOREG(m_lockregs[m_addr]);
			break;
		case EQSPIF_CLRFLAGS:
			assert(0 && "Too many clocks for CLSR command!!\n");
			break;
		case EQSPIF_READ_OTP:
			if (m_count == 32) {
				m_addr = m_ireg & 0x0ffffff;
				assert(m_addr < 65);
				m_otp[64] = (m_otp_wp)?0:1;
				
				if (m_debug) printf("READOTP, SETTING ADDR = %08x (%02x:%02x:%02x:%02x)\n", m_addr,
					((m_addr<65)?m_otp[m_addr]:0)&0x0ff,
					((m_addr<64)?m_otp[m_addr+1]:0)&0x0ff,
					((m_addr<63)?m_otp[m_addr+2]:0)&0x0ff,
					((m_addr<62)?m_otp[m_addr+3]:0)&0x0ff);
				if (m_debug) printf("READOTP, Array is %s, m_otp[64] = %d\n", 
					(m_otp_wp)?"Locked":"Unlocked",
					m_otp[64]);
				QOREG(m_otp[m_addr]);
			} else if (m_count < 40) {
			} // else if (m_count == 40)
			else if ((m_count&7)==0) {
				if (m_debug) printf("READOTP, ADDR = %08x\n", m_addr);
				if (m_addr < 65)
					QOREG(m_otp[m_addr]);
				else
					QOREG(0);
				if (m_debug) printf("EQSPI: READING OTP, %02x%s\n",
					(m_addr<65)?m_otp[m_addr]&0x0ff:0xfff,
					(m_addr > 65)?"-- PAST OTP LENGTH!":"");
				m_addr++;
			}
			break;
		case EQSPIF_RDID:
			if ((m_count&7)==0) {
				m_addr++;
				if (m_debug) printf("READID, ADDR = %08x\n", m_addr);
				if (m_addr < sizeof(IDSTR))
					QOREG(IDSTR[m_addr]);
				else
					QOREG(0);
				if (m_debug) printf("EQSPI: READING ID, %02x%s\n",
					IDSTR[m_addr]&0x0ff,
					(m_addr >= sizeof(IDSTR))?"-- PAST ID LENGTH!":"");
			}
			break;
		case EQSPIF_RDSR:
			// printf("Read SREG = %02x, wait = %08x\n", m_sreg,
				// m_write_count);
			QOREG(m_sreg);
			break;
		case EQSPIF_RDCR:
			if (m_debug) printf("Read VCONF = %02x\n", m_vconfig);
			QOREG(m_creg);
			break;
		case EQSPIF_FAST_READ:
			if (m_count < 32) {
				if (m_debug) printf("FAST READ, WAITING FOR FULL COMMAND (count = %d)\n", m_count);
				QOREG(0x0c3);
			} else if (m_count == 32) {
				m_addr = m_ireg & 0x0ffffff;
				if (m_debug) printf("FAST READ, ADDR = %08x\n", m_addr);
				QOREG(0x0c3);
				assert((m_addr & 0xf000003)==0);
			} else if ((m_count >= 40)&&(0 == (m_sreg&0x01))) {
				if (m_count == 40)
					printf("DUMMY BYTE COMPLETE ...\n");
				QOREG(m_mem[m_addr++]);
				if (m_debug) printf("SPIF[%08x] = %02x -> %02x\n", m_addr-1, m_mem[m_addr-1]&0x0ff, m_oreg);
			} else if (0 != (m_sreg&0x01)) {
				m_oreg = 0;
				if (m_debug) printf("CANNOT READ WHEN WRITE IN PROGRESS, m_sreg = %02x\n", m_sreg);
			} else printf("How did I get here, m_count = %d\n", m_count);
			break;
		case EQSPIF_QUAD_READ_CMD:
			// The command to go into quad read mode took 8 bits
			// that changes the timings, else we'd use quad_Read
			// below
			if (m_count == 32) {
				m_addr = m_ireg & 0x0ffffff;
				// printf("FAST READ, ADDR = %08x\n", m_addr);
				printf("EQSPI: QUAD READ, ADDR = %06x (%02x:%02x:%02x:%02x)\n", m_addr,
					(m_addr<0x1000000)?(m_mem[m_addr]&0x0ff):0,
					(m_addr<0x0ffffff)?(m_mem[m_addr+1]&0x0ff):0,
					(m_addr<0x0fffffe)?(m_mem[m_addr+2]&0x0ff):0,
					(m_addr<0x0fffffd)?(m_mem[m_addr+3]&0x0ff):0);
				assert((m_addr & (~(MEMBYTES-1)))==0);
			} else if (m_count == 32+8) {
				QOREG(m_mem[m_addr++]);
				m_quad_mode = true;
				m_mode_byte = (m_ireg & 0x080);
				printf("EQSPI: (QUAD) MODE BYTE = %02x\n", m_mode_byte);
			} else if ((m_count > 32+8)&&(0 == (m_sreg&0x01))) {
				QOREG(m_mem[m_addr++]);
				// printf("EQSPIF[%08x]/QR = %02x\n",
					// m_addr-1, m_oreg);
			} else {
				// printf("ERR: EQSPIF--TRYING TO READ WHILE BUSY! (count = %d)\n", m_count);
				m_oreg = 0;
			}
			break;
		case EQSPIF_QUAD_READ:
			if (m_count == 24+8*4) {// Requires 8 QUAD clocks
				m_mode_byte = (m_ireg>>24) & 0x10;
				printf("EQSPI/QR: MODE BYTE = %02x\n", m_mode_byte);
				QOREG(m_mem[m_addr++]);
			} else if ((m_count >= 64)&&(0 == (m_sreg&0x01))) {
				QOREG(m_mem[m_addr++]);
				printf("EQSPIF[%08x]/QR = %02x\n", m_addr-1, m_oreg & 0x0ff);
			} else {
				m_oreg = 0;
				printf("EQSPI/QR ... m_count = %d\n", m_count);
			}
			break;
		case EQSPIF_PP:
			if (m_count == 32) {
				m_addr = m_ireg & 0x0ffffff;
				if (m_debug) printf("EQSPI: PAGE-PROGRAM ADDR = %06x\n", m_addr);
				assert((m_addr & 0xfc00000)==0);
				// m_page = m_addr >> 8;
				for(int i=0; i<256; i++)
					m_pmem[i] = 0x0ff;
			} else if (m_count >= 40) {
				m_pmem[m_addr & 0x0ff] = m_ireg & 0x0ff;
				// printf("EQSPI: PMEM[%02x] = 0x%02x -> %02x\n", m_addr & 0x0ff, m_ireg & 0x0ff, (m_pmem[(m_addr & 0x0ff)]&0x0ff));
				m_addr = (m_addr & (~0x0ff)) | ((m_addr+1)&0x0ff);
			} break;
		case EQSPIF_QPP:
			if (m_count == 32) {
				m_addr = m_ireg & 0x0ffffff;
				m_quad_mode = true;
				if (m_debug) printf("EQSPI/QR: PAGE-PROGRAM ADDR = %06x\n", m_addr);
				assert((m_addr & 0xfc00000)==0);
				// m_page = m_addr >> 8;
				for(int i=0; i<256; i++)
					m_pmem[i] = 0x0ff;
			} else if (m_count >= 40) {
				m_pmem[m_addr & 0x0ff] = m_ireg & 0x0ff;
				// printf("EQSPI/QR: PMEM[%02x] = 0x%02x -> %02x\n", m_addr & 0x0ff, m_ireg & 0x0ff, (m_pmem[(m_addr & 0x0ff)]&0x0ff));
				m_addr = (m_addr & (~0x0ff)) | ((m_addr+1)&0x0ff);
			} break;
		case EQSPIF_SUBSECTOR_ERASE:
			if (m_count == 32) {
				m_addr = m_ireg & 0x0fff000;
				if (m_debug) printf("SUBSECTOR_ERASE ADDRESS = %08x\n", m_addr);
				assert((m_addr & 0xff000000)==0);
			} break;
		case EQSPIF_SECTOR_ERASE:
			if (m_count == 32) {
				m_addr = m_ireg & 0x0ff0000;
				if (m_debug) printf("SECTOR_ERASE ADDRESS = %08x\n", m_addr);
				assert((m_addr & 0xf000000)==0);
			} break;
		case EQSPIF_PROGRAM_OTP:
			if (m_count == 32) {
				m_addr = m_ireg & 0x0ff;
				for(int i=0; i<65; i++)
					m_pmem[i] = 0x0ff;
			} else if ((m_count >= 40)&&(m_addr < 65)) {
				m_pmem[m_addr++] = m_ireg & 0x0ff;
			} break;
		/*
		case EQSPIF_RELEASE:
			if (m_count >= 32) {
				QOREG(DEVESD);
			} break;
		*/
		default:
			printf("EQSPI ... DEFAULT OP???\n");
			QOREG(0xff);
			break;
		}
	} // else printf("SFLASH->count = %d\n", m_count);

	m_last_sck = sck;
	int	out = m_nxtout[3];
	m_nxtout[3] = m_nxtout[2];
	m_nxtout[2] = m_nxtout[1];
	m_nxtout[1] = m_nxtout[0];
	if (m_quad_mode)
		m_nxtout[0] =  (m_oreg>>8)&0x0f;
	else
		m_nxtout[0] =  (m_oreg & 0x0100)?2:0;
	return out;
}

