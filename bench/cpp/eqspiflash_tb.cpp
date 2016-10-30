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
#include "Veqspiflash.h"
#include "eqspiflashsim.h"

#define	QSPIFLASH	0x0400000
const int	BOMBCOUNT = 2048;

class	EQSPIFLASH_TB {
	long		m_tickcount;
	Veqspiflash	*m_core;
	EQSPIFLASHSIM	*m_flash;
	bool		m_bomb;
public:

	EQSPIFLASH_TB(void) {
		m_core = new Veqspiflash;
		m_flash= new EQSPIFLASHSIM;
	}

	unsigned operator[](const int index) { return (*m_flash)[index]; }
	void	setflash(unsigned addr, unsigned v) {
		m_flash->set(addr, v);
	}
	void	load(const char *fname) {
		m_flash->load(0,fname);
	}

	void	tick(void) {
		m_core->i_clk_82mhz = 0;
		m_core->eval();
		m_core->i_qspi_dat = (*m_flash)(m_core->o_qspi_cs_n,
			m_core->o_qspi_sck, m_core->o_qspi_dat);

		m_core->i_clk_82mhz = 1;
		printf("%08lx-WB: %s %s/%s %s %s[%s%s%s%s%s] %s %s@0x%08x[%08x/%08x] -- SPI %s%s[%x/%x](%d,%d)",
			m_tickcount,
			(m_core->i_wb_cyc)?"CYC":"   ",
			(m_core->i_wb_data_stb)?"DSTB":"    ",
			(m_core->i_wb_ctrl_stb)?"CSTB":"    ",
			(m_core->o_wb_stall)?"STALL":"     ",
			(m_core->o_wb_ack)?"ACK":"   ",
			(m_core->v__DOT__bus_wb_ack)?"BS":"  ",
			(m_core->v__DOT__rd_data_ack)?"RD":"  ",
			(m_core->v__DOT__ew_data_ack)?"EW":"  ",
			(m_core->v__DOT__id_data_ack)?"ID":"  ",
			(m_core->v__DOT__ct_data_ack)?"CT":"  ",
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
		if (m_core->v__DOT__owned) {
			switch(m_core->v__DOT__owner&3) {
			case 0: printf("RD"); break;
			case 1: printf("EW"); break;
			case 2: printf("ID"); break;
			case 3: printf("CT"); break;
			}
		} else printf("  ");

		printf(" REQ[%s%s%s%s]",
			(m_core->v__DOT__rd_qspi_req)?"RD":"  ",
			(m_core->v__DOT__ew_qspi_req)?"EW":"  ",
			(m_core->v__DOT__id_qspi_req)?"ID":"  ",
			(m_core->v__DOT__ct_qspi_req)?"CT":"  ");

		printf(" %s[%s%2d%s%s0x%08x]",
			(m_core->v__DOT__spi_wr)?"CMD":"   ",
			(m_core->v__DOT__spi_hold)?"HLD":"   ",
			(m_core->v__DOT__spi_len+1)*8,
			(m_core->v__DOT__spi_dir)?"RD":"WR",
			(m_core->v__DOT__spi_spd)?"Q":" ",
			(m_core->v__DOT__spi_word));

		printf(" STATE[%2x%s,%2x%s,%2x%s,%2x%s]",
			m_core->v__DOT__rdproc__DOT__rd_state,
				(m_core->v__DOT__rd_spi_wr)?"W":" ",
			m_core->v__DOT__ewproc__DOT__wr_state,
				(m_core->v__DOT__ew_spi_wr)?"W":" ",
			m_core->v__DOT__idotp__DOT__id_state,
				(m_core->v__DOT__id_spi_wr)?"W":" ",
			m_core->v__DOT__ctproc__DOT__ctstate,
				(m_core->v__DOT__ct_spi_wr)?"W":" ");

		printf(" LL:[%s%s%d(%08x)->%08x]",
			(m_core->v__DOT__spi_busy)?"BSY":"   ",
			(m_core->v__DOT__spi_valid)?"VAL":"   ",
			(m_core->v__DOT__lowlvl__DOT__state),
			(m_core->v__DOT__lowlvl__DOT__r_input),
			(m_core->v__DOT__spi_out));

		// printf(" 0x%08x,%02x ", m_core->v__DOT__id_data, 
			// m_core->v__DOT__bus_addr);
		printf(" %s%08x@%08x",
			(m_core->v__DOT__bus_wr)?"W":"R",
			m_core->v__DOT__bus_data, m_core->v__DOT__bus_addr);

		if (m_core->v__DOT__idotp__DOT__id_state == 5)
			printf(" %s[%2x]%s",
				(m_core->v__DOT__idotp__DOT__last_addr)?"LST":"   ",
				(m_core->v__DOT__idotp__DOT__lcl_id_addr),
				(m_core->v__DOT__idotp__DOT__id_loaded)?"LOD":"   ");
			

		printf(" %s[%08x]",
			(m_core->v__DOT__idotp__DOT__nxt_data_ack)
			?"NXT":"   ", m_core->v__DOT__idotp__DOT__nxt_data);
		printf(" %s[%x]",
			(m_core->v__DOT__idotp__DOT__set_val)?"SET":"   ",
			(m_core->v__DOT__idotp__DOT__set_addr));

		printf(" RD:IACK[%x]",
			(m_core->v__DOT__rdproc__DOT__invalid_ack_pipe));
		printf(" CT:IACK[%x]",
			(m_core->v__DOT__ctproc__DOT__invalid_ack_pipe));

		{
			unsigned counts = m_flash->counts_till_idle();
			if (counts)
				printf(" %8dI ", counts);
		}
		printf("%s%s%s%s",
			(m_core->v__DOT__rdproc__DOT__accepted)?"RD-ACC":"",
			(m_core->v__DOT__ewproc__DOT__accepted)?"EW-ACC":"",
			(m_core->v__DOT__idotp__DOT__accepted)?"ID-ACC":"",
			(m_core->v__DOT__ctproc__DOT__accepted)?"CT-ACC":"");


		printf("%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s",
			(m_core->v__DOT__preproc__DOT__pending)?" PENDING":"",
			(m_core->v__DOT__preproc__DOT__lcl_key)?" KEY":"",
			(m_core->v__DOT__preproc__DOT__ctreg_stb)?" CTSTB":"",
			(m_core->v__DOT__bus_ctreq)?" BUSCTRL":"",
			(m_core->v__DOT__bus_other_req)?" BUSOTHER":"",
			(m_core->v__DOT__preproc__DOT__wp)?" WP":"",
			(m_core->v__DOT__bus_wip)?" WIP":"",
			// (m_core->v__DOT__preproc__DOT__lcl_reg)?" LCLREG":"",
			// (m_core->v__DOT__w_xip)?" XIP":"",
			// (m_core->v__DOT__w_quad)?" QUAD":"",
			(m_core->v__DOT__bus_piperd)?" RDPIPE":"",
			(m_core->v__DOT__preproc__DOT__wp)?" WRWP":"",
			(m_core->v__DOT__ewproc__DOT__cyc)?" WRCYC":"",
			(m_core->v__DOT__bus_pipewr)?" WRPIPE":"",
			(m_core->v__DOT__bus_endwr)?" ENDWR":"",
			(m_core->v__DOT__ct_ack)?" CTACK":"",
			(m_core->v__DOT__rd_bus_ack)?" RDACK":"",
			(m_core->v__DOT__id_bus_ack)?" IDACK":"",
			(m_core->v__DOT__ew_bus_ack)?" EWACK":"",
			(m_core->v__DOT__preproc__DOT__lcl_ack)?" LCLACK":"",
			(m_core->v__DOT__rdproc__DOT__r_leave_xip)?" LVXIP":"",
			(m_core->v__DOT__preproc__DOT__new_req)?" NREQ":"");

		printf("%s%s%s",
			(m_core->v__DOT__bus_idreq)?" BUSID":"",
			(m_core->v__DOT__id_bus_ack)?" BUSAK":"",
			(m_core->v__DOT__idotp__DOT__id_read_request)?" IDRD":"");

		if (m_core->v__DOT__rdproc__DOT__r_requested)
			fputs(" RD:R_REQUESTED", stdout);
		if (m_core->v__DOT__rdproc__DOT__r_leave_xip)
			fputs(" RD:R_LVXIP", stdout);


		printf("\n");

		m_core->eval();
		m_core->i_clk_82mhz = 0;
		m_core->eval();

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

		if (m_core->o_wb_stall)
			while((errcount++ < BOMBCOUNT)&&(m_core->o_wb_stall))
				tick();
		else
			tick();

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
			printf("SETTING ERR TO TRUE!!!!!\n");
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
			printf("SETTING ERR TO TRUE!!!!!\n");
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
			printf("SETTING ERR TO TRUE!!!!!\n");
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

	while (tb->wb_read(0)&0x01000000)
		;
	while(tb->wb_read(0)&0x80000000)
		;
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
