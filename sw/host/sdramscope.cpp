////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	sdramscope.cpp
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2024, Gisselquist Technology, LLC
// {{{
// This file is part of the OpenArty project.
//
// The OpenArty project is free software and gateware, licensed under the terms
// of the 3rd version of the GNU General Public License as published by the
// Free Software Foundation.
//
// This project is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
// }}}
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
#include "scopecls.h"

#define	WBSCOPE		R_RAMSCOPE
#define	WBSCOPEDATA	R_RAMSCOPED

FPGA	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

class	RAMSCOPE : public SCOPE {
public:
	RAMSCOPE(FPGA *fpga, unsigned addr, bool vecread)
		: SCOPE(fpga, addr, false, false) {};
	~RAMSCOPE(void) {}
	virtual	void	decode(DEVBUS::BUSW val) const {
/*
		int	ras, cas, wen, stb, we, stall, ack, dqs, dm, oe, addr,
			odat, idat, wdbg, cmd;
		static const char *cmdstr[] = { "[MRSET]", "[REFRESH]",
				"[PRECHARGE]", "[ACTIVATE]", "[WRITE]",
				"[READ]", "[ZQS]", "[NOOP]"
			};

		ras      = (val>>31)&1;
		cas      = (val>>30)&1;
		wen      = (val>>29)&1;
		stb      = (val>>28)&1;
		we       = (val>>27)&1;
		stall    = (val>>26)&1;
		ack      = (val>>25)&1;
		dqs      = (val>>24)&1;
		dm       = (val>>23)&1;
		oe       = (val>>22)&1;
		addr     = (val>>20)&3;
		odat     = (val>>14)&63;
		idat      = (val>>8)&63;
		wdbg      = (val    )&0xff;

		cmd = (ras<<2)|(cas<<1)|wen;
		printf("%s%s%s%s %s%s%s %x %2xO %2xI %4xW %d%d%d%s",
			(stb)?"S":" ",
			(we)?"W":"R",
			(stall)?"S":" ",
			(ack)?"AK":"  ",
			//
			dqs?"D":" ",dm?"M":" ",oe?"W":"z",
			addr, odat, idat, wdbg,
			ras,cas,wen,
			cmdstr[cmd]);
*/
		int	stb, stall, ack, err, head, tail, rid, 
			arvalid, arready, awvalid, awready, wvalid, wready,
			rvalid, bvalid;

		stb      = (val>>31)&1;
		stall    = (val>>30)&1;
		ack      = (val>>29)&1;
		err      = (val>>28)&1;
		head     = (val>>22)&0x03f;
		tail     = (val>>16)&0x03f;
		rid      = (val>>10)&0x03f;
		arvalid  = (val>> 9)&1;
		arready  = (val>> 8)&1;
		awvalid  = (val>> 7)&1;
		awready  = (val>> 6)&1;
		wvalid   = (val>> 5)&1;
		wready   = (val>> 4)&1;
		rvalid   = (val>> 3)&1;
		bvalid   = (val>> 2)&1;

		printf("%s %s %s %s ", (stb)?"STB":"   ", (stall)?"STL":"   ",
			(ack)?"ACK":"   ", (err)?"ERR":"   ");

		printf("%2x:%2x AR[%c%c] AW[%c%c] W[%c%c] ", head, tail,
			(arvalid)?'V':' ', (arready)?'R':' ',
			(awvalid)?'V':' ', (awready)?'R':' ',
			(wvalid)?'V':' ', (wready)?'R':' ');

		if (rvalid)
			printf("RV[%2x] %c", rid, bvalid?'B':' ');
		else if (bvalid)
			printf("BV[%2x]", rid);
			
	}
};

int main(int argc, char **argv) {
	int	skp=0, port = FPGAPORT;
	bool	use_usb = false;

	skp=1;
	for(int argn=0; argn<argc-skp; argn++) {
		if (argv[argn+skp][0] == '-') {
			if (argv[argn+skp][1] == 'u')
				use_usb = true;
			else if (argv[argn+skp][1] == 'p') {
				use_usb = false;
				if (isdigit(argv[argn+skp][2]))
					port = atoi(&argv[argn+skp][2]);
			}
			skp++; argn--;
		} else
			argv[argn] = argv[argn+skp];
	} argc -= skp;

	FPGAOPEN(m_fpga);

	signal(SIGSTOP, closeup);
	signal(SIGHUP, closeup);

	RAMSCOPE *scope = new RAMSCOPE(m_fpga, WBSCOPE, false);
	if (!scope->ready()) {
		printf("Scope is not yet ready:\n");
		scope->decode_control();
	} else
		scope->read();
	delete	m_fpga;
}

