#!/bin/bash
################################################################################
##
## Filename: 	txmem.sh
##
## Project:	OpenArty, an entirely open SoC based upon the Arty platform
##
## Purpose:	A quick shell script for no other purpose than reading from the
##		network transmit hardware buffer.
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2017, Gisselquist Technology, LLC
##
## This program is free software (firmware): you can redistribute it and/or
## modify it under the terms of  the GNU General Public License as published
## by the Free Software Foundation, either version 3 of the License, or (at
## your option) any later version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
## for more details.
##
## You should have received a copy of the GNU General Public License along
## with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
## target there if the PDF file isn't present.)  If not, see
## <http://www.gnu.org/licenses/> for a copy.
##
## License:	GPL, v3, as defined and found on www.gnu.org,
##		http://www.gnu.org/licenses/gpl.html
##
##
################################################################################
##
##
wbregs	0x3000
wbregs	0x3004
wbregs	0x3008
wbregs	0x300c
wbregs	0x3010
wbregs	0x3014
wbregs	0x3018
wbregs	0x301c
wbregs	0x3020
wbregs	0x3024
wbregs	0x3028
wbregs	0x302c
wbregs	0x3030
wbregs	0x3034
wbregs	0x3038
wbregs	0x303c
