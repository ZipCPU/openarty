////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	manping.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To manually construct a packet, to be sent to the network port,
//		to command the network to ping a target.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2019, Gisselquist Technology, LLC
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
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <strings.h>
#include <ctype.h>
#include <string.h>
#include <signal.h>
#include <assert.h>

#include "port.h"
#include "regdefs.h"
#include "ttybus.h"
#include "design.h"

#define	TXGO		0x04000
#define	NOHWCRC		0x08000
#define	NOHWMAC		0x10000
#define	NETRESET	0x20000

//
// Define DONT_INVERT for debugging only, as it will break the interface
// test
//
// #define	DONT_INVERT


FPGA	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

void	usage(void) {
	printf("USAGE: manping EN:RX:xx:xx:xx:xx AR:TY:EN:TX:xx:xx de.st.ip.x ar.ty.ip.x\n");
}

bool	strtoenetaddr(char *s, unsigned char *addr) {
	char	*p, *c;

	p = s;
	addr[0] = (unsigned char)(strtoul(p, NULL, 16)&0x0ff);
	c = strchr(p,':');
	if((!c) || ((c-p)>=3))
		return false;

	p = c+1;
	addr[1] = (unsigned char)(strtoul(p, NULL, 16)&0x0ff);
	c = strchr(p,':');
	if((!c) || ((c-p)>=3))
		return false;

	p = c+1;
	addr[2] = (unsigned char)(strtoul(p, NULL, 16)&0x0ff);
	c = strchr(p,':');
	if((!c) || ((c-p)>=3))
		return false;

	p = c+1;
	addr[3] = (unsigned char)(strtoul(p, NULL, 16)&0x0ff);
	c = strchr(p,':');
	if((!c) || ((c-p)>=3))
		return false;

	p = c+1;
	addr[4] = (unsigned char)(strtoul(p, NULL, 16)&0x0ff);
	c = strchr(p,':');
	if((!c) || ((c-p)>=3))
		return false;

	p = c+1;
	addr[5] = (unsigned char)(strtoul(p, NULL, 16)&0x0ff);

	return true;
}

bool	strtoinetaddr(char *s, unsigned char *addr) {
	char	*p, *c;

	p = s;
	addr[0] = (unsigned char)(strtoul(p, NULL, 10)&0x0ff);
	c = strchr(p,'.');
	if((!c) || ((c-p)>3))
		return false;

	p = c+1;
	addr[1] = (unsigned char)(strtoul(p, NULL, 10)&0x0ff);
	c = strchr(p,'.');
	if((!c) || ((c-p)>3))
		return false;

	p = c+1;
	addr[2] = (unsigned char)(strtoul(p, NULL, 10)&0x0ff);
	c = strchr(p,'.');
	if((!c) || ((c-p)>3))
		return false;

	p = c+1;
	addr[3] = (unsigned char)(strtoul(p, NULL, 10)&0x0ff);

	return true;
}

unsigned	calccrc(const int bytelen, const unsigned *buf) {
	const unsigned int	taps = 0xedb88320u;
#ifdef	DONT_INVERT
	unsigned int	crc = 0;
#else
	unsigned int	crc = 0xffffffff; // initial value
#endif
	int	bidx;
	int	bp = 0;

	for(bidx = 0; bidx<bytelen; bidx++) {
		if (bidx == 14)
			bidx+=2;
		unsigned char	byte = buf[(bidx>>2)]>>(24-((bidx&3)<<3));

		// printf("CRC[%2d]: %02x ([%2d]0x%08x)\n", bidx, byte, (bidx>>2), buf[(bidx>>2)]);

		for(int bit=8; --bit>= 0; byte >>= 1) {
			if ((crc ^ byte) & 1) {
				crc >>= 1;
				crc ^= taps;
			} else
				crc >>= 1;
		} bp++;
	}
#ifndef	DONT_INVERT
	crc ^= 0xffffffff;
#endif
	// Now, we need to reverse these bytes
	// ABCD
	unsigned a,b,c,d;
	a = (crc>>24); // &0x0ff;
	b = (crc>>16)&0x0ff;
	c = (crc>> 8)&0x0ff;
	d = crc; // (crc    )&0x0ff;
	crc = (d<<24)|(c<<16)|(b<<8)|a;

	// printf("%d bytes processed\n", bp);
	return crc;
}

void	ipchecksum(unsigned *packet) {
	int npkt = (packet[0]>>24)&0x0f;
	unsigned checksum = 0;

	packet[2] &= 0xffff0000;
	printf("PKT[2] set to %08x\n", packet[2]);
	printf("checksum = %08x\n", checksum);
	for(int i=0; i<npkt; i++)
		checksum += packet[i] & 0x0ffff;
	printf("checksum = %08x\n", checksum);
	for(int i=0; i<npkt; i++)
		checksum += (packet[i]>>16)&0x0ffff;
	printf("checksum = %08x\n", checksum);
	checksum = (checksum & 0x0ffff) + (checksum >> 16);
	checksum = (checksum & 0x0ffff) + (checksum >> 16);
	packet[2] |= (checksum & 0x0ffff)^0x0ffff;

	printf("PKT[2] set to 0x%08x\n", packet[2]);
	checksum = 0;
	for(int i=0; i<npkt; i++)
		checksum += packet[i] & 0x0ffff;
	for(int i=0; i<npkt; i++)
		checksum += (packet[i]>>16)&0x0ffff;
	checksum = (checksum & 0x0ffff) + (checksum >> 16);
	checksum = (checksum & 0x0ffff) + (checksum >> 16);
	checksum ^= 0x0ffff;

	assert(checksum == 0);
}

void	clear_scope(FPGA *fpga) {
#ifdef	R_NETSCOPE
	unsigned	scopev;

	scopev = m_fpga->readio(R_NETSCOPE);
	int delay = (scopev>>20)&0x0f;
	delay = (1<<(delay))-32;
	m_fpga->writeio(R_NETSCOPE, (delay));
#endif
}

int main(int argc, char **argv) {
#ifndef	ETHERNET_ACCESS
	fprintf(stderr,
"The ethernet core was not included in this design.  Reconfigure your\n"
"autofpga settings, and build this again if you want to test your network\n"
"access\n\n");
	exit(EXIT_FAILURE);
#else
	bool	config_hw_mac = true, config_hw_crc = true;
	FPGA::BUSW	txstat;
	int	argn;
	unsigned	checksum;
	unsigned	urand[16], nu = 0;

	{
		FILE *fp;
		for(int i=0; i<16; i++)
			urand[i] = rand();

		// Now, see if we can do better than the library random
		// number generator--but don't fail if we can't.
		fp = fopen("/dev/urandom", "r");
		if (fp != NULL) {
			int nr = fread(urand, sizeof(short), 16, fp);
			fclose(fp);
			if (nr<0)
				printf("Could not generate random numbers from /dev/urandom!\nTest may not be valid.\n");
		}
	}
			

	FPGAOPEN(m_fpga);

	signal(SIGSTOP, closeup);
	signal(SIGHUP, closeup);

	txstat = m_fpga->readio(R_NET_TXCMD);

	// Take the ethernet out of reset
	if ((txstat & NETRESET) != 0)
		m_fpga->writeio(R_NET_TXCMD, (txstat &=(~NETRESET)));

	unsigned	packet[14];

	unsigned char	smac[6], dmac[6];
	unsigned char	sip[4],  dip[4];

	// I know the ethernet MAC of the computer I wish to test with
	dmac[0] = 0xc8; dmac[1] = 0x3a; dmac[2] = 0x35;
	dmac[3] = 0xd2; dmac[4] = 0x07; dmac[5] = 0xb1;
	// And just something from /dev/urandom to create our source address
	smac[0] = 0xd2; smac[1] = 0xd8; smac[2] = 0x28;
	smac[3] = 0xe8; smac[4] = 0xb0; smac[5] = 0x96;

	// Similarly with the destination IP of the computer I wish to test with
	dip[0] = 192; dip[1] = 168; dip[2] = 15; dip[3] = 1;
	// and let's pick a source IP just ... somewhere on that network
	sip[0] = 192; sip[1] = 168; sip[2] = 15; sip[3] = 22;

// #define	SIMULATION
#ifdef	SIMULATION
	for(int i=0; i<6; i++)	dmac[i] = smac[i];
	for(int i=0; i<4; i++)	dip[i] = dip[i];
#endif

	clear_scope(m_fpga);

	argn = 1;

	{
		bool	bad_address = false;
		char	*badp = NULL;
		if ((argn<argc)&&(strchr(argv[argn], ':'))) {
			if (!strtoenetaddr(argv[argn++], dmac)) {
				badp = argv[argn-1];
				bad_address = true;
			} else if ((argn<argc)&&(strchr(argv[argn], ':'))) {
				if (!strtoenetaddr(argv[argn++], smac)) {
					badp = argv[argn-1];
					bad_address = true;
				}
			}
		} if ((argn<argc)&&(!bad_address)&&(strchr(argv[argn], '.'))) {
			if (!strtoinetaddr(argv[argn++], dip)) {
				badp = argv[argn-1];
				bad_address = true;
			} else if ((argn<argc)&&(strchr(argv[argn], '.'))) {
				if (!strtoinetaddr(argv[argn++], sip)) {
					badp = argv[argn-1];
					bad_address = true;
				}
			}
		}

		if (bad_address) {
			usage();
			fprintf(stderr, "ERR: could not comprehend address, %s\n", badp);
			exit(EXIT_FAILURE);
		}
	}

	printf("Building packet\n");
	printf("From %3d.%3d.%3d.%3d [%02x:%02x:%02x:%02x:%02x:%02x]\n",
		sip[0], sip[1], sip[2], sip[3],
		smac[0], smac[1], smac[2], smac[3], smac[4], smac[5]);
	printf("To   %3d.%3d.%3d.%3d [%02x:%02x:%02x:%02x:%02x:%02x]\n",
		dip[0], dip[1], dip[2], dip[3],
		dmac[0], dmac[1], dmac[2], dmac[3], dmac[4], dmac[5]);


	// Let's build ourselves a ping packet
	packet[ 0] = (dmac[0]<<24)|(dmac[1]<<16)|(dmac[2]<<8)|(dmac[3]);
	packet[ 1] = (dmac[4]<<24)|(dmac[5]<<16)|(smac[0]<<8)|(smac[1]);
	packet[ 2] = (smac[2]<<24)|(smac[3]<<16)|(smac[4]<<8)|(smac[5]);
	packet[ 3] = 0x08000800;
	packet[ 4] = 0x4500001c; // IPv4, 20byte header, type of service = 0
	packet[ 5] = (urand[nu++]&0xffff0000); // Packet ID
	packet[ 6] = 0x80010000; // no flags, fragment offset=0, ttl=0, proto=1
	packet[ 7] = (sip[0]<<24)|(sip[1]<<16)|(sip[2]<<8)|(sip[3]);
	packet[ 8] = (dip[0]<<24)|(dip[1]<<16)|(dip[2]<<8)|(dip[3]);
	// Ping payload: type = 0x08 (PING, the response will be zero)
	//	CODE = 0
	//	Checksum will be filled in later
	packet[ 9] = 0x08000000;
	// This is the PING identifier and sequence number.  For now, we'll
	// just feed it random information--doesn't really matter what
	packet[10] = urand[nu++];
	// Now, the minimum ethernet packet is 16 words.  So, let's flush
	// ourselves out to that minimum length.
	packet[11] = 0;
	packet[12] = 0;
	packet[13] = 0;
	packet[14] = 0;

	// Calculate the IP header checksum
	ipchecksum(&packet[4]);

	// Calculate the PING payload checksum
	checksum  =  packet[ 9] & 0x0ffff;
	checksum += (packet[ 9]>>16)&0x0ffff;
	checksum +=  packet[10] & 0x0ffff;
	checksum += (packet[10]>>16)&0x0ffff;
	checksum  = ((checksum >> 16)&0x0ffff) + (checksum & 0x0ffff);
	checksum  = ((checksum >> 16)&0x0ffff) + (checksum & 0x0ffff);
	packet[ 9] = ((packet[9] & 0xffff0000)|(checksum))^0x0ffff;

	// Calculate the CRC--assuming we'll use it.
	packet[15] = calccrc(15*4, packet);

	// Clear any/all pending receiving errors or packets
	m_fpga->writeio(R_NET_RXCMD, 0x0fffff);
	if (config_hw_mac) {
		int ln;

		m_fpga->writeio(R_NET_MACHI, (smac[0]<<8)|(smac[1]));
		m_fpga->writeio(R_NET_MACLO, (smac[2]<<24)|(smac[3]<<16)|(smac[4]<<8)|(smac[5]));
			
		// Now, let's rebuild our packet for the non-hw-mac option,
		// now that we know the CRC.  In general, we're just going
		// to copy the packet we created earlier, but we need to
		// shift things as we do so.
		packet[ 0] = (dmac[0]<<24)|(dmac[1]<<16)|(dmac[2]<<8)|(dmac[3]);
		packet[ 1] = (dmac[4]<<24)|(dmac[5]<<16)|0x0800;
		packet[ 2] = packet[ 4];
		packet[ 3] = packet[ 5];
		packet[ 4] = packet[ 6];
		packet[ 5] = packet[ 7];
		packet[ 6] = packet[ 8];
		packet[ 7] = packet[ 9];
		packet[ 8] = packet[10];
		packet[ 9] = packet[11];
		packet[10] = packet[12];
		packet[11] = packet[13];
		packet[12] = packet[14];
		packet[13] = packet[15];

		ln = (config_hw_crc)?9:14;
		printf("Packet:\n");
		for(int i=0; i<14; i++)
			printf("\t%2d: 0x%08x\n", i, packet[i]);

		// Load the packet into the hardware buffer
		m_fpga->writei(R_NET_TXBUF, ln, packet);

		// And give it the transmit command.
		{ unsigned cmd;
		cmd = TXGO|(ln<<2)|((config_hw_crc)?0:NOHWCRC);
		m_fpga->writeio(R_NET_TXCMD, cmd);
		printf("Sent TX command: 0x%x\n", cmd);
		}

	} else {
		int	ln;

		ln = (config_hw_crc)?11:12;
		printf("Packet:\n");
		for(int i=0; i<15; i++)
			printf("\t%3d: 0x%08x\n", i, packet[i]);
		printf("\tCRC: 0x%08x\n", packet[15]);

		// Load the packet into the hardware buffer
		m_fpga->writei(R_NET_TXBUF, ln, packet);

		// And give it the transmit command
		m_fpga->writeio(R_NET_TXCMD, TXGO|NOHWMAC|(ln<<2)|((config_hw_crc)?0:NOHWCRC));
	}

	// First, we need to look for any ARP requests, and we'll need to
	// respond to them.  If during this time we get a ping response
	// packet, we're done.

	printf("\nLooking for a response ...\n");
	unsigned rxstat;
	int	errcount = 0;
	do {
		rxstat = m_fpga->readio(R_NET_RXCMD);
		if (rxstat & 0x04000) {
			int	rxlen;
			unsigned *buf;
			printf("RX Status = %08x\n", rxstat);
			rxlen = ((rxstat & 0x03fff)+3)>>2;
			buf = new unsigned[rxlen];
			m_fpga->readi(R_NET_RXBUF, rxlen, buf);
			for(int i=0; i<rxlen; i++)
				printf("\tRX[%2d]: 0x%08x\n", i, buf[i]);
			delete[] buf;
			// m_fpga->writeio(R_NET_RXCMD, 0xffffff);
			break;
		}
	} while(((rxstat & 0x04000)==0)&&(errcount++ < 500));

	rxstat = m_fpga->readio(R_NET_RXCMD);
	printf("Final Rx Status = %08x\n", rxstat);

	
	delete	m_fpga;
#endif
}

