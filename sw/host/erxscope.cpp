////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	erxscope.cpp
//
// Project:	XuLA2-LX25 SoC based upon the ZipCPU
//
// Purpose:	This file decodes the debug bits produced by the enetpackets.v
//		Verilog module, and stored in a Wishbone Scope.  It is useful
//	for determining if the packet transmitter works at all or not.
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
#include "scopecls.h"

#define	WBSCOPE		R_NETSCOPE
#define	WBSCOPEDATA	R_NETSCOPED

FPGA	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

class	ERXSCOPE : public SCOPE {
public:
	ERXSCOPE(FPGA *fpga, unsigned addr, bool vecread = true)
		: SCOPE(fpga, addr, false, vecread) {};
	~ERXSCOPE(void) {}
	virtual	void	decode(DEVBUS::BUSW val) const {
		int	trigger, nerr, wr, nprev, crcv, mace, bcast, clear,
			rxerr, miss, rxvalid, rxbusy, crs, dv, rxd, macv,
			pred, crcd, macd, neop;

		trigger= (val>>31)&1;
		neop   = (val>>30)&1;
		wr     = (val>>29)&1;
		nprev  = (val>>28)&1;
		pred   = (val>>24)&15;
		crcv   = (val>>23)&1;
		crcd   = (val>>19)&15;
		mace   = (val>>18)&1;
		bcast  = (val>>17)&1;
		macv   = (val>>16)&1;
		macd   = (val>>12)&15;
		clear  = (val>>11)&1;
		rxerr  = (val>>10)&1;
		miss   = (val>> 9)&1;
		nerr   = (val>> 8)&1;
		rxvalid= (val>> 7)&1;
		rxbusy = (val>> 6)&1;
		crs    = (val>> 5)&1;
		dv     = (val>> 4)&1;
		rxd    = (val    )&15;

		printf("%s [%s%s%s%x] p[%s%x] c[%s%x] m[%s%s%s%x] ![%s-] %s%s%s%s%s%s",
			(trigger)?"TR":"  ",
			(rxerr)?"RXER":"    ",
			(crs)?"CRS":"   ",
			(dv)?"DV":"  ",  rxd,
			(nprev)?"P":" ", pred,
			(crcv)?"C":" ",  crcd,
			(bcast)?"B":" ", (mace)?"E":" ", (macv)?"M":" ",  macd,
			(wr)?"WR":"  ", (nerr)?"ER":"  ", (rxbusy)?"BSY":"   ",
			(neop)?"EOP":"   ",
			(miss)?"MISS":"    ", (clear)?"CLEAR":"     ",
			(rxvalid)?"VALID":"     ");
	}
};

int main(int argc, char **argv) {
	FPGAOPEN(m_fpga);

	signal(SIGSTOP, closeup);
	signal(SIGHUP, closeup);

	ERXSCOPE *scope = new ERXSCOPE(m_fpga, WBSCOPE);
	if (!scope->ready()) {
		printf("Scope is not yet ready:\n");
		scope->decode_control();
	} else
		scope->read();
	delete	m_fpga;
}

