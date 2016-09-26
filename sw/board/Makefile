################################################################################
##
## Filename:	Makefile
##
## Project:	OpenArty, an entirely open SoC based upon the Arty platform
##
## Purpose:	
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2015, Gisselquist Technology, LLC
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
## License:	GPL, v3, as defined and found on www.gnu.org,
##		http:##www.gnu.org/licenses/gpl.html
##
##
################################################################################
##
##
.PHONY: all
all:	exstartup
#

exstartup: exstartup.c artyboard.h zipsys.h arty.ld
	zip-gcc -O3 -T arty.ld -Wl,-Map=exstartup.map exstartup.c -o exstartup

exstartup.txt: exstartup
	zip-objdump -S -D exstartup > exstartup.txt

