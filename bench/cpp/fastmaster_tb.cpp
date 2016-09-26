////////////////////////////////////////////////////////////////////////////////
//
// Filename:	fastmaster_tb.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This is a piped version of the testbench for the fastmaster
//		verilog module.  The fastmaster code is designed to be a
//	complete code set implementing all of the functionality of the Digilent
//	Arty board.  If done well, the programs talking to this one should be
//	able to talk to the board and apply the same tests to the board itself.
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
#include <signal.h>
#include <time.h>
#include <ctype.h>

#include "verilated.h"
#include "Vfastmaster.h"

#include "testb.h"
// #include "twoc.h"
#include "pipecmdr.h"
#include "eqspiflashsim.h"
#ifdef	SDRAM_ACCESS
#include "ddrsdramsim.h"
#endif
#include "sdspisim.h"
#include "uartsim.h"
#include "enetctrlsim.h"

#include "port.h"

const int	LGMEMSIZE = 28;

// No particular "parameters" need definition or redefinition here.
class	FASTMASTER_TB : public PIPECMDR<Vfastmaster> {
public:
	unsigned long	m_tx_busy_count;
	EQSPIFLASHSIM	m_flash;
	SDSPISIM	m_sdcard;
#ifdef	SDRAM_ACCESS
	DDRSDRAMSIM	m_sdram;
#endif
	ENETCTRLSIM	*m_mid;
	UARTSIM		m_uart;

	unsigned	m_last_led, m_last_pic, m_last_tx_state;
	time_t		m_start_time;
	bool		m_last_writeout;
	int		m_last_bus_owner, m_busy;

	FASTMASTER_TB(void) : PIPECMDR(FPGAPORT),
#ifdef	SDRAM_ACCESS
			m_sdram(LGMEMSIZE),
#endif
			m_uart(FPGAPORT+1)
			{
		m_start_time = time(NULL);
		m_mid = new ENETCTRLSIM;
	}

	void	setsdcard(const char *fn) {
		m_sdcard.load(fn);
	
		printf("LOADING SDCARD FROM: \'%s\'\n", fn);
	}

	void	tick(void) {
		if ((m_tickcount & ((1<<28)-1))==0) {
			double	ticks_per_second = m_tickcount;
			time_t	seconds_passed = time(NULL)-m_start_time;
			if (seconds_passed != 0) {
			ticks_per_second /= (double)(time(NULL) - m_start_time);
			printf(" ********   %.6f TICKS PER SECOND\n", 
				ticks_per_second);
			}
		}

		// Set up the bus before any clock tick
		m_core->i_clk = 1;

		m_core->i_qspi_dat = m_flash(m_core->o_qspi_cs_n,
				m_core->o_qspi_sck, m_core->o_qspi_dat);

		m_core->i_mdio = (*m_mid)(m_core->o_mdclk,
				((m_core->o_mdwe)&(m_core->o_mdio))
				|((m_core->o_mdwe)?0:1));

#ifdef	SDRAM_ACCESS
		m_core->i_ddr_data = m_sdram(
				m_core->o_ddr_reset_n,
				m_core->o_ddr_cke,
				m_core->o_ddr_cs_n,
				m_core->o_ddr_ras_n,
				m_core->o_ddr_cas_n,
				m_core->o_ddr_we_n,
				m_core->o_ddr_dqs,
				m_core->o_ddr_dm,
				m_core->o_ddr_odt,
				m_core->o_ddr_bus_oe,
				m_core->o_ddr_addr,
				m_core->o_ddr_ba,
				m_core->o_ddr_data);
#else
		m_core->i_ddr_data = 0;
#endif

		m_core->i_aux_rx = m_uart(m_core->o_aux_tx,
				m_core->v__DOT__runio__DOT__aux_setup);

		m_core->i_sd_data = m_sdcard((m_core->o_sd_data&8)?1:0,
				m_core->o_sd_sck, m_core->o_sd_cmd);
		m_core->i_sd_data &= 1;
		m_core->i_sd_data |= (m_core->o_sd_data&0x0e);

		PIPECMDR::tick();

// #define	DEBUGGING_OUTPUT
		bool	writeout = false;
		/*
		*/
		if ((writeout)||(m_last_writeout)) {
			printf("%08lx:", m_tickcount);

			/*
			printf("%d/%02x %d/%02x%s ",
				m_core->i_rx_stb, m_core->i_rx_data,
				m_core->o_tx_stb, m_core->o_tx_data,
				m_core->i_tx_busy?"/BSY":"    ");
			*/

			/*
			printf("(%d,%d->%d),(%c:%d,%d->%d)|%c[%08x/%08x]@%08x %c%c%c",
				m_core->v__DOT__wbu_cyc,
				m_core->v__DOT__dwb_cyc, // was zip_cyc
				0,
				m_core->v__DOT__wb_cyc,
				//
				m_core->v__DOT__wbu_zip_arbiter__DOT__r_a_owner?'Z':'j',
				m_core->v__DOT__wbu_stb,
				// 0, // m_core->v__DOT__dwb_stb, // was zip_stb
				m_core->v__DOT__zippy__DOT__thecpu__DOT__mem_stb_gbl,
				m_core->v__DOT__wb_stb,
				//
				(m_core->v__DOT__wb_we)?'W':'R',
				m_core->v__DOT__wb_data,
					m_core->v__DOT__dwb_idata,
				m_core->v__DOT__wb_addr,
				(m_core->v__DOT__dwb_ack)?'A':
					(m_core->v__DOT____Vcellinp__genbus____pinNumber9)?'a':' ',
				(m_core->v__DOT__dwb_stall)?'S':
					(m_core->v__DOT____Vcellinp__genbus____pinNumber10)?'s':' ',
				(m_core->v__DOT__wb_err)?'E':'.');
			*/

			/*
			*/

			/*
			// CPU Pipeline debugging
			*/

			/*
			printf(" SDSPI[%d,%d(%d),(%d)]",
				m_core->v__DOT__sdcard_controller__DOT__r_cmd_busy,
				m_core->v__DOT__sdcard_controller__DOT__r_sdspi_clk,
				m_core->v__DOT__sdcard_controller__DOT__r_cmd_state,
				m_core->v__DOT__sdcard_controller__DOT__r_rsp_state);
			printf(" LL[%d,%2x->CK=%d/%2x,%s,ST=%2d,TX=%2x,RX=%2x->%d,%2x] ",
				m_core->v__DOT__sdcard_controller__DOT__ll_cmd_stb,
				m_core->v__DOT__sdcard_controller__DOT__ll_cmd_dat,
				m_core->v__DOT__sdcard_controller__DOT__lowlevel__DOT__r_z_counter,
				// (m_core->v__DOT__sdcard_controller__DOT__lowlevel__DOT__r_clk_counter==0)?1:0,
				m_core->v__DOT__sdcard_controller__DOT__lowlevel__DOT__r_clk_counter,
				(m_core->v__DOT__sdcard_controller__DOT__lowlevel__DOT__r_idle)?"IDLE":"    ",
				m_core->v__DOT__sdcard_controller__DOT__lowlevel__DOT__r_state,
				m_core->v__DOT__sdcard_controller__DOT__lowlevel__DOT__r_byte,
				m_core->v__DOT__sdcard_controller__DOT__lowlevel__DOT__r_ireg,
				m_core->v__DOT__sdcard_controller__DOT__ll_out_stb,
				m_core->v__DOT__sdcard_controller__DOT__ll_out_dat
				);
			printf(" CRC=%02x/%2d",
				m_core->v__DOT__sdcard_controller__DOT__r_cmd_crc,
				m_core->v__DOT__sdcard_controller__DOT__r_cmd_crc_cnt);
			printf(" SPI(%d,%d,%d/%d,%d)->?",
				m_core->o_sf_cs_n,
				m_core->o_sd_cs_n,
				m_core->o_spi_sck, m_core->v__DOT__sdcard_sck,
				m_core->o_spi_mosi);

			printf(" CK=%d,LN=%d",
				m_core->v__DOT__sdcard_controller__DOT__r_sdspi_clk,
				m_core->v__DOT__sdcard_controller__DOT__r_lgblklen);


			if (m_core->v__DOT__sdcard_controller__DOT__r_use_fifo){
				printf(" FIFO");
				if (m_core->v__DOT__sdcard_controller__DOT__r_fifo_wr)
					printf("-WR(%04x,%d,%d,%d)",
						m_core->v__DOT__sdcard_controller__DOT__fifo_rd_crc_reg,
						m_core->v__DOT__sdcard_controller__DOT__fifo_rd_crc_stb,
						m_core->v__DOT__sdcard_controller__DOT__ll_fifo_pkt_state,
						m_core->v__DOT__sdcard_controller__DOT__r_have_data_response_token);
				else
					printf("-RD(%04x,%d,%d,%d)",
						m_core->v__DOT__sdcard_controller__DOT__fifo_wr_crc_reg,
						m_core->v__DOT__sdcard_controller__DOT__fifo_wr_crc_stb,
						m_core->v__DOT__sdcard_controller__DOT__ll_fifo_wr_state,
						m_core->v__DOT__sdcard_controller__DOT__ll_fifo_wr_complete
						);
			}
			*/


			printf("\n"); fflush(stdout);
		} m_last_writeout = writeout;
	}
};

FASTMASTER_TB	*tb;

void	fastmaster_kill(int v) {
	tb->kill();
	fprintf(stderr, "KILLED!!\n");
	exit(0);
}

int	main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	tb = new FASTMASTER_TB;

	// signal(SIGINT,  fastmaster_kill);

	tb->reset();
	if (argc > 1)
		tb->setsdcard(argv[1]);
	else
		tb->setsdcard("/dev/zero");

	while(1)
		tb->tick();

	exit(0);
}

