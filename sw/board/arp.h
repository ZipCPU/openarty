////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	arp.h
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To encapsulate common functions associated with the ARP protocol
//		and hardware (ethernet MAC) address resolution.
//
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
#ifndef	ARP_H
#define	ARP_H

extern void	init_arp_table(void);
extern	int	arp_lookup(unsigned ipaddr, unsigned long *mac);
extern	void	arp_table_add(unsigned ipaddr, unsigned long mac);
extern	void	send_arp_reply(unsigned machi, unsigned maclo, unsigned ipaddr);

#endif
