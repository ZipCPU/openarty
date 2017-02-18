////////////////////////////////////////////////////////////////////////////////
//
// Filename:	fastmaster_tb.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This is a piped version of the testbench for the wishbone
//		master verilog module, whether it be fastmaster.v or
//	busmaster.v.  Both fastmaster.v and busmaster.v are designed to be
//	complete code sets implementing all of the functionality of the Digilent
//	Arty board---save the hardware dependent features to include the DDR3
//	memory.  If done well, the programs talking to this one should be
//	able to talk to the board and apply the same tests to the board itself.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2017, Gisselquist Technology, LLC
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
#include <signal.h>
#include <time.h>
#include <ctype.h>

#include "verilated.h"
#ifdef	FASTCLK
#include "Vfastmaster.h"
#define	BASECLASS	Vfastmaster
#error "This should never be incldued"
#else
#include "Vbusmaster.h"
#define	BASECLASS	Vbusmaster
#endif

#include "testb.h"
// #include "twoc.h"
#include "pipecmdr.h"
#include "eqspiflashsim.h"
#include "sdspisim.h"
#include "uartsim.h"
#include "enetctrlsim.h"
#include "memsim.h"
#ifdef	OLEDSIM
#include "oledsim.h"
#endif

#include "zipelf.h"
#include "byteswap.h"
#include "port.h"

const int	LGMEMSIZE = 28;
//
// Define where our memory is at, so we can load into it properly
// The following comes from the "skipaddr" reference in the I/O handling
// section.  For example, if address line 23 is high, the address is for
// SDRAM base.  The extra +2 is because each bus address references four
// bytes, and so there are two phantom address lines that need to be
// accounted for.
#define	MEMBASE		(1<<(15+2))
#define	FLASHBASE	(1<<(22+2))
#define	SDRAMBASE	(1<<(26+2))
//
// Setting the length to the base address works because the base address for
// each of these memory regions is given by a 'one' in the first bit not used
// by the respective device.  If the memory is ever placed elsewhere, that will
// no longer work, and a proper  length will need to be entered in here.
#define	MEMLEN		MEMBASE
#define	FLASHLEN	FLASHBASE
#define	SDRAMLEN	SDRAMBASE


// No particular "parameters" need definition or redefinition here.
class	TESTBENCH : public PIPECMDR<BASECLASS> {
public:
	unsigned long	m_tx_busy_count;
	EQSPIFLASHSIM	m_flash;
	SDSPISIM	m_sdcard;
	ENETCTRLSIM	*m_mid;
	UARTSIM		m_uart;
	MEMSIM		m_ram;
#ifdef	OLEDSIM_H
	OLEDWIN		m_oled;
#endif
	int		m_halt_in_count;

	unsigned	m_last_led, m_last_pic, m_last_tx_state, m_net_ticks;
	time_t		m_start_time;
	bool		m_last_writeout, m_cpu_started;
	int		m_last_bus_owner, m_busy, m_bomb;
	unsigned long	m_gps_err, m_gps_step, m_gps_newstep, m_traceticks;
	unsigned 	m_gps_stepc;
	bool		m_done;

	TESTBENCH(int fpgaport, int serialport, bool copy_to_stdout, bool debug)
			: PIPECMDR(fpgaport, copy_to_stdout),
			m_flash(24, debug), m_uart(serialport), m_ram(1<<26)
			{
		if (debug)
			printf("Copy-to-stdout is %s\n", (copy_to_stdout)?"true":"false");

		m_start_time = time(NULL);
		m_mid = new ENETCTRLSIM;
		m_cpu_started =false;
#ifdef	OLEDSIM_H
		Glib::signal_idle().connect(sigc::mem_fun((*this),&TESTBENCH::on_tick));
#endif
		m_done = false;
		m_bomb = 0;
		m_traceticks = 0;
		//
		m_core->i_aux_rts = 1;
		//
		m_halt_in_count = 0;
	}

	void	reset(void) {
		m_core->i_clk = 1;
		m_core->eval();
	}

	void	trace(const char *vcd_trace_file_name) {
		fprintf(stderr, "Opening TRACE(%s)\n", vcd_trace_file_name);
		opentrace(vcd_trace_file_name);
		m_traceticks = 0;
	}

	void	close(void) {
		// TESTB<BASECLASS>::closetrace();
		m_done = true;
	}

	void	setsdcard(const char *fn) {
		m_sdcard.load(fn);
	}

	void	load(uint32_t addr, const char *buf, uint32_t len) {
		if ((addr >= MEMBASE)&&(addr + len <= MEMBASE+MEMLEN)) {
			char	*bswapd = new char[len+8];
			assert( ((len&3)==0) && ((addr&3)==0) );
			memcpy(bswapd, buf, len);
			byteswapbuf(len>>2, (uint32_t *)bswapd);
			memcpy(&m_core->v__DOT__blkram__DOT__mem[addr-MEMBASE],
				bswapd, len);
			delete[] bswapd;
		} else if ((addr >= FLASHBASE)&&(addr + len<= FLASHBASE+FLASHLEN))
			m_flash.load(addr-FLASHBASE, buf, len);
		else if ((addr >= SDRAMBASE)&&(addr + len<= SDRAMBASE+SDRAMLEN))
			m_ram.load(addr-SDRAMBASE, buf, len);
		else {
			fprintf(stderr, "ERR: Address range %07x-%07x does not exist in memory\n",
				addr, addr+len);
			exit(EXIT_FAILURE);
		}
	}

	bool	gie(void) {
		return (m_core->v__DOT__swic__DOT__thecpu__DOT__r_gie);
	}

	void dump(const uint32_t *regp) {
		uint32_t	uccv, iccv;
		fflush(stderr);
		fflush(stdout);
		printf("ZIPM--DUMP: ");
		if (gie())
			printf("Interrupts-enabled\n");
		else
			printf("Supervisor mode\n");
		printf("\n");

		iccv = m_core->v__DOT__swic__DOT__thecpu__DOT__w_iflags;
		uccv = m_core->v__DOT__swic__DOT__thecpu__DOT__w_uflags;

		printf("sR0 : %08x ", regp[0]);
		printf("sR1 : %08x ", regp[1]);
		printf("sR2 : %08x ", regp[2]);
		printf("sR3 : %08x\n",regp[3]);
		printf("sR4 : %08x ", regp[4]);
		printf("sR5 : %08x ", regp[5]);
		printf("sR6 : %08x ", regp[6]);
		printf("sR7 : %08x\n",regp[7]);
		printf("sR8 : %08x ", regp[8]);
		printf("sR9 : %08x ", regp[9]);
		printf("sR10: %08x ", regp[10]);
		printf("sR11: %08x\n",regp[11]);
		printf("sR12: %08x ", regp[12]);
		printf("sSP : %08x ", regp[13]);
		printf("sCC : %08x ", iccv);
		printf("sPC : %08x\n",regp[15]);

		printf("\n");

		printf("uR0 : %08x ", regp[16]);
		printf("uR1 : %08x ", regp[17]);
		printf("uR2 : %08x ", regp[18]);
		printf("uR3 : %08x\n",regp[19]);
		printf("uR4 : %08x ", regp[20]);
		printf("uR5 : %08x ", regp[21]);
		printf("uR6 : %08x ", regp[22]);
		printf("uR7 : %08x\n",regp[23]);
		printf("uR8 : %08x ", regp[24]);
		printf("uR9 : %08x ", regp[25]);
		printf("uR10: %08x ", regp[26]);
		printf("uR11: %08x\n",regp[27]);
		printf("uR12: %08x ", regp[28]);
		printf("uSP : %08x ", regp[29]);
		printf("uCC : %08x ", uccv);
		printf("uPC : %08x\n",regp[31]);
		printf("\n");
		fflush(stderr);
		fflush(stdout);
	}


	void	execsim(const uint32_t imm) {
		uint32_t	*regp = m_core->v__DOT__swic__DOT__thecpu__DOT__regset;
		int		rbase;
		rbase = (gie())?16:0;

		fflush(stdout);
		if ((imm & 0x03fffff)==0)
			return;
		// fprintf(stderr, "SIM-INSN(0x%08x)\n", imm);
		if ((imm & 0x0fffff)==0x00100) {
			// SIM Exit(0)
			close();
			exit(0);
		} else if ((imm & 0x0ffff0)==0x00310) {
			// SIM Exit(User-Reg)
			int	rcode;
			rcode = regp[(imm&0x0f)+16] & 0x0ff;
			close();
			exit(rcode);
		} else if ((imm & 0x0ffff0)==0x00300) {
			// SIM Exit(Reg)
			int	rcode;
			rcode = regp[(imm&0x0f)+rbase] & 0x0ff;
			close();
			exit(rcode);
		} else if ((imm & 0x0fff00)==0x00100) {
			// SIM Exit(Imm)
			int	rcode;
			rcode = imm & 0x0ff;
			close();
			exit(rcode);
		} else if ((imm & 0x0fffff)==0x002ff) {
			// Full/unconditional dump
			printf("SIM-DUMP\n");
			dump(regp);
		} else if ((imm & 0x0ffff0)==0x00200) {
			// Dump a register
			int rid = (imm&0x0f)+rbase;
			printf("%8ld @%08x R[%2d] = 0x%08x\n", m_tickcount,
			m_core->v__DOT__swic__DOT__thecpu__DOT__ipc,
			rid, regp[rid]);
		} else if ((imm & 0x0ffff0)==0x00210) {
			// Dump a user register
			int rid = (imm&0x0f);
			printf("%8ld @%08x uR[%2d] = 0x%08x\n", m_tickcount,
				m_core->v__DOT__swic__DOT__thecpu__DOT__ipc,
				rid, regp[rid+16]);
		} else if ((imm & 0x0ffff0)==0x00230) {
			// SOUT[User Reg]
			int rid = (imm&0x0f)+16;
			printf("%c", regp[rid]&0x0ff);
		} else if ((imm & 0x0fffe0)==0x00220) {
			// SOUT[User Reg]
			int rid = (imm&0x0f)+rbase;
			printf("%c", regp[rid]&0x0ff);
		} else if ((imm & 0x0fff00)==0x00400) {
			// SOUT[Imm]
			printf("%c", imm&0x0ff);
		} else { // if ((insn & 0x0f7c00000)==0x77800000)
			uint32_t	immv = imm & 0x03fffff;
			// Simm instruction that we dont recognize
			// if (imm)
			// printf("SIM 0x%08x\n", immv);
			printf("SIM 0x%08x (ipc = %08x, upc = %08x)\n", immv,
				m_core->v__DOT__swic__DOT__thecpu__DOT__ipc,
				m_core->v__DOT__swic__DOT__thecpu__DOT__r_upc
				);
		} fflush(stdout);
	}

	bool	on_tick(void) {
		if (!m_done) {
			tick();
			return true; // Keep going 'til the kingdom comes
		} else return false;
	}

	void	tick(void) {
		if (m_done)
			return;
		if ((m_tickcount & ((1<<28)-1))==0) {
			double	ticks_per_second = m_tickcount;
			time_t	seconds_passed = time(NULL)-m_start_time;
			if (seconds_passed != 0) {
			ticks_per_second /= (double)(time(NULL) - m_start_time);
			printf(" ********   %.6f TICKS PER SECOND\n", 
				ticks_per_second);
			}
		}

		if (m_halt_in_count > 0) {
			if (m_halt_in_count-- <= 0) {
				m_done = true;
			}
		}

		if (TESTB<BASECLASS>::m_trace)
			m_traceticks++;

		// Set up the bus before any clock tick
#ifdef	OLEDSIM_H
		m_oled(m_core->o_oled_pmoden, m_core->o_oled_reset_n,
			m_core->o_oled_vccen, m_core->o_oled_cs_n,
			m_core->o_oled_sck, m_core->o_oled_dcn,
			m_core->o_oled_mosi);
#endif
		m_core->i_qspi_dat = m_flash(m_core->o_qspi_cs_n,
				m_core->o_qspi_sck, m_core->o_qspi_dat);

		m_core->i_mdio = (*m_mid)((m_core->o_net_reset_n==0)?1:0, m_core->o_mdclk,
				((m_core->o_mdwe)&&(!m_core->o_mdio))?0:1);

		/*
		printf("MDIO: %d %d %d %d/%d -> %d\n",
			m_core->o_net_reset_n,
			m_core->o_mdclk,
			m_core->o_mdwe,
			m_core->o_mdio,
			((m_core->o_mdwe)&&(!m_core->o_mdio))?0:1,
			m_core->i_mdio);
		*/

		m_core->i_aux_rx = m_uart(m_core->o_aux_tx,
				m_core->v__DOT__console__DOT__uart_setup);
		m_core->i_gps_rx = 1;

		m_core->i_sd_data = m_sdcard((m_core->o_sd_data&8)?1:0,
				m_core->o_sd_sck, m_core->o_sd_cmd);
		m_core->i_sd_data &= 1;
		m_core->i_sd_data |= (m_core->o_sd_data&0x0e);

		// Turn the network into a simple loopback device.
		if (++m_net_ticks>5)
			m_net_ticks = 0;
		m_core->i_net_rx_clk = (m_net_ticks >= 2)&&(m_net_ticks < 5);
		m_core->i_net_tx_clk = (m_net_ticks >= 0)&&(m_net_ticks < 3);
		if (!m_core->i_net_rx_clk) {
			m_core->i_net_dv    = m_core->o_net_tx_en;
			m_core->i_net_rxd   = m_core->o_net_txd;
			m_core->i_net_crs   = m_core->o_net_tx_en;
		} m_core->i_net_rxerr = 0;
		if (!m_core->o_net_reset_n) {
			m_core->i_net_dv = 0;
			m_core->i_net_crs= 0;
		}

		m_ram.apply(m_core->o_ram_cyc, m_core->o_ram_stb,
			m_core->o_ram_we, m_core->o_ram_addr,
			m_core->o_ram_wdata, m_core->o_ram_sel,
			m_core->i_ram_ack, m_core->i_ram_stall,
			m_core->i_ram_rdata);

		PIPECMDR::tick();

		// Sim instructions
		if ((m_core->v__DOT__swic__DOT__thecpu__DOT__op_sim)
			&&(m_core->v__DOT__swic__DOT__thecpu__DOT__op_valid)
			&&(m_core->v__DOT__swic__DOT__thecpu__DOT__alu_ce)
			&&(!m_core->v__DOT__swic__DOT__thecpu__DOT__new_pc)) {
			//
			execsim(m_core->v__DOT__swic__DOT__thecpu__DOT__op_sim_immv);
		}

// #define	DEBUGGING_OUTPUT
#ifdef	DEBUGGING_OUTPUT
		bool	writeout = false;

		/*
		// Ethernet triggers
		if (m_core->o_net_tx_en)
			writeout = true;
		if (m_core->v__DOT__netctrl__DOT__n_rx_busy)
			writeout = true;
		if (m_core->v__DOT__netctrl__DOT__r_txd_en)
			writeout = true;
		if (m_core->v__DOT__netctrl__DOT__w_rxwr)
			writeout = true;
		*/

		/*
		// GPS Clock triggers
		if (m_core->v__DOT__ppsck__DOT__tick)
			writeout = true;
		if (m_core->v__DOT__gps_step != m_gps_step) {
			writeout = true;
			// printf("STEP");
		} if (m_core->v__DOT__gps_err != m_gps_err) {
			writeout = true;
			// printf("ERR");
		} if (m_core->v__DOT__ppsck__DOT__step_correction != m_gps_stepc) {
			writeout = true;
			// printf("DSTP");
		} if (m_core->v__DOT__ppsck__DOT__getnewstep__DOT__genblk2__DOT__genblk1__DOT__r_out != m_gps_newstep)
			writeout = true;
		*/

		/*
		m_gps_step = m_core->v__DOT__gps_step;
		m_gps_err  = m_core->v__DOT__gps_err;
		m_gps_stepc= m_core->v__DOT__ppsck__DOT__step_correction;
		m_gps_newstep=m_core->v__DOT__ppsck__DOT__getnewstep__DOT__genblk2__DOT__genblk1__DOT__r_out;
		*/

		if (m_core->o_oled_cs_n == 0)
			writeout = true;
		if (m_core->o_oled_sck  == 0)
			writeout = true;
		if (m_core->v__DOT__rgbctrl__DOT__dev_wr)
			writeout = true;
		if (m_core->v__DOT__rgbctrl__DOT__r_busy)
			writeout = true;
		if (m_core->v__DOT__rgbctrl__DOT__dev_busy)
			writeout = true;
		if (m_core->v__DOT__swic__DOT__thecpu__DOT__instruction_decoder__DOT__r_lock)
			writeout = true;
		if (m_core->v__DOT__swic__DOT__thecpu__DOT__genblk3__DOT__r_op_lock)
			writeout = true;
		if (m_core->v__DOT__swic__DOT__thecpu__DOT__genblk9__DOT__r_prelock_stall)
			writeout = true;

		if (m_core->v__DOT__swic__DOT__dma_controller__DOT__dma_state != 0)
			writeout = true;
		if (m_core->v__DOT__swic__DOT__thecpu__DOT__genblk9__DOT__r_bus_lock)
			writeout = true;


		/*
		// GPS Tracking triggers
		if (m_core->v__DOT__ppsck__DOT__err_tick)
			writeout = true;
		if (m_core->v__DOT__ppsck__DOT__sub_tick)
			writeout = true;
		if (m_core->v__DOT__ppsck__DOT__shift_tick)
			writeout = true;
		if (m_core->v__DOT__ppsck__DOT__fltr_tick)
			writeout = true;
		if (m_core->v__DOT__ppsck__DOT__config_tick)
			writeout = true;
		if (m_core->v__DOT__ppsck__DOT__mpy_sync)
			writeout = true;
		if (m_core->v__DOT__ppsck__DOT__mpy_sync_two)
			writeout = true;
		if (m_core->v__DOT__ppsck__DOT__delay_step_clk)
			writeout = true;
		*/

		// if (m_core->v__DOT__wbu_cyc)
			// writeout = true;
		// if (m_core->v__DOT__dwb_cyc)
			// writeout = true;

		// CPU Debugging triggers
		// Write out if the CPU is active at all
		if (m_core->v__DOT__swic__DOT__thecpu__DOT__master_ce)
			writeout = true;
		if (m_core->v__DOT__swic__DOT__thecpu__DOT__dbgv)
			writeout = true;
		if ((m_core->v__DOT__swic__DOT__dbg_cyc)&&(m_core->v__DOT__swic__DOT__dbg_stb))
			writeout = true;
		if ((m_core->v__DOT__swic__DOT__dbg_cyc)&&(m_core->v__DOT__swic__DOT__dbg_ack))
			writeout = true;
		if (m_core->v__DOT__swic__DOT__thecpu__DOT__pf_cyc)
			writeout = true;
		if (m_core->v__DOT__swic__DOT__thecpu__DOT__ipc < 0x10000000)
			writeout = false;

		writeout = true;
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

			// To get some understanding of what is on the bus,
			// and hence some context for everything else,
			// this offers a view of the bus.
			printf("(%d,%d->%d)%s(%c:%s,%s->%s)",
				m_core->v__DOT__wbu_cyc,
				m_core->v__DOT__dwb_cyc, // was zip_cyc
				m_core->v__DOT__wb_cyc,
				"", // (m_core->v__DOT__wbu_zip_delay__DOT__r_stb)?"!":" ",
				//
				m_core->v__DOT__wbu_zip_arbiter__DOT__r_a_owner?'Z':'j',
				(m_core->v__DOT__wbu_stb)?"1":" ", // WBU strobe
				(m_core->v__DOT__swic__DOT__ext_stb)?"1":" ", // zip_stb
				(m_core->v__DOT__wb_stb)?"1":" "); // m_core->v__DOT__wb_stb, output of delay(ed) strobe
				//
			printf("|%c[%08x/%08x]@%08x|%x %c%c%c",
				(m_core->v__DOT__wb_we)?'W':'R',
				m_core->v__DOT__wb_data,
					m_core->v__DOT__dwb_idata,
				m_core->v__DOT__wb_addr<<2,
				m_core->v__DOT__wb_sel,
				(m_core->v__DOT__dwb_ack)?'A':
					(m_core->v__DOT____Vcellinp__genbus____pinNumber9)?'a':' ',
				(m_core->v__DOT__dwb_stall)?'S':
					(m_core->v__DOT____Vcellinp__genbus____pinNumber10)?'s':' ',
				(m_core->v__DOT__wb_err)?'E':'.');

			// CPU Pipeline debugging
			printf("%s%s%s%s%s%s%s%s%s%s%s",
				// (m_core->v__DOT__swic__DOT__dbg_ack)?"A":"-",
				// (m_core->v__DOT__swic__DOT__dbg_stall)?"S":"-",
				// (m_core->v__DOT__swic__DOT__sys_dbg_cyc)?"D":"-",
				(m_core->v__DOT__swic__DOT__cpu_lcl_cyc)?"L":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__r_halted)?"Z":"-",
				(m_core->v__DOT__swic__DOT__cpu_break)?"!":"-",
				(m_core->v__DOT__swic__DOT__cmd_halt)?"H":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__r_gie)?"G":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__pf_cyc)?"P":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__pf_valid)?"V":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__pf_illegal)?"i":" ",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__new_pc)?"N":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__domem__DOT__r_wb_cyc_gbl)?"G":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__domem__DOT__r_wb_cyc_lcl)?"L":"-");
			printf("|%s%s%s%s%s%s",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__r_dcd_valid)?"D":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__dcd_ce)?"d":"-",
				"x", // (m_core->v__DOT__swic__DOT__thecpu__DOT__dcdA_stall)?"A":"-",
				"x", // (m_core->v__DOT__swic__DOT__thecpu__DOT__dcdB_stall)?"B":"-",
				"x", // (m_core->v__DOT__swic__DOT__thecpu__DOT__dcdF_stall)?"F":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__dcd_illegal)?"i":"-");
			
			printf("|%s%s%s%s%s%s%s%s%s%s",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__op_valid)?"O":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__op_ce)?"k":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__op_stall)?"s":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__op_illegal)?"i":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__r_op_break)?"B":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__genblk3__DOT__r_op_lock)?"L":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__r_op_pipe)?"P":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__r_break_pending)?"p":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__r_op_gie)?"G":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__op_valid_alu)?"A":"-");
			printf("|%s%s%s%d",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__genblk9__DOT__r_prelock_stall)?"P":".",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__genblk9__DOT__r_prelock_primed)?"p":".",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__genblk9__DOT__r_bus_lock)?"L":".",
				m_core->v__DOT__swic__DOT__thecpu__DOT__genblk9__DOT__r_bus_lock);
			printf("|%s%s%s%s%s",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__alu_ce)?"a":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__alu_stall)?"s":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__doalu__DOT__r_busy)?"B":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__r_alu_gie)?"G":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__r_alu_illegal)?"i":"-");
			printf("|%s%s%s%2x %s%s%s %2d %2d",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__op_valid_mem)?"M":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__mem_ce)?"m":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__adf_ce_unconditional)?"!":"-",
				(m_core->v__DOT__swic__DOT__cmd_addr),
				(m_core->v__DOT__swic__DOT__thecpu__DOT__bus_err)?"BE":"  ",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__ibus_err_flag)?"IB":"  ",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__r_ubus_err_flag)?"UB":"  ",
				m_core->v__DOT__swic__DOT__thecpu__DOT__domem__DOT__rdaddr,
				m_core->v__DOT__swic__DOT__thecpu__DOT__domem__DOT__wraddr);
			printf("|%s%s",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__div_busy)?"D":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__div_error)?"E":"-");
			printf("|%s%s[%2x]%08x",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__wr_reg_ce)?"W":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__wr_flags_ce)?"F":"-",
				m_core->v__DOT__swic__DOT__thecpu__DOT__wr_reg_id,
				m_core->v__DOT__swic__DOT__thecpu__DOT__wr_gpreg_vl);

			// Program counter debugging
			printf(" PC0x%08x/%08x/%08x-I:%08x %s0x%08x%s", 
				m_core->v__DOT__swic__DOT__thecpu__DOT__pf_pc,
				m_core->v__DOT__swic__DOT__thecpu__DOT__ipc,
				m_core->v__DOT__swic__DOT__thecpu__DOT__r_upc,
				m_core->v__DOT__swic__DOT__thecpu__DOT__pf_instruction,
				(m_core->v__DOT__swic__DOT__thecpu__DOT__instruction_decoder__DOT__genblk3__DOT__r_early_branch)?"EB":
				((m_core->v__DOT__swic__DOT__thecpu__DOT__instruction_decoder__DOT__genblk3__DOT__r_ljmp)?"JM":"  "),
				m_core->v__DOT__swic__DOT__thecpu__DOT__instruction_decoder__DOT__genblk3__DOT__r_branch_pc<<2,
				(m_core->v__DOT__swic__DOT__thecpu__DOT__r_clear_icache)?"-CLRC":"     "
				);
			// More in-depth
			printf(" [%c%08x,%c%08x,%c%08x]",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__r_dcd_valid)?'D':'-',
				m_core->v__DOT__swic__DOT__thecpu__DOT__dcd_pc<<2,
				(m_core->v__DOT__swic__DOT__thecpu__DOT__op_valid)?'O':'-',
				m_core->v__DOT__swic__DOT__thecpu__DOT__op_pc<<2,
				(m_core->v__DOT__swic__DOT__thecpu__DOT__alu_valid)?'A':'-',
				m_core->v__DOT__swic__DOT__thecpu__DOT__r_alu_pc<<2);
			
			// Prefetch debugging
			printf(" [PC%08x,LST%08x]->[%d%s%s](%d,%08x/%08x)->%08x@%08x",
				m_core->v__DOT__swic__DOT__thecpu__DOT__pf_pc<<2,
				m_core->v__DOT__swic__DOT__thecpu__DOT__pf__DOT__lastpc<<2,
				m_core->v__DOT__swic__DOT__thecpu__DOT__pf__DOT__rvsrc,
				(m_core->v__DOT__swic__DOT__thecpu__DOT__pf__DOT__rvsrc)
				?((m_core->v__DOT__swic__DOT__thecpu__DOT__pf__DOT__r_v_from_pc)?"P":" ")
				:((m_core->v__DOT__swic__DOT__thecpu__DOT__pf__DOT__r_v_from_pc)?"p":" "),
				(!m_core->v__DOT__swic__DOT__thecpu__DOT__pf__DOT__rvsrc)
				?((m_core->v__DOT__swic__DOT__thecpu__DOT__pf__DOT__r_v_from_last)?"l":" ")
				:((m_core->v__DOT__swic__DOT__thecpu__DOT__pf__DOT__r_v_from_last)?"L":" "),
				m_core->v__DOT__swic__DOT__thecpu__DOT__pf__DOT__isrc,
				m_core->v__DOT__swic__DOT__thecpu__DOT__pf__DOT__r_pc_cache,
				m_core->v__DOT__swic__DOT__thecpu__DOT__pf__DOT__r_last_cache,
				m_core->v__DOT__swic__DOT__thecpu__DOT__pf_instruction,
				m_core->v__DOT__swic__DOT__thecpu__DOT__pf_instruction_pc<<2);

			// Decode Stage debugging
			// (nothing)

			// Op Stage debugging
			printf(" (Op %02x,%02x)(%08x,%08x->%02x)",
				m_core->v__DOT__swic__DOT__thecpu__DOT__dcd_opn,
				m_core->v__DOT__swic__DOT__thecpu__DOT__r_op_opn,
				m_core->v__DOT__swic__DOT__thecpu__DOT__op_Av,
				m_core->v__DOT__swic__DOT__thecpu__DOT__op_Bv,
				m_core->v__DOT__swic__DOT__thecpu__DOT__r_op_R);

			printf(" %s[",
				m_core->v__DOT__swic__DOT__thecpu__DOT__wr_reg_ce?"WR":"--");
			{	int	reg;
				const static char	*rnames[] = {
						"sR0", "sR1", "sR2", "sR3",
						"sR4", "sR5", "sR6", "sR7",
						"sR8", "sR9", "sRa", "sRb",
						"sRc", "sSP", "sCC", "sPC",
						"uR0", "uR1", "uR2", "uR3",
						"uR4", "uR5", "uR6", "uR7",
						"uR8", "uR9", "uRa", "uRb",
						"uRc", "uSP", "uCC", "uPC"
				};
				reg = m_core->v__DOT__swic__DOT__thecpu__DOT__wr_reg_id & 0x01f;
				printf("%s", rnames[reg]);
			}
			printf("]=%08x(%08x)",
				m_core->v__DOT__swic__DOT__thecpu__DOT__wr_gpreg_vl,
				m_core->v__DOT__swic__DOT__thecpu__DOT__wr_spreg_vl
				);

			printf(" %s[%s%s%s%s]",
				m_core->v__DOT__swic__DOT__thecpu__DOT__wr_reg_ce?"F":"-",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__alu_flags&1)?"Z":".",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__alu_flags&2)?"C":".",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__alu_flags&4)?"N":".",
				(m_core->v__DOT__swic__DOT__thecpu__DOT__alu_flags&8)?"V":".");

			printf(" DBG%s%s%s[%s/%02x]=%08x/%08x",
				(m_core->v__DOT__swic__DOT__dbg_cyc)?"CYC":"   ",
				(m_core->v__DOT__swic__DOT__dbg_stb)?"STB":((m_core->v__DOT__swic__DOT__dbg_ack)?"ACK":"   "),
				((m_core->v__DOT__swic__DOT__dbg_cyc)&&(m_core->v__DOT__swic__DOT__dbg_stb))?((m_core->v__DOT__swic__DOT__dbg_we)?"-W":"-R"):"  ",
				(!m_core->v__DOT__swic__DOT__dbg_cyc) ? " ":
					((m_core->v__DOT__swic__DOT__dbg_addr)?"D":"C"),
				(m_core->v__DOT__swic__DOT__cmd_addr),
				(m_core->v__DOT__swic__DOT__dbg_idata),
				m_core->v__DOT__zip_dbg_data);

			printf(" %s,0x%08x", (m_core->i_ram_ack)?"RCK":"   ",
				m_core->i_ram_rdata);


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

			/*
			// Network debugging
			printf("ETH[TX:%s%s%x%s]",
				(m_core->i_net_tx_clk)?"CK":"  ",
				(m_core->o_net_tx_en)?" ":"(",
				m_core->o_net_txd,
				(m_core->o_net_tx_en)?" ":")");
			printf("/%s(%04x,%08x[%08x])",
				(m_core->v__DOT__netctrl__DOT__n_tx_busy)?"BSY":"   ",
				m_core->v__DOT__netctrl__DOT__n_tx_addr,
				m_core->v__DOT__netctrl__DOT__n_next_tx_data,
				m_core->v__DOT__netctrl__DOT__n_tx_data);
			printf("[RX:%s%s%s%s%x%s]",
				(m_core->i_net_rx_clk)?"CK":"  ",
				(m_core->i_net_crs)?"CR":"  ",
				(m_core->i_net_rxerr)?"ER":"  ",
				(m_core->i_net_dv)?" ":"(",
				m_core->i_net_rxd,
				(m_core->i_net_dv)?" ":")");
			printf("%s%s%s",
				(m_core->v__DOT__netctrl__DOT__n_rx_valid)?"V":" ",
				(m_core->v__DOT__netctrl__DOT__n_rx_clear)?"C":" ",
				(m_core->v__DOT__netctrl__DOT__n_rx_net_err)?"E":" ");
			printf("/%s(%04x,%s%08x)",
				(m_core->v__DOT__netctrl__DOT__n_rx_busy)?"BSY":"   ",
				m_core->v__DOT__netctrl__DOT__w_rxaddr,
				(m_core->v__DOT__netctrl__DOT__w_rxwr)?"W":" ",
				m_core->v__DOT__netctrl__DOT__w_rxdata);

			printf(" TXMAC %x%s -> %2x -> %x%s",
				m_core->v__DOT__netctrl__DOT__r_txd,
				(m_core->v__DOT__netctrl__DOT__r_txd_en)?"!":" ",
				(m_core->v__DOT__netctrl__DOT__txmaci__DOT__r_pos),
				m_core->v__DOT__netctrl__DOT__w_macd,
				(m_core->v__DOT__netctrl__DOT__w_macen)?"!":" ");
			printf(" TXCRC %x%s ->%2x/0x%08x-> %x%s",
				m_core->v__DOT__netctrl__DOT__w_padd,
				(m_core->v__DOT__netctrl__DOT__w_paden)?"!":" ",
				m_core->v__DOT__netctrl__DOT__txcrci__DOT__r_p,
				m_core->v__DOT__netctrl__DOT__txcrci__DOT__r_crc,
				m_core->v__DOT__netctrl__DOT__w_txcrcd,
				(m_core->v__DOT__netctrl__DOT__w_txcrcen)?"!":" ");

			printf(" RXCRC %x%s -> 0x%08x/%2x/%2x/%s -> %x%s",
				m_core->v__DOT__netctrl__DOT__w_npred,
				(m_core->v__DOT__netctrl__DOT__w_npre)?"!":" ",
				m_core->v__DOT__netctrl__DOT__rxcrci__DOT__r_crc,
				(m_core->v__DOT__netctrl__DOT__rxcrci__DOT__r_mq),
				(m_core->v__DOT__netctrl__DOT__rxcrci__DOT__r_mp),
				(m_core->v__DOT__netctrl__DOT__rxcrci__DOT__r_err)?"E":" ",
				m_core->v__DOT__netctrl__DOT__w_rxcrcd,
				(m_core->v__DOT__netctrl__DOT__w_rxcrc)?"!":" ");

			printf(" RXIP %x%s ->%4x%s->%4x/%2d/%2d/%s",
				m_core->v__DOT__netctrl__DOT__w_rxcrcd,
				(m_core->v__DOT__netctrl__DOT__w_rxcrc)?"!":" ",
				(m_core->v__DOT__netctrl__DOT__rxipci__DOT__r_word)&0x0ffff,
				(m_core->v__DOT__netctrl__DOT__rxipci__DOT__r_v)?"!":" ",
				(m_core->v__DOT__netctrl__DOT__rxipci__DOT__r_check)&0x0ffff,
				(m_core->v__DOT__netctrl__DOT__rxipci__DOT__r_idx),
				(m_core->v__DOT__netctrl__DOT__rxipci__DOT__r_hlen),
				(m_core->v__DOT__netctrl__DOT__w_iperr)?"E"
				:(m_core->v__DOT__netctrl__DOT__rxipci__DOT__r_ip)?" ":"z");
			printf(" RXMAC %x%s ->%2x-> %x%s",
				m_core->v__DOT__netctrl__DOT__w_rxcrcd,
				(m_core->v__DOT__netctrl__DOT__w_rxcrc)?"!":" ",
				(m_core->v__DOT__netctrl__DOT__rxmaci__DOT__r_p)&0x0ff,
				m_core->v__DOT__netctrl__DOT__w_rxmacd,
				(m_core->v__DOT__netctrl__DOT__w_rxmac)?"!":" ");
			*/

			/*
			// Flash debugging support
			printf("%s/%s %s %s[%s%s%s%s%s] %s@%08x[%08x/%08x] -- SPI %s%s[%x/%x](%d,%d)",
				((m_core->v__DOT__wb_stb)&&((m_core->v__DOT__skipaddr>>3)==1))?"D":" ",
				((m_core->v__DOT__wb_stb)&&(m_core->v__DOT__flctl_sel))?"C":" ",
				(m_core->v__DOT__flashmem__DOT__bus_wb_stall)?"STALL":"     ",
				(m_core->v__DOT__flash_ack)?"ACK":"   ",
				(m_core->v__DOT__flashmem__DOT__bus_wb_ack)?"BS":"  ",
				(m_core->v__DOT__flashmem__DOT__rd_data_ack)?"RD":"  ",
				(m_core->v__DOT__flashmem__DOT__ew_data_ack)?"EW":"  ",
				(m_core->v__DOT__flashmem__DOT__id_data_ack)?"ID":"  ",
				(m_core->v__DOT__flashmem__DOT__ct_data_ack)?"CT":"  ",
				(m_core->v__DOT__wb_we)?"W":"R",
				(m_core->v__DOT__wb_addr),
				(m_core->v__DOT__wb_data),
				(m_core->v__DOT__flash_data),
				(m_core->o_qspi_cs_n)?"CS":"  ",
				(m_core->o_qspi_sck)?"CK":"  ",
				(m_core->o_qspi_dat),
				(m_core->i_qspi_dat),
				(m_core->o_qspi_dat)&1,
				((m_core->i_qspi_dat)&2)?1:0),

			printf(" REQ[%s%s%s%s]",
				m_core->v__DOT__flashmem__DOT__rd_qspi_req?"RD":"  ",
				m_core->v__DOT__flashmem__DOT__ew_qspi_req?"EW":"  ",
				m_core->v__DOT__flashmem__DOT__id_qspi_req?"ID":"  ",
				m_core->v__DOT__flashmem__DOT__ct_qspi_req?"CT":"  ");

			printf(" %s[%s%2d%s%s0x%08x]",
				(m_core->v__DOT__flashmem__DOT__spi_wr)?"CMD":"   ",
				(m_core->v__DOT__flashmem__DOT__spi_hold)?"HLD":"   ",
				(m_core->v__DOT__flashmem__DOT__spi_len+1)*8,
				(m_core->v__DOT__flashmem__DOT__spi_dir)?"RD":"WR",
				(m_core->v__DOT__flashmem__DOT__spi_spd)?"Q":" ",
				m_core->v__DOT__flashmem__DOT__spi_word);

			printf(" STATE[%2x%s,%2x%s,%2x%s,%2x%s]",
				m_core->v__DOT__flashmem__DOT__rdproc__DOT__rd_state, (m_core->v__DOT__flashmem__DOT__rd_spi_wr)?"W":" ",
				m_core->v__DOT__flashmem__DOT__ewproc__DOT__wr_state, (m_core->v__DOT__flashmem__DOT__ew_spi_wr)?"W":" ",
				m_core->v__DOT__flashmem__DOT__idotp__DOT__id_state, (m_core->v__DOT__flashmem__DOT__id_spi_wr)?"W":" ",
				m_core->v__DOT__flashmem__DOT__ctproc__DOT__ctstate, (m_core->v__DOT__flashmem__DOT__ct_spi_wr)?"W":" ");
			printf("%s%s%s%s",
				(m_core->v__DOT__flashmem__DOT__rdproc__DOT__accepted)?"RD-ACC":"",
				(m_core->v__DOT__flashmem__DOT__ewproc__DOT__accepted)?"EW-ACC":"",
				(m_core->v__DOT__flashmem__DOT__idotp__DOT__accepted)?"ID-ACC":"",
				(m_core->v__DOT__flashmem__DOT__ctproc__DOT__accepted)?"CT-ACC":"");

			printf("%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s",
				(m_core->v__DOT__flashmem__DOT__preproc__DOT__pending)?" PENDING":"",
				(m_core->v__DOT__flashmem__DOT__preproc__DOT__lcl_key)?" KEY":"",
				(m_core->v__DOT__flashmem__DOT__preproc__DOT__ctreg_stb)?" CTSTB":"",
				(m_core->v__DOT__flashmem__DOT__bus_ctreq)?" BUSCTRL":"",
				(m_core->v__DOT__flashmem__DOT__bus_other_req)?" BUSOTHER":"",
				(m_core->v__DOT__flashmem__DOT__preproc__DOT__wp)?" WRWP":"",
				(m_core->v__DOT__flashmem__DOT__bus_wip)?" WIP":"",
				(m_core->v__DOT__flashmem__DOT__ewproc__DOT__cyc)?" WRCYC":"",
				(m_core->v__DOT__flashmem__DOT__bus_pipewr)?" WRPIPE":"",
				(m_core->v__DOT__flashmem__DOT__bus_endwr)?" ENDWR":"",
				(m_core->v__DOT__flashmem__DOT__ct_ack)?" CTACK":"",
				(m_core->v__DOT__flashmem__DOT__rd_bus_ack)?" RDACK":"",
				(m_core->v__DOT__flashmem__DOT__id_bus_ack)?" IDACK":"",
				(m_core->v__DOT__flashmem__DOT__ew_bus_ack)?" EWACK":"",
				(m_core->v__DOT__flashmem__DOT__preproc__DOT__lcl_ack)?" LCLACK":"",
				(m_core->v__DOT__flashmem__DOT__rdproc__DOT__r_leave_xip)?" LVXIP":"",
				(m_core->v__DOT__flashmem__DOT__preproc__DOT__new_req)?" NREQ":"");
			*/


			/*
			// Debugging the GPS tracking circuit
			printf("COUNT %016lx STEP %016lx+%08x->%016lx ERR %016lx %s",
				m_core->v__DOT__gps_now,
				m_core->v__DOT__gps_step,
				m_core->v__DOT__ppsck__DOT__step_correction,
				m_core->v__DOT__ppsck__DOT__getnewstep__DOT__genblk2__DOT__genblk1__DOT__r_out,
				m_core->v__DOT__gps_err,
				(m_core->v__DOT__ppsck__DOT__tick)?"TICK":"    ");
			*/


			/*
			// Debug the OLED

			{ const char *pwr; int pwrk;
			if (m_core->o_oled_pmoden) {
				if (!m_core->o_oled_reset_n)
					pwr = "RST";
				else if (m_core->o_oled_vccen)
					pwr = "ON ";
				else
					pwr = "VIO";
			} else if (m_core->o_oled_vccen)
				pwr = "ERR";
			else
				pwr = "OFF";
			pwrk = (m_core->o_oled_reset_n)?4:0;
			pwrk|= (m_core->o_oled_vccen)?2:0;
			pwrk|= (m_core->o_oled_pmoden);
			// First the top-level ports
			printf(" OLED[%s/%d,%s%s%s-%d]",
				pwr, pwrk,
				(!m_core->o_oled_cs_n)?"CS":"  ",
				(m_core->o_oled_sck)?"CK":"  ",
				(m_core->o_oled_dcn)?"/D":"/C",
				(m_core->o_oled_mosi));
			}
			// Now the low-level internals
			printf("LL[");
			switch(m_core->v__DOT__rgbctrl__DOT__lwlvl__DOT__state){
			case 0: printf("I,"); break;
			case 1: printf("S,"); break;
			case 2: printf("B,"); break;
			case 3: printf("R,"); break;
			case 4: printf("!,"); break;
			case 5: printf(".,"); break;
			default: printf("U%d",
				m_core->v__DOT__rgbctrl__DOT__lwlvl__DOT__state);
			}
			printf("%2d,%s%2d,%08x]",
				m_core->v__DOT__rgbctrl__DOT__lwlvl__DOT__spi_len,
				(m_core->v__DOT__rgbctrl__DOT__lwlvl__DOT__pre_last_counter)?"P":" ",

				m_core->v__DOT__rgbctrl__DOT__lwlvl__DOT__counter,
				m_core->v__DOT__rgbctrl__DOT__lwlvl__DOT__r_word);
			printf("[%s%s%s/%2d/%d]",
				(m_core->v__DOT__rgbctrl__DOT__dev_wr)?"W":" ",
				(m_core->v__DOT__rgbctrl__DOT__r_busy)?"BSY":"   ",
				(m_core->v__DOT__rgbctrl__DOT__dev_busy)?"D-BSY":"     ",
				m_core->v__DOT__rgbctrl__DOT__r_len,
				m_core->v__DOT__rgbctrl__DOT__dev_len);
			printf((m_core->v__DOT__oled_int)?"I":" "); // And the interrupt
			*/

			/*
			// Debug the DMA
			printf(" DMAC[%d]: %08x/%08x/%08x(%03x)%d%d%d%d -- (%d,%d,%c)%c%c:@%08x-[%4d,%4d/%4d,%4d-#%4d]%08x",
				m_core->v__DOT__swic__DOT__dma_controller__DOT__dma_state,
				m_core->v__DOT__swic__DOT__dma_controller__DOT__cfg_waddr,
				m_core->v__DOT__swic__DOT__dma_controller__DOT__cfg_raddr,
				m_core->v__DOT__swic__DOT__dma_controller__DOT__cfg_len,
				m_core->v__DOT__swic__DOT__dma_controller__DOT__cfg_blocklen_sub_one,
				m_core->v__DOT__swic__DOT__dma_controller__DOT__last_read_request,
				m_core->v__DOT__swic__DOT__dma_controller__DOT__last_read_ack,
				m_core->v__DOT__swic__DOT__dma_controller__DOT__last_write_request,
				m_core->v__DOT__swic__DOT__dma_controller__DOT__last_write_ack,
				m_core->v__DOT__swic__DOT__dc_cyc,
				// m_core->v__DOT__swic__DOT__dc_stb,
				(m_core->v__DOT__swic__DOT__dma_controller__DOT__dma_state == 2)?1:0,

				((m_core->v__DOT__swic__DOT__dma_controller__DOT__dma_state == 4)
				||(m_core->v__DOT__swic__DOT__dma_controller__DOT__dma_state == 5)
				||(m_core->v__DOT__swic__DOT__dma_controller__DOT__dma_state == 6))?'W':'R',
				//(m_core->v__DOT__swic__DOT__dc_we)?'W':'R',
				(m_core->v__DOT__swic__DOT__dc_ack)?'A':' ',
				(m_core->v__DOT__swic__DOT__dc_stall)?'S':' ',
				m_core->v__DOT__swic__DOT__dc_addr,
				m_core->v__DOT__swic__DOT__dma_controller__DOT__rdaddr,
				m_core->v__DOT__swic__DOT__dma_controller__DOT__nread,
				m_core->v__DOT__swic__DOT__dma_controller__DOT__nracks,
				m_core->v__DOT__swic__DOT__dma_controller__DOT__nwacks,
				m_core->v__DOT__swic__DOT__dma_controller__DOT__nwritten,
				m_core->v__DOT__swic__DOT__dc_data);
			printf((m_core->v__DOT__swic__DOT__dma_controller__DOT__trigger)?"T":" ");
			printf((m_core->v__DOT__swic__DOT__dma_controller__DOT__cfg_incs)?"+":".");
			printf((m_core->v__DOT__swic__DOT__dma_controller__DOT__cfg_incd)?"+":".");
			printf("%s[%2x]",
				(m_core->v__DOT__swic__DOT__dma_controller__DOT__cfg_on_dev_trigger)?"!":" ",
				(m_core->v__DOT__swic__DOT__dma_controller__DOT__cfg_dev_trigger));
			*/

			printf(" INT:0x%08x/0x%08x",
				m_core->v__DOT__swic__DOT__main_int_vector,
				m_core->v__DOT__swic__DOT__alt_int_vector);

			printf("\n"); fflush(stdout);
		} m_last_writeout = writeout;
#endif

/*
		if (m_core->v__DOT__swic__DOT__cpu_break) {
			m_bomb++;
		} else if (m_bomb) {
			if (m_bomb++ > 12)
				m_done = true;
			fprintf(stderr, "BREAK-BREAK-BREAK (m_bomb = %d)%s\n",
				m_bomb, (m_done)?" -- DONE!":"");
		}
*/
	}

	bool	done(void) {
		if (!m_trace)
			return m_done;
		else
			return (m_done)||(m_traceticks > 6000000);
	}
};

TESTBENCH	*tb;

void	busmaster_kill(int v) {
	tb->close();
	fprintf(stderr, "KILLED!!\n");
	exit(EXIT_SUCCESS);
}

void	usage(void) {
	puts("USAGE: busmaster_tb [-cdpsth] <ZipElfProgram> <SDCardBackFile>\n"
"\n"
"	-c	Copies all FPGA control/command communications to the\n"
"		  standard output\n"
"	-d	Sets the debug flag.  This turns on the trace feature, dumping\n"
"		  the trace to trace.vcd by default.  This can be overridden by\n"
"		  the -t option\n"
"	-h	Prints this usage statement\n"
"	-p #	Sets the TCP/IP port number for the command port\n"
"	-s #	Sets the TCP/IP port number for the simulated serial port\n"
"	-t <fname>	Creates a VCD trace file with the name <fname>\n");
}

int	main(int argc, char **argv) {
	const	char *elfload = NULL, *sdload = "/dev/zero",
			*trace_file = NULL; // "trace.vcd";
	bool	debug_flag = false, willexit = false;
	int	fpga_port = FPGAPORT, serial_port = -(FPGAPORT+1);
	int	copy_comms_to_stdout = -1;
#ifdef	OLEDSIM_H
	Gtk::Main	main_instance(argc, argv);
#endif
	Verilated::commandArgs(argc, argv);

	for(int argn=1; argn < argc; argn++) {
		if (argv[argn][0] == '-') for(int j=1;
					(j<512)&&(argv[argn][j]);j++) {
			switch(tolower(argv[argn][j])) {
			case 'c': copy_comms_to_stdout = 1; break;
			case 'd': debug_flag = true;
				if (trace_file == NULL)
					trace_file = "trace.vcd";
				break;
			case 'p': fpga_port = atoi(argv[++argn]); j=1000; break;
			case 's': serial_port=atoi(argv[++argn]); j=1000; break;
			case 't': trace_file = argv[++argn]; j=1000; break;
			case 'h': usage(); break;
			default:
				fprintf(stderr, "ERR: Unexpected flag, -%c\n\n",
					argv[argn][j]);
				usage();
				break;
			}
		} else if (iself(argv[argn])) {
			elfload = argv[argn];
		} else if (0 == access(argv[argn], R_OK)) {
			sdload = argv[argn];
		} else {
			fprintf(stderr, "ERR: Cannot read %s\n", argv[argn]);
			perror("O/S Err:");
			exit(EXIT_FAILURE);
		}
	}

	if (elfload) {
		if (serial_port < 0)
			serial_port = 0;
		if (copy_comms_to_stdout < 0)
			copy_comms_to_stdout = 0;
		tb = new TESTBENCH(fpga_port, serial_port,
			(copy_comms_to_stdout)?true:false, debug_flag);
		willexit = true;
	} else {
		if (serial_port < 0)
			serial_port = -serial_port;
		if (copy_comms_to_stdout < 0)
			copy_comms_to_stdout = 1;
		tb = new TESTBENCH(fpga_port, serial_port,
			(copy_comms_to_stdout)?true:false, debug_flag);
	}

	if (debug_flag) {
		printf("Opening Bus-master with\n");
		printf("\tDebug Access port = %d\n", fpga_port);
		printf("\tSerial Console    = %d%s\n", serial_port,
			(serial_port == 0) ? " (Standard output)" : "");
		printf("\tDebug comms will%s be copied to the standard output%s.",
			(copy_comms_to_stdout)?"":" not",
			((copy_comms_to_stdout)&&(serial_port == 0))
			? " as well":"");
		printf("\tVCD File         = %s\n", trace_file);
	} if (trace_file)
		tb->trace(trace_file);
	signal(SIGINT,  busmaster_kill);

	tb->reset();
	tb->setsdcard(sdload);

	if (elfload) {
		uint32_t	entry;
		ELFSECTION	**secpp = NULL, *secp;
		elfread(elfload, entry, secpp);

		if (secpp) for(int i=0; secpp[i]->m_len; i++) {
			secp = secpp[i];
			tb->load(secp->m_start, secp->m_data, secp->m_len);
		}

		tb->m_core->v__DOT__swic__DOT__thecpu__DOT__ipc = entry;
		tb->tick();
		tb->m_core->v__DOT__swic__DOT__thecpu__DOT__ipc = entry;
		tb->m_core->v__DOT__swic__DOT__cmd_halt = 0;
		tb->tick();
	}

#ifdef	OLEDSIM_H
	Gtk::Main::run(tb->m_oled);
#else
	if (willexit) {
		while(!tb->done())
			tb->tick();
	} else
		while(!tb->done())
			tb->tick();

#endif

	exit(0);
}

