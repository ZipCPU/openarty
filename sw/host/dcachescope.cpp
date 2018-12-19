////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	dcachescope.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To read out, and decompose, the results of the wishbone scope
//		as applied to the ZipCPU internal operation.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2018, Gisselquist Technology, LLC
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
#include "llcomms.h"
#include "regdefs.h"
#include "scopecls.h"
#include "ttybus.h"

#define	WBSCOPE		R_DCACHESCOPE
#define	WBSCOPEDATA	R_DCACHESCOPED

FPGA	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

class	DCACHESCOPE : public SCOPE {
public:
	DCACHESCOPE(FPGA *fpga, unsigned addr, bool vecread)
		: SCOPE(fpga, addr, false, vecread) {};
	~DCACHESCOPE(void) {}
	virtual	void	decode(DEVBUS::BUSW val) const {
		int	pipestb, state, cyc, stb, i_oreg, o_wreg,
			rdaddr, wraddr, ack, err, stalled, busy,
			svalid, dvalid, pending;
#define	BIT(N)		((val>>N)&1)
#define	WORD(N,W)	((val>>N)&((1<<W)-1))
		pipestb = BIT(31);
		state  = WORD(29,2);
		cyc    = BIT(28);
		stb    = BIT(27);
		i_oreg = WORD(22,5);
		o_wreg = WORD(17,5);
		rdaddr = WORD(12,5);
		wraddr = WORD( 7,5);
		ack    = BIT( 6);
		err    = BIT( 5);
		stalled= BIT( 4);
		busy   = BIT( 3);
		svalid = BIT( 2);
		dvalid = BIT( 1);
		pending= BIT( 0);

		printf("%3s -> %x (%3s%3s)",
			pipestb ? "REQ":"",
			i_oreg, (busy)?"BSY":"", (stalled)?"STL":"");
		printf("| %3s%3s -> %3s%3s",
			cyc ? "CYC":"",
			stb ? "STB":"",
			ack ? "ACK":"",
			err ? "ERR":"");
		printf("| S=%d[%02x,%02x]", state, wraddr, rdaddr);
		printf("| %2s%2s%4s", (svalid)?"SV":"", (dvalid)?"DV":"",
			(pending)?"PEND":"");
		printf("| -> %x", o_wreg);
	}

	virtual void define_traces(void) {
		register_trace("pipestb", 1, 31);
		register_trace("state",   2, 29);
		register_trace("cyc",     1, 28);
		register_trace("stb",     1, 27);
		register_trace("i_oreg",  5, 22);
		register_trace("o_wreg",  5, 17);
		register_trace("rdaddr",  5, 12);
		register_trace("wraddr",  5,  7);
		register_trace("ack",     1,  6);
		register_trace("err",     1,  5);
		register_trace("stalled", 1,  4);
		register_trace("busy",    1,  3);
		register_trace("svalid",  1,  2);
		register_trace("dvalid",  1,  1);
		register_trace("pending", 1,  0);
	}
};

int main(int argc, char **argv) {
#ifndef	R_ZIPSCOPE
	printf("This design was not built with a CPU scope within it.\n");
#else
	FPGAOPEN(m_fpga);

	signal(SIGSTOP, closeup);
	signal(SIGHUP, closeup);

	DCACHESCOPE *scope = new DCACHESCOPE(m_fpga, WBSCOPE, true);
	if (!scope->ready()) {
		printf("Scope is not yet ready:\n");
		scope->decode_control();
	} else {
		scope->print();
		scope->writevcd("dcachescope.vcd");
	}
	delete	m_fpga;
#endif
}

