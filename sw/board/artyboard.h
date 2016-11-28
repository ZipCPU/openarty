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

// BUS Interrupts
#define	BUS_BUTTON	0x0001
#define	BUS_SWITCH	0x0002
#define	BUS_PPS		0x0004
#define	BUS_RTC		0x0008
#define	BUS_NETRX	0x0010
#define	BUS_NETTX	0x0020
#define	BUS_UARTRX	0x0040
#define	BUS_UARTTX	0x0080
#define	BUS_GPIO	0x0100
#define	BUS_FLASH	0x0200
#define	BUS_SCOPE	0x0400
#define	BUS_GPSRX	0x0800
#define	BUS_SDCARD	0x1000
#define	BUS_OLED	0x2000
#define	BUS_ZIP		0x4000

// DMA Interrupt parameters
#define	DMA_ONPPS	DMA_ONINT(6)
#define	DMA_ONNETRX	DMA_ONINT(7)
#define	DMA_ONNETTX	DMA_ONINT(8)
#define	DMA_ONUARTRX	DMA_ONINT(9)
#define	DMA_ONUARTTX	DMA_ONINT(10)
#define	DMA_ONGPSRX	DMA_ONINT(11)
#define	DMA_ONGPSTX	DMA_ONINT(12)
#define	DMA_ONSDCARD	DMA_ONINT(13)
#define	DMA_ONOLED	DMA_ONINT(14)

// That's our maximum number of interrupts.  Any more, and we'll need to 
// remove one.  Don't forget, the primary interrupt source will be the SYS_
// interrupts, and there's another set of AUX_ interrupts--both available if
// the ZipSystem is in use.

typedef	struct	{
	unsigned	s_ctrl, s_data;
} SCOPE;
#define	SCOPE_NO_RESET	0x80000000
#define	SCOPE_TRIGGER	(SCOPE_NO_RESET|0x08000000)
#define	SCOPE_MANUAL	SCOPE_TRIGGER
#define	SCOPE_DISABLE	0x04000000	// Disable the scope trigger

typedef	struct	{
	unsigned	sd_ctrl, sd_data, sd_fifo[2];
} SDCARD;
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
	unsigned	r_clock, r_stopwach, r_timer, r_alarm;
} RTC;

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

typedef	struct {
	unsigned	e_v[32];
} ENETMDIO;

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

typedef struct {
	unsigned	f_ereg, f_status, f_nvconfig, f_vconfig,
			f_evconfig, f_flags, f_lock, f_;
	unsigned	f_id[5], f_unused[3];
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

typedef	struct	{
	int		io_version, io_pic;
	unsigned	*io_buserr;
	unsigned	io_pwrcount;
	unsigned	io_btnsw;
	unsigned	io_ledctrl;
	unsigned	io_auxsetup, io_gpssetup;
#define	UART_PARITY_NONE	0
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
	unsigned	io_clrled[4];
	unsigned	io_rtcdate;
	unsigned	io_gpio;
#define	GPIO_SET(X)	(X |(X<<16))
#define	GPIO_CLEAR(X)	(X<<16)
	unsigned	io_uart_rx, io_uart_tx;
	unsigned	io_gps_rx, io_gps_tx;
#define	UART_RX_BREAK		0x0800
#define	UART_RX_FRAMEERR	0x0400
#define	UART_RX_PARITYERR	0x0200
#define	UART_RX_NOTREADY	0x0100
#define	UART_RX_ERR		(-256)
#define	UART_TX_BUSY		0x0100
#define	UART_TX_BREAK		0x0200
	union {
		unsigned long now;
		struct { unsigned sec; unsigned sub; };
	} io_tim;
	unsigned	io_gps_sec, io_gps_sub, io_gps_step;
	unsigned		io_reserved[32-23];
	SCOPE			io_scope[4];
	RTC			io_rtc;
	SDCARD			io_sd;
	GPSTRACKER		io_gps;
	OLEDRGB			io_oled;
	ENETPACKET		io_enet;
	GPSTB			io_gpstb;
	unsigned		io_ignore_1[8+16+64];
	ENETMDIO		io_netmdio;
	EFLASHCTRL		io_eflash;
	unsigned		io_icape2[32];
	unsigned		io_ignore_2[0x800-0x1e0-32-1];
	unsigned		io_enet_rx[1024];
	unsigned		io_enet_tx[1024];
} IOSPACE;

static volatile IOSPACE	* const sys = (IOSPACE *)0x0100;

static volatile SDCARD	* const sd = (SDCARD *)0x0120;

#define	BKRAM	(void *)0x0008000
#define	FLASH	(void *)0x0400000
#define	SDRAM	(void *)0x4000000
#define	CLOCKFREQHZ	81250000
#define	CLOCKFREQ_HZ	CLOCKFREQHZ
//
#define	MEMWORDS	0x0008000
#define	FLASHWORDS	0x0400000
#define	SDRAMWORDS	0x4000000

#endif
