////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	etxscope.cpp
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This file decodes the debug bits produced by the enetpackets.v
//		Verilog module, and stored in a Wishbone Scope.  It is useful
//	for determining if the packet transmitter works at all or not.
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
#include "design.h"
#include "regdefs.h"
#include "ttybus.h"
#include "scopecls.h"

#define	WBSCOPE		R_NETSCOPE
#define	WBSCOPEDATA	R_NETSCOPED

FPGA	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

class	ETXSCOPE : public SCOPE {
public:
	ETXSCOPE(FPGA *fpga, unsigned addr, bool vecread = true)
		: SCOPE(fpga, addr, false, vecread) {};
	~ETXSCOPE(void) {}
	virtual	void	decode(DEVBUS::BUSW val) const {
		int	trigger, addr, cancel, cmd, complete, busy, en, txd;
		int	lrxclk, ltxclk, txstb;

		trigger = (val>>31)&1;
		ltxclk  = (val>>30)&1;
		lrxclk  = (val>>29)&1;
		addr    = (val>>10)&0x0ffff;
		txstb   = (val>> 9)&1;
		cancel  = (val>> 8)&1;
		cmd     = (val>> 7)&1;
		complete= (val>> 6)&1;
		busy    = (val>> 5)&1;
		en      = (val>> 4)&1;
		txd     = (val    )&15;

		printf("%s %s %s ",
			(lrxclk)?"LRX":"   ",
			(ltxclk)?"LTX":"   ",
			(txstb)?"TXSTB":"     ");
		printf("%s %04x %s%s%s%s %s/%x",
			(trigger)?"TR":"  ",
			(addr),
			(cancel)?"X":"   ",
			(cmd)?" CMD":"    ",
			(complete)?"DON":"   ",
			(busy)?"BSY":"   ",
			(en)?"EN":"  ", txd);
	}
};

#ifndef	R_NETSCOPE
#define	NO_NETSCOPE
#else
#ifdef	ENETRX_SCOPE
#define	NO_NETSCOPE
#endif
#endif

int main(int argc, char **argv) {
#ifdef	NO_NETSCOPE
	printf("This design was not built with a NET scope within it.\n");
#else
	FPGAOPEN(m_fpga);

	signal(SIGSTOP, closeup);
	signal(SIGHUP, closeup);

	ETXSCOPE *scope = new ETXSCOPE(m_fpga, WBSCOPE);
	if (!scope->ready()) {
		printf("Scope is not yet ready:\n");
		scope->decode_control();
	} else
		scope->read();
	delete	m_fpga;
#endif
}

