################################################################################
##
## Filename:	Makefile
##
## Project:	OpenArty, an entirely open SoC based upon the Arty platform
##
## Purpose:	To coordinate the build of a cycle accurate, Verilator based,
##		simulation of the main module.  Access to the simulation is
##	provided via the same software commands that will access the board, save
##	that the parameters are a touch different.  (See the access software for
##	more information ...)
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2015-2019, Gisselquist Technology, LLC
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
# Make certain the "all" target is the first and therefore the default target
all:
CXX	:= g++
OBJDIR	:= obj-pc
RTLD	:= ../../rtl
VOBJDR	:= $(RTLD)/obj_dir
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
VINC	:= -I$(VINCD) -I$(VINCD)/vltstd -I$(VOBJDR)
INCS	:= -I. -I../../sw/host -I$(RTLD) $(VINC)
#
# A list of our sources and headers
#
SOURCES := automaster_tb.cpp main_tb.cpp			\
	oledsim.cpp enetctrlsim.cpp zipelf.cpp byteswap.cpp	\
	memsim.cpp sdspisim.cpp uartsim.cpp flashsim.cpp
	## eqspiflashsim.cpp ddrsdramsim.cpp
HEADERS := ddrsdramsim.h enetctrlsim.h memsim.h			\
	oledsim.h port.h sdspisim.h testb.h uartsim.h zipelf.h \
	flashsim.h
VOBJDR	:= $(RTLD)/obj_dir
VOBJS   := $(OBJDIR)/verilated.o $(OBJDIR)/verilated_vcd_c.o
VMAIN	:= $(VOBJDR)/Vmain__ALL.a
SIMSRCS := enetctrlsim.cpp zipelf.cpp dbluartsim.cpp flashsim.cpp	\
	memsim.cpp sdspisim.cpp uartsim.cpp oledsim.cpp byteswap.cpp
SIMOBJ := $(subst .cpp,.o,$(SIMSRCS))
SIMOBJS:= $(addprefix $(OBJDIR)/,$(SIMOBJ))
#
PROGRAMS := main_tb enetctrl_tb
# Now the return to the "all" target, and fill in some details
all:	$(PROGRAMS) hex

$(OBJDIR)/%.o: %.cpp
	$(mk-objdir)
	$(CXX) $(FLAGS) $(INCS) -c $< -o $@

$(OBJDIR)/%.o: $(VINCD)/%.cpp
	$(mk-objdir)
	$(CXX) $(FLAGS) $(INCS) -c $< -o $@

.PHONY: hex
hex: $(subst $(RTLD)/,,$(wildcard $(RTLD)/*.hex))
%.hex: $(RTLD)/%.hex
	@bash -c "if [ ! -e $@ ]; then ln -s $< $@ ; fi"

.PHONY: oledsim.o
oledsim.o: $(OBJDIR)/oledsim.o
$(OBJDIR)/oledsim.o: oledsim.cpp
	$(CXX) $(FLAGS) $(GFXFLAGS) -c $< -o $@
#
$(OBJDIR)/main_tb.o: automaster_tb.cpp
	$(CXX) $(FLAGS) $(GFXFLAGS) $(INCS) -c $< -o $@


main_tb: $(OBJDIR)/main_tb.o $(OBJDIR)/zipelf.o $(SIMOBJS) $(VMAIN) $(VOBJS)
	$(CXX) $(FLAGS) $(GFXFLAGS) $(INCS) $^ $(GFXLIBS) -lelf -o $@

#
# The "clean" target, removing any and all remaining build products
#
.PHONY: clean
clean:
	rm -f *.vcd
	rm -f $(PROGRAMS)
	rm -rf $(OBJDIR)/

#
# The "depends" target, to know what files things depend upon.  The depends
# file itself is kept in $(OBJDIR)/depends.txt
#
define build-depends
	$(mk-objdir)
	@echo "Building dependency file"
	@$(CXX) $(VDEFS) $(GFXFLAGS) $(INCS) -MM $(SOURCES) > $(OBJDIR)/xdepends.txt
	@sed -e 's/^.*.o: /$(OBJDIR)\/&/' < $(OBJDIR)/xdepends.txt > $(OBJDIR)/depends.txt
	@rm $(OBJDIR)/xdepends.txt
endef

.PHONY: depends
depends: tags
	$(build-depends)

$(OBJDIR)/depends.txt: depends

enetctrl_tb: enetctrl_tb.cpp $(OBJDIR)/enetctrlsim.o
enetctrl_tb: $(VOBJS) $(VOBJDR)/Venetctrl__ALL.a
	$(CXX) $(FLAGS) $(INCS) $^ $(VOBJDR)/Venetctrl__ALL.a -o $@
#
define	mk-objdir
	@bash -c "if [ ! -e $(OBJDIR) ]; then mkdir -p $(OBJDIR); fi"
endef


#
# The "tags" target
#
tags:	$(SOURCES) $(HEADERS)
	@echo "Generating tags"
	@ctags $(SOURCES) $(HEADERS)


ifneq ($(MAKECMDGOALS),clean)
-include $(OBJDIR)/depends.txt
endif
