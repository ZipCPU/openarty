////////////////////////////////////////////////////////////////////////////////
//
// Filename:	./board.h
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
#ifndef	BOARD_H
#define	BOARD_H

// And, so that we can know what is and isn't defined
// from within our main.v file, let's include:
#include <design.h>

#include <design.h>
#include <cpudefs.h>

#define	_HAVE_ZIPSYS
#define	PIC	zip->z_pic

#ifdef	INCLUDE_ZIPCPU
#ifdef INCLUDE_DMA_CONTROLLER
#define	_HAVE_ZIPSYS_DMA
#endif	// INCLUDE_DMA_CONTROLLER
#ifdef INCLUDE_ACCOUNTING_COUNTERS
#define	_HAVE_ZIPSYS_PERFORMANCE_COUNTERS
#endif	// INCLUDE_ACCOUNTING_COUNTERS
#endif // INCLUDE_ZIPCPU


#define	CLKFREQHZ	81250000


// Network packet interface
#define	ENET_TXGO		0x004000
#define	ENET_TXBUSY		0x004000
#define	ENET_NOHWCRC		0x008000
#define	ENET_NOHWMAC		0x010000
#define	ENET_RESET		0x020000
#define	ENET_NOHWIPCHK		0x040000
#define	ENET_TXCMD(LEN)		((LEN)|ENET_TXGO)
#define	ENET_TXCLR		0x038000
#define	ENET_TXCANCEL		0x000000
#define	ENET_RXAVAIL		0x004000
#define	ENET_RXBUSY		0x008000
#define	ENET_RXMISS		0x010000
#define	ENET_RXERR		0x020000
#define	ENET_RXCRC		0x040000	// Set on a CRC error
#define	ENET_RXLEN		rxcmd & 0x0ffff
#define	ENET_RXCLR		0x004000
#define	ENET_RXBROADCAST	0x080000
#define	ENET_RXCLRERR		0x078000
#define	ENET_TXBUFLN(NET)	(1<<(NET.txcmd>>24))
#define	ENET_RXBUFLN(NET)	(1<<(NET.rxcmd>>24))
typedef	struct ENETPACKET_S {
	unsigned	n_rxcmd, n_txcmd;
	unsigned long	n_mac;
	unsigned	n_rxmiss, n_rxerr, n_rxcrc, n_txcol;
} ENETPACKET;


#define	SDSPI_SETAUX	0x0ff
#define	SDSPI_READAUX	0x0bf
#define	SDSPI_CMD		0x040
#define	SDSPI_ACMD		(0x040+55) // CMD55
#define	SDSPI_FIFO_OP	0x0800	// Read only
#define	SDSPI_WRITEOP	0x0c00	// Write to the FIFO
#define	SDSPI_ALTFIFO	0x1000
#define	SDSPI_BUSY		0x4000
#define	SDSPI_ERROR	0x8000
#define	SDSPI_CLEARERR	0x8000
#define	SDSPI_READ_SECTOR	((SDSPI_CMD|SDSPI_CLEARERR|SDSPI_FIFO_OP)+17)
#define	SDSPI_WRITE_SECTOR	((SDSPI_CMD|SDSPI_CLEARERR|SDSPI_WRITEOP)+24)

typedef	struct SDSPI_S {
	unsigned	sd_ctrl, sd_data, sd_fifo[2];
} SDSPI;


typedef	struct	RTCLIGHT_S	{
	unsigned	r_clock, r_stopwatch, r_timer, r_alarm;
} RTCLIGHT;


#ifndef	WBSCOPE_H
#define	WBSCOPE_H

#define	WBSCOPE_NO_RESET	0x800000000
#define	WBSCOPE_TRIGGER		(WBSCOPE_NO_RESET|0x08000000)
#define	WBSCOPE_MANUAL		(WBSCOPE_TRIGGER)
#define	WBSCOPE_DISABLE		0x04000000

typedef struct WBSCOPE_S {
	unsigned s_ctrl, s_data;
} WBSCOPE;
#endif


#ifndef	WBUART_H
#define	WBUART_H

#define UART_PARITY_NONE        0
#define UART_HWFLOW_OFF         0x40000000
#define UART_PARITY_ODD         0x04000000
#define UART_PARITY_EVEN        0x05000000
#define UART_PARITY_SPACE       0x06000000
#define UART_PARITY_MARK        0x07000000
#define UART_STOP_ONEBIT        0
#define UART_STOP_TWOBITS       0x08000000
#define UART_DATA_8BITS         0
#define UART_DATA_7BITS         0x10000000
#define UART_DATA_6BITS         0x20000000
#define UART_DATA_5BITS         0x30000000
#define UART_RX_BREAK           0x0800
#define UART_RX_FRAMEERR        0x0400
#define UART_RX_PARITYERR       0x0200
#define UART_RX_NOTREADY        0x0100
#define UART_RX_ERR             (-256)
#define UART_TX_BUSY            0x0100
#define UART_TX_BREAK           0x0200

typedef struct  WBUART_S {
	unsigned	u_setup;
	unsigned	u_fifo;
	unsigned	u_rx, u_tx;
} WBUART;

#endif	// WBUART_H



typedef	struct	GPSTRACKER_S	{
	unsigned	g_alpha, g_beta, g_gamma, g_step;
} GPSTRACKER;


// Offsets for the ICAPE2 interface
#define	CFG_CRC		0
#define	CFG_FAR		1
#define	CFG_FDRI	2
#define	CFG_FDRO	3
#define	CFG_CMD		4
#define	CFG_CTL0	5
#define	CFG_MASK	6
#define	CFG_STAT	7
#define	CFG_LOUT	8
#define	CFG_COR0	9
#define	CFG_MFWR	10
#define	CFG_CBC		11
#define	CFG_IDCODE	12
#define	CFG_AXSS	13
#define	CFG_COR1	14
#define	CFG_WBSTAR	16
#define	CFG_TIMER	17
#define	CFG_BOOTSTS	22
#define	CFG_CTL1	24
#define	CFG_BSPI	31


typedef	struct	GPSTB_S	{
	unsigned	tb_maxcount, tb_jump;
	unsigned long	tb_err, tb_count, tb_step;
} GPSTB;




#define	CLRLED_RED	0x0ff0000
#define	CLRLED_GREEN	0x000ff00
#define	CLRLED_BLUE	0x00000ff


typedef struct  CONSOLE_S {
	unsigned	u_setup;
	unsigned	u_fifo;
	unsigned	u_rx, u_tx;
} CONSOLE;



//
// The Ethernet MDIO interface
//
#define MDIO_BMCR	0x00
#define MDIO_BMSR	0x01
#define MDIO_PHYIDR1	0x02
#define MDIO_PHYIDR2	0x03
#define MDIO_ANAR	0x04
#define MDIO_ANLPAR	0x05
#define MDIO_ANLPARNP	0x05	// Duplicate register address
#define MDIO_ANER	0x06
#define MDIO_ANNPTR	0x07
#define MDIO_PHYSTS	0x10
#define MDIO_FCSCR	0x14
#define MDIO_RECR	0x15
#define MDIO_PCSR	0x16
#define MDIO_RBR	0x17
#define MDIO_LEDCR	0x18
#define MDIO_PHYCR	0x19
#define MDIO_BTSCR	0x1a
#define MDIO_CDCTRL	0x1b
#define MDIO_EDCR	0x1d

typedef struct ENETMDIO_S {
	unsigned	e_v[32];
} ENETMDIO;



#define	ALTPIC(A)	(1<<(A))


#define	SYSPIC(A)	(1<<(A))


#ifdef	SDRAM_ACCESS
#define	_BOARD_HAS_SDRAM
extern char	_sdram[0x20000000];
#endif	// SDRAM_ACCESS
#ifdef	ETHERNET_ACCESS
#define	_BOARD_HAS_ENETP
static volatile ENETPACKET *const _netp = ((ENETPACKET *)0x04800080);
#endif	// ETHERNET_ACCESS
#ifdef	SDSPI_ACCESS
#define	_BOARD_HAS_SDSPI
static volatile SDSPI *const _sdcard = ((SDSPI *)0x02000000);
#endif	// SDSPI_ACCESS
#ifdef	BKRAM_ACCESS
#define	_BOARD_HAS_BKRAM
extern char	_bkram[0x00020000];
#endif	// BKRAM_ACCESS
#ifdef	RTC_ACCESS
#define	_BOARD_HAS_RTCLIGHT
static volatile RTCLIGHT *const _rtc = ((RTCLIGHT *)0x04800040);
#endif	// RTC_ACCESS
#ifdef	FLASH_ACCESS
#define	_BOARD_HAS_FLASH
extern int _flash[1];
#endif	// FLASH_ACCESS
#define	_BOARD_HAS_BUSERR
static volatile unsigned *const _buserr = ((unsigned *)50331648);
#ifdef	FLASHCFG_ACCESS
#define	_BOARD_HAS_FLASHCFG
static volatile unsigned * const io_flctl = ((unsigned *)(0x00800000));
#endif	// FLASHCFG_ACCESS
#ifdef	SDSPI_SCOPE
#define	_BOARD_HAS_SDSPI_SCOPE
static volatile WBSCOPE *const _scope_sdcard = ((WBSCOPE *)0x01000000);
#endif	// SDSPI_SCOPE
#ifdef	GPSUART_ACCESS
#define	_BOARD_HAS_GPS_UART
static volatile WBUART *const gpsu = ((WBUART *)0x01800000);
#endif	// GPSUART_ACCESS
#ifdef	BUSPIC_ACCESS
#define	_BOARD_HAS_BUSPIC
static volatile unsigned *const _buspic = ((unsigned *)0x03000004);
#endif	// BUSPIC_ACCESS
#ifdef	CFG_ACCESS
#define	_BOARD_HAS_ICAPTETWO
static volatile unsigned *const _icape = ((unsigned *)58720256);
#endif	// CFG_ACCESS
#ifdef	SPIO_ACCESS
#define	_BOARD_HAS_spio
static volatile unsigned *const _io_spio = ((unsigned *)50331664);
#endif	// SPIO_ACCESS
#ifdef	CLRLED_ACCESS
#define	_BOARD_HAS_CLRLED
static volatile unsigned *const _io_clrled = ((unsigned *)0x04800000);
#endif	// CLRLED_ACCESS
#ifdef	PWRCOUNT_ACCESS
static volatile unsigned *const _pwrcount = ((unsigned *)0x03000008);
#endif	// PWRCOUNT_ACCESS
#ifdef	RTCDATE_ACCESS
#define	_BOARD_HAS_RTCDATE
static volatile unsigned *const _rtcdate = ((unsigned *)50331660);
#endif	// RTCDATE_ACCESS
#define	_BOARD_HAS_VERSION
#ifdef	BUSCONSOLE_ACCESS
#define	_BOARD_HAS_BUSCONSOLE
static volatile CONSOLE *const _uart = ((CONSOLE *)41943040);
#endif	// BUSCONSOLE_ACCESS
#ifdef	NETCTRL_ACCESS
#define	_BOARD_HAS_NETMDIO
static volatile ENETMDIO *const _mdio = ((ENETMDIO *)67108864);
#endif	// NETCTRL_ACCESS
//
// Interrupt assignments (3 PICs)
//
// PIC: buspic
#define	BUSPIC_SDCARD	BUSPIC(0)
#define	BUSPIC_SPIO	BUSPIC(1)
// PIC: altpic
#define	ALTPIC_UIC	ALTPIC(0)
#define	ALTPIC_UOC	ALTPIC(1)
#define	ALTPIC_UPC	ALTPIC(2)
#define	ALTPIC_UTC	ALTPIC(3)
#define	ALTPIC_MIC	ALTPIC(4)
#define	ALTPIC_MOC	ALTPIC(5)
#define	ALTPIC_MPC	ALTPIC(6)
#define	ALTPIC_MTC	ALTPIC(7)
#define	ALTPIC_RTC	ALTPIC(8)
#define	ALTPIC_GPSRX	ALTPIC(9)
#define	ALTPIC_GPSTX	ALTPIC(10)
#define	ALTPIC_GPSTXF	ALTPIC(11)
#define	ALTPIC_UARTTX	ALTPIC(12)
#define	ALTPIC_UARTRX	ALTPIC(13)
// PIC: syspic
#define	SYSPIC_DMAC	SYSPIC(0)
#define	SYSPIC_JIFFIES	SYSPIC(1)
#define	SYSPIC_TMC	SYSPIC(2)
#define	SYSPIC_TMB	SYSPIC(3)
#define	SYSPIC_TMA	SYSPIC(4)
#define	SYSPIC_ALT	SYSPIC(5)
#define	SYSPIC_BUS	SYSPIC(6)
#define	SYSPIC_NETTX	SYSPIC(7)
#define	SYSPIC_NETRX	SYSPIC(8)
#define	SYSPIC_SDCARD	SYSPIC(9)
#define	SYSPIC_GPSRXF	SYSPIC(10)
#define	SYSPIC_PPS	SYSPIC(11)
#define	SYSPIC_UARTTXF	SYSPIC(12)
#define	SYSPIC_UARTRXF	SYSPIC(13)
#define	SYSINT_GPSRXF	SYSINT(10)
#define	SYSINT_GPSTXF	SYSINT(11)
#define	SYSINT_GPSRX	ALTINT(9)
#define	SYSINT_GPSTX	ALTINT(10)


#define	SYSINT_PPS	SYSINT(11)


#endif	// BOARD_H
