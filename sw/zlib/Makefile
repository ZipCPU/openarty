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
all: libarty.a
CFLAGS: -ffreestanding

$(OBJDIR)/:
	@bash -c "if [[ ! -e $(OBJDIR) ]]; then mkdir -p $(OBJDIR); fi"

$(OBJDIR)/artyboard.o: $(OBJDIR)/
$(OBJDIR)/artyboard.o: bootloader.h
$(OBJDIR)/artyboard.o: zipcpu.h
$(OBJDIR)/artyboard.o: zipsys.h
$(OBJDIR)/artyboard.o: crt0.c
$(OBJDIR)/artyboard.o: syscalls.c
$(OBJDIR)/artyboard.o: artyboard.c
	$(CC) $(CFLAGS) -c artyboard.c -o $(OBJDIR)/artyboard.o

libarty.a: $(OBJDIR)/artyboard.o
	$(AR) -cru libarty.a $(OBJDIR)/artyboard.o


clean:
	rm -rf libarty.a libarty.a $(OBJDIR)/
