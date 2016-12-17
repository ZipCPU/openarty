////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	arp.c
//
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
#include "zipcpu.h"
#include "zipsys.h"
#define	KTRAPID_SENDPKT	0
#include "artyboard.h"
#include "etcnet.h"
#include "protoconst.h"
#include "ipcksum.h"

///////////
//
//
// Simplified ARP table and ARP requester
//
//
///////////

typedef	struct	{
	int		valid;
	unsigned	age, ipaddr;
	unsigned long	mac;
} ARP_TABLE_ENTRY;

#define	NUM_ARP_ENTRIES	8
ARP_TABLE_ENTRY	arp_table[NUM_ARP_ENTRIES];

void	init_arp_table(void) {
	for(int k=0; k<NUM_ARP_ENTRIES; k++)
		arp_table[k].valid = 0;
}

int	get_next_arp_index(void) {
	int	eid, eldest = 0, unused_id = -1, oldage = 0, found=-1;
	for(eid=0; eid<NUM_ARP_ENTRIES; eid++) {
		if (!arp_table[eid].valid) {
			unused_id = eid;
			break;
		} else if (arp_table[eid].age > oldage) {
			oldage = arp_table[eid].age;
			eldest = eid;
		}
	}

	if (unused_id >= 0)
		return unused_id;
	return eldest;
}

void	send_arp_request(int ipaddr) {
	unsigned	pkt[9];

	pkt[0] = 0xffffffff;
	pkt[1] = 0xffff0000 | ETHERTYPE_ARP;
	pkt[2] = 0x010800;	// hardware type (enet), proto type (inet)
	pkt[3] = 0x06040001;	// 6 octets in enet addr, 4 in inet addr,request
	pkt[4] = (unsigned)(my_mac_addr>>16);
	pkt[5] = ((unsigned)(my_mac_addr<<16))|(my_ip_addr>>16);
	pkt[6] = (my_ip_addr<<16);
	pkt[7] = 0;
	pkt[8] = ipaddr;

	// Send our packet
	syscall(KTRAPID_SENDPKT,0,(unsigned)pkt, 9*4);
}

int	arp_lookup(unsigned ipaddr, unsigned long *mac) {
	int	eid, eldest = 0, unused_id = -1, oldage = 0, found=-1;

	if (((((ipaddr ^ my_ip_addr) & my_ip_mask) != 0)
		|| (ipaddr == my_ip_router))
			&&(router_mac_addr)) {
		*mac = router_mac_addr;
		return 0;
	}

	for(eid=0; eid<NUM_ARP_ENTRIES; eid++) {
		if (arp_table[eid].valid) {
			if (arp_table[eid].ipaddr == ipaddr) {
				arp_table[eid].age = 0;
				*mac = arp_table[eid].mac;
				return 0;
			} else if (arp_table[eid].age > oldage) {
				oldage = arp_table[eid].age++;
				eldest = eid;
				if (oldage >= 0x010000)
					arp_table[eid].valid = 0;
			} else
				arp_table[eid].age++;
		}
	}

	send_arp_request(ipaddr);
	return 1;
}

typedef struct	{
	unsigned ipaddr;
	unsigned long	mac;
} ARP_TABLE_LOG_ENTRY;

int	arp_logid = 0;
ARP_TABLE_LOG_ENTRY	arp_table_log[32];

void	arp_table_add(unsigned ipaddr, unsigned long mac) {
	unsigned long	lclmac;
	int		eid;

	arp_table_log[arp_logid].ipaddr = ipaddr;
	arp_table_log[arp_logid].mac = mac;
	arp_logid++;
	arp_logid&= 31;
	

	if (ipaddr == my_ip_addr)
		return;
	// Missing the 'if'??
	else if (ipaddr == my_ip_router) {
		router_mac_addr = mac;
	} else if (arp_lookup(ipaddr, &lclmac)==0) {
		if (mac != lclmac) {
			for(eid=0; eid<NUM_ARP_ENTRIES; eid++) {
				if ((arp_table[eid].valid)&&
					(arp_table[eid].ipaddr == ipaddr)) {
					volatile int *ev = &arp_table[eid].valid;
					// Prevent anyone from using an invalid
					// entry while we are updating it
					*ev = 0;
					arp_table[eid].age = 0;
					arp_table[eid].mac = mac;
					*ev = 1;
					break;
				}
			}
		}
	} else {
		volatile int *ev = &arp_table[eid].valid;
		eid = get_next_arp_index();

		// Prevent anyone from using an invalid entry while we are
		// updating it
		*ev = 0;
		arp_table[eid].age = 0;
		arp_table[eid].ipaddr = ipaddr;
		arp_table[eid].mac = mac;
		*ev = 1;
	}
}

void	send_arp_reply(unsigned machi, unsigned maclo, unsigned ipaddr) {
	unsigned pkt[9];
	pkt[0] = (machi<<16)|(maclo>>16);
	pkt[1] = (maclo<<16)|ETHERTYPE_ARP;
	pkt[2] = 0x010800;	// hardware type (enet), proto type (inet)
	pkt[3] = 0x06040002;
	pkt[4] = (unsigned)(my_mac_addr>>16);
	pkt[5] = ((unsigned)(my_mac_addr<<16))|(my_ip_addr>>16);
	pkt[6] = (my_ip_addr<<16)|(machi);
	pkt[7] = maclo;
	pkt[8] = ipaddr;

	syscall(KTRAPID_SENDPKT, 0, (int)pkt, 9*4);
}

