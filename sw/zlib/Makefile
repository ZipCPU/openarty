################################################################################
##
## Filename: 	
##
## Project:	XuLA2-LX25 SoC based upon the ZipCPU
##
## Purpose:	
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2017, Gisselquist Technology, LLC
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
CC := zip-gcc
AR := zip-ar
OBJDIR := obj-zip
all: libxula9.a libxula25.a
CFLAGS: -ffreestanding

$(OBJDIR)/:
	@bash -c "if [[ ! -e $(OBJDIR) ]]; then mkdir -p $(OBJDIR); fi"

$(OBJDIR)/xula9.o: $(OBJDIR)/
$(OBJDIR)/xula9.o: bootloader.h
$(OBJDIR)/xula9.o: zipcpu.h
$(OBJDIR)/xula9.o: zipsys.h
$(OBJDIR)/xula9.o: crt0.c
$(OBJDIR)/xula9.o: syscalls.c
$(OBJDIR)/xula9.o: xulaboard.c
	$(CC) $(CFLAGS) -c xulaboard.c -o $(OBJDIR)/xula9.o

libxula9.a: $(OBJDIR)/xula9.o
	$(AR) -cru libxula9.a $(OBJDIR)/xula9.o


$(OBJDIR)/xula25.o: $(OBJDIR)/
$(OBJDIR)/xula25.o: bootloader.h
$(OBJDIR)/xula25.o: zipcpu.h
$(OBJDIR)/xula25.o: zipsys.h
$(OBJDIR)/xula25.o: crt0.c
$(OBJDIR)/xula25.o: syscalls.c
$(OBJDIR)/xula25.o: xulaboard.c
	$(CC) $(CFLAGS) -DXULA25 -c xulaboard.c -o $(OBJDIR)/xula25.o

libxula25.a: $(OBJDIR)/xula25.o
	$(AR) -cru libxula25.a $(OBJDIR)/xula25.o

clean:
	rm -rf libxula25.a libxula9.a $(OBJDIR)/
