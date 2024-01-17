////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	gpsdump.c
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To dump the GPS UART to the auxiliary UART.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2024, Gisselquist Technology, LLC
// {{{
// This file is part of the OpenArty project.
//
// The OpenArty project is free software and gateware, licensed under the terms
// of the 3rd version of the GNU General Public License as published by the
// Free Software Foundation.
//
// This project is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
// }}}
#include "board.h"
#include "zipcpu.h"
#include "zipsys.h"

#ifdef	GPSUART_ACCESS
void main(int argc, char **argv) {
	/*
	// Method one: direct polling
	while(1) {
		int	ch;
		ch = sys->io_gps_rx;
		if ((ch&UART_RX_ERR)==0)
			sys->io_uart_tx = ch;
	}
	*/

	// Method two: Waiting on interrupts
	int	lglen = (1<<((_gpsu->u_fifo >> 12)&0x0f))-1;
	_zip->z_pic = SYSINT_GPSRXF;
	while(1) {
		while((_zip->z_pic & SYSINT_GPSRXF)==0)
			;
		for(int i=0; i<lglen/2; i++)
			_uart->u_tx = _gpsu->u_rx & 0x0ff;
		_zip->z_pic = SYSINT_GPSRXF;
	}

	/*
	// Method three: Use the DMA
	_zip->z_dma.d_ctrl = DMACLEAR;
	while(1) {
		_zip->z_dma.d_rd = (int *)&sys->io_gps_rx;
		_zip->z_dma.d_wr = (int *)&sys->io_uart_tx;
		_zip->z_dma.d_len = 0x01000000; // More than we'll ever do ...
		_zip->z_dma.d_ctrl = (DMAONEATATIME|DMA_CONSTDST|DMA_CONSTSRC|DMA_ONGPSRX);

		while(_zip->z_dma.d_ctrl & DMA_BUSY) {
			zip_idle();
			if (_zip->z_dma.d_ctrl & DMA_ERR)
				zip_halt();
		}
	}
	*/
}
#else
#include <stdio.h>

int	main(int argc, char **argv) {
	printf("This design requires the GPS UART to be installed\n");
}
#endif
