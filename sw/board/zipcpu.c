////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	zipsystem.c
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	Implements some ZipCPU specific functions.  Specifically, these
//		are the system call trap (which just switches to supervisor 
//		mode), and the two context switching functions.  
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2016, Gisselquist Technology, LLC
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
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
#include "zipcpu.h"

// Implement a save_context function.  This really boils into a long series of
// instructions within the compiler.  For this reason, it makes more sense
// for it to be a function call rather than an inline function--although
// zip_save_context could be either.  Of course, the difficult part of placing
// it in line is that the CPU may not realize the context changes between one
// invocation of save_context and the corresponding restore_context function...
void	save_context(int *c) {
	zip_save_context(c);
}

void	restore_context(int *c) {
	zip_restore_context(c);
}

#ifdef	C_SYSCALL
/* While the following system call *should* be identical to the assembly
 * equivalent beneath it, the dependency is actually dependent upon any
 * optimizations within the compiler.  If the compiler is not optimized,
 * then it may try to create a stack frame, store id, a, b, and c, on the
 * stack frame, call the system call, clear the stack frame and return.
 * 
 * The problem with this is that system traps may believe that they can replace
 * the system call with a goto.  In that case, there is no knowledge of the
 * stack frame that needs to be unwound.  Hence, we need to make certain that
 * the system call does not create a stack frame, and thus use the assembly
 * form beneath here.
 */
int	syscall(const int id, const int a, const int b, const int c) {
	zip_syscall();
}
#else
/* By making this into an assembly language equivalent, we can be specific about
 * what we are expecting.  That way the kernel can just set the PC address and
 * the system call may believe that it was called like any ordinary subroutine.
 */
asm(ASMFNSTR("syscall")
	"\tCLR\tCC\n"
	"\tRETN\n"
);
#endif


