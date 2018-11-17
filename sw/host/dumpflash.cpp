////////////////////////////////////////////////////////////////////////////////
//
// Filename:	dumpflash.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Read/Empty the entire contents of the flash memory to a file.
//		The flash is unchanged by this process.
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

#include "port.h"
#include "regdefs.h"
#include "ttybus.h"
#include "byteswap.h"

FPGA	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

int main(int argc, char **argv) {
#ifdef	FLASH_ACCESS
#define	DUMPMEM		EQSPIFLASH
#define	DUMPWORDS	(FLASHLEN>>2)

	FILE	*fp;
	const int	BUFLN = FLASHLEN;
	char	*buf = new char[FLASHLEN];

	FPGAOPEN(m_fpga);
	fprintf(stderr, "Before starting, nread = %ld\n", 
		m_fpga->m_total_nread);

	// Start with testing the version:
	printf("VERSION: %08x\n", m_fpga->readio(R_VERSION));

	// SPI flash testing
	// Enable the faster (vector) reads
	bool	vector_read = true;
	unsigned	sz;

	if (vector_read) {
		m_fpga->readi(DUMPMEM, BUFLN>>2, (DEVBUS::BUSW *)&buf[0]);
		byteswapbuf(BUFLN>>2, (DEVBUS::BUSW *)&buf[0]);
	} else {
		for(int i=0; i<BUFLN; i+=4) {
			DEVBUS::BUSW	word;

			word = m_fpga->readio(DUMPMEM+i);
			
			buf[i  ] = (word>>24) & 0x0ff;
			buf[i+1] = (word>>16) & 0x0ff;
			buf[i+2] = (word>> 8) & 0x0ff;
			buf[i+3] = (word    ) & 0x0ff;
		}
	}
	printf("\nREAD-COMPLETE\n");

	// Now, let's find the end
	sz = BUFLN-1;
	while((sz>0)&&((unsigned char)buf[sz] == 0xff))
		sz--;
	sz+=1;

#define	FLASHFILE	"eqspidump.bin"

	if (access(FLASHFILE, F_OK)==0) {
		fprintf(stderr, "Cowardly refusing to overwrite %s\n", FLASHFILE);
		exit(EXIT_FAILURE);
	}

	fp = fopen(FLASHFILE,"w");
	fwrite(buf, sizeof(buf[0]), sz, fp);
	fclose(fp);

	printf("The read was accomplished in %ld bytes over the UART\n",
		m_fpga->m_total_nread);

	if (m_fpga->poll())
		printf("FPGA was interrupted\n");
	delete	m_fpga;
#else
	printf(
"This design requires some kind of flash be available within your design.\n"
"\n"
"To use this dumpflash program, add a flash component in the auto-data\n"
"directory, and then add that component to the AutoFPGA makefile to\n"
"include it.  This file should then build properly, and be able to dump\n"
"the given flash device.\n");
#endif
}


