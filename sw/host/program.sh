#!/bin/bash
################################################################################
##
## Filename: 	program.sh
## {{{
## Project:	OpenArty, an entirely open SoC based upon the Arty platform
##
## Purpose:	To install a new program into the Arty, using the alternate
##		programming slot (slot 1, starting at 0x470000).
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
## }}}
## Copyright (C) 2015-2024, Gisselquist Technology, LLC
## {{{
## This file is part of the OpenArty project.
##
## The OpenArty project is free software and gateware, licensed under the terms
## of the 3rd version of the GNU General Public License as published by the
## Free Software Foundation.
##
## This project is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
## for more details.
##
## You should have received a copy of the GNU General Public License along
## with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
## target there if the PDF file isn't present.)  If not, see
## <http://www.gnu.org/licenses/> for a copy.
## }}}
## License:	GPL, v3, as defined and found on www.gnu.org,
## {{{
##		http://www.gnu.org/licenses/gpl.html
##
################################################################################
##
## }}}
export PATH=$PATH:.
export BINFILE=../../xilinx/openarty.runs/impl_1/toplevel.bit

WBREGS=wbregs
WBPROG=wbprogram

RED=0x000f0000
GREEN=0x0000ff00
YELLOW=0x00170700
WHITE=0x000f0f0f
BLACK=0x00000000
DIMGREEN=0x00001f00

$WBREGS led 0x0ff
$WBREGS clrled0 $YELLOW
$WBREGS clrled1 $YELLOW
$WBREGS clrled2 $YELLOW
$WBREGS clrled3 $YELLOW

# 
# $WBREGS qspiv 0x8b	# Accomplished by the flash driver
#
$WBREGS stopwatch 2	# Clear and stop the stopwatch
$WBREGS stopwatch 1	# Start the stopwatch
$WBPROG @0x011c0000 $BINFILE
$WBREGS stopwatch 0	# Stop the stopwatch, we are done
$WBREGS stopwatch	# Print out the time on the stopwatch

$WBREGS led 0x0f0
$WBREGS clrled0 $DIMGREEN
$WBREGS clrled1 $DIMGREEN
$WBREGS clrled2 $DIMGREEN
$WBREGS clrled3 $DIMGREEN

$WBREGS wbstar 0x01c0000
$WBREGS fpgacmd 15
sleep 1

if [[ -x ./wbsettime ]]; then
  ./wbsettime
fi

