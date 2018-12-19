////////////////////////////////////////////////////////////////////////////////
//
// Filename:	flashid.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Reads the ID from the flash, and verifies that the flash can
//		be put back into QSPI mode after reading the ID.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2018, Gisselquist Technology, LLC
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
#include "flashdrvr.h"

FPGA	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

void	usage(void) {
	printf("USAGE: flashid\n"
"\n"
"\tflashid reads the ID from the flash, and then attempts to place the\n"
"\tflash back into QSPI mode, followed by reading several values from it\n"
"\tin order to demonstrate that it was truly returned to QSPI mode\n");
}

int main(int argc, char **argv) {
	FLASHDRVR	*m_flash;
	FPGAOPEN(m_fpga);

	m_flash = new FLASHDRVR(m_fpga);
	printf("Flash device ID: 0x%08x\n", m_flash->flashid());
	printf("First several words:\n");
	for(int k=0; k<12; k++)
		printf("\t0x%08x\n", m_fpga->readio(R_FLASH+(k<<2)));

#ifdef	RESET_ADDRESS
	printf("From the RESET_ADDRESS:\n");
	for(int k=0; k<5; k++) {
		printf("%08x: ", RESET_ADDRESS + (k<<2)); fflush(stdout);
		printf("\t0x%08x\n", m_fpga->readio(RESET_ADDRESS+(k<<2)));
		fflush(stdout);
	}
#endif

	delete	m_flash;
	delete	m_fpga;
}

