////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	port.h
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
#ifndef	PORT_H
#define	PORT_H

// #define	FPGAHOST	"lazarus"
#define	FPGAHOST	"localhost"
#define	FPGATTY		"/dev/ttyUSB1"
#define	FPGAPORT	6510

#ifndef	FORCE_UART
#define	FPGAOPEN(V) V= new FPGA(new NETCOMMS(FPGAHOST, FPGAPORT))
#else
#define	FPGAOPEN(V) V= new FPGA(new TTYCOMMS(FPGATTY))
#endif

#endif
