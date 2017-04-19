################################################################################
##
## Filename:	Makefile
##
## Project:	OpenArty, an entirely open SoC based upon the Arty platform
##
## Purpose:	
## Targets:	
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
.PHONY: all
PROGRAMS := wbregs netuart wbsettime wbprogram netsetup manping	\
	zipload zipstate zipdbg divutb dumpflash
SCOPES := eqspiscope etxscope erxscope cpuscope
all: $(PROGRAMS) $(SCOPES) gps
CXX := g++
OBJDIR := obj-pc
BUSSRCS := ttybus.cpp llcomms.cpp regdefs.cpp byteswap.cpp
SOURCES := wbregs.cpp wbprogram.cpp netuart.cpp wbsettime.cpp		\
	dumpflash.cpp eqspiscope.cpp flashdrvr.cpp 			\
	scopecls.cpp sdramscope.cpp					\
	zipload.cpp zipstate.cpp zipdbg.cpp		\
	erxscope.cpp etxscope.cpp netsetup.cpp cpuscope.cpp		\
	 mdioscope.cpp manping.cpp $(BUSSRCS)
	# ziprun.cpp cfgscope.cpp
HEADERS := llcomms.h ttybus.h devbus.h
OBJECTS := $(addprefix $(OBJDIR)/,$(subst .cpp,.o,$(SOURCES)))
BUSOBJS := $(addprefix $(OBJDIR)/,$(subst .cpp,.o,$(BUSSRCS)))
CFLAGS := -g -Wall -I.
LIBS :=
SUBMAKE := $(MAKE) --no-print-directory

%.o: $(OBJDIR)/%.o
$(OBJDIR)/%.o: %.cpp
	$(CXX) $(CFLAGS) -c $< -o $@
$(OBJDIR)/%.o: %.c
	$(CXX) $(CFLAGS) -c $< -o $@

.PHONY: gps
gps: $(BUSOBJS) $(OBJDIR)/scopecls.o
	@bash -c "if [[ -e gps/Makefile ]]; then $(SUBMAKE) --directory=gps; fi"

$(OBJDIR)/hsnetuart.o: netuart.cpp
	$(CXX) $(CFLAGS) -c -DHIGH_SPEED $< -o $@

.PHONY: clean
clean:
	rm -rf $(OBJDIR)/ $(PROGRAMS) a.out

$(OBJDIR)/scopecls.o: scopecls.cpp scopecls.h $(OBJDIR)/
$(OBJDIR)/eqspiscope.o: eqspiscope.cpp scopecls.h $(OBJDIR)/
$(OBJDIR)/dumpflash.o: dumpflash.cpp regdefs.h $(OBJDIR)/

netuart: $(OBJDIR)/netuart.o
	$(CXX) $(CFLAGS) $^ -o $@
hsnetuart: $(OBJDIR)/hsnetuart.o
	$(CXX) $(CFLAGS) $^ -o $@
#
# Some simple programs that just depend upon the ability to talk to the FPGA,
# and little more. 
wbsettime: $(OBJDIR)/wbsettime.o $(BUSOBJS)
	$(CXX) $(CFLAGS) $^ -o $@
mtest: $(OBJDIR)/mtest.o $(BUSOBJS)
	$(CXX) $(CFLAGS) $^ -o $@
manping: $(OBJDIR)/manping.o $(BUSOBJS)
	$(CXX) $(CFLAGS) $^ -o $@
zipstate: $(OBJDIR)/zipstate.o $(BUSOBJS)
	$(CXX) $(CFLAGS) $^ $(LIBS) -o $@
netsetup: $(OBJDIR)/netsetup.o $(BUSOBJS)
	$(CXX) $(CFLAGS) $^ $(LIBS) -o $@
wbregs: $(OBJDIR)/wbregs.o $(BUSOBJS)
	$(CXX) $(CFLAGS) $^ $(LIBS) -o $@
dumpflash: $(OBJDIR)/dumpflash.o $(BUSOBJS)
	$(CXX) $(CFLAGS) $^ $(LIBS) -o $@
divutb: $(OBJDIR)/divutb.o
	$(CXX) $(CFLAGS) $^ -o $@

#
# Programs that depend upon not just the bus objects, but the flash driver
# as well.
wbprogram: $(OBJDIR)/wbprogram.o $(OBJDIR)/flashdrvr.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
zipload: $(OBJDIR)/zipload.o $(OBJDIR)/flashdrvr.o $(BUSOBJS) $(OBJDIR)/zipelf.o
	$(CXX) -g $^ -lelf -o $@


## SCOPES
# These depend upon the scopecls.o, the bus objects, as well as their
# main file(s).
eqspiscope: $(OBJDIR)/eqspiscope.o $(OBJDIR)/scopecls.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
sdramscope: $(OBJDIR)/sdramscope.o $(OBJDIR)/scopecls.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
cfgscope: $(OBJDIR)/cfgscope.o $(OBJDIR)/scopecls.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
cpuscope: $(OBJDIR)/cpuscope.o $(OBJDIR)/scopecls.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
erxscope: $(OBJDIR)/erxscope.o $(OBJDIR)/scopecls.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
etxscope: $(OBJDIR)/etxscope.o $(OBJDIR)/scopecls.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
mdioscope: $(OBJDIR)/mdioscope.o $(OBJDIR)/scopecls.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
wbuscope: $(OBJDIR)/wbuscope.o $(OBJDIR)/scopecls.o $(BUSOBJS)
	$(CXX) -g $^ -o $@

#
DBGSRCS  := zopcodes.cpp twoc.cpp
DBGOBJS := $(addprefix $(OBJDIR)/,$(subst .cpp,.o,$(DBGSRCS)))
zipdbg: $(OBJDIR)/zipdbg.o $(BUSOBJS) $(DBGOBJS)
	$(CXX) -g $^ -lcurses -o $@

define	build-depends
	@echo "Building dependency file(s)"
	@bash -c "if [ ! -e $(OBJDIR) ]; then mkdir -p $(OBJDIR)/; fi"
	$(CXX) $(CPPFLAGS) -MM $(SOURCES) > $(OBJDIR)/xdepends.txt
	@sed -e 's/^.*.o: /$(OBJDIR)\/&/' < $(OBJDIR)/xdepends.txt > $(OBJDIR)/depends.txt
	@rm $(OBJDIR)/xdepends.txt
endef

tags: $(SOURCES) $(HEADERS)
	@echo "Generating tags"
	@ctags $(SOURCES) $(HEADERS)

.PHONY: depends
depends: tags
	$(build-depends)

$(OBJDIR)/depends.txt: $(SOURCES) $(HEADERS)
	$(build-depends)

$(OBJDIR)/:
	@bash -c "if [ ! -e $(OBJDIR) ]; then mkdir -p $(OBJDIR)/; fi"

-include $(OBJDIR)/depends.txt
