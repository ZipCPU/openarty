////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	gettysburg.c
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	The classical "Hello, world!\r\n" program.  This one, however,
//		runs on the Arty using the PModUSBUART
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
#include <unistd.h>

const char	address[] = 
"\r\n"
"Gettysburg Address\r\n"
"----------------------\r\n\r\n"
"Four score and seven years ago our fathers brought forth on this continent, "
"a\r\nnew nation, conceived in Liberty, and dedicated to the proposition that "
"all men\r\nare created equal.\r\n"
"\r\n"
"Now we are engaged in a great civil war, testing whether that nation, or "
"any\r\nnation so conceived and so dedicated, can long endure. We are met on a "
"great\r\nbattle-field of that war. We have come to dedicate a portion of that "
"field, as\r\na final resting place for those who here gave their lives that "
"that nation\r\nmight live. It is altogether fitting and proper that we should "
"do this.\r\n"
"\r\n"
"But, in a larger sense, we can not dedicate-we can not consecrate-we can "
"not\r\nhallow-this ground. The brave men, living and dead, who struggled "
"here, have\r\nconsecrated it, far above our poor power to add or detract. "
"The world will\r\nlittle note, nor long remember what we say here, but it "
"can never forget what\r\nthey did here. It is for us the living, rather, "
"to be dedicated here to the\r\nunfinished work which they who fought "
"here have thus far so nobly advanced. It\r\nis rather for us to be here "
"dedicated to the great task remaining before\r\nus-that from these honored "
"dead we take increased devotion to that cause for\r\nwhich they gave "
"the last full measure of devotion-that we here highly resolve\r\nthat "
"these dead shall not have died in vain-that this nation, under God, "
"shall\r\nhave a new birth of freedom-and that government of the people, "
"by the people,\r\nfor the people, shall not perish from the earth.\r\n\r\n\r\n";


int	main(int argc, char **argv) {
	// Print the Gettysburg address out the UART!
	write(STDOUT_FILENO, address, sizeof(address));
	return 0;
}

