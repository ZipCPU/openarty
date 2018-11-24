////////////////////////////////////////////////////////////////////////////////
//
// Filename:	./regdefs.h
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// DO NOT EDIT THIS FILE!
// Computer Generated: This file is computer generated by AUTOFPGA. DO NOT EDIT.
// DO NOT EDIT THIS FILE!
//
// CmdLine:	autofpga autofpga -d -o . global.txt bkram.txt buserr.txt dlyarbiter.txt allclocks.txt spio.txt icape.txt mdio.txt gps.txt pic.txt pwrcount.txt rtcdate.txt rtcgps.txt clrspio.txt version.txt wbuconsole.txt zipmaster.txt sdspi.txt enet.txt flash.txt sdram.txt
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2017-2018, Gisselquist Technology, LLC
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


//
// The @REGDEFS.H.INCLUDE tag
//
// @REGDEFS.H.INCLUDE for masters
// @REGDEFS.H.INCLUDE for peripherals
// And finally any master REGDEFS.H.INCLUDE tags
// End of definitions from REGDEFS.H.INCLUDE


//
// Register address definitions, from @REGS.#d
//
// FLASH erase/program configuration registers
#define	R_FLASHCFG      	0x00800000	// 00800000, wbregs names: FLASHCFG, QSPIC
// SDSPI Debugging scope
#define	R_SDSPI_SCOPC   	0x01000000	// 01000000, wbregs names: SDSCOPC, SDSCOPE
#define	R_SDSPI_SCOPD   	0x01000004	// 01000000, wbregs names: SDSCOPD
// GPS UART registers, similar to WBUART
#define	R_GPSU_SETUP    	0x01800000	// 01800000, wbregs names: GPSSETUP
#define	R_GPSU_FIFO     	0x01800004	// 01800000, wbregs names: GPSFIFO
#define	R_GPSU_UARTRX   	0x01800008	// 01800000, wbregs names: GPSRX
#define	R_GPSU_UARTTX   	0x0180000c	// 01800000, wbregs names: GPSTX
// SD-SPI addresses
#define	R_SDSPI_CTRL    	0x02000000	// 02000000, wbregs names: SDCARD
#define	R_SDSPI_DATA    	0x02000004	// 02000000, wbregs names: SDDATA
#define	R_SDSPI_FIFOA   	0x02000008	// 02000000, wbregs names: SDFIFOA, SDFIF0, SDFIFA
#define	R_SDSPI_FIFOB   	0x0200000c	// 02000000, wbregs names: SDFIFOB, SDFIF1, SDFIFB
// CONSOLE registers
#define	R_CONSOLE_FIFO  	0x02800004	// 02800000, wbregs names: UFIFO
#define	R_CONSOLE_UARTRX	0x02800008	// 02800000, wbregs names: RX
#define	R_CONSOLE_UARTTX	0x0280000c	// 02800000, wbregs names: TX
#define	R_BUSERR        	0x03000000	// 03000000, wbregs names: BUSERR
#define	R_BUSERR        	0x03000000	// 03000000, wbregs names: BUSERR
#define	R_PIC           	0x03000004	// 03000004, wbregs names: PIC
#define	R_PIC           	0x03000004	// 03000004, wbregs names: PIC
#define	R_PWRCOUNT      	0x03000008	// 03000008, wbregs names: PWRCOUNT
#define	R_PWRCOUNT      	0x03000008	// 03000008, wbregs names: PWRCOUNT
#define	R_RTCDATE       	0x0300000c	// 0300000c, wbregs names: RTCDATE, DATE
#define	R_RTCDATE       	0x0300000c	// 0300000c, wbregs names: RTCDATE, DATE
#define	R_SPIO          	0x03000010	// 03000010, wbregs names: SPIO
#define	R_SPIO          	0x03000010	// 03000010, wbregs names: SPIO
#define	R_VERSION       	0x03000014	// 03000014, wbregs names: VERSION
#define	R_VERSION       	0x03000014	// 03000014, wbregs names: VERSION
// FPGA CONFIG REGISTERS: 0x4e0-0x4ff
#define	R_CFG_CRC       	0x03800000	// 03800000, wbregs names: FPGACRC
#define	R_CFG_FAR       	0x03800004	// 03800000, wbregs names: FPGAFAR
#define	R_CFG_FDRI      	0x03800008	// 03800000, wbregs names: FPGAFDRI
#define	R_CFG_FDRO      	0x0380000c	// 03800000, wbregs names: FPGAFDRO
#define	R_CFG_CMD       	0x03800010	// 03800000, wbregs names: FPGACMD
#define	R_CFG_CTL0      	0x03800014	// 03800000, wbregs names: FPGACTL0
#define	R_CFG_MASK      	0x03800018	// 03800000, wbregs names: FPGAMASK
#define	R_CFG_STAT      	0x0380001c	// 03800000, wbregs names: FPGASTAT
#define	R_CFG_LOUT      	0x03800020	// 03800000, wbregs names: FPGALOUT
#define	R_CFG_COR0      	0x03800024	// 03800000, wbregs names: FPGACOR0
#define	R_CFG_MFWR      	0x03800028	// 03800000, wbregs names: FPGAMFWR
#define	R_CFG_CBC       	0x0380002c	// 03800000, wbregs names: FPGACBC
#define	R_CFG_IDCODE    	0x03800030	// 03800000, wbregs names: FPGAIDCODE
#define	R_CFG_AXSS      	0x03800034	// 03800000, wbregs names: FPGAAXSS
#define	R_CFG_COR1      	0x03800038	// 03800000, wbregs names: FPGACOR1
#define	R_CFG_WBSTAR    	0x03800040	// 03800000, wbregs names: WBSTAR
#define	R_CFG_TIMER     	0x03800044	// 03800000, wbregs names: CFGTIMER
#define	R_CFG_BOOTSTS   	0x03800058	// 03800000, wbregs names: BOOTSTS
#define	R_CFG_CTL1      	0x03800060	// 03800000, wbregs names: FPGACTL1
#define	R_CFG_BSPI      	0x0380007c	// 03800000, wbregs names: FPGABSPI
// Ethernet configuration (MDIO) port
#define	R_MDIO_BMCR     	0x04000000	// 04000000, wbregs names: BMCR
#define	R_MDIO_BMSR     	0x04000004	// 04000000, wbregs names: BMSR
#define	R_MDIO_PHYIDR1  	0x04000008	// 04000000, wbregs names: PHYIDR1
#define	R_MDIO_PHYIDR2  	0x0400000c	// 04000000, wbregs names: PHYIDR2
#define	R_MDIO_ANAR     	0x04000010	// 04000000, wbregs names: ANAR
#define	R_MDIO_ANLPAR   	0x04000014	// 04000000, wbregs names: ANLPAR
#define	R_MDIO_ANER     	0x04000018	// 04000000, wbregs names: ANER
#define	R_MDIO_ANNPTR   	0x0400001c	// 04000000, wbregs names: ANNPTR
#define	R_MDIO_PHYSTS   	0x04000040	// 04000000, wbregs names: PHYSYTS
#define	R_MDIO_FCSCR    	0x04000050	// 04000000, wbregs names: FCSCR
#define	R_MDIO_RECR     	0x04000054	// 04000000, wbregs names: RECR
#define	R_MDIO_PCSR     	0x04000058	// 04000000, wbregs names: PCSR
#define	R_MDIO_RBR      	0x0400005c	// 04000000, wbregs names: RBR
#define	R_MDIO_LEDCR    	0x04000060	// 04000000, wbregs names: LEDCR
#define	R_MDIO_PHYCR    	0x04000064	// 04000000, wbregs names: PHYCR
#define	R_MDIO_BTSCR    	0x04000068	// 04000000, wbregs names: BTSCR
#define	R_MDIO_CDCTRL   	0x0400006c	// 04000000, wbregs names: CDCTRL
#define	R_MDIO_EDCR     	0x04000074	// 04000000, wbregs names: EDCR
#define	R_CLRLED        	0x04800000	// 04800000, wbregs names: CLRLED
#define	R_CLRLED0       	0x04800000	// 04800000, wbregs names: CLRLED0, CLR0
#define	R_CLRLED1       	0x04800004	// 04800000, wbregs names: CLRLED1, CLR1
#define	R_CLRLED2       	0x04800008	// 04800000, wbregs names: CLRLED2, CLR2
#define	R_CLRLED3       	0x0480000c	// 04800000, wbregs names: CLRLED3, CLR3
#define	R_CLRLED        	0x04800000	// 04800000, wbregs names: CLRLED
#define	R_CLRLED0       	0x04800000	// 04800000, wbregs names: CLRLED0, CLR0
#define	R_CLRLED1       	0x04800004	// 04800000, wbregs names: CLRLED1, CLR1
#define	R_CLRLED2       	0x04800008	// 04800000, wbregs names: CLRLED2, CLR2
#define	R_CLRLED3       	0x0480000c	// 04800000, wbregs names: CLRLED3, CLR3
// GPS clock tracker, control loop settings registers
#define	R_GPS_ALPHA     	0x04800020	// 04800020, wbregs names: ALPHA
#define	R_GPS_BETA      	0x04800024	// 04800020, wbregs names: BETA
#define	R_GPS_GAMMA     	0x04800028	// 04800020, wbregs names: GAMMA
#define	R_GPS_STEP      	0x0480002c	// 04800020, wbregs names: STEP
// GPS clock tracker, control loop settings registers
#define	R_GPS_ALPHA     	0x04800020	// 04800020, wbregs names: ALPHA
#define	R_GPS_BETA      	0x04800024	// 04800020, wbregs names: BETA
#define	R_GPS_GAMMA     	0x04800028	// 04800020, wbregs names: GAMMA
#define	R_GPS_STEP      	0x0480002c	// 04800020, wbregs names: STEP
// RTC clock registers
#define	R_CLOCK         	0x04800040	// 04800040, wbregs names: CLOCK
#define	R_TIMER         	0x04800044	// 04800040, wbregs names: TIMER
#define	R_STOPWATCH     	0x04800048	// 04800040, wbregs names: STOPWATCH
#define	R_CKALARM       	0x0480004c	// 04800040, wbregs names: ALARM, CKALARM
// RTC clock registers
#define	R_CLOCK         	0x04800040	// 04800040, wbregs names: CLOCK
#define	R_TIMER         	0x04800044	// 04800040, wbregs names: TIMER
#define	R_STOPWATCH     	0x04800048	// 04800040, wbregs names: STOPWATCH
#define	R_CKALARM       	0x0480004c	// 04800040, wbregs names: ALARM, CKALARM
// GPS clock test bench registers, for measuring the clock trackers performance
#define	R_GPSTB_FREQ    	0x04800060	// 04800060, wbregs names: GPSFREQ
#define	R_GPSTB_JUMP    	0x04800064	// 04800060, wbregs names: GPSJUMP
#define	R_GPSTB_ERRHI   	0x04800068	// 04800060, wbregs names: ERRHI
#define	R_GPSTB_ERRLO   	0x0480006c	// 04800060, wbregs names: ERRLO
#define	R_GPSTB_COUNTHI 	0x04800070	// 04800060, wbregs names: CNTHI
#define	R_GPSTB_COUNTLO 	0x04800074	// 04800060, wbregs names: CNTLO
#define	R_GPSTB_STEPHI  	0x04800078	// 04800060, wbregs names: STEPHI
#define	R_GPSTB_STEPLO  	0x0480007c	// 04800060, wbregs names: STEPLO
// GPS clock test bench registers, for measuring the clock trackers performance
#define	R_GPSTB_FREQ    	0x04800060	// 04800060, wbregs names: GPSFREQ
#define	R_GPSTB_JUMP    	0x04800064	// 04800060, wbregs names: GPSJUMP
#define	R_GPSTB_ERRHI   	0x04800068	// 04800060, wbregs names: ERRHI
#define	R_GPSTB_ERRLO   	0x0480006c	// 04800060, wbregs names: ERRLO
#define	R_GPSTB_COUNTHI 	0x04800070	// 04800060, wbregs names: CNTHI
#define	R_GPSTB_COUNTLO 	0x04800074	// 04800060, wbregs names: CNTLO
#define	R_GPSTB_STEPHI  	0x04800078	// 04800060, wbregs names: STEPHI
#define	R_GPSTB_STEPLO  	0x0480007c	// 04800060, wbregs names: STEPLO
#define	R_NET_RXCMD     	0x04800080	// 04800080, wbregs names: RXCMD, NETRX
#define	R_NET_TXCMD     	0x04800084	// 04800080, wbregs names: TXCMD, NETTX
#define	R_NET_MACHI     	0x04800088	// 04800080, wbregs names: MACHI
#define	R_NET_MACLO     	0x0480008c	// 04800080, wbregs names: MACLO
#define	R_NET_RXMISS    	0x04800090	// 04800080, wbregs names: NETMISS
#define	R_NET_RXERR     	0x04800094	// 04800080, wbregs names: NETERR
#define	R_NET_RXCRC     	0x04800098	// 04800080, wbregs names: NETCRCERR
#define	R_NET_TXCOL     	0x0480009c	// 04800080, wbregs names: NETCOL
#define	R_NET_RXCMD     	0x04800080	// 04800080, wbregs names: RXCMD, NETRX
#define	R_NET_TXCMD     	0x04800084	// 04800080, wbregs names: TXCMD, NETTX
#define	R_NET_MACHI     	0x04800088	// 04800080, wbregs names: MACHI
#define	R_NET_MACLO     	0x0480008c	// 04800080, wbregs names: MACLO
#define	R_NET_RXMISS    	0x04800090	// 04800080, wbregs names: NETMISS
#define	R_NET_RXERR     	0x04800094	// 04800080, wbregs names: NETERR
#define	R_NET_RXCRC     	0x04800098	// 04800080, wbregs names: NETCRCERR
#define	R_NET_TXCOL     	0x0480009c	// 04800080, wbregs names: NETCOL
#define	R_NET_RXBUF     	0x05000000	// 05000000, wbregs names: NETRXB
#define	R_NET_TXBUF     	0x05002000	// 05000000, wbregs names: NETTXB
#define	R_BKRAM         	0x05800000	// 05800000, wbregs names: RAM
#define	R_FLASH         	0x06000000	// 06000000, wbregs names: FLASH
#define	R_SDRAM         	0x08000000	// 08000000, wbregs names: SDRAM


//
// The @REGDEFS.H.DEFNS tag
//
// @REGDEFS.H.DEFNS for masters
#define	R_ZIPCTRL	0x10000000
#define	R_ZIPDATA	0x10000004
// #define	RESET_ADDRESS	0x06400000
#define	BAUDRATE	1000000
// @REGDEFS.H.DEFNS for peripherals
#define	SDRAMBASE	0x08000000
#define	SDRAMLEN	0x20000000
// And ... since the SDRAM defines the clock rate
#define	CLKFREQHZ	81250000
#define	BKRAMBASE	0x05800000
#define	BKRAMLEN	0x00020000
#define	FLASHBASE	0x06000000
#define	FLASHLEN	0x01000000
#define	FLASHLGLEN	24
// @REGDEFS.H.DEFNS at the top level
// End of definitions from REGDEFS.H.DEFNS
//
// The @REGDEFS.H.INSERT tag
//
// @REGDEFS.H.INSERT for masters

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

#ifdef	FLASH_ACCESS
#define	RESET_ADDRESS 0x06400000
#elif	defined(SDRAM_ACCESS)
#define	RESET_ADDRESS 0x08000000
#elif	defined(BKRAM_ACCESS)
#define	RESET_ADDRESS 0x05800000
#endif

// @REGDEFS.H.INSERT for peripherals
// Flash control constants
#define	QSPI_FLASH	// This core and hardware support a Quad SPI flash
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

// @REGDEFS.H.INSERT from the top level
typedef	struct {
	unsigned	m_addr;
	const char	*m_name;
} REGNAME;

extern	const	REGNAME	*bregs;
extern	const	int	NREGS;
// #define	NREGS	(sizeof(bregs)/sizeof(bregs[0]))

extern	unsigned	addrdecode(const char *v);
extern	const	char *addrname(const unsigned v);
// End of definitions from REGDEFS.H.INSERT


#endif	// REGDEFS_H
