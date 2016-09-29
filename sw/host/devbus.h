////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	devbus.h
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	The purpose of this file is to document an interface which
//		any devic with a bus, whether it be implemented over a UART,
//	an ethernet, or a PCI express bus, must implement.  This describes only
//	an interface, and not how that interface is to be accomplished.
//
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
#ifndef	DEVBUS_H
#define	DEVBUS_H

#include <stdio.h>
#include <unistd.h>

typedef	unsigned int	uint32;

class	BUSERR {
public:
	uint32 addr;
	BUSERR(const uint32 a) : addr(a) {};
};

class	DEVBUS {
public:
	typedef	uint32	BUSW;

	virtual	void	kill(void) = 0;
	virtual	void	close(void) = 0;

	// Write a single value to a single address
	virtual	void	writeio(const BUSW a, const BUSW v) = 0;

	// Read a single value to a single address
	virtual	BUSW	readio(const BUSW a) = 0;

	// Read a series of values from values from a block of memory
	virtual	void	readi(const BUSW a, const int len, BUSW *buf) = 0;

	// Read a series of values from the same address in memory
	virtual	void	readz(const BUSW a, const int len, BUSW *buf) = 0;

	virtual	void	writei(const BUSW a, const int len, const BUSW *buf) = 0;
	virtual	void	writez(const BUSW a, const int len, const BUSW *buf) = 0;

	// Query whether or not an interrupt has taken place
	virtual	bool	poll(void) = 0;

	// Sleep until interrupt, but sleep no longer than msec milliseconds
	virtual	void	usleep(unsigned msec) = 0;

	// Sleep until an interrupt, no matter how long it takes for that
	// interrupt to take place
	virtual	void	wait(void) = 0;

	// Query whether or not a bus error has taken place.  This is somewhat
	// of a misnomer, as my current bus error detection code exits any
	// interface, but ... it is what it is.
	virtual	bool	bus_err(void) const = 0;

	// Clear any bus error condition.
	virtual	void	reset_err(void) = 0;

	// Clear any interrupt condition that has already been noticed by
	// the interface, does not check for further interrupt
	virtual	void	clear(void) = 0;

	virtual	~DEVBUS(void) { };
};

#endif
