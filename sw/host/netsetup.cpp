////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	netsetup.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	
//
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

FPGA	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

void	usage(void) {
	printf("USAGE: netsetup\n");
}

int main(int argc, char **argv) {
	FPGAOPEN(m_fpga);

	signal(SIGSTOP, closeup);
	signal(SIGHUP, closeup);

	if ((argc < 1)||(argc > 2)) {
		// usage();
		printf("USAGE: netsetup\n");
		exit(-1);
	}

#ifndef	MDIO_ACCESS
	printf(
"This program depends upon the MDIO interface.  This interface was not\n"
"built into your design.  Please add it in and try again.\n");
#else
	unsigned	v;
	v = m_fpga->readio(R_MDIO_BMCR);
	printf("    BMCR    %04x\tBasic Mode Control Register\n", v);
	if (v & 0x08000)
		printf("                \tReset in progress\n");
	if (v & 0x04000)
		printf("                \tLoopback enabled\n");
	if (v & 0x01000)
		printf("                \tAuto-negotiation enabled\n");
	else if (v & 0x02000)
		printf("                \t100Mb/s -- manual selection\n");
	else
		printf("                \t 10Mb/s -- manual selection\n");
	if (v & 0x00800)
		printf("                \tPHY is powered down\n");
	if (v & 0x00400)
		printf("                \tPort is isolated from MII\n");
	if (v & 0x00200)
		printf("                \tRestart-auto-negotiation\n");
	if ((v& 0x00100)==0)
		printf("                \tHalf-duplex mode\n");
	if (v & 0x00080)
		printf("                \tCollision test enabled\n");
	v = m_fpga->readio(R_MDIO_BMSR);
	printf("R/O BMSR    %04x\tBasic Mode Status Register\n", v);
	if (v & 0x08000)
		printf("                \t100Base-T4 capable\n");
	if (v & 0x04000)
		printf("                \t100Base-TX Full Duplex capable\n");
	if (v & 0x02000)
		printf("                \t100Base-TX Half Duplex capable\n");
	if (v & 0x01000)
		printf("                \t 10Base-TX Full Duplex capable\n");
	if (v & 0x00800)
		printf("                \t 10Base-TX Half Duplex capable\n");
	if (v & 0x00040)
		printf("                \tPreamble suppression capable\n");
	if (v & 0x00020)
		printf("                \tAuto-negotiation complete\n");
	if (v & 0x00010)
		printf("                \tRemote fault detected\n");
	if (v & 0x00008)
		printf("                \tDevice is capable of auto-negotiation\n");
	if (v & 0x00004)
		printf("                \tLink is up\n");
	if (v & 0x00002)
		printf("                \tJabber condition detected (10Mb/s mode)\n");
	if (v & 0x00001)
		printf("                \tExtended register capabilities\n");
	v = m_fpga->readio(R_MDIO_PHYIDR1);
	printf("R/O PHYID1  %04x\tPHY Identifier Reg #1\n", v);
	//printf("            %4x\tOUI MSB\n", v);
	v = m_fpga->readio(R_MDIO_PHYIDR2);
	printf("R/O PHYID2  %04x\tPHY Identifier Reg #2\n", v);
	printf("            %4x\tOUI LSBs\n", (v>>10)&0x3f);
	printf("            %4x\tVendor model number\n",   (v>>4)&0x3f);
	printf("            %4x\tModel revision number\n", v&0x0f);
	v = m_fpga->readio(R_MDIO_ANAR);
	printf("    ANAR    %04x\tAuto-negotiation advertisement register\n", v);
	v = m_fpga->readio(R_MDIO_ANLPAR);
	printf("    ANLPAR  %04x\tAuto-negotiation link partner ability\n", v);
	v = m_fpga->readio(R_MDIO_ANER);
	printf("    ANER    %04x\tAuto-negotiation expansion register\n", v);
	v = m_fpga->readio(R_MDIO_ANNPTR);
	printf("    ANNPTR  %04x\tAuto-negotiation Next page TX\n", v);
	v = m_fpga->readio(R_MDIO_PHYSTS);
	printf("R/O PHYSTS  %04x\tPHY status register\n", v);
	if (v&0x4000)
		printf("                \tMDI pairs swapped\n");
	if (v&0x2000)
		printf("                \tReceive error event since last read of RXERCNT\n");
	if (v&0x1000)
		printf("                \tInverted polarity detected\n");
	if (v&0x800)
		printf("                \tFalse carrier sense latch\n");
	if (v&0x400)
		printf("                \tUnconditional signal detection from PMD\n");
	if (v&0x200)
		printf("                \tDescrambler lock from PMD\n");
	if (v&0x100)
		printf("                \tNew link codeword page has been received\n");
	if (v&0x40)
		printf("                \tRemote fault condition detected\n");
	if (v&0x20)
		printf("                \tJabber condition detected\n");
	if (v&0x10)
		printf("                \tAuto-negotiation complete\n");
	if (v&0x08)
		printf("                \tLoopback enabled\n");
	if (v&0x04)
		printf("                \tFull duplex mode\n");
	printf("             %3d\tSpeed from autonegotiation\n", (v&2)?10:100);
	if ((v&0x01)==0)
		printf("                \tNo link established\n");
	v = m_fpga->readio(R_MDIO_FCSCR);
	printf("    FCSCR   %04x\tFalse Carrier Sense Counter Register\n", v);
	v = m_fpga->readio(R_MDIO_RECR);
	printf("    RECR    %04x\tReceive Error Counter Register\n", v);
	v = m_fpga->readio(R_MDIO_PCSR);
	printf("    PCSR    %04x\tPCB Sub-Layer Configuration and Status Register\n", v);
	if (v&0x400)
		printf("                \tTrue Quiet (TQ) mode enabled\n");
	if (v&0x200)
		printf("                \tSignal detecttion forced in PMA\n");
	if (v&0x100)
		printf("                \tEnhanced signal detetion algorithm\n");
	if (v&0x80)
		printf("                \tDescrambler timeout = 2ms (for large packets)\n");
	if (v&0x20)
		printf("                \tForce 100Mb/s good link\n");
	if (v&0x4)
		printf("                \tNRZI bypass enabled\n");
	v = m_fpga->readio(R_MDIO_RBR);
	printf("    RBR     %04x\tRMII and Bypass Register\n", v);
	if (v&0x20)
		printf("                \tRMII mode enabled\n");
	v = m_fpga->readio(R_MDIO_LEDCR);
	printf("    LEDCR   %04x\tLED Direct Control Register\n", v);
	if (v&0x20)
		printf("             %s\tLED_SPEED LED\n", (v&0x4)?"ON ":"OFF");
	if (v&0x10)
		printf("             %s\tLED_LINK  LED\n", (v&0x2)?"ON ":"OFF");
		
	v = m_fpga->readio(R_MDIO_PHYCR);
	printf("    PHYCR   %04x\tPHY control register\n", v);
	if (v&0x8000)
		printf("                \tAuto-neg auto-MDIX enabled\n");
	if (v&0x4000)
		printf("                \tForce MDI pairs to cross\n");
	if (v&0x2000)
		printf("                \tPause receive negotiation\n");
	if (v&0x1000)
		printf("                \tPause transmit negotiation\n");
	if (v&0x0800)
		printf("                \tForce BIST error\n");
	if (v&0x0400)
		printf("                \tPSR15 BIST sequence selected\n");
	if (v&0x0200)
		printf("                \tBIST test passed\n");
	if (v&0x0100)
		printf("                \tBIST start\n");
	if (v&0x0080)
		printf("                \tBypass LED stretching\n");
	if ((v&0x0020)==0)
		printf("                \tDon\'t blink LED\'s on activity\n");
	if (v&0x001f)
		printf("            %4x\tPHY Addr\n", v & 0x01f);
	v = m_fpga->readio(R_MDIO_BTSCR);
	printf("    BTSCR   %04x\t10-Base T Status/Control Register\n", v);
	v = m_fpga->readio(R_MDIO_CDCTRL);
	printf("    CDCTRL  %04x\tCD Test Control Register, BIST Extension Register\n", v);
	if (v&0xff00)
		printf("            %04x\tBIST error counter\n", (v>>8)&0x0ff);
	if (v&0x20)
		printf("                \tPacket BIST continuous mode\n");
	if (v&0x10)
		printf("                \tCD pattern enable for 10Mb\n");
	v = m_fpga->readio(R_MDIO_EDCR);
	printf("    EDCR    %04x\tEnergy Detect Control Register\n", v);
	if (v&0x8000)
		printf("                \tEnergy detect mode enabled\n");
	if (v&0x4000)
		printf("                \tEnergy detect power up\n");
	if (v&0x2000)
		printf("                \tEnergy detect power down\n");
	if (v&0x1000)
		printf("                \tEnergy detect manual power up/down\n");
	if (v&0x0800)
		printf("                \tDisable bursting of energy detection bursts\n");
	if (v&0x0400)
		printf("                \tED Power state\n");
	if (v&0x0200)
		printf("                \tEnergy detect err threshold met\n");
	if (v&0x0100)
		printf("                \tEnergy detect data threshold met\n");
	printf("            %04x\tEnergy detect err  threshold\n", (v>>4)&15);
	printf("            %04x\tEnergy detect data threshold\n", (v)&15);

	delete	m_fpga;
#endif
}

