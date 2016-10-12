////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	eqspiflashsim.h
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This library simulates the operation of an Extended Quad-SPI
//		commanded flash, such as the N25Q128A used on the Arty
//		development board by Digilent.  As such, it is defined by
//		16 MBytes of memory (4 MWords).
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
#ifndef	EQSPIFLASHSIM_H
#define	EQSPIFLASHSIM_H

#define	EQSPIF_WIP_FLAG			0x0001
#define	EQSPIF_WEL_FLAG			0x0002
#define	EQSPIF_DEEP_POWER_DOWN_FLAG	0x0200
class	EQSPIFLASHSIM {
	typedef	enum {
		EQSPIF_IDLE,
		EQSPIF_XIP,
		EQSPIF_RDSR,
		EQSPIF_RDCR,
		EQSPIF_RDNVCONFIG,
		EQSPIF_RDEVCONFIG,
		EQSPIF_WRSR,
		EQSPIF_WRCR,
		EQSPIF_WRNVCONFIG,
		EQSPIF_WREVCONFIG,
		EQSPIF_RDFLAGS,
		EQSPIF_CLRFLAGS,
		EQSPIF_RDLOCK,
		EQSPIF_WRLOCK,
		EQSPIF_RDID,
		EQSPIF_RELEASE,
		EQSPIF_FAST_READ,
		EQSPIF_QUAD_READ_CMD,
		EQSPIF_QUAD_READ,
		EQSPIF_PP,
		EQSPIF_QPP,
	// Erase states
		EQSPIF_SUBSECTOR_ERASE,
		EQSPIF_SECTOR_ERASE,
		EQSPIF_BULK_ERASE,
	// OTP memory
		EQSPIF_PROGRAM_OTP,
		EQSPIF_READ_OTP,
	//
		EQSPIF_INVALID
	} EQSPIF_STATE;

	EQSPIF_STATE	m_state;
	char		*m_mem, *m_pmem, *m_otp, *m_lockregs;
	int		m_last_sck;
	unsigned	m_write_count, m_ireg, m_oreg, m_sreg, m_addr,
			m_count, m_vconfig, m_mode_byte, m_creg,
			m_nvconfig, m_evconfig, m_flagreg, m_nxtout[4];
	bool		m_quad_mode, m_debug, m_otp_wp;

public:
	EQSPIFLASHSIM(void);
	void	load(const char *fname) { load(0, fname); }
	void	load(const unsigned addr, const char *fname);
	void	debug(const bool dbg) { m_debug = dbg; }
	bool	debug(void) const { return m_debug; }
	bool	write_enabled(void) const { return m_debug; }
	unsigned counts_till_idle(void) const {
		return m_write_count; }
	unsigned operator[](const int index) {
		unsigned char	*cptr = (unsigned char *)&m_mem[index<<2];
		unsigned	v;
		v = (*cptr++);
		v = (v<<8)|(*cptr++);
		v = (v<<8)|(*cptr++);
		v = (v<<8)|(*cptr);

		return v; }
	void set(const unsigned addr, const unsigned val) {
		unsigned char	*cptr = (unsigned char *)&m_mem[addr<<2];
		*cptr++ = (val>>24);
		*cptr++ = (val>>16);
		*cptr++ = (val>> 8);
		*cptr   = (val);
		return;}
	int	operator()(const int csn, const int sck, const int dat);
};

#endif
