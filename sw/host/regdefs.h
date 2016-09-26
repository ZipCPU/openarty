////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	regdefs.h
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
#ifndef	REGDEFS_H
#define	REGDEFS_H

#define	R_VERSION	0x00000100
#define	R_ICONTROL	0x00000101
#define	R_BUSERR	0x00000102
#define	R_PWCOUNT	0x00000103
#define	R_BTNSW		0x00000104
#define	R_LEDS		0x00000105
#define	R_UART_SETUP	0x00000106
#define	R_GPS_SETUP	0x00000107
#define	R_CLR0		0x00000108
#define	R_CLR1		0x00000109
#define	R_CLR2		0x0000010a
#define	R_CLR3		0x0000010b
#define	R_DATE		0x0000010c
#define	R_GPIO		0x0000010d	// No GPIO device exists ... yet
#define	R_UARTRX	0x0000010e
#define	R_UARTTX	0x0000010f
#define	R_GPSRX		0x00000110
#define	R_GPSTX		0x00000111
// WB Scope registers
#define	R_QSCOPE	0x00000120	// Quad SPI scope ctrl
#define	R_QSCOPED	0x00000121	//	and data
#define	R_GPSCOPE	0x00000122	// GPS configuration scope control
#define	R_GPSCOPED	0x00000123	//	and data
#define	R_CFGSCOPE	0x00000122	// ICAPE2 configuration scop control
#define	R_CFGSCOPED	0x00000123	//	and data
#define	R_RAMSCOPE	0x00000124	// DDR3 SDRAM Scope
#define	R_RAMSCOPED	0x00000125	//
#define	R_NETSCOPE	0x00000126	// Ethernet debug scope
#define	R_NETSCOPED	0x00000127	//
// RTC Clock Registers
#define	R_CLOCK		0x00000128
#define	R_TIMER		0x00000129
#define	R_STOPWATCH	0x0000012a
#define	R_CKALARM	0x0000012b
// SD Card Control
#define	R_SDCARD_CTRL	0x0000012c
#define	R_SDCARD_DATA	0x0000012d
#define	R_SDCARD_FIFOA	0x0000012e
#define	R_SDCARD_FIFOB	0x0000012f
// GPS Loop control, 0x0130
#define	R_GPS_ALPHA	0x00000130
#define	R_GPS_BETA	0x00000131
#define	R_GPS_GAMMA	0x00000132
#define	R_GPS_STEP	0x00000133
// OLED
#define	R_OLED_CMD	0x00000134
#define	R_OLED_CDATA	0x00000135
#define	R_OLED_CDATB	0x00000136
#define	R_OLED_DATA	0x00000137
// Network packet interface, 0x0184
#define	R_NET_RXCMD	0x00000138
#define	R_NET_TXCMD	0x00000139
#define	R_NET_MACHI	0x0000013a
#define	R_NET_MACLO	0x0000013b
#define	R_NET_RXMISS	0x0000013c
#define	R_NET_RXERR	0x0000013d
#define	R_NET_RXCRC	0x0000013e
#define	R_NET_TXCOL	0x0000013f
// Unused: 0x13c-0x13f
// GPS Testbench: 0x140-0x147
#define	R_GPSTB_FREQ	0x00000140
#define	R_GPSTB_JUMP	0x00000141
#define	R_GPSTB_ERRHI	0x00000142
#define	R_GPSTB_ERRLO	0x00000143
#define	R_GPSTB_COUNTHI	0x00000144
#define	R_GPSTB_COUNTLO	0x00000145
#define	R_GPSTB_STEPHI	0x00000146
#define	R_GPSTB_STEPLO	0x00000147
// Unused: 0x148-0x19f
// Ethernet configuration (MDIO) port: 0x1a0-0x1bf
#define	R_MDIO_BMCR	0x000001a0
#define	R_MDIO_BMSR	0x000001a1
#define	R_MDIO_PHYIDR1	0x000001a2
#define	R_MDIO_PHYIDR2	0x000001a3
#define	R_MDIO_ANAR	0x000001a4
#define	R_MDIO_ANLPAR	0x000001a5
// #define	R_MDIO_ANLPARNP	0x000001a5
#define	R_MDIO_ANER	0x000001a6
#define	R_MDIO_ANNPTR	0x000001a7
#define	R_MDIO_PHYSTS	0x000001b0
#define	R_MDIO_FCSCR	0x000001b4
#define	R_MDIO_RECR	0x000001b5
#define	R_MDIO_PCSR	0x000001b6
#define	R_MDIO_RBR	0x000001b7
#define	R_MDIO_LEDCR	0x000001b8
#define	R_MDIO_PHYCR	0x000001b9
#define	R_MDIO_BTSCR	0x000001ba
#define	R_MDIO_CDCTRL	0x000001bb
#define	R_MDIO_EDCR	0x000001bd
// Flash: 0x1c0-0x1df
#define	R_QSPI_EREG	0x000001c0
#define	R_QSPI_STAT	0x000001c1
#define	R_QSPI_NVCONF	0x000001c2
#define	R_QSPI_VCONF	0x000001c3
#define	R_QSPI_EVCONF	0x000001c4
#define	R_QSPI_LOCK	0x000001c5
#define	R_QSPI_FLAG	0x000001c6
// #define	R_QSPI_ASYNC	0x000001c7
#define	R_QSPI_ID	0x000001c8
#define	R_QSPI_IDA	0x000001c9
#define	R_QSPI_IDB	0x000001ca
#define	R_QSPI_IDC	0x000001cb
#define	R_QSPI_IDD	0x000001cc
//
#define	R_QSPI_OTPWP	0x000001cf
#define	R_QSPI_OTP	0x000001d0

// FPGA CONFIG REGISTERS: 0x1e0-0x1ff
#define	R_CFG_CRC	0x000001e0
#define	R_CFG_FAR	0x000001e1
#define	R_CFG_FDRI	0x000001e2
#define	R_CFG_FDRO	0x000001e3
#define	R_CFG_CMD	0x000001e4
#define	R_CFG_CTL0	0x000001e5
#define	R_CFG_MASK	0x000001e6
#define	R_CFG_STAT	0x000001e7
#define	R_CFG_LOUT	0x000001e8
#define	R_CFG_COR0	0x000001e9
#define	R_CFG_MFWR	0x000001ea
#define	R_CFG_CBC	0x000001eb
#define	R_CFG_IDCODE	0x000001ec
#define	R_CFG_AXSS	0x000001ed
#define	R_CFG_COR1	0x000001ee
#define	R_CFG_WBSTAR	0x000001f0
#define	R_CFG_TIMER	0x000001f1
#define	R_CFG_BOOTSTS	0x000001f6
#define	R_CFG_CTL1	0x000001f8
#define	R_CFG_BSPI	0x000001ff
// Block RAM memory space
#define	MEMBASE		0x00008000
#define	MEMWORDS	0x00008000
// Flash memory space
#define	EQSPIFLASH	0x00400000
#define	FLASHWORDS	(1<<22)
// DDR3 SDRAM memory space
#define	RAMBASE		0x04000000
#define	SDRAMBASE	RAMBASE
#define	RAMWORDS	(1<<26)
// Zip CPU Control and Debug registers
#define	R_ZIPCTRL	0x01000000
#define	R_ZIPDATA	0x01000001

// Interrupt control constants
#define	GIE		0x80000000	// Enable all interrupts
#define	ISPIF_EN	0x82000200	// Enable all, enable QSPI, clear QSPI
#define	ISPIF_DIS	0x02000200	// Disable all, disable QSPI
#define	ISPIF_CLR	0x00000200	// Clear QSPI interrupt
#define	SCOPEN		0x84000400	// Enable WBSCOPE interrupts

// Flash control constants
#define	ERASEFLAG	0xc00001be
#define	DISABLEWP	0x40000000
#define	ENABLEWP	0x00000000

#define	SZPAGEB		256
#define	PGLENB		256
#define	SZPAGEW		64
#define	PGLENW		64
#define	NPAGES		256
#define	SECTORSZB	(NPAGES * SZPAGEB)	// In bytes, not words!!
#define	SECTORSZW	(NPAGES * SZPAGEW)	// In words
#define	NSECTORS	64
#define	SECTOROF(A)	((A) & (-1<<14))
#define	SUBSECTOROF(A)	((A) & (-1<<10))
#define	PAGEOF(A)	((A) & (-1<<6))

#define	CPU_GO		0x0000
#define	CPU_RESET	0x0040
#define	CPU_INT		0x0080
#define	CPU_STEP	0x0100
#define	CPU_STALL	0x0200
#define	CPU_HALT	0x0400
#define	CPU_CLRCACHE	0x0800
#define	CPU_sR0		(0x0000|CPU_HALT)
#define	CPU_sSP		(0x000d|CPU_HALT)
#define	CPU_sCC		(0x000e|CPU_HALT)
#define	CPU_sPC		(0x000f|CPU_HALT)
#define	CPU_uR0		(0x0010|CPU_HALT)
#define	CPU_uSP		(0x001d|CPU_HALT)
#define	CPU_uCC		(0x001e|CPU_HALT)
#define	CPU_uPC		(0x001f|CPU_HALT)

#define	SCOPE_NO_RESET	0x80000000
#define	SCOPE_TRIGGER	(0x08000000|SCOPE_NO_RESET)
#define	SCOPE_DISABLE	(0x04000000)

typedef	struct {
	unsigned	m_addr;
	const char	*m_name;
} REGNAME;

extern	const	REGNAME	*bregs;
extern	const	int	NREGS;
// #define	NREGS	(sizeof(bregs)/sizeof(bregs[0]))

extern	unsigned	addrdecode(const char *v);
extern	const	char *addrname(const unsigned v);

#include "ttybus.h"
// #include "portbus.h"

typedef	TTYBUS	FPGA;

#endif
