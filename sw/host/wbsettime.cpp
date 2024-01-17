////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbsettime.cpp
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To give a user access, via a command line program, to set the
//		real time clock within the FPGA.  Note, however, that the RTC
//	clock device only sets the subseconds field when you program it at the
//	top of a minute.  This program, therefore, will wait 'til the top of a 
//	minute to set the clock.  It can be annoying, but ... it works.
//
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
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <strings.h>
#include <ctype.h>
#include <string.h>
#include <signal.h>
#include <assert.h>
#include <time.h>

#include "port.h"
#include "llcomms.h"
#include "ttybus.h"
#include "regdefs.h"

DEVBUS	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

int main(int argc, char **argv) {
	bool	set_time = true, read_hack = false;

	FPGAOPEN(m_fpga);

	signal(SIGSTOP, closeup);
	signal(SIGHUP, closeup);


	time_t	now, then;

	// We first wait for a second change, because we don't know how
	// much time this will take.
	DEVBUS::BUSW	clockword = 0l, dateword = 0l;
	clockword = m_fpga->readio(R_CLOCK);

	now = time(NULL);
	while(time(NULL) == now)
		;

	if (set_time) {
		// Now, we have one second to set the time
		struct	tm	*tmp;
		int		sleepv = 0;

		then = now+1;
		tmp = localtime(&then);
		clockword &= ~0x03fffff;

		if (tmp->tm_sec != 0) {
			// printf("THEN SECONDS = %d, ADDING %d\n",
				// tmp->tm_sec, 60-tmp->tm_sec);
			if (tmp->tm_sec < 58)
				sleepv = 59 - tmp->tm_sec;
			then += 60 - tmp->tm_sec;
			tmp = localtime(&then);
			// printf("Sleeping %d seconds (THEN->SEC = %d)\n", sleepv, tmp->tm_sec);
		}

		// printf("ORIGINAL : %02d:%02d:%02d\n", tmp->tm_hour, tmp->tm_min, tmp->tm_sec);
		// Seconds
		clockword |= (((tmp->tm_sec)%10)&0x0f);
		clockword |= (((tmp->tm_sec)/10)&0x0f)<< 4;
		// Minutes
		clockword |= (((tmp->tm_min)%10)&0x0f)<< 8;
		clockword |= (((tmp->tm_min)/10)&0x0f)<<12;
		// Hours
		clockword |= (((tmp->tm_hour)%10)&0x0f)<<16;
		clockword |= (((tmp->tm_hour)/10)&0x0f)<<20;

		// Years
		dateword   = 0x00000000;
		dateword  |= (((tmp->tm_year+1900)/1000)&0x0f)<<28;
		dateword  |=((((tmp->tm_year+1900)/100 )%10)&0x0f)<<24;
		dateword  |=((((tmp->tm_year+1900)/10  )%10)&0x0f)<<20;
		dateword  |=((((tmp->tm_year+1900)     )%10)&0x0f)<<16;
		dateword  |= (((tmp->tm_mon +1)/10)&0x0f)<<12;
		dateword  |= (((tmp->tm_mon +1)%10)&0x0f)<< 8;
		dateword  |= (((tmp->tm_mday  )/10)&0x0f)<< 4;
		dateword  |= (((tmp->tm_mday  )%10)&0x0f);
		if (sleepv > 0)
			sleep(sleepv);

		while(time(NULL) < then)
			;
		m_fpga->writeio(R_CLOCK, clockword);

		printf("Time set to   %06x\n", clockword & 0x03fffff);
#ifdef R_DATE	// If we have the date capability
		m_fpga->writeio(R_DATE, dateword);
		printf("Date set to %08x\n", dateword);
		printf("(Now reads %08x)\n", m_fpga->readio(R_DATE));
#endif // R_DATE

		now = then;
	} if (read_hack) {
		then = time(NULL) + 5;
		while(time(NULL) < then)
			;
		clockword = m_fpga->readio(R_CLOCK);
	}
	
	if (m_fpga->poll())
		printf("FPGA was interrupted\n");
	delete	m_fpga;
}

