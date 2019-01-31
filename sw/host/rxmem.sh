#!/bin/bash
################################################################################
##
## Filename: 	rxmem.sh
##
## Project:	OpenArty, an entirely open SoC based upon the Arty platform
##
## Purpose:	A quick shell script for no other purpose than reading from the
##		network receive memory h/w buffer.
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2017-2019, Gisselquist Technology, LLC
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
wbregs	0x2000
wbregs	0x2004
wbregs	0x2008
wbregs	0x200c
wbregs	0x2010
wbregs	0x2014
wbregs	0x2018
wbregs	0x201c
wbregs	0x2020
wbregs	0x2024
wbregs	0x2028
wbregs	0x202c
wbregs	0x2030
wbregs	0x2034
wbregs	0x2038
wbregs	0x203c
