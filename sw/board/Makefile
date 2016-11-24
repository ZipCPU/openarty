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
################################################################################
##
##
.PHONY: all
PROGRAMS := exstartup oledtest gpsdump exmulti cputest
all:	$(PROGRAMS)
OBJDIR := obj-zip
NM := zip-nm
RDELF := zip-readelf
CC := zip-gcc
OBJDUMP := zip-objdump
SOURCES := exstartup.c bootloader.c gpsdump.c oledtest.c exmulti.c
HEADERS := artyboard.h zipsys.h
DUMPRTL := -fdump-rtl-all
DUMPTREE:= -fdump-tree-all
#
# For source analysis, the following macros are defined:

#

%.o: $(OBJDIR)/%.o
$(OBJDIR)/%.o: %.c
	$(CC) -O3 -c -fno-builtin $< -o $@
$(OBJDIR)/%.s: %.c
	$(CC) -O3 -S -fno-builtin $< -o $@
$(OBJDIR)/%.txt: $(OBJDIR)/%.o
	bash -c "$(RDELF) -a $^ ; $(OBJDUMP) -S -D $^ " | tee $@
%.txt: %
	$(OBJDUMP) -S -D $^ > $@



exstartup: $(OBJDIR)/exstartup.o $(OBJDIR)/bootloader.o arty.ld
	$(CC) -O3 -T arty.ld -fno-builtin -Wl,-Map=exstartup.map $(OBJDIR)/exstartup.o $(OBJDIR)/bootloader.o -o exstartup

gpsdump: $(OBJDIR)/gpsdump.o $(OBJDIR)/bootloader.o arty.ld
	$(CC) -O3 -T arty.ld -fno-builtin -Wl,-Map=gpsdump.map $(OBJDIR)/bootloader.o $(OBJDIR)/gpsdump.o -o $@

oledtest: $(OBJDIR)/oledtest.o $(OBJDIR)/bootloader.o $(OBJDIR)/splash.o $(OBJDIR)/mug.o arty.ld 
	$(CC) -O3 -T arty.ld -fno-builtin -Wl,-Map=oledtest.map $(OBJDIR)/oledtest.o $(OBJDIR)/bootloader.o $(OBJDIR)/splash.o $(OBJDIR)/mug.o -o $@

exmulti: $(OBJDIR)/exmulti.o $(OBJDIR)/bootloader.o arty.ld 
	$(CC) -O3 -T arty.ld -fno-builtin -Wl,-Map=exmulti.map $(OBJDIR)/exmulti.o $(OBJDIR)/bootloader.o -o $@

cputest: $(OBJDIR)/cputest.o artyram.ld 
	$(CC) -O3 -T artyram.ld -fno-builtin -Wl,-Map=cputest.map $(OBJDIR)/cputest.o -o $@

exstartup.txt: exstartup
	$(OBJDUMP) -S -D $^ > $@

clean:
	rm -rf $(PROGRAMS) $(addsuffix .map,$(PROGRAMS)) $(addsuffix .txt,$(PROGRAMS))
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
