////////////////////////////////////////////////////////////////////////////////
//
// Filename:	automaster_tb.cpp
//
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	This file calls and accesses the main.v function via the
//		MAIN_TB class found in main_tb.cpp.  When put together with
//	the other components here, this file will simulate (all of) the
//	host's interaction with the FPGA circuit board.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2020, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
#include <signal.h>
#include <time.h>
#include <ctype.h>
#include <string.h>
#include <stdint.h>

#include "verilated.h"
#include "design.h"
#include "cpudefs.h"

#ifdef	OLEDRGB_ACCESS
#include "oledsim.h"
#endif

#include "testb.h"
// #include "twoc.h"

#include "port.h"

#include "main_tb.cpp"

void	usage(void) {
	fprintf(stderr, "USAGE: main_tb <options> [zipcpu-elf-file]\n");
	fprintf(stderr,
// -h
// -p # command port
// -s # serial port
// -f # profile file
#ifdef	SDSPI_ACCESS
"\t-c <img-file>\n"
"\t\tSpecifies a memory image which will be used to make the SD-card\n"
"\t\tmore realistic.  Reads from the SD-card will be directed to\n"
"\t\t\"sectors\" within this image.\n\n"
#endif
"\t-d\tSets the debugging flag\n"
"\t-t <filename>\n"
"\t\tTurns on tracing, sends the trace to <filename>--assumed to\n"
"\t\tbe a vcd file\n"
);
}

int	main(int argc, char **argv) {
#ifdef	OLEDRGB_ACCESS
	Gtk::Main	main_instance(argc, argv);
#endif
	Verilated::commandArgs(argc, argv);

	const	char *elfload = NULL,
#ifdef	SDSPI_ACCESS
			*sdimage_file = NULL,
#endif
			*profile_file = NULL,
			*trace_file = NULL; // "trace.vcd";
	bool	debug_flag = false, willexit = false;
	FILE	*profile_fp;

	MAINTB	*tb = new MAINTB;

	for(int argn=1; argn < argc; argn++) {
		if (argv[argn][0] == '-') for(int j=1;
					(j<512)&&(argv[argn][j]);j++) {
			switch(tolower(argv[argn][j])) {
#ifdef	SDSPI_ACCESS
			case 'c': sdimage_file = argv[++argn]; j = 1000; break;
#endif
			case 'd': debug_flag = true;
				if (trace_file == NULL)
					trace_file = "trace.vcd";
				break;
			case 'f': profile_file = "pfile.bin"; break;
			case 't': trace_file = argv[++argn]; j=1000; break;
			case 'h': usage(); exit(0); break;
			default:
				fprintf(stderr, "ERR: Unexpected flag, -%c\n\n",
					argv[argn][j]);
				usage();
				break;
			}
		} else if (iself(argv[argn])) {
			elfload = argv[argn];
#ifdef	SDSPI_ACCESS
		} else if (0 == access(argv[argn], R_OK)) {
			sdimage_file = argv[argn];
#endif
		} else {
			fprintf(stderr, "ERR: Cannot read %s\n", argv[argn]);
			perror("O/S Err:");
			exit(EXIT_FAILURE);
		}
	}

	if (elfload)
		willexit = true;
	if (debug_flag) {
		printf("Opening design with\n");
		printf("\tDebug Access port = %d\n", FPGAPORT); // fpga_port);
		printf("\tSerial Console    = %d\n", FPGAPORT+1);
		printf("\tVCD File         = %s\n", trace_file);
		if (elfload)
			printf("\tELF File         = %s\n", elfload);
	} if (trace_file)
		tb->opentrace(trace_file);

	if (profile_file) {
#ifndef	INCLUDE_ZIPCPU
		fprintf(stderr, "ERR: Design has no ZipCPU\n");
		exit(EXIT_FAILURE);
#endif
		profile_fp = fopen(profile_file, "w");
		if (profile_fp == NULL) {
			fprintf(stderr, "ERR: Cannot open profile output "
				"file, %s\n", profile_file);
			exit(EXIT_FAILURE);
		}
	} else
		profile_fp = NULL;


	tb->reset();
#ifdef	SDSPI_ACCESS
	tb->setsdcard(sdimage_file);
#endif

	if (elfload) {
		const	unsigned	MAX_RESET_CLOCKS = 40;
#ifndef	INCLUDE_ZIPCPU
		fprintf(stderr, "ERR: Design has no ZipCPU\n");
		exit(EXIT_FAILURE);
#endif
		tb->loadelf(elfload);

		ELFSECTION	**secpp;
		uint32_t	entry;

		elfread(elfload, entry, secpp);
		free(secpp);

		printf("Attempting to start from 0x%08x\n", entry);
		tb->m_core->cpu_ipc = entry;

		tb->m_core->cpu_cmd_halt = 1;
		tb->m_core->cpu_reset    = 0;
		tb->tick();

		tb->m_core->cpu_ipc = entry;
		tb->m_core->cpu_cmd_halt = 1;
		tb->m_core->cpu_reset    = 0;

		for(unsigned k=0; k<MAX_RESET_CLOCKS; k++) {
			tb->m_core->cpu_cmd_halt = 1;
			while(tb->m_core->i_clk)
				tb->tick();
			while(!tb->m_core->i_clk)
				tb->tick();
		}

	//
		// tb->m_core->alu_wR  = 1;
		tb->m_core->cpu_new_pc   = 1;
		tb->m_core->cpu_pf_pc    = entry;
		tb->m_core->CPUVAR(_alu_reg) = 15;
		tb->m_core->CPUVAR(_dbgv)    = 1;
		tb->m_core->CPUVAR(_dbg_val) = entry;
		tb->m_core->CPUVAR(_dbg_clear_pipe) = 1;
		tb->m_core->eval();
	//
		tb->tick();
		tb->m_core->cpu_cmd_halt = 0;
		tb->m_core->VVAR(_swic__DOT__cmd_reset) = 0;
		tb->m_core->VVAR(_swic__DOT__cpu_halt) = 0;
	}

#ifdef	OLEDRGB_ACCESS
	Gtk::Main::run(tb->m_oledrgb);
#else
	if (profile_fp) {
		unsigned long	last_instruction_tick = 0, now = 0;
		while((!willexit)||(!tb->done())) {
			unsigned long	iticks;
			unsigned	buf[2];

			now++;
			tb->tick();

			if (((tb->m_core->cpu_alu_pc_valid)
					||(tb->m_core->cpu_mem_pc_valid))
				&&(!tb->m_core->cpu_alu_phase)
				&&(!tb->m_core->cpu_new_pc)) {
				iticks = now - last_instruction_tick;
				buf[0] = tb->m_core->cpu_alu_pc;
				buf[1] = (unsigned)iticks;
				fwrite(buf, sizeof(unsigned), 2, profile_fp);

				last_instruction_tick = now;
			}
		}
	} else if (willexit) {
		while(!tb->done())
			tb->tick();
	} else
		while(true)
			tb->tick();
#endif

	tb->close();
	delete tb;

	return	EXIT_SUCCESS;
}
