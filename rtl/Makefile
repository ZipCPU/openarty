##########################################################################/
##
## Filename:	Makefile
##
## Project:	OpenArty, an entirely open SoC based upon the Arty platform
##
## Purpose:	To direct the Verilator build of the SoC sources.  The result
##		is C++ code (built by Verilator), that is then built (herein)
##	into a library.
##
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
##########################################################################/
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
##########################################################################/
##
##
all:	test
YYMMDD=`date +%Y%m%d`
CXX   := g++
FBDIR := .
VDIRFB:= $(FBDIR)/obj_dir

.PHONY: test
test: $(VDIRFB)/Veqspiflash__ALL.a
test: $(VDIRFB)/Venetctrl__ALL.a
# test: $(VDIRFB)/Vfastmaster__ALL.a
test: $(VDIRFB)/Vbusmaster__ALL.a

CPUDR := cpu
CPUSOURCESnD := zipcpu.v cpuops.v pfcache.v pipemem.v		\
			pfcache.v idecode.v wbpriarbiter.v zipbones.v	\
	zipsystem.v zipcounter.v zipjiffies.v ziptimer.v		\
		wbdmac.v icontrol.v wbwatchdog.v
CPUSOURCES := $(addprefix $(CPUDR)/,$(CPUSOURCESnD))

JTAGBUS := wbufifo.v wbubus.v wbucompactlines.v				\
	wbucompress.v wbudecompress.v wbudeword.v wbuexec.v		\
	wbuidleint.v wbuinput.v wbuoutput.v wbureadcw.v wbusixchar.v	\
	wbutohex.v
PERIPHERALS:= enetctrl.v enetpackets.v fastio.v rtcdate.v rtcgps.v	\
	rxuart.v txuart.v eqspiflash.v lleqspi.v flash_config.v		\
	wbicapetwo.v sdspi.v gpsclock_tb.v gpsclock.v wboled.v lloled.v	\
	wbscopc.v wbscope.v memdev.v addepreamble.v addemac.v addecrc.v
BIGMATH:= bigadd.v bigsmpy.v bigsub.v
SOURCES := fastmaster.v builddate.v					\
	$(CPUSOURCES) $(JTAGBUS) $(PERIPHERALS) $(BIGMATH)
SLOWSRC := busmaster.v builddate.v					\
	$(CPUSOURCES) $(JTAGBUS) $(PERIPHERALS) $(BIGMATH)

$(VDIRFB)/Vfastmaster__ALL.a: $(VDIRFB)/Vfastmaster.h $(VDIRFB)/Vfastmaster.cpp
$(VDIRFB)/Vfastmaster__ALL.a: $(VDIRFB)/Vfastmaster.mk
$(VDIRFB)/Vfastmaster.h $(VDIRFB)/Vfastmaster.cpp $(VDIRFB)/Vfastmaster.mk: $(SOURCES)

$(VDIRFB)/Vbusmaster__ALL.a: $(VDIRFB)/Vbusmaster.h $(VDIRFB)/Vbusmaster.cpp
$(VDIRFB)/Vbusmaster__ALL.a: $(VDIRFB)/Vbusmaster.mk
$(VDIRFB)/Vbusmaster.h $(VDIRFB)/Vbusmaster.cpp $(VDIRFB)/Vbusmaster.mk: $(SLOWSRC)

$(VDIRFB)/Venetctrl.h $(VDIRFB)/Venetctrl.cpp $(VDIRFB)/Venetctrl.mk: enetctrl.v
$(VDIRFB)/Veqspiflash.h $(VDIRFB)/Veqspiflash.cpp $(VDIRFB)/Veqspiflash.mk: eqspiflash.v lleqspi.v
$(VDIRFB)/V%.cpp $(VDIRFB)/V%.h $(VDIRFB)/V%.mk: $(FBDIR)/%.v
	verilator -cc -y $(CPUDR) $*.v 


$(VDIRFB)/V%__ALL.a: $(VDIRFB)/V%.mk
	cd $(VDIRFB); make -f V$*.mk

.PHONY:
archive:
	tar --transform s,^,$(YYMMDD)-rtl/, -chjf $(YYMMDD)-rtl.tjz Makefile *.v cpu/*.v

.PHONY: clean
clean:
	rm -rf $(VDIRFB)/*.mk
	rm -rf $(VDIRFB)/*.cpp
	rm -rf $(VDIRFB)/*.h
	rm -rf $(VDIRFB)/

