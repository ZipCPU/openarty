////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbregs.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To give a user access, via a command line program, to read
//		and write wishbone registers one at a time.  Thus this program
//		implements readio() and writeio() but nothing more.
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
#include "regdefs.h"

FPGA	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

void	usage(void) {
	printf("USAGE: wbregs address [value]\n"
"\n"
"\tWBREGS stands for Wishbone registers.  It is designed to allow a\n"
"\tuser to peek and poke at registers within a given FPGA design, so\n"
"\tlong as those registers have addresses on the wishbone bus.  The\n"
"\taddress may reference peripherals or memory, depending upon how the\n"
"\tbus is configured.\n"
"\n"
"\tAddress is either a 32-bit value with the syntax of strtoul, or a\n"
"\tregister name.  Register names can be found in regdefs.cpp\n"
"\n"
"\tIf a value is given, that value will be written to the indicated\n"
"\taddress, otherwise the result from reading the address will be \n"
"\twritten to the screen.\n");
}

int main(int argc, char **argv) {
	int	skp=0, port = FPGAPORT;
	bool	use_usb = true, use_decimal = false;

	skp=1;
	for(int argn=0; argn<argc-skp; argn++) {
		if (argv[argn+skp][0] == '-') {
			if (argv[argn+skp][1] == 'd') {
				use_decimal = true;
			} else {
				usage();
				exit(EXIT_SUCCESS);
			}
			skp++; argn--;
		} else
			argv[argn] = argv[argn+skp];
	} argc -= skp;

	FPGAOPEN(m_fpga);

	signal(SIGSTOP, closeup);
	signal(SIGHUP, closeup);

	if ((argc < 1)||(argc > 2)) {
		// usage();
		printf("USAGE: wbregs address [value]\n");
		exit(-1);
	}

	const char *nm;
	unsigned address = addrdecode(argv[0]), value;
	nm = addrname(address);
	if (nm == NULL)
		nm = "no name";

	if (argc < 2) {
		FPGA::BUSW	v;
		try {
			unsigned char a, b, c, d;
			v = m_fpga->readio(address);
			a = (v>>24)&0x0ff;
			b = (v>>16)&0x0ff;
			c = (v>> 8)&0x0ff;
			d = (v    )&0x0ff;
			if (use_decimal)
				printf("%d\n", v);
			else
			printf("%08x (%8s) : [%c%c%c%c] %08x\n", address, nm, 
				isgraph(a)?a:'.', isgraph(b)?b:'.',
				isgraph(c)?c:'.', isgraph(d)?d:'.', v);
		} catch(BUSERR b) {
			printf("%08x (%8s) : BUS-ERROR\n", address, nm);
		}
	} else {
		value = strtoul(argv[1], NULL, 0);
		m_fpga->writeio(address, value);
		printf("%08x (%8s)-> %08x\n", address, nm, value);
	}

	if (m_fpga->poll())
		printf("FPGA was interrupted\n");
	delete	m_fpga;
}

