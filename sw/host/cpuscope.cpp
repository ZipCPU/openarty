////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	cpuscope.cpp
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
#include "llcomms.h"
#include "regdefs.h"
#include "scopecls.h"
#include "ttybus.h"

#define	WBSCOPE		R_ZIPSCOPE
#define	WBSCOPEDATA	R_ZIPSCOPED

#include "zopcodes.h"

FPGA	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

const char *regstr[] = {
	"R0","R1","R2","R3","R4","R5","R6","R7","R8","R9","RA","RB","RC",
	"SP","CC","PC"
};

class	CPUSCOPE : public SCOPE {
public:
	CPUSCOPE(FPGA *fpga, unsigned addr, bool vecread)
		: SCOPE(fpga, addr, false, vecread) {};
	~CPUSCOPE(void) {}
	virtual	void	decode(DEVBUS::BUSW val) const {
		if (val & 0x80000000)
			printf("TRIG ");
		else
			printf("     ");
		if (true) {
		if ((val & 0x40000000)==0) {
			printf("%s <- 0x.%07x", regstr[(val>>(32-6))&0xf], val&0x03ffffff);
		} else if ((val & 0x60000000)==0x60000000) {
			uint32_t addr = val & 0x7ffffff;
			if (val&0x08000000)
				printf("MEM-W[0x........] <- 0x.%07x %s",
					addr,
					(val&0x10000000)?"(GBL)":"");
			else
				printf("MEM-R[0x.%07x] -> (Not Givn) %s",
					(addr<<2)&0x0ffffffc,
					(val&0x10000000)?"(GBL)":"");
		} else if ((val & 0x70000000)==0x40000000) {
			val &= 0x0fffffff;
			val <<= 2;
			printf("JMP 0x%08x", (val&0x0fffffff));
		} else {
			int	master, halt, brk, sleep, buserr, trap,
				ill, clri, pfv, pfi, dcdce, dcdv, dcdstall,
				opce, opvalid, oppipe, aluce, alubsy, aluwr,
				memce, memwe, membsy;
			// int	gie, aluill, aluwrf;
			master = (val>>27)&1;
			halt   = (val>>26)&1;
			brk    = (val>>25)&1;
			sleep  = (val>>24)&1;
			// gie    = (val>>23)&1;
			buserr = (val>>22)&1;
			trap   = (val>>21)&1;
			ill    = (val>>20)&1;
			clri   = (val>>19)&1;
			pfv    = (val>>18)&1;
			pfi    = (val>>17)&1;
			dcdce  = (val>>16)&1;
			dcdv   = (val>>15)&1;
			dcdstall=(val>>14)&1;
			opce   = (val>>13)&1;
			opvalid= (val>>12)&1;
			oppipe = (val>>11)&1;
			aluce  = (val>>10)&1;
			alubsy = (val>> 9)&1;
			aluwr  = (val>> 8)&1;
			// aluill = (val>> 7)&1;
			// aluwrf = (val>> 6)&1;
			memce  = (val>> 5)&1;
			memwe  = (val>> 4)&1;
			membsy = (val>> 3)&1;
			printf("FLAGS %08x", val);
			printf(" CE[%c%c%c%c]",
				(dcdce)?'D':' ',
				(opce)?'O':' ',
				(aluce)?'A':' ',
				(memce)?'M':' ');
			printf(" V[%c%c%c%c]",
				(pfv)?'P':' ',
				(dcdv)?'D':' ',
				(opvalid)?'O':' ',
				(aluwr)?'A':' ');
			if (master) printf(" MCE");
			if (halt)   printf(" I-HALT");
			if (brk)    printf(" O-BREAK");
			if (sleep)  printf(" SLP");
			// if (GIE)    printf(" GIE");
			if (buserr) printf(" BE");
			if (trap)   printf(" TRAP");
			if (ill)    printf(" ILL");
			if (clri)   printf(" CLR-I");
			if (pfi)    printf(" PF-ILL");
			if (dcdstall)printf(" DCD-STALL");
			if (oppipe) printf(" OP-PIPE");
			if (alubsy) printf(" ALU-BUSY");
			if (memwe)  printf(" MEM-WE");
			if (membsy) printf(" MEM-BUSY");
			//
		}}

		if (false) {
			// CPU internal bus_debug
			int	mce, mwe, mbsy, mpip,
				gcyc, gstb, lcyc, lstb, we, ack, stall, err,
				pcyc, pstb, pack, pstall, perr,
				mcycg, mstbg, mcycl, mstbl, mack, mstall, merr;

			mce    = (val>>24)&1;
			//
			mbsy   = (val>>22)&1;
			mpip   = (val>>21)&1;
			gcyc   = (val>>20)&1;
			gstb   = (val>>19)&1;
			lcyc   = (val>>18)&1;
			lstb   = (val>>17)&1;
			we     = (val>>16)&1;
			ack    = (val>>15)&1;
			stall  = (val>>14)&1;
			err    = (val>>13)&1;
			pcyc   = (val>>12)&1;
			pstb   = (val>>11)&1;
			pack   = (val>>10)&1;
			pstall = (val>> 9)&1;
			perr   = (val>> 8)&1;
			mcycg  = (val>> 7)&1;
			mstbg  = (val>> 6)&1;
			mcycl  = (val>> 5)&1;
			mstbl  = (val>> 4)&1;
			mwe    = (val>> 3)&1;
			mack   = (val>> 2)&1;
			mstall = (val>> 1)&1;
			merr   = (val&1);

			printf("P[%s%s%s%s%s]",
				(pcyc)?"C":" ",
				(pstb)?"S":" ",
				(pack)?"A":" ",
				(pstall)?"S":" ",
				(perr)?"E":" ");

			printf("M[(%s%s)(%s%s)%s%s%s%s]",
				(mcycg)?"C":" ", (mstbg)?"S":" ",
				(mcycl)?"C":" ", (mstbl)?"S":" ",
				(mwe)?"W":"R", (mack)?"A":" ",
				(mstall)?"S":" ",
				(merr)?"E":" ");

			printf("O[(%s%s)(%s%s)%s%s%s%s]",
				(gcyc)?"C":" ", (gstb)?"S":" ",
				(lcyc)?"C":" ", (lstb)?"S":" ",
				(we)?"W":"R", (ack)?"A":" ",
				(stall)?"S":" ",
				(err)?"E":" ");

			if (mbsy) printf("M-BUSY ");
			if (mpip) printf("M-PIPE ");
			if (mce)  printf("M-CE ");
		}
	}

	virtual void define_traces(void) {
	
	}
};

int main(int argc, char **argv) {
#ifndef	R_ZIPSCOPE
	printf("This design was not built with a CPU scope within it.\n");
#else
	FPGAOPEN(m_fpga);

	signal(SIGSTOP, closeup);
	signal(SIGHUP, closeup);

	CPUSCOPE *scope = new CPUSCOPE(m_fpga, WBSCOPE, true);
	if (!scope->ready()) {
		printf("Scope is not yet ready:\n");
		scope->decode_control();
	} else {
		scope->print();
		scope->writevcd("cpuscope.vcd");
	}
	delete	m_fpga;
#endif
}

