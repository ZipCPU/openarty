////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	zipstate.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To get a quick (understandable) peek at what the ZipCPU
//		is up to without stopping the CPU.  This is basically
//	identical to a "wbregs cpu" command, save that the bit fields of the
//	result are broken out into something more human readable.
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

FPGA	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

unsigned int	cmd_read(FPGA *fpga, int r) {
	const unsigned int	MAXERR = 1000;
	unsigned int	errcount = 0;
	unsigned int	s;

	fpga->writeio(R_ZIPCTRL, CPU_HALT|(r&0x03f));
	while((((s = fpga->readio(R_ZIPCTRL))&CPU_STALL)== 0)&&(errcount<MAXERR))
		errcount++;
	if (errcount >= MAXERR) {
		printf("ERR: errcount(%d) >= MAXERR on cmd_read(a=%02x)\n",
			errcount, r);
		printf("ZIPCTRL = 0x%08x", s);
		if ((s & 0x0200)==0) printf(" BUSY");
		if  (s & 0x0400)     printf(" HALTED");
		if ((s & 0x03000)==0x01000)
			printf(" SW-HALT");
		else {
			if (s & 0x01000) printf(" SLEEPING");
			if (s & 0x02000) printf(" GIE(UsrMode)");
		} printf("\n");
		exit(EXIT_FAILURE);
	} return fpga->readio(R_ZIPDATA);
}

void	usage(void) {
	printf("USAGE: zipstate\n");
}

int main(int argc, char **argv) {
	int	skp=0, port = FPGAPORT;
	bool	long_state = false;
	unsigned int	v;

	skp=1;
	for(int argn=0; argn<argc-skp; argn++) {
		if (argv[argn+skp][0] == '-') {
			if (argv[argn+skp][1] == 'l')
				long_state = true;
			skp++; argn--;
		} else
			argv[argn] = argv[argn+skp];
	} argc -= skp;

	FPGAOPEN(m_fpga);

	if (!long_state) {
		v = m_fpga->readio(R_ZIPCTRL);

		printf("0x%08x: ", v);
		if (v & 0x0080) printf("PINT ");
		// if (v & 0x0100) printf("STEP "); // self resetting
		if((v & 0x00200)==0) printf("BUSY ");
		if (v & 0x00400) printf("HALTED ");
		if((v & 0x03000)==0x01000) {
			printf("SW-HALT");
		} else {
			if (v & 0x01000) printf("SLEEPING ");
			if (v & 0x02000) printf("GIE(UsrMode) ");
		}
		// if (v & 0x0800) printf("CLR-CACHE ");
		printf("\n");
	} else {
		printf("Reading the long-state ...\n");
		for(int i=0; i<14; i++) {
			printf("sR%-2d: 0x%08x ", i, cmd_read(m_fpga, i));
			if ((i&3)==3)
				printf("\n");
		} printf("sCC : 0x%08x ", cmd_read(m_fpga, 14));
		printf("sPC : 0x%08x ", cmd_read(m_fpga, 15));
		printf("\n\n"); 

		for(int i=0; i<14; i++) {
			printf("uR%-2d: 0x%08x ", i, cmd_read(m_fpga, i+16));
			if ((i&3)==3)
				printf("\n");
		} printf("uCC : 0x%08x ", cmd_read(m_fpga, 14+16));
		printf("uPC : 0x%08x ", cmd_read(m_fpga, 15+16));
		printf("\n\n"); 
	}

	delete	m_fpga;
}

