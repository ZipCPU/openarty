////////////////////////////////////////////////////////////////////////////////
//
// Filename:	dumpuart.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To produce any and all data from the UART port onto an output
//		pipe and/or an output file.  This replaces the minicom
//	interface.  This is necessary because 1) minicom can take a while to
//	set up, 2) the default interface is at 115200 Baud (not minicom's 
//	default), 3) this produces an unfiltered/unbuffered terminal output,
//	and 4) it also guarantees that output goes to a file (when requested).
//
// This program was originally a part of the S6SoC suite of host programs.  It
// has since been modified for the OpenArty project--mostly by just changing the
// data speed from 9.6kB to 115.2kB.
//
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
//
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <strings.h>
#include <ctype.h>
#include <string.h>
#include <signal.h>
#include <assert.h>
#include <termios.h>

int main(int argc, char **argv) {
	const char	*dev = argv[1];
	const	char	*fname = (argc>=3)?argv[2]:NULL;
	int	ttyfd = -1, dumpfd = -1;

	ttyfd = open(dev, O_RDONLY);
	if (fname)
		dumpfd = open(fname, O_CREAT|O_TRUNC|O_WRONLY, 0644);

	// Set the baud rate ...
	{
		struct	termios tb;

		tcgetattr(ttyfd, &tb);
		// Set to raw mode
		cfmakeraw(&tb);
		// Non-canonical mode (no line editing ...)
		tb.c_lflag &= (~(ICANON));
		// Set no parity
		tb.c_cflag &= (~(PARENB));
		// Set 8 data bits
		tb.c_cflag &= (~(CSIZE));
		tb.c_cflag |= CS8;
		// Turn on hardware flow control
		tb.c_cflag |= CRTSCTS;
		// One stop bit
		tb.c_cflag &= (~(CSTOPB));
		// 115200 Baud
		cfsetspeed(&tb, B115200);
		// Block until at least one byte is available
		tb.c_cc[VMIN] = 1;
		tb.c_cc[VTIME] = 0;
		// Commit the changes
		tcsetattr(ttyfd, TCSANOW, &tb);
	}

	/*
	if (isatty(STDOUT_FILENO)) {
		struct	termios	tb;
		tcgetattr(STDOUT_FILENO, &tb);
	}
	*/

	char	buf[64];
	int	nr;

	while((nr=read(ttyfd, buf, sizeof(buf)))>0) {
		if (dumpfd >= 0)
			write(dumpfd, buf, nr);
		write(STDOUT_FILENO, buf, nr);
	}

	close(ttyfd);
	if (dumpfd >= 0)
		close(dumpfd);
}
