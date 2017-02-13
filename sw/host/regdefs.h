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
#ifndef	REGDEFS_H
#define	REGDEFS_H

#define	CLOCKFREQ_HZ	81250000
#define	R_VERSION	0x00000400
#define	R_ICONTROL	0x00000404
#define	R_BUSERR	0x00000408
#define	R_PWCOUNT	0x0000040c
#define	R_BTNSW		0x00000410
#define	R_LEDS		0x00000414
#define	R_DATE		0x00000418
#define	R_GPIO		0x0000041c
#define	R_CLR0		0x00000420
#define	R_CLR1		0x00000424
#define	R_CLR2		0x00000428
#define	R_CLR3		0x0000042c
#define	R_IOTIMES	0x00000430
#define	R_IOSUBSEC	0x00000434
#define	R_IOTIMSTEP	0x00000438

// WB Scope registers
#define	R_QSCOPE	0x00000480	// Scope #0: Quad SPI scope ctrl
#define	R_QSCOPED	0x00000484	//	and data
#define	R_CPUSCOPE	0x00000480	// CPU scope (if so configured)
#define	R_CPUSCOPED	0x00000484	//	and data
#define	R_GPSCOPE	0x00000488	// Scope #1: GPS config scope control
#define	R_GPSCOPED	0x0000048c	//	and data
#define	R_CFGSCOPE	0x00000488	// ICAPE2 configuration scop control
#define	R_CFGSCOPED	0x0000048c	//	and data
#define	R_BUSSCOPE	0x00000488	// WBUBUS scope control
#define	R_BUSSCOPED	0x0000048c	//	and data
#define	R_RAMSCOPE	0x00000490	// Scope #2: DDR3 SDRAM Scope
#define	R_RAMSCOPED	0x00000494	//
#define	R_NETSCOPE	0x00000498	// Scope #3: Ethernet debug scope
#define	R_NETSCOPED	0x0000049c	//
// RTC Clock Registers
#define	R_CLOCK		0x000004a0
#define	R_TIMER		0x000004a4
#define	R_STOPWATCH	0x000004a8
#define	R_CKALARM	0x000004ac
// OLED
#define	R_OLED_CMD	0x000004b0
#define	R_OLED_CDATA	0x000004b4
#define	R_OLED_CDATB	0x000004b8
#define	R_OLED_DATA	0x000004bc
// WBUART - AUX
#define	R_UART_SETUP	0x000004c0
#define	R_UART_FIFO	0x000004c4
#define	R_UARTRX	0x000004c8
#define	R_UARTTX	0x000004cc
// WBUART - GPS
#define	R_GPS_SETUP	0x000004d0
#define	R_GPS_FIFO	0x000004d4
#define	R_GPSRX		0x000004d8
#define	R_GPSTX		0x000004dc
// SD Card Control
#define	R_SDCARD_CTRL	0x000004e0
#define	R_SDCARD_DATA	0x000004e4
#define	R_SDCARD_FIFOA	0x000004e8
#define	R_SDCARD_FIFOB	0x000004ec
// Unused, 4x positions
// Unused		0x000004f0
// Unused		0x000004f4
// Unused		0x000004f8
// Unused		0x000004fc
// GPS Loop control
#define	R_GPS_ALPHA	0x00000500
#define	R_GPS_BETA	0x00000504
#define	R_GPS_GAMMA	0x00000508
#define	R_GPS_STEP	0x0000050c
// Unused, 4x positions
// Unused		0x00000510
// Unused		0x00000514
// Unused		0x00000518
// Unused		0x0000051c
// GPS Testbench:
#define	R_GPSTB_FREQ	0x00000520
#define	R_GPSTB_JUMP	0x00000524
#define	R_GPSTB_ERRHI	0x00000528
#define	R_GPSTB_ERRLO	0x0000052c
#define	R_GPSTB_COUNTHI	0x00000530
#define	R_GPSTB_COUNTLO	0x00000534
#define	R_GPSTB_STEPHI	0x00000538
#define	R_GPSTB_STEPLO	0x0000053c
// Network packet interface
#define	R_NET_RXCMD	0x00000540
#define	R_NET_TXCMD	0x00000544
#define	R_NET_MACHI	0x00000548
#define	R_NET_MACLO	0x0000054c
#define	R_NET_RXMISS	0x00000550
#define	R_NET_RXERR	0x00000554
#define	R_NET_RXCRC	0x00000558
#define	R_NET_TXCOL	0x0000055c
// Unused: 0x560-0x57f
// Ethernet configuration (MDIO) port: 0x1a0-0x1bf
#define	R_MDIO_BMCR	0x00000580
#define	R_MDIO_BMSR	0x00000584
#define	R_MDIO_PHYIDR1	0x00000588
#define	R_MDIO_PHYIDR2	0x0000058c
#define	R_MDIO_ANAR	0x00000590
#define	R_MDIO_ANLPAR	0x00000594
// #define R_MDIO_ANLPARNP	0x00000594 // (duplicate reg)
#define	R_MDIO_ANER	0x00000598
#define	R_MDIO_ANNPTR	0x0000059c
// 8-15
#define	R_MDIO_PHYSTS	0x000005c0
#define	R_MDIO_FCSCR	0x000005d0
#define	R_MDIO_RECR	0x000005d4
#define	R_MDIO_PCSR	0x000005d8
#define	R_MDIO_RBR	0x000005dc
#define	R_MDIO_LEDCR	0x000005d0
#define	R_MDIO_PHYCR	0x000005d4
#define	R_MDIO_BTSCR	0x000005d8
#define	R_MDIO_CDCTRL	0x000005dc
#define	R_MDIO_EDCR	0x000005e4
//
// Flash: 0x1c0-0x1df
#define	R_QSPI_EREG	0x00000600
#define	R_QSPI_STAT	0x00000604
#define	R_QSPI_NVCONF	0x00000608
#define	R_QSPI_VCONF	0x0000060c
#define	R_QSPI_EVCONF	0x00000610
#define	R_QSPI_LOCK	0x00000614
#define	R_QSPI_FLAG	0x00000618
// #define	R_QSPI_ASYNC	0x0000061c
#define	R_QSPI_ID	0x00000620
#define	R_QSPI_IDA	0x00000624
#define	R_QSPI_IDB	0x00000628
#define	R_QSPI_IDC	0x0000062c
#define	R_QSPI_IDD	0x00000630
//
#define	R_QSPI_OTPWP	0x0000063c
#define	R_QSPI_OTP	0x00000640

// FPGA CONFIG REGISTERS: 0x4e0-0x4ff
#define	R_CFG_CRC	0x00000680
#define	R_CFG_FAR	0x00000684
#define	R_CFG_FDRI	0x00000688
#define	R_CFG_FDRO	0x0000068c
#define	R_CFG_CMD	0x00000690
#define	R_CFG_CTL0	0x00000694
#define	R_CFG_MASK	0x00000698
#define	R_CFG_STAT	0x0000069c
#define	R_CFG_LOUT	0x000006a0
#define	R_CFG_COR0	0x000006a4
#define	R_CFG_MFWR	0x000006a8
#define	R_CFG_CBC	0x000006ac
#define	R_CFG_IDCODE	0x000006b0
#define	R_CFG_AXSS	0x000006b4
#define	R_CFG_COR1	0x000006b8
#define	R_CFG_WBSTAR	0x000006c0
#define	R_CFG_TIMER	0x000006c4
#define	R_CFG_BOOTSTS	0x000006d8
#define	R_CFG_CTL1	0x000006e0
#define	R_CFG_BSPI	0x000006fc
// Network buffer space
#define	R_NET_RXBUF	0x00002000
#define	R_NET_TXBUF	0x00003000
// Block RAM memory space
#define	MEMBASE		0x00020000
#define	MEMLEN		0x00020000
// Flash memory space
#define	EQSPIFLASH	0x01000000
#define	RESET_ADDRESS	0x010e0000
// #define	FLASHWORDS	(1<<22)
#define	FLASHLEN	(1<<24)
// DDR3 SDRAM memory space
#define	RAMBASE		0x10000000
#define	SDRAMBASE	RAMBASE
// #define	RAMWORDS	(1<<26)
#define	RAMLEN		(1<<28)
// Zip CPU Control and Debug registers
#define	R_ZIPCTRL	0x20000000
#define	R_ZIPDATA	0x20000004

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
#define	SECTOROF(A)	((A) & (-1<<16))
#define	SUBSECTOROF(A)	((A) & (-1<<12))
#define	PAGEOF(A)	((A) & (-1<<8))

#define	CPU_GO		0x0000
#define	CPU_RESET	0x0040
#define	CPU_INT		0x0080
#define	CPU_STEP	0x0100
#define	CPU_STALL	0x0200
#define	CPU_HALT	0x0400
#define	CPU_CLRCACHE	0x0800
#define	CPU_sR0		0x0000
#define	CPU_sSP		0x000d
#define	CPU_sCC		0x000e
#define	CPU_sPC		0x000f
#define	CPU_uR0		0x0010
#define	CPU_uSP		0x001d
#define	CPU_uCC		0x001e
#define	CPU_uPC		0x001f

#define	SCOPE_NO_RESET	0x80000000
#define	SCOPE_TRIGGER	(0x08000000|SCOPE_NO_RESET)
#define	SCOPE_MANUAL	SCOPE_TRIGGER
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
