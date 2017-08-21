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
all:
CXX	:= g++
OBJDIR  := obj-pc
RTLD	:= ../../rtl
ifneq ($(VERILATOR_ROOT),)
VERILATOR:=$(VERILATOR_ROOT)/bin/verilator
else
VERILATOR_ROOT ?= $(shell bash -c 'verilator -V|grep VERILATOR_ROOT | head -1 | sed -e " s/^.*=\s*//"')
endif
export	$(VERILATOR)
VROOT   := $(VERILATOR_ROOT)
VDEFS   := $(shell ./vversion.sh)
GFXFLAGS:= `pkg-config gtkmm-3.0 --cflags`
GFXLIBS := `pkg-config gtkmm-3.0 --cflags --libs`
FLAGS	:= -Wall -Og -g $(VDEFS)
VINCD   := $(VROOT)/include
INCS	:= -I$(RTLD)/obj_dir/ -I$(RTLD) -I$(VINCD) -I$(VINCD)/vltstd
SOURCES := fastmaster_tb.cpp eqspiflashsim.cpp eqspiflash_tb.cpp	\
	oledsim.cpp enetctrlsim.cpp zipelf.cpp byteswap.cpp		\
	memsim.cpp sdspisim.cpp uartsim.cpp ddrsdramsim.cpp
HEADERS := ddrsdramsim.h enetctrlsim.h eqspiflashsim.h memsim.h	\
	oledsim.h pipecmdr.h port.h sdspisim.h testb.h uartsim.h zipelf.h
VOBJDR	:= $(RTLD)/obj_dir
VOBJS   := $(OBJDIR)/verilated.o $(OBJDIR)/verilated_vcd_c.o
SIMSRCS := enetctrlsim.cpp eqspiflashsim.cpp zipelf.cpp		\
	memsim.cpp sdspisim.cpp uartsim.cpp oledsim.cpp byteswap.cpp
SIMOBJ := $(subst .cpp,.o,$(SIMSRCS))
SIMOBJS:= $(addprefix $(OBJDIR)/,$(SIMOBJ))
PROGRAMS := busmaster_tb eqspiflash_tb enetctrl_tb
all:	$(PROGRAMS)

%.o: $(OBJDIR)/%.o
$(OBJDIR)/%.o: %.cpp
	$(mk-objdir)
	$(CXX) $(FLAGS) $(INCS) -c $< -o $@

$(OBJDIR)/%.o: $(VINCD)/%.cpp
	$(mk-objdir)
	$(CXX) $(FLAGS) $(INCS) -c $< -o $@

.PHONY: oledsim.o
oledsim.o: $(OBJDIR)/oledsim.o
$(OBJDIR)/oledsim.o: oledsim.cpp
	$(CXX) $(FLAGS) $(GFXFLAGS) -c $< -o $@

# While busmaster_tb.o isnt really dependent upon fastmaster_tb.o, this
# makes certain that all of the dependencies of fastmaster_tb are captured
# in busmaster.  Hence, if fastmaster_tb is remade/rebuilt because one of
# its dependencies change, so too is busmaster_tb.
#
$(OBJDIR)/busmaster_tb.o: fastmaster_tb.cpp
	$(CXX) $(FLAGS) $(GFXFLAGS) $(INCS) -c $< -o $@

# $(OBJDIR)/fastmaster_tb.o: fastmaster_tb.cpp
#	$(CXX) -DFASTCLK $(FLAGS) $(GFXFLAGS) $(INCS) -c $< -o $@



eqspiflash_tb: $(OBJDIR)/eqspiflash_tb.o $(OBJDIR)/eqspiflashsim.o
eqspiflash_tb: $(VOBJS) $(VOBJDR)/Veqspiflash__ALL.a
	$(CXX) $(FLAGS) $(INCS) $^ $(VOBJDR)/Veqspiflash__ALL.a -o $@

enetctrl_tb: enetctrl_tb.cpp $(OBJDIR)/enetctrlsim.o
enetctrl_tb: $(VOBJS) $(VOBJDR)/Venetctrl__ALL.a
	$(CXX) $(FLAGS) $(INCS) $^ $(VOBJDR)/Venetctrl__ALL.a -o $@

fastmaster_tb: $(OBJDIR)/fastmaster_tb.o $(SIMOBJS)
fastmaster_tb: $(VOBJS) $(VOBJDR)/Vfastmaster__ALL.a
	$(CXX) $(GFXLIBS) $^ $(VOBJDR)/Vfastmaster__ALL.a -lelf -o $@
busmaster_tb: $(OBJDIR)/busmaster_tb.o $(SIMOBJS)
busmaster_tb: $(VOBJS) $(VOBJDR)/Vbusmaster__ALL.a
	$(CXX) $(GFXLIBS) $(INCS) $^ $(VOBJDR)/Vbusmaster__ALL.a $(GFXLIBS) -lelf -o $@

define	mk-objdir
	@bash -c "if [ ! -e $(OBJDIR) ]; then mkdir -p $(OBJDIR); fi"
endef

define	build-depends
	@echo "Building dependency file(s)"
	$(mk-objdir)
	@$(CXX) $(VDEFS) $(GFXFLAGS) $(INCS) -MM $(SOURCES) > $(OBJDIR)/xdepends.txt
	@sed -e 's/^.*.o: /$(OBJDIR)\/&/' < $(OBJDIR)/xdepends.txt	\
		| sed -e 's/fastmaster_tb.o/busmaster_tb.o/g' 		\
		> $(OBJDIR)/depends.txt
	@rm $(OBJDIR)/xdepends.txt
endef

tags: $(SOURCES) $(HEADERS)
	@echo "Generating tags"
	@ctags $(SOURCES) $(HEADERS)

.PHONY: clean
clean:
	rm -f *.vcd
	rm -rf $(OBJDIR)/
	rm -f $(PROGRAMS)
	# rm -f ./fastmaster_tb

.PHONY: depends
depends: tags
	$(build-depends)

$(OBJDIR)/depends.txt: $(SOURCES) $(HEADERS)
	$(build-depends)

-include $(OBJDIR)/depends.txt
