////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	ledcolors.h
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Just to provide some simple color constants that can be used
//		to drive the color LEDs present on the Arty.
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
#ifndef	LEDCOLORS_H
#define	LEDCOLORS_H

#define	LEDC_BRIGHTRED		0x0ff0000
#define	LEDC_BRIGHTGREEN	0x000ff00
#define	LEDC_BRIGHTBLUE		0x00000ff

#define	LEDC_RED		0x0070000
#define	LEDC_GREEN		0x0000700
#define	LEDC_BLUE		0x0000007
#define	LEDC_YELLOW		0x0070700

#define	LEDC_WHITE		0x0070707
#define	LEDC_OFF		0


#endif
