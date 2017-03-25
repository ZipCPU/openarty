////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	flashdrvr.h
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Flash driver.  Encapsulates writing, both erasing sectors and
//		the programming pages, to the flash device.
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
//
#ifndef	FLASHDRVR_H
#define	FLASHDRVR_H

#include "regdefs.h"

class	FLASHDRVR {
private:
	DEVBUS	*m_fpga;
	bool	m_debug;

	bool	verify_config(void);
	void	set_config(void);
	void	flwait(void);
public:
	FLASHDRVR(DEVBUS *fpga) : m_fpga(fpga), m_debug(false) {}
	bool	erase_sector(const unsigned sector, const bool verify_erase=true);
	bool	page_program(const unsigned addr, const unsigned len,
			const char *data, const bool verify_write=true);
	bool	write(const unsigned addr, const unsigned len,
			const char *data, const bool verify=false);
};

#endif
