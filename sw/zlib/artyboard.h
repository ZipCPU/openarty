////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	artyboard.h
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	A description of the hardware and I/O parts and pieces specific
//		to the OpenArty distribution, for the purpose of writing
//	ZipCPU software that will run on the board.
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
#ifndef	ARTYBOARD_H
#define	ARTYBOARD_H

#include <stdint.h>

// We have the full ZIP System installed
#define	_HAVE_ZIPSYS_PERFORMANCE_COUNTERS
#define	_HAVE_ZIPSYS_DMA
#include "zipsys.h"

#define	GPIO_SET(X)	(X |(X<<16))
#define	GPIO_CLEAR(X)	(X<<16)
typedef	struct	{
	uint32_t	i_version;
	uint32_t	i_pic;
	uint32_t	*i_buserr;
	uint32_t	i_pwrcount;
	uint32_t	i_btnsw, i_leds;
	uint32_t	i_rtcdate;
	uint32_t	i_gpio;
	uint32_t	i_clrled[4];
	union	{
		unsigned long now;
		struct { uint32_t sec; uint32_t sub; };
	} i_tim;

	unsigned        i_gps_step;
	uint32_t	i_unused[32-15];
} BASICIO;

#define	SD_SETAUX	0x0ff
#define	SD_READAUX	0x0bf
#define	SD_CMD		0x040
#define	SD_FIFO_OP	0x0800	// Read only
#define	SD_WRITEOP	0x0c00	// Write to the FIFO
#define	SD_ALTFIFO	0x1000
#define	SD_BUSY		0x4000
#define	SD_ERROR	0x8000
#define	SD_CLEARERR	0x8000
#define	SD_READ_SECTOR	((SD_CMD|SD_CLEARERR|SD_FIFO_OP)+17)
#define	SD_WRITE_SECTOR	((SD_CMD|SD_CLEARERR|SD_WRITEOP)+24)

typedef	struct	{
	unsigned	sd_ctrl, sd_data, sd_fifo[2];
} SDCARD;


typedef	struct	RTCLIGHT_S {
	unsigned	r_clock, r_stopwatch, r_timer, r_alarm;
} RTCLIGHT;

typedef	struct	{
	unsigned	g_alpha, g_beta, g_gamma, g_step;
} GPSTRACKER;

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
typedef	struct	{
	unsigned	n_rxcmd, n_txcmd;
	unsigned long	n_mac;
	unsigned	n_rxmiss, n_rxerr, n_rxcrc, n_txcol;
} ENETPACKET;


#define	OLED_PMODEN		0x0010001
#define	OLED_PMODEN_OFF		0x0010000
#define	OLED_IOPWR		OLED_PMODEN
#define	OLED_VCCEN		0x0020002
#define	OLED_VCC_DISABLE	0x0020000
#define	OLED_RESET		0x0040000
#define	OLED_RESET_CLR		0x0040004
#define	OLED_FULLPOWER		(OLED_PMODEN|OLED_VCCEN|OLED_RESET_CLR)
#define	OLED_POWER_DOWN		(OLED_PMODEN_OFF|OLED_VCCEN|OLED_RESET_CLR)
#define	OLED_BUSY(dev)		(dev.o_ctrl & 1)
#define	OLED_DISPLAYON		0x0af	// To be sent over the control channel
typedef	struct {
	unsigned	o_ctrl, o_a, o_b, o_data;
} OLEDRGB;

typedef	struct {
	unsigned	tb_maxcount, tb_jump;
	unsigned long	tb_err, tb_count, tb_step;
} GPSTB;

#define	MDIO_BMCR	0x00
#define	MDIO_BMSR	0x01
#define	MDIO_PHYIDR1	0x02
#define	MDIO_PHYIDR2	0x03
#define	MDIO_ANAR	0x04
#define	MDIO_ANLPAR	0x05
#define	MDIO_ANLPARNP	0x05	// Duplicate register address
#define	MDIO_ANER	0x06
#define	MDIO_ANNPTR	0x07
#define	MDIO_PHYSTS	0x10
#define	MDIO_FCSCR	0x14
#define	MDIO_RECR	0x15
#define	MDIO_PCSR	0x16
#define	MDIO_RBR	0x17
#define	MDIO_LEDCR	0x18
#define	MDIO_PHYCR	0x19
#define	MDIO_BTSCR	0x1a
#define	MDIO_CDCTRL	0x1b
#define	MDIO_EDCR	0x1d

typedef	struct {
	unsigned	e_v[32];
} ENETMDIO;

typedef struct {
	unsigned	f_ereg, f_status, f_nvconfig, f_vconfig,
			f_evconfig, f_flags, f_lock, f_;
	unsigned	f_id[5], f_unused[2];
	unsigned	f_otpc, f_otp[16];
} EFLASHCTRL;

#define	EQSPI_SZPAGE	64
#define	EQSPI_NPAGES	256
#define	EQSPI_NSECTORS	256
#define	EQSPI_SECTORSZ	(EQSPI_SZPAGE * EQSPI_NPAGES)
#define	EQSPI_SECTOROF(A)	((A)& (-EQSPI_SECTORSZ))
#define	EQSPI_SUBSECTOROF(A)	((A)& (-1<<10))
#define	EQSPI_PAGEOF(A)		((A)& (-SZPAGE))
#define	EQSPI_ERASEFLAG	0xc00001be
#define	EQSPI_ERASECMD(A)	(EQSPI_ERASEFLAG | EQSPI_SECTOROF(A))
#define	EQSPI_ENABLEWP	0x00000000
#define	EQSPI_DISABLEWP	0x40000000

#define	UART_PARITY_NONE	0
#define	UART_HWFLOW_OFF		0x40000000
#define	UART_PARITY_ODD		0x04000000
#define	UART_PARITY_EVEN	0x05000000
#define	UART_PARITY_SPACE	0x06000000
#define	UART_PARITY_MARK	0x07000000
#define	UART_STOP_ONEBIT	0
#define	UART_STOP_TWOBITS	0x08000000
#define	UART_DATA_8BITS		0
#define	UART_DATA_7BITS		0x10000000
#define	UART_DATA_6BITS		0x20000000
#define	UART_DATA_5BITS		0x30000000
#define	UART_RX_BREAK		0x0800
#define	UART_RX_FRAMEERR	0x0400
#define	UART_RX_PARITYERR	0x0200
#define	UART_RX_NOTREADY	0x0100
#define	UART_RX_ERR		(-256)
#define	UART_TX_BUSY		0x0100
#define	UART_TX_BREAK		0x0200

typedef	struct	WBUART_S {
	unsigned	u_setup;
	unsigned	u_fifo;
	unsigned	u_rx, u_tx;
} WBUART;


#define	WBSCOPE_NO_RESET	0x80000000
#define	WBSCOPE_TRIGGER	(WBSCOPE_NO_RESET|0x08000000)
#define	WBSCOPE_MANUAL	WBSCOPE_TRIGGER
#define	WBSCOPE_DISABLE	0x04000000	// Disable the scope trigger
typedef	struct	WBSCOPE_S {
	unsigned	s_ctrl, s_data;
} WBSCOPE;



typedef	struct ARTYBOARD_S {
	BASICIO		io_b;
	WBSCOPE		io_scope[4];
	RTCLIGHT	io_rtc;
	OLEDRGB		io_oled;
	WBUART		io_uart;
	WBUART		io_gpsu;
	SDCARD		io_sd;
	unsigned	io_ignore_0[4];
	GPSTRACKER	io_gps;
	unsigned	io_ignore_1[4];
	GPSTB		io_gpstb;
	ENETPACKET	io_enet;
	unsigned	io_ignore_2[8];
	ENETMDIO	io_netmdio;
	EFLASHCTRL	io_eflash;	// 32 positions
	unsigned	io_icape2[32];
	unsigned	io_ignore_3[0x800-(0x700>>2)];
	unsigned	io_enet_rx[1024];
	unsigned	io_enet_tx[1024];
} ARTYBOARD;

#define	PERIPHERAL_ADDR	0x400

static	volatile ARTYBOARD	*const _sys    = (ARTYBOARD *)PERIPHERAL_ADDR;
#define	_ZIP_HAS_WBUART
static	volatile WBUART		*const _uart   = &((ARTYBOARD *)PERIPHERAL_ADDR)->io_uart;
#define	_ZIP_HAS_WBUARTX
#define	_uarttx		_uart->u_tx
#define	_ZIP_HAS_WBUARTRX
#define	_uartrx		_uart->u_rx
#define	_ZIP_HAS_UARTSETUP
#define	_uartsetup	_uart->u_setup

#define	_ZIP_HAS_RTC
static	volatile RTCLIGHT	*const _rtcdev = &((ARTYBOARD *)PERIPHERAL_ADDR)->io_rtc;
#define	_ZIP_HAS_RTDATE
static	volatile uint32_t	*const _rtdate = &((ARTYBOARD *)PERIPHERAL_ADDR)->io_b.i_rtcdate;
#define	_ZIP_HAS_SDCARD
static	volatile SDCARD		*const _sdcard = &((ARTYBOARD *)PERIPHERAL_ADDR)->io_sd;

#define	SYSTIMER	zip->z_tma
#define	SYSPIC		zip->z_pic
#define	ALTPIC		zip->z_zpic
#define	COUNTER		zip->z_m.ac_ck

#define	BKRAM	(void *)0x00020000
#define	FLASH	(void *)0x01000000
#define	SDRAM	(void *)0x10000000
#define	CLOCKFREQHZ	81250000
#define	CLOCKFREQ_HZ	CLOCKFREQHZ
//
#define	MEMLEN		0x00020000
#define	FLASHLEN	0x01000000
#define	SDRAMLEN	0x10000000

// Finally, let's assign some of our interrupts:
//
// We're allowed nine interrupts to the master interrupt controller in the
// ZipSys
#define	SYSINT_PPS	SYSINT(6)
#define	SYSINT_ENETRX	SYSINT(7)
#define	SYSINT_ENETTX	SYSINT(8)
#define	SYSINT_UARTRXF	SYSINT(9)
#define	SYSINT_UARTTXF	SYSINT(10)
#define	SYSINT_GPSRXF	SYSINT(11)
#define	SYSINT_GPSTXF	SYSINT(12)
#define	SYSINT_BUS	SYSINT(13)
#define	SYSINT_OLED	SYSINT(14)
//
#define	ALTINT_PPD	ALTINT(8)
#define	ALTINT_UARTRX	ALTINT(9)
#define	ALTINT_UARTTX	ALTINT(10)
#define	ALTINT_GPSRX	ALTINT(11)
#define	ALTINT_GPSTX	ALTINT(12)
//


// BUS Interrupts
#define	BUS_BUTTON	SYSINT(0)
#define	BUS_SWITCH	SYSINT(1)
#define	BUS_PPS		SYSINT(2)
#define	BUS_RTC		SYSINT(3)
#define	BUS_NETRX	SYSINT(4)
#define	BUS_NETTX	SYSINT(5)
#define	BUS_UARTRX	SYSINT(6)
#define	BUS_UARTTX	SYSINT(7)
#define	BUS_GPIO	SYSINT(8)
#define	BUS_FLASH	SYSINT(9)
#define	BUS_SCOPE	SYSINT(10)
#define	BUS_GPSRX	SYSINT(11)
#define	BUS_SDCARD	SYSINT(12)
#define	BUS_OLED	SYSINT(13)
// #define	BUS_ZIP SYSINT(14)


// DMA Interrupt parameters
#define	DMA_ONPPS	DMA_ONINT(6)
#define	DMA_ONNETRX	DMA_ONINT(7)
#define	DMA_ONNETTX	DMA_ONINT(8)
#define	DMA_ONUARTRXF	DMA_ONINT(9)
#define	DMA_ONUARTTXF	DMA_ONINT(10)
#define	DMA_ONGPSRXF	DMA_ONINT(11)
#define	DMA_ONGPSTXF	DMA_ONINT(12)
#define	DMA_ONBUS	DMA_ONINT(13)
#define	DMA_ONOLED	DMA_ONINT(14)

#endif	// define ARTYBOARD_H
