////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	cpuscope.cpp
//
// Project:	XuLA2-LX25 SoC based upon the ZipCPU
//
// Purpose:	To read out, and decompose, the results of the wishbone scope
//		as applied to the ZipCPU internal operation.
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
#include "scopecls.h"

#define	WBSCOPE		R_CPUSCOPE
#define	WBSCOPEDATA	R_CPUSCOPED

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
		: SCOPE(fpga, addr, false, false) {};
	~CPUSCOPE(void) {}
	virtual	void	decode(DEVBUS::BUSW val) const {
		if (val & 0x80000000)
			printf("TRIG ");
		else
			printf("     ");
		if ((val & 0x40000000)==0) {
			printf("%s <- 0x.%08x", regstr[(val>>32-6)&0xf], val&0x03ffffff);
		} else if ((val & 0x60000000)==0x60000000) {
			if (val&0x08000000)
				printf("MEM-W[0x........] <- 0x.%07x %s",
					(val&0x07ffffff),
					(val&0x10000000)?"(GBL)":"");
			else
				printf("MEM-R[0x.%07x] -> (Not Givn) %s",
					(val&0x07ffffff),
					(val&0x10000000)?"(GBL)":"");
		} else if ((val & 0x70000000)==0x40000000)
			printf("JMP 0x%08x", (val&0x0fffffff));
		else {
			int	master, halt, brk, sleep, gie, buserr, trap,
				ill, clri, pfv, pfi, dcdce, dcdv, dcdstall,
				opce, opvalid, oppipe, aluce, alubsy, aluwr,
				aluill, aluwrf, memce, memwe, membsy;
			master = (val>>27)&1;
			halt   = (val>>26)&1;
			brk    = (val>>25)&1;
			sleep  = (val>>24)&1;
			gie    = (val>>23)&1;
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
			aluill = (val>> 7)&1;
			aluwrf = (val>> 6)&1;
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
			if (GIE)    printf(" GIE");
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
		}
	}
};

int main(int argc, char **argv) {
	FPGAOPEN(m_fpga);

	signal(SIGSTOP, closeup);
	signal(SIGHUP, closeup);

	CPUSCOPE *scope = new CPUSCOPE(m_fpga, WBSCOPE, false);
	if (!scope->ready()) {
		printf("Scope is not yet ready:\n");
		scope->decode_control();
		scope->decode(WBSCOPEDATA);
		printf("\n");
	} else
		scope->read();
	delete	m_fpga;
}

