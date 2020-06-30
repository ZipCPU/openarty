////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbufifo.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This was once a FIFO for a UART ... but now it works as a
//		synchronous FIFO for JTAG-wishbone conversion 36-bit codewords. 
//
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
`default_nettype none
//
module wbufifo(i_clk, i_reset, i_wr, i_data, i_rd, o_data, o_empty_n, o_err);
	parameter	BW=66, LGFLEN=10;
	input	wire		i_clk, i_reset;
	input	wire		i_wr;
	input	wire [(BW-1):0]	i_data;
	input	wire		i_rd;
	output	reg [(BW-1):0]	o_data;
	output	reg		o_empty_n;
	output	wire		o_err;

	localparam	FLEN=(1<<LGFLEN);

	reg	[(BW-1):0]	fifo[0:(FLEN-1)];
	reg	[LGFLEN:0]	r_wrptr, r_rdptr;
	wire	[LGFLEN:0]	nxt_wrptr, nxt_rdptr;
	reg			will_overflow,will_underflow, r_empty_n;
	wire			w_write, w_read;

	assign	w_write = (i_wr && (!will_overflow || i_rd));
	assign	w_read  = (i_rd||!o_empty_n) && !will_underflow;

	assign	nxt_wrptr = r_wrptr + 1;
	assign	nxt_rdptr = r_rdptr + 1;

	initial	will_overflow = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		will_overflow <= 1'b0;
	else if (i_rd)
		will_overflow <= (will_overflow)&&(i_wr);
	else if (w_write)
		will_overflow <= (nxt_wrptr[LGFLEN-1:0] == r_rdptr[LGFLEN-1:0])
			&&(nxt_wrptr[LGFLEN] != r_rdptr[LGFLEN]);
	// else if (nxt_wrptr == r_rdptr)
	//	will_overflow <= 1'b1;

	// Write
	initial	r_wrptr = 0;
	always @(posedge i_clk)
	if (i_reset)
		r_wrptr <= 0;
	else if (w_write)
		r_wrptr <= nxt_wrptr;

	always @(posedge i_clk)
	if (w_write)
		fifo[r_wrptr[LGFLEN-1:0]] <= i_data;

	// Reads
	//	Following a read, the next sample will be available on the
	//	next clock
	//	Clock	ReadCMD	ReadAddr	Output
	//	0	0	0		fifo[0]
	//	1	1	0		fifo[0]
	//	2	0	1		fifo[1]
	//	3	0	1		fifo[1]
	//	4	1	1		fifo[1]
	//	5	1	2		fifo[2]
	//	6	0	3		fifo[3]
	//	7	0	3		fifo[3]
	initial	will_underflow = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		will_underflow <= 1'b1;
	else if (i_wr)
		will_underflow <= 1'b0;
	else if (w_read)
		will_underflow <= (will_underflow) || (nxt_rdptr==r_wrptr);

	initial	r_rdptr = 0;
	always @(posedge i_clk)
	if (i_reset)
		r_rdptr <= 0;
	else if (w_read && r_empty_n)
		r_rdptr <= r_rdptr + 1;

	always @(posedge i_clk)
	if (w_read && r_empty_n)
		o_data<= fifo[r_rdptr[LGFLEN-1:0]];

	assign	o_err = ((i_wr)&&(will_overflow)&&(!i_rd))
				||(i_rd && !o_empty_n);

	always @(*)
		r_empty_n = !will_underflow;

	initial	o_empty_n = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_empty_n <= 1'b0;
	else if (!o_empty_n || i_rd)
		o_empty_n <= r_empty_n;

`ifdef	FORMAL
// Formal properties for this module are maintained elsewhere
`endif
endmodule
