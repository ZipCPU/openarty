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
all:	exstartup oledtest gpsdump
OBJDIR := obj-zip
CC := zip-gcc
OBJDUMP := zip-objdump
SOURCES := exstartup.c bootloader.c gpsdump.c oledtest.c
HEADERS := artyboard.h zipsys.h
#
# For source analysis, the following macros are defined:

#

%.o: $(OBJDIR)/%.o
$(OBJDIR)/%.o: %.c
	$(CC) -c -fno-builtin $< -o $@
%.txt: %
	$(OBJDUMP) -S -D $^ > $@

exstartup: exstartup.c artyboard.h zipsys.h arty.ld
	$(CC) -O3 -T arty.ld -fno-builtin -Wl,-Map=exstartup.map exstartup.c -o exstartup
gpsdump: $(OBJDIR)/gpsdump.o $(OBJDIR)/bootloader.o arty.ld
	$(CC) -O3 -T arty.ld -fno-builtin -Wl,-Map=gpsdump.map $(OBJDIR)/gpsdump.o $(OBJDIR)/bootloader.o -o $@
oledtest: $(OBJDIR)/oledtest.o $(OBJDIR)/bootloader.o $(OBJDIR)/splash.o $(OBJDIR)/mug.o arty.ld 
	$(CC) -O3 -T arty.ld -fno-builtin -Wl,-Map=gpsdump.map $(OBJDIR)/oledtest.o $(OBJDIR)/bootloader.o $(OBJDIR)/splash.o $(OBJDIR)/mug.o -o $@

exstartup.txt: exstartup
	$(OBJDUMP) -S -D $^ > $@

clean:
	rm -f exstartup exstartup.map exstartup.txt
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

$(OBJDIR)/:
	@bash -c "if [ ! -e $(OBJDIR) ]; then mkdir -p $(OBJDIR)/; fi"

-include $(OBJDIR)/depends.txt
