#!/bin/bash
################################################################################
##
## Filename: 	zprog.sh
##
## Project:	OpenArty, an entirely open SoC based upon the Arty platform
##
## Purpose:	To install a new program into the Arty, using the main
##		programming slot (slot 0).
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2015-2016, Gisselquist Technology, LLC
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
## with this program.  (It's in the $(ROOT)/doc directory, run make with no
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
echo $WBPROG @0x1000000 $BINFILE
$WBPROG @0x1000000 $BINFILE
$WBREGS stopwatch 0	# Stop the stopwatch, we are done
$WBREGS stopwatch	# Print out the time on the stopwatch

$WBREGS led 0x0f0
$WBREGS clrled0 $DIMGREEN
$WBREGS clrled1 $DIMGREEN
$WBREGS clrled2 $DIMGREEN
$WBREGS clrled3 $DIMGREEN

$WBREGS wbstar 0
$WBREGS fpgacmd 15
sleep 1

if [[ -x ./wbsettime ]]; then
  ./wbsettime
fi

