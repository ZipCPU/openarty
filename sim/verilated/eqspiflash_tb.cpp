////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	eqspiflash_tb.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To determine whether or not the eqspiflash module works.  Run
//		this with no arguments, and check whether or not the last line
//	contains "SUCCESS" or not.  If it does contain "SUCCESS", then the
//	module passes all tests found within here.
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
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Veqspiflash.h"
#include "eqspiflashsim.h"

#define	QSPIFLASH	0x0400000
const int	BOMBCOUNT = 2048;

class	EQSPIFLASH_TB {
	unsigned long		m_tickcount;
	Veqspiflash	*m_core;
	EQSPIFLASHSIM	*m_flash;
	bool		m_bomb;
	VerilatedVcdC*	m_trace;

public:

	EQSPIFLASH_TB(void) {
		Verilated::traceEverOn(true);
		m_core = new Veqspiflash;
		m_flash= new EQSPIFLASHSIM(24,true);
		m_trace= NULL;
	}

	unsigned operator[](const int index) { return (*m_flash)[index]; }
	void	setflash(unsigned addr, unsigned v) {
		m_flash->set(addr, v);
	}
	void	load(const char *fname) {
		m_flash->load(0,fname);
	}

	void	trace(const char *fname) {
		if (!m_trace) {
			m_trace = new VerilatedVcdC;
			m_core->trace(m_trace, 99);
			m_trace->open(fname);
		}
	}

	void	tick(void) {
		// m_core->i_clk_82mhz = 0;
		// m_core->eval();
		m_core->i_qspi_dat = (*m_flash)(m_core->o_qspi_cs_n,
			m_core->o_qspi_sck, m_core->o_qspi_dat);

		m_core->i_clk_82mhz = 1;
		m_core->eval();
// #define	DEBUGGING_OUTPUT
#ifdef	DEBUGGING_OUTPUT
#ifdef	NEW_VERILATOR
#define	VVAR(A)	eqspiflash__DOT_ ## A
#else
#define	VVAR(A)	v__DOT_	## A
#endif

#define	bus_wb_ack	VVAR(_bus_wb_ack)
#define	rd_data_ack	VVAR(_rd_data_ack)
#define	ew_data_ack	VVAR(_ew_data_ack)
#define	id_data_ack	VVAR(_id_data_ack)
#define	ct_data_ack	VVAR(_ct_data_ack)
#define	owned		VVAR(_owned)
#define	owner		VVAR(_owner)
#define	rd_qspi_req	VVAR(_rd_qspi_req)
#define	ew_qspi_req	VVAR(_ew_qspi_req)
#define	id_qspi_req	VVAR(_id_qspi_req)
#define	ct_qspi_req	VVAR(_ct_qspi_req)
#define	spi_wr		VVAR(_spi_wr)
#define	spi_hold	VVAR(_spi_hold)
#define	spi_len		VVAR(_spi_len)
#define	spi_dir		VVAR(_spi_dir)
#define	spi_spd		VVAR(_spi_spd)
#define	spi_word	VVAR(_spi_word)
#define	rd_state	VVAR(_rdproc__DOT__rd_state)
#define	wr_state	VVAR(_ewproc__DOT__wr_state)
#define	id_state	VVAR(_idotp__DOT__id_state)
#define	ctstate		VVAR(_ctproc__DOT__ctstate)
#define	rd_spi_wr	VVAR(_rd_spi_wr)
#define	ew_spi_wr	VVAR(_ew_spi_wr)
#define	id_spi_wr	VVAR(_id_spi_wr)
#define	ct_spi_wr	VVAR(_ct_spi_wr)
#define	spi_busy	VVAR(_spi_busy)
#define	spi_valid	VVAR(_spi_valid)
#define	ll_state	VVAR(_lowlvl__DOT__state)
#define	ll_input	VVAR(_lowlvl__DOT__r_input)
#define	spi_out		VVAR(_spi_out)
#define	id_last_addr	VVAR(_idotp__DOT__last_addr)
#define	id_lcl_id_addr	VVAR(_idotp__DOT__lcl_id_addr)
#define	id_loaded	VVAR(_idotp__DOT__id_loaded)
#define	id_nxt_data_ack	VVAR(_idotp__DOT__nxt_data_ack)
#define	id_nxt_data	VVAR(_idotp__DOT__nxt_data)
#define	id_set_val	VVAR(_idotp__DOT__set_val)
#define	id_set_addr	VVAR(_idotp__DOT__set_addr)
#define	rd_invalid_ack_pipe	VVAR(_rdproc__DOT__invalid_ack_pipe)
#define	ct_invalid_ack_pipe	VVAR(_ctproc__DOT__invalid_ack_pipe)
#define	rd_accepted	VVAR(_rdproc__DOT__accepted)
#define	ew_accepted	VVAR(_ewproc__DOT__accepted)
#define	id_accepted	VVAR(_idotp__DOT__accepted)
#define	ct_accepted	VVAR(_ctproc__DOT__accepted)
#define	pp_pending	VVAR(_preproc__DOT__pending)
#define	pp_lcl_key	VVAR(_preproc__DOT__lcl_key)
#define	pp_ctreg_stb	VVAR(_preproc__DOT__ctreg_stb)
#define	bus_ctreq	VVAR(_bus_ctreq)
#define	bus_other_req	VVAR(_bus_other_req)
#define	pp_wp		VVAR(_preproc__DOT__wp)
#define	bus_wip		VVAR(_bus_wip)
#define	pp_lcl_reg	VVAR(_preproc__DOT__lcl_reg)
#define	xip		VVAR(_w_xip)
#define	quad		VVAR(_w_quad)
#define	bus_piperd	VVAR(_bus_piperd)
#define	pp_wp		VVAR(_preproc__DOT__wp)
#define	ew_cyc		VVAR(_ewproc__DOT__cyc)
#define	bus_pipewr	VVAR(_bus_pipewr)
#define	bus_endwr	VVAR(_bus_endwr)
#define	ct_ack		VVAR(_ct_ack)
#define	rd_bus_ack	VVAR(_rd_bus_ack)
#define	id_bus_ack	VVAR(_id_bus_ack)
#define	ew_bus_ack	VVAR(_ew_bus_ack)
#define	pp_lcl_ack	VVAR(_preproc__DOT__lcl_ack)
#define	rd_leave_xip	VVAR(_rdproc__DOT__r_leave_xip)
#define	pp_new_req	VVAR(_preproc__DOT__new_req)
#define	bus_idreq	VVAR(_bus_idreq)
#define	id_bus_ack	VVAR(_id_bus_ack)
#define	id_read_request	VVAR(_idotp__DOT__id_read_request)
#define	rd_requested	VVAR(_rdproc__DOT__r_requested)
#define	rd_leave_xip	VVAR(_rdproc__DOT__r_leave_xip)


		printf("%08lx-WB: %s %s/%s %s %s[%s%s%s%s%s] %s %s@0x%08x[%08x/%08x] -- SPI %s%s[%x/%x](%d,%d)",
			m_tickcount,
			(m_core->i_wb_cyc)?"CYC":"   ",
			(m_core->i_wb_data_stb)?"DSTB":"    ",
			(m_core->i_wb_ctrl_stb)?"CSTB":"    ",
			(m_core->o_wb_stall)?"STALL":"     ",
			(m_core->o_wb_ack)?"ACK":"   ",
			(m_core->bus_wb_ack)?"BS":"  ",
			(m_core->rd_data_ack)?"RD":"  ",
			(m_core->ew_data_ack)?"EW":"  ",
			(m_core->id_data_ack)?"ID":"  ",
			(m_core->ct_data_ack)?"CT":"  ",
			(m_core->o_cmd_accepted)?"BUS":"   ",
			(m_core->i_wb_we)?"W":"R",
			(m_core->i_wb_addr), (m_core->i_wb_data),
			(m_core->o_wb_data),
			(!m_core->o_qspi_cs_n)?"CS":"  ",
			(m_core->o_qspi_sck)?"CK":"  ",
			(m_core->o_qspi_dat), (m_core->i_qspi_dat),
			(m_core->o_qspi_dat)&1, ((m_core->i_qspi_dat)&2)?1:0);

		/// printf("%08lx-EQ: ", m_tickcount);
		printf("EQ: ");
		if (m_core->owned) {
			switch(m_core->owner&3) {
			case 0: printf("RD"); break;
			case 1: printf("EW"); break;
			case 2: printf("ID"); break;
			case 3: printf("CT"); break;
			}
		} else printf("  ");

		printf(" REQ[%s%s%s%s]",
			(m_core->rd_qspi_req)?"RD":"  ",
			(m_core->ew_qspi_req)?"EW":"  ",
			(m_core->id_qspi_req)?"ID":"  ",
			(m_core->ct_qspi_req)?"CT":"  ");

		printf(" %s[%s%2d%s%s0x%08x]",
			(m_core->spi_wr)?"CMD":"   ",
			(m_core->spi_hold)?"HLD":"   ",
			(m_core->spi_len+1)*8,
			(m_core->spi_dir)?"RD":"WR",
			(m_core->spi_spd)?"Q":" ",
			(m_core->spi_word));


		printf(" STATE[%2x%s,%2x%s,%2x%s,%2x%s]",
			m_core->rd_state,
				(m_core->rd_spi_wr)?"W":" ",
			m_core->wr_state,
				(m_core->ew_spi_wr)?"W":" ",
			m_core->id_state,
				(m_core->id_spi_wr)?"W":" ",
			m_core->ctstate,
				(m_core->ct_spi_wr)?"W":" ");

		printf(" LL:[%s%s%d(%08x)->%08x]",
			(m_core->spi_busy)?"BSY":"   ",
			(m_core->spi_valid)?"VAL":"   ",
			(m_core->ll_state),
			(m_core->ll_input),
			(m_core->spi_out));

		// printf(" 0x%08x,%02x ", m_core->v__DOT__id_data, 
			// m_core->v__DOT__bus_addr);
		printf(" %s%08x@%08x",
			(m_core->v__DOT__bus_wr)?"W":"R",
			m_core->v__DOT__bus_data, m_core->v__DOT__bus_addr);

		if (m_core->id_state == 5)
			printf(" %s[%2x]%s",
				(m_core->id_last_addr)?"LST":"   ",
				(m_core->id_lcl_id_addr),
				(m_core->id_loaded)?"LOD":"   ");
			


		printf(" %s[%08x]",
			(m_core->id_nxt_data_ack)
			?"NXT":"   ", m_core->id_nxt_data);
		printf(" %s[%x]",
			(m_core->id_set_val)?"SET":"   ",
			(m_core->id_set_addr));

		printf(" RD:IACK[%x]",
			(m_core->rd_invalid_ack_pipe));
		printf(" CT:IACK[%x]",
			(m_core->ct_invalid_ack_pipe));

		{
			unsigned counts = m_flash->counts_till_idle();
			if (counts)
				printf(" %8dI ", counts);
		}

		printf("%s%s%s%s",
			(m_core->rd_accepted)?"RD-ACC":"",
			(m_core->ew_accepted)?"EW-ACC":"",
			(m_core->id_accepted)?"ID-ACC":"",
			(m_core->ct_accepted)?"CT-ACC":"");


		printf("%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s",
			(m_core->pp_pending)?" PENDING":"",
			(m_core->pp_lcl_key)?" KEY":"",
			(m_core->pp_ctreg_stb)?" CTSTB":"",
			(m_core->bus_ctreq)?" BUSCTRL":"",
			(m_core->bus_other_req)?" BUSOTHER":"",
			(m_core->pp_wp)?" WP":"",
			(m_core->bus_wip)?" WIP":"",
			// (m_core->pp_lcl_reg)?" LCLREG":"",
			// (m_core->xip)?" XIP":"",
			// (m_core->quad)?" QUAD":"",
			(m_core->bus_piperd)?" RDPIPE":"",
			(m_core->v__DOT__preproc__DOT__wp)?" WRWP":"",
			(m_core->ew_cyc)?" WRCYC":"",
			(m_core->bus_pipewr)?" WRPIPE":"",
			(m_core->bus_endwr)?" ENDWR":"",
			(m_core->ct_ack)?" CTACK":"",
			(m_core->rd_bus_ack)?" RDACK":"",
			(m_core->id_bus_ack)?" IDACK":"",
			(m_core->ew_bus_ack)?" EWACK":"",
			(m_core->pp_lcl_ack)?" LCLACK":"",
			(m_core->rd_leave_xip)?" LVXIP":"",
			(m_core->pp_new_req)?" NREQ":"");


		printf("%s%s%s",
			(m_core->bus_idreq)?" BUSID":"",
			(m_core->id_bus_ack)?" BUSAK":"",
			(m_core->id_read_request)?" IDRD":"");

		if (m_core->rd_requested)
			fputs(" RD:R_REQUESTED", stdout);
		if (m_core->rd_leave_xip)
			fputs(" RD:R_LVXIP", stdout);


		printf("\n");
#endif

		if ((m_trace)&&(m_tickcount>0))	m_trace->dump(10*m_tickcount-2);
		m_core->i_clk_82mhz = 1;
		m_core->eval();
		if (m_trace)	m_trace->dump(10*m_tickcount);
		m_core->i_clk_82mhz = 0;
		m_core->eval();
		if (m_trace)	m_trace->dump(10*m_tickcount+5);

		m_tickcount++;

		/*
		if ((m_core->o_wb_ack)&&(!m_core->i_wb_cyc)) {
			printf("SETTING ERR TO TRUE!!!!!  ACK w/ no CYC\n");
			// m_bomb = true;
		}
		*/
	}

	void wb_tick(void) {
		printf("WB-TICK()\n");
		m_core->i_wb_cyc   = 0;
		m_core->i_wb_data_stb = 0;
		m_core->i_wb_ctrl_stb = 0;
		tick();
	}

	unsigned wb_read(unsigned a) {
		int		errcount = 0;
		unsigned	result;

		printf("WB-READ(%08x)\n", a);

		m_core->i_wb_cyc = 1;
		m_core->i_wb_data_stb = (a & QSPIFLASH)?1:0;
		m_core->i_wb_ctrl_stb = !(m_core->i_wb_data_stb);
		m_core->i_wb_we  = 0;
		m_core->i_wb_addr= a & 0x03fffff;

		if (m_core->o_wb_stall) {
			while((errcount++ < BOMBCOUNT)&&(m_core->o_wb_stall))
				tick();
		} tick();

		m_core->i_wb_data_stb = 0;
		m_core->i_wb_ctrl_stb = 0;

		while((errcount++ <  BOMBCOUNT)&&(!m_core->o_wb_ack))
			tick();


		result = m_core->o_wb_data;

		// Release the bus?
		m_core->i_wb_cyc = 0;
		m_core->i_wb_data_stb = 0;
		m_core->i_wb_ctrl_stb = 0;

		if(errcount >= BOMBCOUNT) {
			printf("RD-SETTING ERR TO TRUE!!!!!\n");
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
		int		cnt, rdidx, inc;

		printf("WB-READ(%08x, %d)\n", a, len);

		while((errcount++ < BOMBCOUNT)&&(m_core->o_wb_stall))
			wb_tick();

		if (errcount >= BOMBCOUNT) {
			m_bomb = true;
			return;
		}

		errcount = 0;
		
		m_core->i_wb_cyc = 1;
		m_core->i_wb_data_stb = (a & QSPIFLASH)?1:0;
		m_core->i_wb_ctrl_stb = !(m_core->i_wb_data_stb);
		m_core->i_wb_we  = 0;
		m_core->i_wb_addr= a & 0x03fffff;

		rdidx =0; cnt = 0;
		inc = (m_core->i_wb_data_stb);

		do {
			int	s;
			s = (m_core->o_wb_stall==0)?0:1;
			tick();
			if (!s)
				m_core->i_wb_addr += inc;
			cnt += (s==0)?1:0;
			if (m_core->o_wb_ack)
				buf[rdidx++] = m_core->o_wb_data;
		} while((cnt < len)&&(errcount++ < THISBOMBCOUNT));

		m_core->i_wb_data_stb = 0;
		m_core->i_wb_ctrl_stb = 0;

		while((rdidx < len)&&(errcount++ < THISBOMBCOUNT)) {
			tick();
			if (m_core->o_wb_ack)
				buf[rdidx++] = m_core->o_wb_data;
		}

		// Release the bus?
		m_core->i_wb_cyc = 0;

		if(errcount >= THISBOMBCOUNT) {
			printf("RDI-SETTING ERR TO TRUE!!!!! (errcount=%08x, THISBOMBCOUNT=%08x)\n", errcount, THISBOMBCOUNT);
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
		m_core->i_wb_data_stb = (a & QSPIFLASH)?1:0;
		m_core->i_wb_ctrl_stb = !(m_core->i_wb_data_stb);
		m_core->i_wb_we  = 1;
		m_core->i_wb_addr= a & 0x03fffff;
		m_core->i_wb_data= v;

		if (m_core->o_wb_stall)
			while((errcount++ < BOMBCOUNT)&&(m_core->o_wb_stall))
				tick();
		tick();

		m_core->i_wb_data_stb = 0;
		m_core->i_wb_ctrl_stb = 0;

		while((errcount++ <  BOMBCOUNT)&&(!m_core->o_wb_ack))
			tick();

		// Release the bus?
		m_core->i_wb_cyc = 0;
		m_core->i_wb_data_stb = 0;
		m_core->i_wb_ctrl_stb = 0;

		if(errcount >= BOMBCOUNT) {
			printf("WB-SETTING ERR TO TRUE!!!!!\n");
			m_bomb = true;
		} tick();
	}

	void	wb_write(unsigned a, unsigned int ln, unsigned int *buf) {
		unsigned errcount = 0, nacks = 0;

		m_core->i_wb_cyc = 1;
		m_core->i_wb_data_stb = (a & QSPIFLASH)?1:0;
		m_core->i_wb_ctrl_stb = !(m_core->i_wb_data_stb);
		for(unsigned stbcnt=0; stbcnt<ln; stbcnt++) {
			m_core->i_wb_we  = 1;
			m_core->i_wb_addr= (a+stbcnt) & 0x03fffff;
			m_core->i_wb_data= buf[stbcnt];
			errcount = 0;

			while((errcount++ < BOMBCOUNT)&&(m_core->o_wb_stall)) {
				tick(); if (m_core->o_wb_ack) nacks++;
			}
			// Tick, now that we're not stalled.  This is the tick
			// that gets accepted.
			tick(); if (m_core->o_wb_ack) nacks++;
		}

		m_core->i_wb_data_stb = 0;
		m_core->i_wb_ctrl_stb = 0;

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
		m_core->i_wb_data_stb = 0;
		m_core->i_wb_ctrl_stb = 0;

		if(errcount >= BOMBCOUNT) {
			printf("WBI-SETTING ERR TO TRUE!!!!!\n");
			m_bomb = true;
		} tick();
	}

	void	wb_write_slow(unsigned a, unsigned int ln, unsigned int *buf,
			int slowcounts) {
		unsigned errcount = 0, nacks = 0;

		m_core->i_wb_cyc = 1;
		m_core->i_wb_data_stb = (a & QSPIFLASH)?1:0;
		m_core->i_wb_ctrl_stb = !(m_core->i_wb_data_stb);
		for(unsigned stbcnt=0; stbcnt<ln; stbcnt++) {
			m_core->i_wb_we  = 1;
			m_core->i_wb_addr= (a+stbcnt) & 0x03fffff;
			m_core->i_wb_data= buf[stbcnt];
			errcount = 0;

			while((errcount++ < BOMBCOUNT)&&(m_core->o_wb_stall)) {
				tick(); if (m_core->o_wb_ack) nacks++;
			}

			// Tick, now that we're not stalled.  This is the tick
			// that gets accepted.
			tick(); if (m_core->o_wb_ack) nacks++;


			m_core->i_wb_data_stb = 0;
			m_core->i_wb_ctrl_stb = 0;
			for(int j=0; j<slowcounts; j++) {
				tick(); if (m_core->o_wb_ack) nacks++;
			}

			// Turn our strobe signal back on again, after we just
			// turned it off.
			m_core->i_wb_data_stb = (a & QSPIFLASH)?1:0;
			m_core->i_wb_ctrl_stb = !(m_core->i_wb_data_stb);
		}

		m_core->i_wb_data_stb = 0;
		m_core->i_wb_ctrl_stb = 0;

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
		m_core->i_wb_data_stb = 0;
		m_core->i_wb_ctrl_stb = 0;

		if(errcount >= BOMBCOUNT) {
			printf("WBS-SETTING ERR TO TRUE!!!!!\n");
			m_bomb = true;
		} tick();
	}

	bool	bombed(void) const { return m_bomb; }

};

int main(int  argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	EQSPIFLASH_TB	*tb = new EQSPIFLASH_TB;
	const char 	*fname = "/dev/urandom";
	unsigned	rdv;
	unsigned	*rdbuf;
	int		 idx = 4;

	tb->load(fname);
	rdbuf = new unsigned[4096];
	tb->setflash(0,0);

	tb->trace("eqspi.vcd");

	tb->wb_tick();
	rdv = tb->wb_read(QSPIFLASH);
	printf("READ[0] = %04x\n", rdv);
	if (rdv != 0)
		goto test_failure;

	tb->wb_tick();
	if (tb->bombed())
		goto test_failure;

	for(int i=0; (i<1000)&&(!tb->bombed()); i++) {
		unsigned	tblv;
		tblv = (*tb)[i];
		rdv = tb->wb_read(QSPIFLASH+i);

		if(tblv != rdv) {
			printf("BOMB: READ[%08x] %08x, EXPECTED %08x\n", QSPIFLASH+i, rdv, tblv);
			goto test_failure;
			break;
		} else printf("MATCH: %08x == %08x\n", rdv, tblv);
	}

	printf("SINGLE-READ TEST PASSES\n");

	for(int i=0; i<1000; i++)
		rdbuf[i] = -1;
	tb->wb_read(QSPIFLASH+1000, 1000, rdbuf);
	if (tb->bombed())
		goto	test_failure;
	for(int i=0; i<1000; i++) {
		if ((*tb)[i+1000] != rdbuf[i]) {
			printf("BOMB: V-READ[%08x] %08x, EXPECTED %08x\n", QSPIFLASH+1000+i, rdv, (*tb)[i+1000]);
			goto	test_failure;
		}
	} if (tb->bombed())
		goto test_failure;
	printf("VECTOR TEST PASSES!\n");

	// Read the status register
	printf("EWCTRL-REG = %02x\n", rdv=tb->wb_read(0));
	if(tb->bombed()) goto test_failure;
	printf("STATUS-REG = %02x\n", rdv=tb->wb_read(1));
	if ((rdv != 0x1c)||(tb->bombed())) goto test_failure;
	printf("NVCONF-REG = %02x\n", tb->wb_read(2)); if(tb->bombed()) goto test_failure;
	printf("VCONFG-REG = %02x\n", tb->wb_read(3)); if(tb->bombed()) goto test_failure;
	printf("EVCONF-REG = %02x\n", tb->wb_read(4)); if(tb->bombed()) goto test_failure;
	printf("LOCK  -REG = %02x\n", tb->wb_read(5)); if(tb->bombed()) goto test_failure;
	printf("FLAG  -REG = %02x\n", tb->wb_read(6)); if(tb->bombed()) goto test_failure;

	if (tb->bombed())
		goto test_failure;

	printf("ID[%2d]-RG = %08x\n", 0, rdv = tb->wb_read(8+0));
	if (rdv != 0x20ba1810) {
		printf("BOMB: ID[%2d]-RG = %08x != %08x\n", 0, rdv,
			0x20ba1810);
		goto test_failure;
	}

	for(int i=1; i<5; i++)
		printf("ID[%2d]-RG = %02x\n", i, tb->wb_read(8+i));
	if (tb->bombed())
		goto test_failure;

	for(int i=0; i<16; i++)
		printf("OTP[%2d]-R = %02x\n", i, tb->wb_read(16+i));
	if (tb->bombed())
		goto test_failure;
	printf("OTP[CT]-R = %02x\n", tb->wb_read(15)>>24);

	if (tb->bombed())
		goto test_failure;

	printf("Attempting to switch in Quad mode\n");
	// tb->wb_write(4, (tb->wb_read(4)&0x07f)); // Adjust EVconfig

	for(int i=0; (i<1000)&&(!tb->bombed()); i++) {
		unsigned	tblv;
		tblv = (*tb)[i];
		rdv = tb->wb_read(QSPIFLASH+i);

		if(tblv != rdv) {
			printf("BOMB: READ %08x, EXPECTED %08x\n", rdv, tblv);
			goto test_failure;
			break;
		} else printf("MATCH: %08x == %08x\n", rdv, tblv);
	} tb->wb_read(QSPIFLASH+1000, 1000, rdbuf);
	if (tb->bombed())
		goto	test_failure;
	for(int i=0; i<1000; i++) {
		if ((*tb)[i+1000] != rdbuf[i]) {
			printf("BOMB: READ %08x, EXPECTED %08x\n", rdv, (*tb)[i+1000]);
			goto	test_failure;
		}
	} printf("VECTOR TEST PASSES! (QUAD)\n");

	printf("Attempting to switch to Quad mode with XIP\n");
	{
		int	nv;
		nv = tb->wb_read(3);
		printf("READ VCONF = %02x\n", nv);
		printf("WRITING VCONF= %02x\n", nv | 0x08);
		tb->wb_write(3, nv|0x08);
	}
	// tb->wb_write(0, 0x22000000);

	printf("Attempting to read in Quad mode, using XIP mode\n");
	for(int i=0; (i<1000)&&(!tb->bombed()); i++) {
		unsigned	tblv;
		tblv = (*tb)[i];
		rdv = tb->wb_read(QSPIFLASH+i);

		if(tblv != rdv) {
			printf("BOMB: READ %08x, EXPECTED %08x\n", rdv, tblv);
			goto test_failure;
			break;
		} else printf("MATCH: %08x == %08x\n", rdv, tblv);
	}

	// Try a vector read
	tb->wb_read(QSPIFLASH+1000, 1000, rdbuf);
	if (tb->bombed())
		goto	test_failure;
	for(int i=0; i<1000; i++) {
		if ((*tb)[i+1000] != rdbuf[i]) {
			printf("BOMB: READ %08x, EXPECTED %08x\n", rdv, (*tb)[i+1000]);
			goto	test_failure;
		}
	} printf("VECTOR TEST PASSES! (QUAD+XIP)\n");

	rdbuf[0] = tb->wb_read(QSPIFLASH+1023);
	rdbuf[1] = tb->wb_read(QSPIFLASH+2048);

	printf("Turning off write-protect, calling WEL\n");
	tb->wb_write(0, 0x620001be);
	printf("Attempting to erase subsector 1\n");
	tb->wb_write(0, 0xf20005be);

	while((tb->wb_read(0)&0x01000000)&&(!tb->bombed()))
		;
	while((tb->wb_read(0)&0x80000000)&&(!tb->bombed()))
		;
	if (tb->bombed())
		goto test_failure;
	if (tb->wb_read(QSPIFLASH+1023) != rdbuf[0])
		goto test_failure;
	if (tb->wb_read(QSPIFLASH+2048) != rdbuf[1])
		goto test_failure;
	tb->wb_read(QSPIFLASH+1024, 1024, rdbuf);
	for(int i=0; i<1024; i++) {
		if (rdbuf[i] != 0xffffffff) {
			printf("BOMB: SUBSECTOR ERASE, EXPECTED[0x%02x] = 0xffffffff != %08x\n", i, rdv);
			goto test_failure;
		} break;
	}

	// Try to execute a single write
	// Check that this will work ...
	for(idx=4; idx<4096; idx++) {
		if (0 != (tb->wb_read(QSPIFLASH+idx)&(~0x11111111)))
			break;
	}
	// First, turn the write-enable back on
	tb->wb_write(0, 0x620001be);
	// Now, write the value
	tb->wb_write(QSPIFLASH+idx, 0x11111111);
	while (tb->wb_read(0)&0x01000000)
		;
	while(tb->wb_read(0)&(0x80000000))
		;
	if (0 != (tb->wb_read(QSPIFLASH+idx)&(~0x11111111)))
		goto test_failure;

	// Try to write a complete block
	{
		FILE *fp = fopen(fname, "r"); // Open /dev/urandom
		if (4096 != fread(rdbuf, sizeof(unsigned), 4096, fp)) {
			perror("Couldnt read /dev/urandom into buffer!");
			goto test_failure;
		} fclose(fp);
	}

	printf("Attempting to write subsector 1\n");
	for(int i=0; i<1024; i+= 64) {
		printf("Turning off write-protect, calling WEL\n");
		tb->wb_write(0, 0x620001be);

		printf("Writing from %08x to %08x from rdbuf\n",
			QSPIFLASH+1024+i, QSPIFLASH+1024+i+63);
		// tb->wb_write(QSPIFLASH+1024+i, 64, &rdbuf[i]);
		tb->wb_write_slow(QSPIFLASH+1024+i, 64, &rdbuf[i], 32);
		while(tb->wb_read(0)&(0x80000000))
			;
	}

	tb->wb_read(QSPIFLASH+1024, 1024, &rdbuf[1024]);
	for(int i=0; i<1024; i++) {
		if (rdbuf[i] != rdbuf[i+1024]) {
			printf("BOMB: SUBSECTOR PROGRAM, EXPECTED[0x%02x] = 0x%08x != %08x\n", i, rdbuf[i], rdbuf[i+1024]);
			goto test_failure;
		}
	}

	// -Try to write an OTP register
	printf("Turning off write-protect, calling WEL\n");
	tb->wb_write( 0, 0x620001be);
	printf("Writing OTP[2]\n");
	tb->wb_write(18, 0x620001be);
	while (tb->wb_read(0)&0x01000000)
		;
	while(tb->wb_read(0)&(0x80000000))
		;
	if (0x620001be != tb->wb_read(18))
		goto test_failure;

	// -Try to write protect all OTP register
	printf("Turning off write-protect, calling WEL\n");
	tb->wb_write( 0, 0x620001be);
	printf("Writing OTP[END]\n");
	tb->wb_write(15, 0);
	while (tb->wb_read(0)&0x01000000)
		;
	while(tb->wb_read(0)&(0x80000000))
		;
	if (0 != tb->wb_read(15))
		goto test_failure;

	// -Try to write OTP after write protecting all OTP registers
	printf("Turning off write-protect, calling WEL\n");
	tb->wb_write( 0, 0x620001be);
	printf("Writing OTP[7]\n");
	tb->wb_write(16+7, 0);
	while (tb->wb_read(0)&0x01000000)
		;
	while(tb->wb_read(0)&(0x80000000))
		;

	// -Verify OTP not written
	if (0 == tb->wb_read(16+7))
		goto test_failure;


	printf("SUCCESS!!\n");
	exit(0);
test_failure:
	printf("FAIL-HERE\n");
	for(int i=0; i<64; i++)
		tb->tick();
	printf("TEST FAILED\n");
	exit(-1);
}
