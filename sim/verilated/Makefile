################################################################################
##
## Filename: 	Makefile
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

CXX	:= g++
OBJDIR  := obj-pc
RTLD	:= ../../rtl
VERILATOR_ROOT ?= $(shell bash -c 'verilator -V|grep VERILATOR_ROOT | head -1 | sed -e " s/^.*=\s*//"')
VROOT   := $(VERILATOR_ROOT)
GFXFLAGS:= `pkg-config gtkmm-3.0 --cflags`
GFXLIBS := `pkg-config gtkmm-3.0 --cflags --libs`
FLAGS	:= -Wall -Og -g
INCS	:= -I$(RTLD)/obj_dir/ -I$(RTLD) -I$(VROOT)/include
SOURCES := fastmaster_tb.cpp eqspiflashsim.cpp eqspiflash_tb.cpp	\
	oledsim.cpp enetctrlsim.cpp					\
	memsim.cpp sdspisim.cpp uartsim.cpp ddrsdramsim.cpp
HEADERS := ddrsdramsim.h enetctrlsim.h eqspiflashsim.h memsim.h	\
	oledsim.h pipecmdr.h port.h sdspisim.h testb.h uartsim.h
VOBJDR	:= $(RTLD)/obj_dir
VLIB	:= $(VROOT)/include/verilated.cpp
SIMSRCS := enetctrlsim.cpp eqspiflashsim.cpp	\
	memsim.cpp sdspisim.cpp uartsim.cpp oledsim.cpp
SIMOBJ := $(subst .cpp,.o,$(SIMSRCS))
SIMOBJS:= $(addprefix $(OBJDIR)/,$(SIMOBJ))
all:	$(OBJDIR)/ busmaster_tb eqspiflash_tb enetctrl_tb

$(OBJDIR)/:
	@bash -c "if [ ! -e $(OBJDIR) ]; then mkdir -p $(OBJDIR); fi"

$(OBJDIR)/%.o: %.cpp
	$(CXX) $(FLAGS) -c $< -o $@

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

$(OBJDIR)/fastmaster_tb.o: fastmaster_tb.cpp
	$(CXX) -DFASTCLK $(FLAGS) $(GFXFLAGS) $(INCS) -c $< -o $@



eqspiflash_tb: eqspiflash_tb.cpp $(OBJDIR)/eqspiflashsim.o $(VOBJDR)/Veqspiflash__ALL.a
	$(CXX) $(FLAGS) $(INCS) $^ $(VOBJDR)/Veqspiflash__ALL.a $(VLIB) -o $@

enetctrl_tb: enetctrl_tb.cpp $(OBJDIR)/enetctrlsim.o $(VOBJDR)/Venetctrl__ALL.a
	$(CXX) $(FLAGS) $(INCS) $^ $(VOBJDR)/Venetctrl__ALL.a $(VLIB) -o $@

fastmaster_tb: $(OBJDIR)/fastmaster_tb.o $(SIMOBJS) $(VOBJDR)/Vfastmaster__ALL.a
	$(CXX) $(GFXLIBS) $^ $(VOBJDR)/Vfastmaster__ALL.a $(VLIB) -o $@
busmaster_tb: $(OBJDIR)/busmaster_tb.o $(SIMOBJS) $(VOBJDR)/Vbusmaster__ALL.a
	$(CXX) $(GFXLIBS) $(INCS) $^ $(VOBJDR)/Vbusmaster__ALL.a $(VLIB) $(GFXLIBS) -o $@

define build-depends
	@echo "Building dependency file(s)"
	@$(CXX) $(GFXFLAGS) $(INCS) -MM $(SOURCES) > $(OBJDIR)/xdepends.txt
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
	rm -rf $(OBJDIR)/
	rm -f ./eqspiflash_tb
	rm -f ./enetctrl_tb
	rm -f ./fastmaster_tb
	rm -f ./busmaster_tb

.PHONY: depends
depends:
	$(build-depends)

$(OBJDIR)/depends.txt: $(OBJDIR)/ $(SOURCES) $(HEADERS)
	$(build-depends)

-include $(OBJDIR)/depends.txt
