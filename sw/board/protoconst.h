////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	protoconst.h
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To define, for our own distribution and use (prior to having any
//		useful /usr/include files for the ZipCPU), network number
//	definitions so that they can be used within our demonstration programs.
//
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2019-2024, Gisselquist Technology, LLC
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
#ifndef	PROTOCONST_H
#define	PROTOCONST_H

//
// These constants were drawn from /usr/include/net/ethernet.h
//
#define	ETHERTYPE_IP		0x0800
#define	ETHERTYPE_ARP		0x0806
#define	ETHERTYPE_IPV6		0x86dd
#define	ETHERTYPE_LOOPBACK	0x9000

//
// These constants were drawn from /usr/include/netinet/in.h
// They can also be found in /usr/include/linux/in.h
//
#define	IPPROTO_IP	0
#define	IPPROTO_ICMP	1
#define	IPPROTO_UDP	17
#define	IPPROTO_TCP	6

//
// These constants were drawn from /usr/include/netinet/ip_icmp.h
// They may also be found in /usr/include/linux/icmp.h
//
#define	ICMP_ECHOREPLY	0
#define	ICMP_ECHO	8

// This number is used in a *very* rudimentary pseudo-random number generation
// algorithm.  THE ALGORITHM IS NOT CRYPTOGRAPHICALLY SECURE!  This means that
// any network protocol using this number can easily be hacked by anyone looking
// hard enough into it.  For now, we use it just to get ourselves off the
// ground, hoping to come back to it later to make it more secure.
#define	BIG_PRIME	0x0134513b

#endif	// PROTOCONST_H

