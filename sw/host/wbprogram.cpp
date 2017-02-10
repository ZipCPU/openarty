////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbprogram.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Program the memory with a given '.bin' file.
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
#include "llcomms.h"
#include "regdefs.h"
#include "flashdrvr.h"

DEVBUS	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

unsigned byteswap(unsigned x) {
	unsigned r;

	r  = x&0x0ff; x>>=8; r<<= 8;
	r |= x&0x0ff; x>>=8; r<<= 8;
	r |= x&0x0ff; x>>=8; r<<= 8;
	r |= x&0x0ff;

	return r;
}

void	usage(void) {
	printf("USAGE: wbprogram [@<Address>] file.bit\n");
	printf("\tYou can also use a .bin file in place of the file.bit.\n");
}

int main(int argc, char **argv) {
	FILE	*fp;
	const int	BUFLN = (1<<20); // 4MB Flash
	DEVBUS::BUSW	*buf = new DEVBUS::BUSW[BUFLN], v, addr = EQSPIFLASH;
	FLASHDRVR	*flash;
	int		argn = 1;

	if ((argc > argn)&&(NULL != strstr(argv[argn],"tty")))
		m_fpga = new FPGA(new TTYCOMMS(argv[argn++]));
	else if ((argc > argn)&&(NULL != strchr(argv[argn],':'))) {
		char *ptr = strchr(argv[argn],':');
		*ptr++ = '\n';
		m_fpga = new FPGA(new NETCOMMS(argv[argn++], atoi(ptr)));
	} else {
		FPGAOPEN(m_fpga);
	}

	// Start with testing the version:
	try {
		printf("VERSION: %08x\n", m_fpga->readio(R_VERSION));
	} catch(BUSERR b) {
		printf("VERSION: (Bus-Err)\n");
		exit(-1);
	}

	// SPI flash testing
	// Enable the faster (vector) reads
	bool	vector_read = true;
	unsigned	sz;
	bool		esectors[NSECTORS];

	argn = 1;
	if (argc <= argn) {
		usage();
		exit(-1);
	} else if (argv[argn][0] == '@') {
		addr = strtoul(&argv[argn][1], NULL, 0);
		if ((addr < EQSPIFLASH)||(addr > EQSPIFLASH*2)) {
			printf("BAD ADDRESS: 0x%08x (from %s)\n", addr, argv[argn]);
			printf("The address you've selected, 0x%08x, is outside the range", addr);
			printf("from 0x%08x to 0x%08x\n", EQSPIFLASH, EQSPIFLASH*2);
			exit(-1);
		} argn++;
	}

	if (argc<= argn) {
		printf("BAD USAGE: no file argument\n");
		exit(-1);
	} else if (0 != access(argv[argn], R_OK)) {
		printf("Cannot access %s\n", argv[argn]);
		exit(-1);
	}

	flash = new FLASHDRVR(m_fpga);

	if ((strcmp(&argv[argn][strlen(argv[argn])-4],".bit")!=0)
		&&(strcmp(&argv[argn][strlen(argv[argn])-4],".bin")!=0)) {
		printf("I'm expecting a '.bit' or \'.bin\' file extension\n");
		exit(-1);
	}

	fp = fopen(argv[argn], "r");
	if (strcmp(&argv[argn][strlen(argv[argn])-4],".bit")==0)
		fseek(fp, 0x5dl, SEEK_SET);
	sz = fread(buf, sizeof(buf[0]), BUFLN, fp);
	fclose(fp);

	for(int i=0; i<sz; i++) {
		buf[i] = byteswap(buf[i]);
	}

	try {
		flash->write(addr, sz, buf, true);
	} catch(BUSERR b) {
		fprintf(stderr, "BUS-ERR @0x%08x\n", b.addr);
		exit(-1);
	}

	try {
		// Turn on the write protect flag
		m_fpga->writeio(R_QSPI_EREG, 0);
	} catch(BUSERR b) {
		fprintf(stderr, "BUS-ERR, trying to read QSPI port\n");
		exit(-1);
	}

	printf("ALL-DONE\n");
	delete	m_fpga;
}


