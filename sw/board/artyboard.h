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
#define	DMA_JIFFIES	(DMA_TRIGGER|0x0400)
#define	DMA_TMC		(DMA_TRIGGER|0x0800)
#define	DMA_TMB		(DMA_TRIGGER|0x0c00)
#define	DMA_TMA		(DMA_TRIGGER|0x1000)
#define	DMA_AUX		(DMA_TRIGGER|0x1400)
#define	DMA_PPS		(DMA_TRIGGER|0x1800)
#define	DMA_NETRX	(DMA_TRIGGER|0x1c00)
#define	DMA_NETTX	(DMA_TRIGGER|0x2000)
#define	DMA_UARTRX	(DMA_TRIGGER|0x2400)
#define	DMA_UARTTX	(DMA_TRIGGER|0x2800)
#define	DMA_GPSRX	(DMA_TRIGGER|0x2c00)
#define	DMA_GPSTX	(DMA_TRIGGER|0x3000)
#define	DMA_SDCARD	(DMA_TRIGGER|0x3400)
#define	DMA_OLED	(DMA_TRIGGER|0x3800)

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

typedef	struct	{
	unsigned	r_clock, r_stopwach, r_timer, r_alarm;
} RTC;

typedef	struct	{
	unsigned	g_alpha, g_beta, g_gamma, g_step;
} GPSTRACKER;

typedef	struct	{
	unsigned	rxcmd, txcmd;
	unsigned	mac[2];
	unsigned	rxmiss, rxerr, rxcrc, txcol;
#define	ENET_TXGO	0x004000
#define	ENET_TXBUSY	0x004000
#define	ENET_NOHWCRC	0x008000
#define	ENET_NOHWMAC	0x010000
#define	ENET_RESET	0x020000
#define	ENET_NOHWIPCHK	0x040000
#define	ENET_TXCMD(LEN)	((LEN)|ENET_TXBIT)
#define	ENET_TXCLR	0x038000
#define	ENET_TXCANCEL	0x000000
#define	ENET_RXAVAIL	0x004000
#define	ENET_RXBUSY	0x008000
#define	ENET_RXERR	0x010000
#define	ENET_RXMISS	0x020000
#define	ENET_RXCRC	0x040000	// Set on a CRC error
#define	ENET_RXLEN	rxcmd & 0x0ffff
#define	ENET_RXCLR	0x004000
#define	ENET_RXCLRERR	0x078000
#define	ENET_TXBUFLN(NET)	(1<<(NET.txcmd>>24))
#define	ENET_RXBUFLN(NET)	(1<<(NET.rxcmd>>24))
} ENETPACKET;

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

typedef struct {
	unsigned	f_ereg, f_status, f_nvconfig, f_vconfig,
			f_evconfig, f_flags, f_lock, f_;
	unsigned	f_id[5], f_unused[3];
	unsigned	f_otpc, f_otp[16];
} EFLASHCTRL;

typedef	struct	{
	int		io_version, io_pic;
	unsigned	*io_buserr;
	unsigned	io_pwrcount;
	unsigned	io_btnsw;
	unsigned	io_ledctrl;
	unsigned	io_auxsetup, io_gpssetup;
	unsigned	io_clrled[4];
	unsigned	io_rtcdate;
	unsigned	io_gpio;
	unsigned	io_uart_rx, io_uart_tx;
	unsigned	io_gps_rx, io_gps_tx;
	unsigned	io_gps_sec, io_gps_sub, io_gps_step;
	unsigned		io_reserved[32-21];
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
	unsigned	io_icape2[32];
	unsigned	io_enet_rx[1024];
	unsigned	io_enet_tx[1024];
} IOSPACE;

static volatile IOSPACE	* const sys = (IOSPACE *)0x0100;

static volatile SDCARD	* const sd = (SDCARD *)0x0120;

#define	BKRAM	(void *)0x0008000
#define	FLASH	(void *)0x0400000
#define	SDRAM	(void *)0x4000000
#define	CLOCKFREQHZ	81250000
#define	CLOCKFREQ_HZ	CLOCKFREQHZ
#define	RAMWORDS	0x800000

#endif
