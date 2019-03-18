################################################################################
##
## Filename:	auto-data/Makefile
##
## Project:	OpenArty, an entirely open SoC based upon the Arty platform
##
## Purpose:	To direct the build of the autofpga automatically generated
##		files.  The various configuration files are the *.txt files
##	found in this directory.
##
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
.PHONY: all
all:	data
#
# Could also depend upon load, if desired, but not necessary
#
# This is the list of components that will form our project.  Each file consists
# of parts and pieces of our project that autofpga will copy/paste into our
# main project files.
#
BASE    := global.txt dlyarbiter.txt icape.txt
AUX     := version.txt buserr.txt pic.txt pwrcount.txt
IO      := spio.txt clrspio.txt # gpio.txt
RTC     := rtcgps.txt rtcdate.txt
DBGBUS  := wbuconsole.txt
MEMORY  := bkram.txt sdram.txt micron.txt # spansion.txt # wbhyperram.txt
CPU     := zipmaster.txt
NETWORK := mdio.txt enet.txt
GPS     := gps.txt
SDCARD  := # sdspi.txt
GFX     := # wboledrgb.txt
SCOPES  := # enetscope.txt mdioscope.txt # flashscope.txt cpuscope.txt
LDSCRIPT:= mem_flash_bkram.txt mem_bkram_only.txt mem_sdram_bkram.txt
DATA := allclocks.txt $(BASE) $(AUX) $(IO) $(RTC)			\
	$(DBGBUS) $(MEMORY) $(CPU) $(NETWORK) $(GPS) $(SDCARD) $(GFX)	\
	$(SCOPES) $(LDSCRIPT)

AUTOFPGA := autofpga
$(AUTOFPGA):

.PHONY: data
data: $(AUTOFPGA) $(DATA)
	$(AUTOFPGA) -d -o . $(DATA)

clean:
	rm -f toplevel.v main.v regdefs.h regdefs.cpp board.h board.ld
	rm -f rtl.make.inc main_tb.cpp
	rm -f dump.txt
