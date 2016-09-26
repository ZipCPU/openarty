################################################################################
##
## Filename: 	Makefile
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
PROGRAMS := wbregs netuart wbsettime dumpflash wbprogram eqspiscope
all: $(PROGRAMS)
CXX := g++
OBJDIR := obj-pc
BUSOBJS := $(OBJDIR)/ttybus.o $(OBJDIR)/llcomms.o $(OBJDIR)/regdefs.o
SOURCES := wbregs.cpp wbprogram.cpp netuart.cpp wbsettime.cpp	\
	ttybus.cpp llcomms.cpp dumpflash.cpp eqspiscope.cpp flashdrvr.cpp \
	regdefs.cpp scopecls.cpp sdramscope.cpp ttybus.cpp	\
	cfgscope.cpp
	# ziprun.cpp zipload.cpp
HEADERS := llcomms.h ttybus.h devbus.h
OBJECTS := $(addprefix $(OBJDIR)/,$(subst .cpp,.o,$(SOURCES)))

%.o: $(OBJDIR)/%.o
$(OBJDIR)/%.o: %.cpp
	$(CXX) -g -c $< -o $@

$(OBJDIR)/hsnetuart.o: netuart.cpp
	$(CXX) -g -c -DHIGH_SPEED $< -o $@

.PHONY: clean
clean:
	rm -rf $(OBJDIR)/*.o $(PROGRAMS)

$(OBJDIR)/scopecls.o: scopecls.cpp scopecls.h
$(OBJDIR)/eqspiscope.o: eqspiscope.cpp scopecls.h
$(OBJDIR)/dumpflash.o: dumpflash.cpp regdefs.h

netuart: $(OBJDIR)/netuart.o
	$(CXX) -g $^ -o $@
hsnetuart: $(OBJDIR)/hsnetuart.o
	$(CXX) -g $^ -o $@
wbsettime: $(OBJDIR)/wbsettime.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
mtest: $(OBJDIR)/mtest.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
wbregs: $(OBJDIR)/wbregs.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
dumpflash: $(OBJDIR)/dumpflash.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
eqspiscope: $(OBJDIR)/eqspiscope.o $(OBJDIR)/scopecls.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
sdramscope: $(OBJDIR)/sdramscope.o $(OBJDIR)/scopecls.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
cfgscope: $(OBJDIR)/cfgscope.o $(OBJDIR)/scopecls.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
wbprogram: $(OBJDIR)/wbprogram.o $(OBJDIR)/flashdrvr.o $(BUSOBJS)
	$(CXX) -g $^ -o $@
# ziprun: $(OBJDIR)/ziprun.o $(OBJDIR)/flashdrvr.o $(BUSOBJS)
#	$(CXX) -g $^ -lelf -o $@
# zipdbg: zipdbg.cpp $(ZIPD)/zparser.cpp $(ZIPD)/zopcodes.cpp $(ZIPD)/twoc.cpp $(BUSOBJS)
#	$(CXX) -g -I../bench/cpp -I $(ZIPD)/ $^ -lncurses -o $@
# zipstate: zipstate.cpp $(BUSOBJS)
	# $(CXX) -g $^ -o $@

define	build-depends
	@echo "Building dependency file(s)"
	@$(CXX) $(CPPFLAGS) -MM $(SOURCES) > $(OBJDIR)/xdepends.txt
	@sed -e 's/^.*.o: /$(OBJDIR)\/&/' < $(OBJDIR)/xdepends.txt > $(OBJDIR)/depends.txt
	@rm $(OBJDIR)/xdepends.txt
endef

tags: $(SOURCES) $(HEADERS)
	@echo "Generating tags"
	@ctags $(SOURCES) $(HEADERS)

.PHONY: depends
depends: tags
	$(build-depends)

$(OBJDIR)/depends.txt: $(OBJDIR)/ $(SOURCES) $(HEADERS)
	$(build-depends)

$(OBJDIR)/:
	@bash -c "if [ ! -e $(OBJDIR) ]; then mkdir -p $(OBJDIR)/; fi"

-include $(OBJDIR)/depends.txt
