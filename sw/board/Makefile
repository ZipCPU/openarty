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
## Copyright (C) 2016-2017, Gisselquist Technology, LLC
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
PROGRAMS := exstartup oledtest gpsdump exmulti cputest cputestcis simple_ping hello gettysburg
all:	$(PROGRAMS)
OBJDIR := obj-zip
NM := zip-nm
RDELF := zip-readelf
CC := zip-gcc
OBJDUMP := zip-objdump
SOURCES := exstartup.c gpsdump.c oledtest.c exmulti.c simple_ping.c ipcksum.c cputest.c hello.c gettysburg.c # ntpserver.c
HEADERS :=
DUMPRTL := -fdump-rtl-all
DUMPTREE:= -fdump-tree-all
LFLAGS  := -T arty.ld -L../zlib -Wl,--start-group -larty
CFLAGS  := -O3 -I../zlib
#
# For source analysis, the following macros are defined:

#

%.o: $(OBJDIR)/%.o
$(OBJDIR)/%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@
$(OBJDIR)/hello.o: hello.c
	$(CC) -O3 -c $< -o $@
$(OBJDIR)/gettysburg.o: gettysburg.c
	$(CC) -O3 -c $< -o $@
$(OBJDIR)/%.s: %.c
	$(CC) $(CFLAGS) -fdump-rtl-all -S $< -o $@
$(OBJDIR)/%.txt: $(OBJDIR)/%.o
	bash -c "$(RDELF) -a $^ ; $(OBJDUMP) -S -D $^ " | tee $@
%.txt: %
	$(OBJDUMP) -S -D $^ > $@


#
# The CPUTest program here is special--it doesn't use the C library.  Hence,
# it must have the -fno-builtin flag in order to build, and the -Tartyram.ld
# linker script to build something that doesn't go into flash but directly into
# RAM instead.
#
$(OBJDIR)/cputest.o: cputest.c
	$(CC) $(CFLAGS) -c -Wa,-nocis -fno-builtin $< -o $@
$(OBJDIR)/cputestcis.o: cputest.c
	$(CC) $(CFLAGS) -c -Wa,-cis -fno-builtin $< -o $@
$(OBJDIR)/cputest.s: cputest.c
	$(CC) $(CFLAGS) -S -Wa,-cis -fno-builtin $< -o $@

cputest: $(OBJDIR)/cputest.o artyram.ld
	$(CC) $(CFLAGS) -T artyram.ld -fno-builtin -Wl,-Map=$(OBJDIR)/cputest.map $(OBJDIR)/cputest.o -o $@
cputestcis: $(OBJDIR)/cputestcis.o artyram.ld
	$(CC) $(CFLAGS) -T artyram.ld -fno-builtin -Wl,-Map=$(OBJDIR)/cputestcis.map $(OBJDIR)/cputestcis.o -o $@


#
# Other programs are much simpler
exstartup: $(OBJDIR)/exstartup.o arty.ld
	$(CC) $(CFLAGS) $(LFLAGS) $(OBJDIR)/exstartup.o -o $@

exmulti: $(OBJDIR)/exmulti.o arty.ld
	$(CC) $(CFLAGS) $(LFLAGS) $(OBJDIR)/exmulti.o -o $@

gpsdump: $(OBJDIR)/gpsdump.o arty.ld
	$(CC) $(CFLAGS) $(LFLAGS) $(OBJDIR)/gpsdump.o -o $@

hello: $(OBJDIR)/hello.o arty.ld
	$(CC) $(CFLAGS) $(LFLAGS) $(OBJDIR)/hello.o -o $@

gettysburg: $(OBJDIR)/gettysburg.o arty.ld
	$(CC) $(CFLAGS) $(LFLAGS) $(OBJDIR)/gettysburg.o -o $@

oledtest: $(OBJDIR)/oledtest.o $(OBJDIR)/splash.o $(OBJDIR)/mug.o
	$(CC) $(CFLAGS)  $(LFLAGS) $^ -o $@

simple_ping: $(OBJDIR)/simple_ping.o
simple_ping: $(OBJDIR)/arp.o $(OBJDIR)/ipcksum.o $(OBJDIR)/ipcksum.o arty.ld
	$(CC) $(CFLAGS) $(LFLAGS) $^ -o simple_ping

exstartup.txt: exstartup
	$(OBJDUMP) -S -D $^ > $@

clean:
	rm -rf $(PROGRAMS) $(addsuffix .map,$(PROGRAMS))
	rm -rf $(addsuffix .txt,$(PROGRAMS))
	rm -rf $(OBJDIR)/

define	build-depends
	@echo "Building dependency file(s)"
	@$(CC) $(CFLAGS) -MM $(SOURCES) > $(OBJDIR)/xdepends.txt
	@sed -e 's/^.*.o: /$(OBJDIR)\/&/' < $(OBJDIR)/xdepends.txt > $(OBJDIR)/depends.txt
	@rm $(OBJDIR)/xdepends.txt
endef

tags: $(SOURCES) $(HEADERS)
	@echo "Generating tags"
	@ctags $(SOURCES) $(HEADERS)

$(OBJDIR)/depends.txt: $(OBJDIR)/
	$(build-depends)

.PHONY: depends
depends:
	$(build-depends)

$(OBJDIR)/:
	@bash -c "if [ ! -e $(OBJDIR) ]; then mkdir -p $(OBJDIR)/; fi"

-include $(OBJDIR)/depends.txt
