////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	etcnet.h
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Most Linux systems maintain a variety of configuration files
//		in their /etc directory telling them how the network is
//	configured.  Since we don't have access to a filesystem (yet), we'll
//	maintain our network configuration here in this C header file.  Please
//	adjust this according to your own network configuration.  Other network
//	enabled programs in this directory should pick up any changes to this
//	file and adjust themselves appropriately.
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
//
////////////////////////////////////////////////////////////////////////////////
//
// }}}
#ifndef	ETCNET_H
#define	ETCNET_H

#define	IPADDR(A,B,C,D)	((((A)&0x0ff)<<24)|(((B)&0x0ff)<<16)	\
			|(((C)&0x0ff)<<8)|(D&0x0ff))

// Adjust these three lines as necessary to change from one network to another
//
//
// First, the default MAC --- this is the MAC of the Arty.  It was generated
// using /dev/rand, and should probably be changed to something else on your
// configuration.
#define	DEFAULTMAC	0xd2d828e8b096l

// Now, for the IP setup defaults
//
// These include the default IP of the Arty, 192.168.15.22.  This comes from
// the fact that this is the network number of my local network (a network with
// no other purpose than to test my Arty), that my local network is not run by
// DHCP (or if it were, that this address is reserved to be a static IP).
#define	DEFAULTIP	IPADDR(192,168,15,22)
//
// The next issue is how to deal with packets that are not on the local network.
// The first step is recognizing them, and that's the purpose of the netmask.
// You might also see this netmask as represented by IPADDR(255,255,255,0),
// or even 255.255.255.0.  I've just converted it to unsignd here.
#define	LCLNETMASK	0xffffff00
// So, if an IP address doesn't match as coming from my local network, then it
// needs to be sent to the router first.  While the router IP address isn't
// used for that purpose, it is used in the ARP query to find the MAC address
// of the router.  As a result, we need it and define our default here.
#define	DEFAULT_ROUTERIP	IPADDR(192,168,15,1)


// All of these constants will need to be copied into a series of global
// variables, whose names are given below.  They will then be represented by
// these (following) names within the code.  Note that this also includes the
// MAC address of the router, which will need to be filled in by the ARP
// resolution routine(s).
extern	unsigned long	my_mac_addr, router_mac_addr;
extern	unsigned	my_ip_addr, my_ip_router;
extern	unsigned	my_ip_mask;

#endif
