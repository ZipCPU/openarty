////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbprogram.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Program the memory with a given '.bin' file onto the flash
//		memory on a given board.
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
#include "ttybus.h"
#include "regdefs.h"
#include "flashdrvr.h"
#include "byteswap.h"

DEVBUS	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

void	usage(void) {
	printf("USAGE: wbprogram [@<Address>] file.bit\n");
	printf("\tYou can also use a .bin file in place of the file.bit.\n");
}

void	skip_bitfile_header(FILE *fp) {
	const unsigned	SEARCHLN = 204, MATCHLN = 52;
	const unsigned char matchstr[MATCHLN] = {
		0xff, 0xff, 0xff, 0xff,
		0xff, 0xff, 0xff, 0xff,
		0xff, 0xff, 0xff, 0xff,
		0xff, 0xff, 0xff, 0xff,
		//
		0xff, 0xff, 0xff, 0xff,
		0xff, 0xff, 0xff, 0xff,
		0xff, 0xff, 0xff, 0xff,
		0xff, 0xff, 0xff, 0xff,
		//
		0x00, 0x00, 0x00, 0xbb,
		0x11, 0x22, 0x00, 0x44,
		0xff, 0xff, 0xff, 0xff,
		0xff, 0xff, 0xff, 0xff,
		//
		0xaa, 0x99, 0x55, 0x66 };
	unsigned char	buf[SEARCHLN];

	rewind(fp);
	fread(buf, sizeof(char), SEARCHLN, fp);
	for(int start=0; start+MATCHLN<SEARCHLN; start++) {
		int	mloc;

		// Search backwards, since the starting bytes just aren't that
		// interesting.
		for(mloc = MATCHLN-1; mloc >= 0; mloc--)
			if (buf[start+mloc] != matchstr[mloc])
				break;
		if (mloc < 0) {
			fseek(fp, start, SEEK_SET);
			return;
		}
	}

	fprintf(stderr, "Could not find bin-file header within bit file\n");
	fclose(fp);
	exit(EXIT_FAILURE);
}

int main(int argc, char **argv) {
#ifndef	FLASH_ACCESS
	fprintf(stderr,
"wbprogram is designed to place a design, and optionally a user flash image\n"
"onto an onboard flash.  Your design does not appear to have such a flash\n"
"defined.  Please adjust your design (in AutoFPGA), and then rebuild this\n"
"program (and others in this directory)\n");
	exit(EXIT_FAILURE);
#else
	FILE	*fp;
	DEVBUS::BUSW	addr = EQSPIFLASH;
	char		*buf = new char[FLASHLEN];
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

	unsigned	sz;

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
		skip_bitfile_header(fp);
	sz = fread(buf, sizeof(buf[0]), FLASHLEN, fp);
	fclose(fp);

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
#endif
}
