////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	ddrsdramsim.h
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
#ifndef	DDRSDRAMSIM_H
#define	DDRSDRAMSIM_H

#define	DDR_MRSET	0
#define	DDR_REFRESH	1
#define	DDR_PRECHARGE	2
#define	DDR_ACTIVATE	3
#define	DDR_WRITE	4
#define	DDR_READ	5
#define	DDR_ZQS		6
#define	DDR_NOOP	7

#define	NBANKS		8
#define	NTIMESLOTS	32

class	BANKINFO {
public:
	int		m_state;
	unsigned	m_row, m_wcounter;
	void	tick(int cmd, unsigned addr=0);
};

class	BUSTIMESLOT	{
public:
	int	m_used, m_read, m_data, m_rtt;
	unsigned	m_addr;
};

class	DDRSDRAMSIM	{
	int		m_reset_state, m_reset_counts, m_memlen, m_busloc,
			m_clocks_since_refresh, m_nrefresh_issued,
			m_last_dqs, m_last_rtt;
	unsigned	*m_mem;
	BANKINFO	m_bank[8];
	BUSTIMESLOT	*m_bus;
	int	cmd(int,int,int,int);
public:
	DDRSDRAMSIM(int lglen);
	unsigned operator()(int, int,
			int, int, int, int,
			int, int, int, int,
			int, int, int);
	unsigned &operator[](unsigned addr) { return m_mem[addr]; };
};

#endif
