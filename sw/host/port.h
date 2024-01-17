////////////////////////////////////////////////////////////////////////////////
//
// Filename:	port.h
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Defines the communication parameters necessary for communicating
//		with either the device or its simulation.
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
#ifndef	PORT_H
#define	PORT_H

// There are two ways to connect: via a serial port, and via a TCP socket
// connected to a serial port.  This way, we can connect the device on one
// computer, test it, and when/if it doesn't work we can replace the device
// with the test-bench.  Across the network, no one will know any better that
// anything had changed.
#define	FPGAHOST	"jericho"
#define	FPGATTY		"/dev/ttyUSB1"
#define	FPGAPORT	6510

#ifndef	FORCE_UART
#define	FPGAOPEN(V) V= new FPGA(new NETCOMMS(FPGAHOST, FPGAPORT))
#else
#define	FPGAOPEN(V) V= new FPGA(new TTYCOMMS(FPGATTY))
#endif

#endif
