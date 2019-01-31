////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	mdioscope.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2019, Gisselquist Technology, LLC
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
#include "scopecls.h"
#include "ttybus.h"

#define	WBSCOPE		R_MDIOSCOPE
#define	WBSCOPEDATA	R_MDIOSCOPED

FPGA	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

class	MDIOSCOPE : public SCOPE {
public:
	MDIOSCOPE(FPGA *fpga, unsigned addr, bool vecread)
		: SCOPE(fpga, addr, false, false) {};
	~MDIOSCOPE(void) {}
	virtual	void	decode(DEVBUS::BUSW val) const {
		int	wbstall, wbstb, wbwe, wbaddr,
			wback, rclk, zclk, zreg, wbdata, regpos, ctstate, rpend,
			mdclk, mdwe, omdio, imdio;

		wbstall = (val>>31)&1;
		wbstb   = (val>>30)&1;
		wbwe    = (val>>29)&1;
		wbaddr  = (val>>24)&0x01f;
		wback   = (val>>23)&1;
		wbdata  = (val>>16)&0x03f;

		rclk    = (val>>22)&1;
		zreg    = (val>>15)&1;
		zclk    = (val>>14)&1;
		regpos  = (val>>8)&0x3f;
		rpend   = (val>>7)&1;
		ctstate = (val>>4)&7;

		mdclk = (val&8)?1:0;
		mdwe  = (val&4)?1:0;
		omdio = (val&2)?1:0;
		imdio = (val&1)?1:0;

		printf("WB[%s%s@%2x -> %s%s/%04x] (%d%d%d,%2d,%2x%s) MDIO[%s%s %d-%d]",
			(wbstb)?"STB":"   ", (wbwe)?"WE":"  ", (wbaddr),
			(wback)?"ACK":"   ",(wbstall)?"STALL":"     ", (wbdata),
			zclk, rclk, zreg, regpos, ctstate,
			(rpend)?"R":" ",
			(mdclk)?"CLK":"   ", (mdwe)?"WE":"  ",(omdio),(imdio));
	}

	virtual	void define_traces(void) {
		register_trace("o_wb_stall", 1, 31);
		register_trace("i_wb_stb",   1, 30);
		register_trace("i_wb_we",    1, 29);
		register_trace("i_wb_addr",  5, 24);
		//
		register_trace("o_wb_ack",     1, 23);
		register_trace("rclk",         1, 22);
		register_trace("o_wb_data",    6, 16);
		//
		register_trace("zreg_pos",     1, 15);
		register_trace("zclk",         1, 14);
		register_trace("reg_pos",      6,  8);
		//
		register_trace("read_pending", 1,  7);
		register_trace("ctrl_state",   3,  4);
		//
		register_trace("o_mdclk",    1,  3);
		register_trace("o_mdwe",     1,  2);
		register_trace("o_mdio",     1,  1);
		register_trace("i_mdio",     1,  0);
	}
};

int main(int argc, char **argv) {
#ifndef	R_MDIOSCOPE
	printf(
"This design was not built with an MDIO network scope attached.\n"
"\n"
"To use this design, create and enable the MDIO network controller, and the\n"
"MDIO scope from\n"
"that.  To do this, you'll need to adjust the flash configuration file\n"
"used by AutoFPGA found in the auto-data/ directory, and then include it\n"
"within the Makefile of the same directory.\n");
#else
	FPGAOPEN(m_fpga);

	signal(SIGSTOP, closeup);
	signal(SIGHUP, closeup);

	MDIOSCOPE *scope = new MDIOSCOPE(m_fpga, WBSCOPE, true);
	scope->set_clkfreq_hz(CLKFREQHZ);
	if (!scope->ready()) {
		printf("Scope is not yet ready:\n");
		scope->decode_control();
	} else {
		scope->print();
		scope->writevcd("mdio.vcd");
	}
	delete	m_fpga;
#endif
}

