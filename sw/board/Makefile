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
## Copyright (C) 2016-2019, Gisselquist Technology, LLC
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
PROGRAMS := exstartup oledtest gpsdump exmulti cputest cputestcis hello gettysburg simple_ping
all:	$(PROGRAMS)
#
#
CC	:=zip-gcc
AS	:=zip-as
LD	:=zip-ld
NM	:=zip-nm
OBJDIR	:= obj-zip
RDELF	:= zip-readelf
OBJDUMP := zip-objdump
SUBMAKE:= $(MAKE) --no-print-directory -C
#
#
SOURCES := exstartup.c gpsdump.c oledtest.c exmulti.c simple_ping.c ipcksum.c cputest.c hello.c gettysburg.c # ntpserver.c
HEADERS :=
DUMPRTL := -fdump-rtl-all
DUMPTREE:= -fdump-tree-all
LFLAGS  := -T board.ld -L../zlib -Wl,--start-group -larty -lgcc
INCS    := -I../zlib -I../../rtl -I.
LFLAGSD := -T sdram.ld -L../zlib -Wl,--start-group -larty -lgcc
CFLAGS  := -O3 $(INCS)
#
# For source analysis, the following macros are defined:
#

%.o: $(OBJDIR)/%.o
$(OBJDIR)/%.o: %.c
	$(mk-objdir)
	$(CC) $(CFLAGS) -c $< -o $@
$(OBJDIR)/hello.o: hello.c
	$(mk-objdir)
	$(CC) -O3 -c $< -o $@
$(OBJDIR)/gettysburg.o: gettysburg.c
	$(mk-objdir)
	$(CC) -O3 -c $< -o $@
$(OBJDIR)/%.s: %.c
	$(mk-objdir)
	$(CC) $(CFLAGS) $(DUMPRTL) -S $< -o $@
$(OBJDIR)/%.txt: $(OBJDIR)/%.o
	bash -c "$(RDELF) -a $^ ; $(OBJDUMP) -S -D $^ " | tee $@
%.txt: %
	$(OBJDUMP) -S -D $^ > $@


#
# The CPUTest program here is special--it doesn't use the C library.  Hence,
# it must have the -fno-builtin flag in order to build, and the -Tbkram.ld
# linker script to build something that doesn't go into flash but directly into
# RAM instead.
#
$(OBJDIR)/cputest.o: cputest.c
	$(CC) $(CFLAGS) -c -Wa,-nocis -fno-builtin $< -o $@
$(OBJDIR)/cputestcis.o: cputest.c
	$(CC) $(CFLAGS) -c -Wa,-cis -fno-builtin $< -o $@
$(OBJDIR)/cputest.s: cputest.c
	$(CC) $(CFLAGS) -S -Wa,-cis -fno-builtin $< -o $@

$(OBJDIR)/cmptst.o: cmptst.c
	$(mk-objdir)
	$(CC) $(CFLAGS) -c $< -o $@

cputest: $(OBJDIR)/cputest.o bkram.ld
	$(CC) $(CFLAGS) -T bkram.ld -fno-builtin -Wl,-Map=$(OBJDIR)/cputest.map $(OBJDIR)/cputest.o -o $@
cputestcis: $(OBJDIR)/cputestcis.o bkram.ld
	$(CC) $(CFLAGS) -T bkram.ld -fno-builtin -Wl,-Map=$(OBJDIR)/cputestcis.map $(OBJDIR)/cputestcis.o -o $@


#
# Other programs are much simpler
exstartup: $(OBJDIR)/exstartup.o board.ld
	$(CC) $(CFLAGS) $(LFLAGS) $(OBJDIR)/exstartup.o -o $@

exmulti: $(OBJDIR)/exmulti.o board.ld
	$(CC) $(CFLAGS) $(LFLAGS) $(OBJDIR)/exmulti.o -o $@

gpsdump: $(OBJDIR)/gpsdump.o board.ld
	$(CC) $(CFLAGS) $(LFLAGS) $(OBJDIR)/gpsdump.o -o $@

hello: $(OBJDIR)/hello.o bkram.ld
	$(CC) $(CFLAGS) $(LFLAGS) $(OBJDIR)/hello.o -o $@
	# $(CC) $(CFLAGS) -T bkram.ld -L../zlib -Wl,--start-group -larty -lgcc $(OBJDIR)/hello.o -o $@

gettysburg: $(OBJDIR)/gettysburg.o board.ld
	$(CC) $(CFLAGS) $(LFLAGS) $(OBJDIR)/gettysburg.o -o $@

oledtest: $(OBJDIR)/oledtest.o $(OBJDIR)/splash.o $(OBJDIR)/mug.o
	$(CC) $(CFLAGS)  $(LFLAGS) $^ -o $@

simple_ping: $(OBJDIR)/simple_ping.o $(OBJDIR)/zipcpu.o
simple_ping: $(OBJDIR)/arp.o $(OBJDIR)/ipcksum.o $(OBJDIR)/ipcksum.o
	$(CC) -Wl,-Map=simple_ping.map $(CFLAGS) $(LFLAGS) $^ -o $@

cmptst: $(OBJDIR)/cmptst.o
	$(CC) $(CFLAGS) $(LFLAGS) $(OBJDIR)/cmptst.o -o $@

exstartup.txt: exstartup
	$(OBJDUMP) -S -D $^ > $@

define	mk-objdir
	@bash -c "if [ ! -e $(OBJDIR) ]; then mkdir -p $(OBJDIR)/; fi"
endef

define	build-depends
	@echo "Building dependency file(s)"
	$(mk-objdir)
	@$(CC) $(CFLAGS) -MM $(SOURCES) > $(OBJDIR)/xdepends.txt
	@sed -e 's/^.*.o: /$(OBJDIR)\/&/' < $(OBJDIR)/xdepends.txt > $(OBJDIR)/depends.txt
	@rm $(OBJDIR)/xdepends.txt
endef

tags: $(SOURCES) $(HEADERS)
	@echo "Generating tags"
	@ctags $(SOURCES) $(HEADERS)

.PHONY: clean
clean:
	rm -f $(PROGRAMS)
	rm -rf $(addsuffix .map,$(PROGRAMS))
	rm -rf $(addsuffix .txt,$(PROGRAMS))
	rm -rf $(OBJDIR)/

$(OBJDIR)/depends.txt: tags
	$(build-depends)

.PHONY: depends
depends:
	$(build-depends)

ifneq ($(MAKECMDGOALS),clean)
-include $(OBJDIR)/depends.txt
endif
