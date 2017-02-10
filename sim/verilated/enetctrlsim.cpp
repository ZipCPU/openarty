////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	enetctrlsim.cpp
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
#include <assert.h>
#include "enetctrlsim.h"

ENETCTRLSIM::ENETCTRLSIM(void) {
	m_consecutive_clocks = 0;
	m_synched = false;
	m_lastclk = 0;
	m_lastout = 0;
	m_tickcount = 0;
	m_ticks_per_clock = 0;
	m_halfword = 0;
	m_datareg = -1;
	PHY_ADDR = 1;
	TICKS_PER_CLOCK = 4;
	for(int i=0; i<ENET_MEMWORDS; i++)
		m_mem[i] = 0;
	m_outreg = -1;
}

int	ENETCTRLSIM::operator()(int in_reset, int clk, int data) {
	int	posedge, negedge, output = 1;

	posedge = ((clk)&&(!m_lastclk));
	negedge = ((!clk)&&(m_lastclk));

	m_tickcount++;

	if (in_reset) {
		m_consecutive_clocks = 0;
		m_synched = false;
		m_lastout = 1;
		m_datareg = -1;

		m_lastclk = clk;

		return 1;
	}

	if (posedge) {
		if ((data)&&(m_consecutive_clocks < 128))
			m_consecutive_clocks++;
		else if (!data)
			m_consecutive_clocks = 0;
		if ((m_tickcount != m_ticks_per_clock)
			||(m_ticks_per_clock < TICKS_PER_CLOCK)) {
			m_consecutive_clocks = 0;
			m_synched = false;
		} m_ticks_per_clock = m_tickcount;
		m_tickcount = 0;
	}
	if (m_consecutive_clocks > 32) {
		if (!m_synched)
			printf("ENETCTRL: SYNCH!\n");
		m_synched = true;
		m_lastout = 1;
		m_halfword = 0;
		m_datareg = -1;
	}

	if ((posedge)&&(m_synched)) {
		m_datareg = (m_datareg<<1)|(data&1);
		if ((!m_halfword)&&((m_datareg&0x8000)==0)) {
			printf("ENETCTRL::HALF-CMD: %08x\n", m_datareg);
			m_halfword = 1;
			int cmd = (m_datareg>>12)&0x0f;
			int phy = (m_datareg>>7)&0x01f;
			if ((cmd != 6)&&(cmd != 5))
				printf("ENETCTRL: Unknown command, %d, expecting either 5 or 6\n", cmd);
			if (phy != PHY_ADDR)
				printf("ENETCTRL: Unknown PHY, %d, expecting %d\n", phy, PHY_ADDR);
			if ((cmd == 6)&&(phy==PHY_ADDR)) {
				int addr = (m_datareg>>2)&0x01f;
				m_outreg = ((m_mem[addr]&0x0ffff)<<15)|0x080007fff;
				printf("ENETCTRL: Sending %04x = MEM[%01x]\n",
					m_mem[addr]&0x0ffff, addr);
			}
		} else if ((m_halfword)&&(m_halfword < 16)) {
			m_halfword++;
		} else if (m_halfword) {
			printf("ENETCTRL::FULL-CMD: %08x\n", m_datareg);
			m_halfword = 0;
			int cmd = (m_datareg>>28)&0x0f;
			int phy = (m_datareg>>23)&0x01f;
			if ((cmd != 6)&&(cmd != 5))
				printf("ENETCTRL: Unknown command, %d, expecting either 5 or 6\n", cmd);
			if (phy != PHY_ADDR)
				printf("ENETCTRL: Unknown PHY, %d, expecting %d\n", phy, PHY_ADDR);
			if ((cmd==5)&&(phy==PHY_ADDR)) {
				int	addr;

				if (m_datareg & 0x010000)
					printf("ERR: ENETCTRL, write command and bit 16 is active!\n");
				assert((m_datareg & 0x010000)==0);
				addr = (m_datareg>>18)&0x1f;
				m_mem[addr] = m_datareg & 0x0ffff;
				printf("ENETCTRL: Setting MEM[%01x] = %04x\n",
					addr, m_datareg&0x0ffff);
			}
			m_datareg = -1;
		}
	} else if (negedge) {
		m_outreg = (m_outreg<<1)|1;
	} output = (m_outreg&0x40000000)?1:0;


	m_lastclk = clk;
	return (data)&(output)&1;
}

int	ENETCTRLSIM::operator[](int index) const {
	return m_mem[index & (ENET_MEMWORDS-1)] & 0x0ffff;
}
