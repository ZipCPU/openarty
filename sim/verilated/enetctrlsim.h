////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	enetsim.h
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2016-2020, Gisselquist Technology, LLC
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
#ifndef	ENETCTRLSIM_H
#define	ENETCTRLSIM_H

#define	ENET_MEMWORDS	32
class	ENETCTRLSIM	{
	int	m_consecutive_clocks, m_lastout,
		m_tickcount, m_ticks_per_clock, m_lastclk;
	int	TICKS_PER_CLOCK, PHY_ADDR;
	int	m_mem[ENET_MEMWORDS];

public:
	bool	m_synched;
	int	m_datareg, m_halfword, m_outreg;
	ENETCTRLSIM(void);
	~ENETCTRLSIM(void) {}

	int	operator()(int inreset, int clk, int data);
	int	operator[](int index) const;
};

#endif	// ENETCTRLSIM_H

