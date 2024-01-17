////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	eqspiscope.cpp
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This program decodes the bits in the debugging wires output
//		from the eqspiflash module, and stored in the Wishbone Scope
//	device.  The result is placed on the screen output, so you can see what
//	is going on internal to the device.
//		
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
#include "ttybus.h"

#define	WBSCOPE		R_QSCOPE
#define	WBSCOPEDATA	R_QSCOPED

FPGA	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

class	EQSPISCOPE : public SCOPE {
	// While I put these in at one time, they really mess up other scopes,
	// since setting parameters based upon the debug word forces the decoder
	// to be non-constant, calling methods change, etc., etc., etc.
	//
	// int	m_oword[2], m_iword[2], m_p;
public:
	EQSPISCOPE(FPGA *fpga, unsigned addr, bool vecread)
		: SCOPE(fpga, addr, false, vecread) {};
	~EQSPISCOPE(void) {}
	virtual	void	decode(DEVBUS::BUSW val) const {
		int	cyc, cstb, dstb, ack, back, accepted, valid, word,
			out, cs, sck, mod, odat, idat;

		cyc      = (val>>31)&1;
		cstb     = (val>>30)&1;
		dstb     = (val>>29)&1;
		ack      = (val>>28)&1;
		back     = (val>>27)&1;
		accepted = (val>>26)&1;
		valid    = (val>>25)&1;
		word     = (val>>18)&0x07f;
		out      = (val>>12)&0x03f;
		cs       = (val>>11)&1;
		sck      = (val>>10)&1;
		mod      = (val>> 8)&3;
		odat     = (val>> 4)&15;
		idat     = (val    )&15;

		/*
		m_p = (m_p^1)&1;
		if (mod&2) {
			m_oword[m_p] = (m_oword[m_p]<<4)|odat;
			m_iword[m_p] = (m_iword[m_p]<<4)|idat;
		} else {
			m_oword[m_p] = (m_oword[m_p]<<1)|(odat&1);
			m_iword[m_p] = (m_iword[m_p]<<1)|((idat&2)?1:0);
		}
		*/

		printf("%s%s%s%s%s%s%s %02x %02x %s%s %d %x.%d->  ->%x.%d",
			(cyc)?"CYC ":"    ",
			(cstb)?"CSTB":"    ",
			(dstb)?"DSTB":"    ",
			(ack)?"AK":"  ",
			(back)?"+":" ",
			(accepted)?"ACC":"   ",
			(valid)?"V":" ",
			word<<1, out<<2,
			(cs)?"  ":"CS",
			(sck)?"CK":"  ",
			(mod), odat, (odat&1)?1:0, idat, (idat&2)?1:0);

		// printf("  / %08x -> %08x", m_oword[m_p], m_iword[m_p]);
			
	}
};

int main(int argc, char **argv) {
#ifndef	R_QSCOPE
	printf(
"This design was not built with a flash scope attached to the EQSPI port.\n"
"\n"
"To use this design, create and enable a flash, and the EQSPI scope from\n"
"that.  To do this, you'll need to add a configuration file for the EQSPI \n"
"scope to the auto-data/ directory, and then include it within the Makefile\n"
"of the same directory.\n");
#else
	FPGAOPEN(m_fpga);

	signal(SIGSTOP, closeup);
	signal(SIGHUP, closeup);

	EQSPISCOPE *scope = new EQSPISCOPE(m_fpga, WBSCOPE, false);
	if (!scope->ready()) {
		printf("Scope is not yet ready:\n");
		scope->decode_control();
	} else
		scope->print();
	delete	m_fpga;
#endif
}

