////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	enetctrl_tb.cpp
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To determine whether or not the enetctrl Verilog module works.
//		Run this program with no arguments.  If the last line output
//	from it is "SUCCESS", you will know it works.  Alternatively you can
//	look at the return code.  If the return code is 0 (EXIT_SUCCESS), then
//	the test passed, ,otherrwise it failed.
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
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Venetctrl.h"
#include "enetctrlsim.h"

const int	BOMBCOUNT = 2048;

#ifdef	NEW_VERILATOR
#define	VVAR(A)	enetctrl__DOT_ ## A
#else
#define	VVAR(A)	v__DOT_ ## A
#endif

#define	reg_pos		VVAR(_reg_pos)
#define	zclk		VVAR(_zclk)
#define	zreg_pos	VVAR(_zreg_pos)
#define	ctrl_state	VVAR(_ctrl_state)
#define	write_reg	VVAR(_write_reg)
#define	read_reg	VVAR(_read_reg)
#define	read_pending	VVAR(_read_pending)
#define	write_pending	VVAR(_write_pending)

class	ENETCTRL_TB {
	unsigned long	m_tickcount;
	Venetctrl	*m_core;
	ENETCTRLSIM	*m_sim;
	bool		m_bomb;
	VerilatedVcdC	*m_trace;

public:

	ENETCTRL_TB(void) {
		m_core = new Venetctrl;
		m_sim  = new ENETCTRLSIM;
		Verilated::traceEverOn(true);
		m_trace = NULL;
		m_tickcount = 0;
	}

	~ENETCTRL_TB(void) {
		if (m_trace) {
			m_trace->close();
			delete	m_trace;
		}
	}

	int	operator[](const int index) { return (*m_sim)[index]; }

	void	trace(const char *fname) {
		if (!m_trace) {
			m_trace = new VerilatedVcdC;
			m_core->trace(m_trace, 99);
			m_trace->open(fname);
		}
	}

	void	tick(void) {
		m_core->i_mdio = (*m_sim)(0, m_core->o_mdclk,
			((m_core->o_mdwe)&(m_core->o_mdio))
				|((m_core->o_mdwe)?0:1));

// #define	DEBUGGING_OUTPUT
#ifdef	DEBUGGING_OUTPUT
		printf("%08lx-WB: %s %s %s%s %s@0x%02x[%04x/%04x] -- %d[%d->(%d)->%d]",
			m_tickcount,
			(m_core->i_wb_cyc)?"CYC":"   ",
			(m_core->i_wb_stb)?"STB":"   ",
			(m_core->o_wb_stall)?"STALL":"     ",
			(m_core->o_wb_ack)?"ACK":"   ",
			(m_core->i_wb_we)?"W":"R",
			(m_core->i_wb_addr)&0x01f, (m_core->i_wb_data)&0x0ffff,
			(m_core->o_wb_data)&0x0ffff,
			(m_core->o_mdclk), (m_core->o_mdio),
			(m_core->o_mdwe), (m_core->i_mdio));

		printf(" [%02x,%d%d%d,%x] ",
			m_core->reg_pos,
			0, // m_core->v__DOT__rclk,
			m_core->zclk,
			m_core->zreg_pos,
			m_core->ctrl_state);
		printf(" 0x%04x/0x%04x ", m_core->write_reg,
				m_core->read_reg);
		printf(" %s%s ", 
			(m_core->read_pending)?"R":" ",
			(m_core->write_pending)?"W":" ");

		printf(" %s:%08x,%2d,%08x ",
			(m_sim->m_synched)?"S":" ",
			m_sim->m_datareg, m_sim->m_halfword,
			m_sim->m_outreg);

		printf("\n");
#endif

		if ((m_trace)&&(m_tickcount>0)) m_trace->dump(10*m_tickcount-2);
		m_core->eval();
		m_core->i_clk = 1;
		m_core->eval();
		if (m_trace) m_trace->dump(10*m_tickcount);
		m_core->i_clk = 0;
		m_core->eval();
		if (m_trace) m_trace->dump(10*m_tickcount+5);

		m_tickcount++;

		if ((m_core->o_wb_ack)&&(!m_core->i_wb_cyc)) {
			printf("SETTING ERR TO TRUE!!!!!  ACK w/ no CYC\n");
			// m_bomb = true;
		}
	}

	void wb_tick(void) {
		// printf("WB-TICK()\n");
		m_core->i_wb_cyc   = 0;
		m_core->i_wb_stb = 0;
		tick();
	}

	unsigned wb_read(unsigned a) {
		int		errcount = 0;
		unsigned	result;

		printf("WB-READ(%08x)\n", a);

		m_core->i_wb_cyc = 1;
		m_core->i_wb_stb = 1;
		m_core->i_wb_we  = 0;
		m_core->i_wb_addr= a & 0x01f;

		if (m_core->o_wb_stall)
			while((errcount++ < BOMBCOUNT)&&(m_core->o_wb_stall))
				tick();
		tick();

		m_core->i_wb_stb = 0;

		while((errcount++ <  BOMBCOUNT)&&(!m_core->o_wb_ack))
			tick();


		result = m_core->o_wb_data;

		// Release the bus?
		m_core->i_wb_cyc = 0;
		m_core->i_wb_stb = 0;

		if(errcount >= BOMBCOUNT) {
			printf("SETTING ERR TO TRUE!!!!!\n");
			m_bomb = true;
		} else if (!m_core->o_wb_ack) {
			printf("SETTING ERR TO TRUE--NO ACK, NO TIMEOUT\n");
			m_bomb = true;
		}
		tick();

		return result;
	}

	void	wb_read(unsigned a, int len, unsigned *buf) {
		int		errcount = 0;
		int		THISBOMBCOUNT = BOMBCOUNT * len;
		int		cnt, rdidx;

		printf("WB-READ(%08x, %d)\n", a, len);

		while((errcount++ < BOMBCOUNT)&&(m_core->o_wb_stall))
			wb_tick();

		if (errcount >= BOMBCOUNT) {
			m_bomb = true;
			return;
		}

		errcount = 0;
		
		m_core->i_wb_cyc = 1;
		m_core->i_wb_stb = 1;
		m_core->i_wb_we  = 0;
		m_core->i_wb_addr= a & 0x01f;

		rdidx =0; cnt = 0;

		do {
			int	s;
			s = (m_core->o_wb_stall==0)?0:1;
			tick();
			if (!s)
				m_core->i_wb_addr = (m_core->i_wb_addr+1)&0x1f;
			cnt += (s==0)?1:0;
			if (m_core->o_wb_ack)
				buf[rdidx++] = m_core->o_wb_data;
		} while((cnt < len)&&(errcount++ < THISBOMBCOUNT));

		m_core->i_wb_stb = 0;

		while((rdidx < len)&&(errcount++ < THISBOMBCOUNT)) {
			tick();
			if (m_core->o_wb_ack)
				buf[rdidx++] = m_core->o_wb_data;
		}

		// Release the bus?
		m_core->i_wb_cyc = 0;

		if(errcount >= THISBOMBCOUNT) {
			printf("SETTING ERR TO TRUE!!!!! (errcount=%08x, THISBOMBCOUNT=%08x)\n", errcount, THISBOMBCOUNT);
			m_bomb = true;
		} else if (!m_core->o_wb_ack) {
			printf("SETTING ERR TO TRUE--NO ACK, NO TIMEOUT\n");
			m_bomb = true;
		}
		tick();
	}

	void	wb_write(unsigned a, unsigned int v) {
		int errcount = 0;

		printf("WB-WRITE(%08x) = %08x\n", a, v);
		m_core->i_wb_cyc = 1;
		m_core->i_wb_stb = 1;
		m_core->i_wb_we  = 1;
		m_core->i_wb_addr= a & 0x01f;
		m_core->i_wb_data= v;

		if (m_core->o_wb_stall)
			while((errcount++ < BOMBCOUNT)&&(m_core->o_wb_stall))
				tick();
		tick();

		m_core->i_wb_stb = 0;

		while((errcount++ <  BOMBCOUNT)&&(!m_core->o_wb_ack))
			tick();

		// Release the bus?
		m_core->i_wb_cyc = 0;
		m_core->i_wb_stb = 0;

		if(errcount >= BOMBCOUNT) {
			printf("SETTING ERR TO TRUE!!!!!\n");
			m_bomb = true;
		} tick();
	}

	void	wb_write(unsigned a, unsigned int ln, unsigned int *buf) {
		unsigned errcount = 0, nacks = 0;

		m_core->i_wb_cyc = 1;
		for(unsigned stbcnt=0; stbcnt<ln; stbcnt++) {
			m_core->i_wb_stb = 1;
			m_core->i_wb_we  = 1;
			m_core->i_wb_addr= (a+stbcnt) & 0x01f;
			m_core->i_wb_data= buf[stbcnt];
			errcount = 0;

			do {
				tick(); if (m_core->o_wb_ack) nacks++;
			} while((errcount++ < BOMBCOUNT)&&(m_core->o_wb_stall));
		}

		m_core->i_wb_stb = 0;

		errcount = 0;
		while((nacks < ln)&&(errcount++ < BOMBCOUNT)) {
			tick();
			if (m_core->o_wb_ack) {
				nacks++;
				errcount = 0;
			}
		}

		// Release the bus
		m_core->i_wb_cyc = 0;
		m_core->i_wb_stb = 0;

		if(errcount >= BOMBCOUNT) {
			printf("SETTING ERR TO TRUE!!!!!\n");
			m_bomb = true;
		} tick();
	}

	bool	bombed(void) const { return m_bomb; }

};

int main(int  argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	ENETCTRL_TB	*tb = new ENETCTRL_TB;
	unsigned	v;
	// unsigned	*rdbuf;

	tb->trace("enetctrl.vcd");

	tb->wb_tick();
	tb->wb_write(0, 0x7f82);
	if ((*tb)[0] != 0x7f82) {
		printf("Somehow wrote a %04x, rather than 0x7f82\n", (*tb)[0]);
		goto test_failure;
	}

	tb->wb_tick();
	if ((v=tb->wb_read(0))!=0x7f82) {
		printf("READ A %08x FROM THE CORE, NOT 0x7f82\n", v);
		goto test_failure;
	}

	// 
	tb->wb_tick();
	tb->wb_write(14, 0x5234);

	tb->wb_tick();
	if (tb->wb_read(14)!=0x5234)
		goto test_failure;

	printf("SUCCESS!!\n");
	exit(EXIT_SUCCESS);
test_failure:
	printf("FAIL-HERE\n");
	for(int i=0; i<64; i++)
		tb->tick();
	printf("TEST FAILED\n");
	exit(EXIT_FAILURE);
}
