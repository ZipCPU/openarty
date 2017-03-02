////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	cmptst.c
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To test and tell whether or not GCC's comparison tests are 
//		working, both for regular integers as well as for long (64-bit)
//	integers.
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
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory, run make with no
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
#include <stdio.h>
#include "artyboard.h"

//
//
// COMPARE SI (4-byte) numbers
//
//
void	cmpsi_eq(int A, int B) {
	printf("\tCOMPARE-SI-EQ : 0x%08x == 0x%08x ", A, B);
	if (A == B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpsi_neq(int A, int B) {
	printf("\tCOMPARE-SI-NEQ: 0x%08x != 0x%08x ", A, B);
	if (A != B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpsi_lt(int A, int B) {
	printf("\tCOMPARE-SI-LT : 0x%08x <  0x%08x ", A, B);
	if (A < B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpsi_lte(int A, int B) {
	printf("\tCOMPARE-SI-LTE: 0x%08x <= 0x%08x ", A, B);
	if (A <= B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpsi_gt(int A, int B) {
	printf("\tCOMPARE-SI-GT : 0x%08x >  0x%08x ", A, B);
	if (A > B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpsi_gte(int A, int B) {
	printf("\tCOMPARE-SI-GTE: 0x%08x >= 0x%08x ", A, B);
	if (A >= B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpsi_ltu(unsigned A, unsigned B) {
	printf("\tCOMPARE-SI-LTU: 0x%08x <  0x%08x ", A, B);
	if (A < B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpsi_leu(unsigned A, unsigned B) {
	printf("\tCOMPARE-SI-LEU: 0x%08x <= 0x%08x ", A, B);
	if (A <= B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpsi_gtu(unsigned A, unsigned B) {
	printf("\tCOMPARE-SI-GTU: 0x%08x >  0x%08x ", A, B);
	if (A > B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpsi_geu(unsigned A, unsigned B) {
	printf("\tCOMPARE-SI-GEU: 0x%08x >= 0x%08x ", A, B);
	if (A >= B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpsi(int A, int B) {
	printf("COMPARE-SI\r\n");
	cmpsi_eq(A, B);
	cmpsi_neq(A, B);
	cmpsi_lt(A, B);
	cmpsi_lte(A, B);
	cmpsi_gt(A, B);
	cmpsi_gte(A, B);
	cmpsi_ltu(A, B);
	cmpsi_leu(A, B);
	cmpsi_gtu(A, B);
	cmpsi_geu(A, B);
}

//
//
// COMPARE DI (8-byte) numbers
//
//
void	cmpdi_eq(long A, long B) {
	printf("\tCOMPARE-EQ : 0x%lx == 0x%lx ", A, B);
	if (A == B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpdi_neq(long A, long B) {
	printf("\tCOMPARE-NEQ: 0x%lx != 0x%lx ", A, B);
	if (A != B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpdi_lt(long A, long B) {
	printf("\tCOMPARE-LT : 0x%lx <  0x%lx ", A, B);
	if (A < B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpdi_lte(long A, long B) {
	printf("\tCOMPARE-LTE: 0x%lx <= 0x%lx ", A, B);
	if (A <= B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpdi_gt(long A, long B) {
	printf("\tCOMPARE-GT : 0x%lx >  0x%lx ", A, B);
	if (A > B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpdi_gte(long A, long B) {
	printf("\tCOMPARE-GTE: 0x%lx >= 0x%lx ", A, B);
	if (A >= B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpdi_ltu(unsigned long A, unsigned long B) {
	printf("\tCOMPARE-LTU: 0x%lx <  0x%lx ", A, B);
	if (A < B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpdi_leu(unsigned long A, unsigned long B) {
	printf("\tCOMPARE-LEU: 0x%lx <= 0x%lx ", A, B);
	if (A <= B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpdi_gtu(unsigned long A, unsigned long B) {
	printf("\tCOMPARE-GTU: 0x%lx >  0x%lx ", A, B);
	if (A > B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpdi_geu(unsigned long A, unsigned long B) {
	printf("\tCOMPARE-GEU: 0x%lx >= 0x%lx ", A, B);
	if (A >= B)
		printf("TRUE\r\n");
	else
		printf("FALSE\r\n");
}

void	cmpdi(long A, long B) {
	// printf("COMPARE-DI\r\n");
	cmpdi_eq(A, B);
	cmpdi_neq(A, B);
	cmpdi_lt(A, B);
	cmpdi_lte(A, B);
	cmpdi_gt(A, B);
	cmpdi_gte(A, B);
	cmpdi_ltu(A, B);
	cmpdi_leu(A, B);
	cmpdi_gtu(A, B);
	cmpdi_geu(A, B);
}


int	main(int argc, char **argv) {
	printf("\r\n\r\nCOMPARISON TESTING\r\n-------------------\r\n\r\n");
	cmpsi(0xffffffff, 0x00000010);
	cmpsi(0x7fffffff, 0x80000000);
	cmpdi(-1l, 0l);
	cmpdi(0l, -1l);
	cmpdi(-1l, -1l);
	cmpdi(-2l, -1l);
	cmpdi(0l, 1l);
	cmpdi(0x7fffffffffffffffl, 0x8000000000000000l);
}

