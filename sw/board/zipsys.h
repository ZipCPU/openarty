////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	zipsys.h
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Declare the capabilities and memory structure of the ZipSystem
//		for programs that must interact with it.
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
#ifndef	ZIPSYS_H
#define	ZIPSYS_H

typedef	struct	{
	volatile unsigned	ck, mem, pf, icnt;
} ZIPTASKCTRS;

typedef	struct	{
	volatile int	ctrl, len;
	volatile int	*rd, *wr;
} ZIPDMA;

#define	DMA_TRIGGER	0x00008000
#define	DMACLEAR	0xffed0000
#define	DMACCOPY	0x0fed0000
#define	DMACERR		0x40000000
#define	DMA_CONSTSRC	0x20000000
#define	DMA_CONSTDST	0x10000000
#define	DMAONEATATIME	0x0fed0001
#define	DMA_BUSY	0x80000000
#define	DMA_ERR		0x40000000

typedef	struct	{
	volatile int	pic, wdt, err, apic, tma, tmb, tmc,
		jiffies;
	ZIPTASKCTRS	m, u;
	ZIPDMA		dma;
} ZIPSYS;

#define	ZIPSYS_ADDR	0xc0000000

#define	SYSINT_DMAC	0x0001
#define	SYSINT_JIFFIES	0x0002
#define	SYSINT_TMC	0x0004
#define	SYSINT_TMB	0x0008
#define	SYSINT_TMA	0x0010
#define	SYSINT_AUX	0x0020
//
#define	SYSINT_PPS	0x0040
#define	SYSINT_NETRX	0x0080
#define	SYSINT_NETTX	0x0100
#define	SYSINT_UARTRX	0x0200
#define	SYSINT_UARTTX	0x0400
#define	SYSINT_GPSRX	0x0800
#define	SYSINT_GPSTX	0x1000
#define	SYSINT_SDCARD	0x2000
#define	SYSINT_OLED	0x4000


#define	ALTINT_UIC	0x0001
#define	ALTINT_UTC	0x0008
#define	ALTINT_MIC	0x0010
#define	ALTINT_MTC	0x0080
#define	ALTINT_RTC	0x0100
#define	ALTINT_BTN	0x0200
#define	ALTINT_SWITCH	0x0400
#define	ALTINT_FLASH	0x0800
#define	ALTINT_SCOP	0x1000
#define	ALTINT_GPIO	0x2000


#define	CC_Z		0x0001
#define	CC_C		0x0002
#define	CC_N		0x0004
#define	CC_V		0x0008
#define	CC_SLEEP	0x0010
#define	CC_GIE		0x0020
#define	CC_STEP		0x0040
#define	CC_BREAK	0x0080
#define	CC_ILL		0x0100
#define	CC_TRAPBIT	0x0200
#define	CC_BUSERR	0x0400
#define	CC_DIVERR	0x0800
#define	CC_FPUERR	0x1000
#define	CC_IPHASE	0x2000
#define	CC_MMUERR	0x8000
#define	CC_EXCEPTION	(CC_ILL|CC_BUSERR|CC_DIVERR|CC_FPUERR|CC_MMUERR)
#define	CC_FAULT	(CC_ILL|CC_BUSERR|CC_DIVERR|CC_FPUERR)

// extern void	zip_break(void);
extern void	zip_rtu(void);
extern void	zip_halt(void);
extern void	zip_idle(void);
extern void	zip_syscall(void);
extern void	zip_restore_context(int *);
extern void	zip_save_context(int *);
extern int	zip_bitrev(int v);
extern unsigned	zip_cc(void);
extern unsigned	zip_ucc(void);

extern	int	_top_of_heap[1];

extern	void	save_context(int *);
extern	void	restore_context(int *);
extern	int	syscall(int,int,int,int);

#ifndef	NULL
#define	NULL	((void *)0)
#endif

#define	EINT(A)	(0x80000000|(A<<16))
#define	DINT(A)	(0x00000000|(A<<16))
#define	CLEARPIC	0x7fff7fff
#define	DALLPIC		0x7fff0000	// Disable all PIC interrupt sources

static	ZIPSYS *const zip = (ZIPSYS *)(ZIPSYS_ADDR);

static inline void	DISABLE_INTS(void) {
	zip->pic = 0;
}

static inline void	ENABLE_INTS(void) {
	zip->pic = 0x80000000;
}

#endif
