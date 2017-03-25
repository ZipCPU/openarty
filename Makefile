################################################################################
##
## Filename:	Makefile
##
## Project:	OpenArty, an entirely open SoC based upon the Arty platform
##
## Purpose:	A master project makefile.  It tries to build all targets
##		within the project, mostly by directing subdirectory makes.
##
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2015-2017, Gisselquist Technology, LLC
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
all:	archive datestamp rtl sim sw
# all:	datestamp archive rtl sw sim bench bit
#
# Could also depend upon load, if desired, but not necessary
BENCH := `find bench -name Makefile` `find bench -name "*.cpp"` `find bench -name "*.h"`
SIM   := `find sim -name Makefile` `find sim -name "*.cpp"` `find sim -name "*.h"` `find sim -name "*.c"`
RTL   := `find rtl -name "*.v"` `find rtl -name Makefile`
NOTES := `find . -name "*.txt"` `find . -name "*.html"`
SW    := `find sw -name "*.cpp"` `find sw -name "*.c"`	\
	`find sw -name "*.h"`	`find sw -name "*.sh"`	\
	`find sw -name "*.py"`	`find sw -name "*.pl"`	\
	`find sw -name "*.png"`	`find sw -name Makefile`
DEVSW := `find sw-board -name "*.cpp"` `find sw-board -name "*.h"` \
	`find sw-board -name Makefile`
PROJ  := 
BIN  := `find xilinx -name "*.bit"`
CONSTRAINTS := arty.xdc migmem.xdc
YYMMDD:=`date +%Y%m%d`
SUBMAKE := $(MAKE) --no-print-directory

.PHONY: datestamp
datestamp:
	@bash -c 'if [ ! -e $(YYMMDD)-build.v ]; then rm -f 20??????-build.v; perl mkdatev.pl > $(YYMMDD)-build.v; rm -f rtl/builddate.v; fi'
	@bash -c 'if [ ! -e rtl/builddate.v ]; then cd rtl; cp ../$(YYMMDD)-build.v builddate.v; fi'

.PHONY: archive
archive:
	tar --transform s,^,$(YYMMDD)-arty/, -chjf $(YYMMDD)-arty.tjz $(BENCH) $(SW) $(RTL) $(SIM) $(NOTES) $(PROJ) $(BIN) $(CONSTRAINTS) README.md

.PHONY: verilated
verilated: datestamp
	$(SUBMAKE) --no-print-directory --directory=rtl

.PHONY: rtl
rtl: verilated

.PHONY: sim
sim: rtl
	$(SUBMAKE) --directory=sim/verilated

# .PHONY: bench
# bench: sw
#	cd sim/verilated ; $(MAKE) --no-print-directory

.PHONY: sw
sw: sw-host sw-board sw-zlib

.PHONY: sw-host
sw-host:
	$(SUBMAKE) --directory=sw/host

.PHONY: sw-zlib
sw-zlib:
	$(SUBMAKE) --directory=sw/zlib

.PHONY: sw-board
sw-board: sw-zlib
	$(SUBMAKE) --directory=sw/board

# .PHONY: bit
# bit:
#	cd xilinx ; $(MAKE) --no-print-directory xula.bit

.PHONY: clean
	$(SUBMAKE) --directory=rtl           clean
	$(SUBMAKE) --directory=sw/host       clean
	$(SUBMAKE) --directory=sw/board      clean
	$(SUBMAKE) --directory=sim/verilated clean
