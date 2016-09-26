////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbufifo.v
//
// Project:	FPGA library
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
// Copyright (C) 2015, Gisselquist Technology, LLC
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
module wbufifo(i_clk, i_rst, i_wr, i_data, i_rd, o_data, o_empty_n, o_err);
	parameter	BW=66, LGFLEN=10;
	input			i_clk, i_rst;
	input			i_wr;
	input	[(BW-1):0]	i_data;
	input			i_rd;
	output	reg [(BW-1):0]	o_data;
	output	reg		o_empty_n;
	output	wire		o_err;

	localparam	FLEN=(1<<LGFLEN);

	reg	[(BW-1):0]	fifo[0:(FLEN-1)];
	reg	[(LGFLEN-1):0]	r_first, r_last;

	reg	will_overflow;
	initial	will_overflow = 1'b0;
	always @(posedge i_clk)
		if (i_rst)
			will_overflow <= 1'b0;
		else if (i_rd)
			will_overflow <= (will_overflow)&&(i_wr);
		else if (i_wr)
			will_overflow <= (r_first+2 == r_last);
		else if (r_first+1 == r_last)
			will_overflow <= 1'b1;

	// Write
	initial	r_first = 0;
	always @(posedge i_clk)
		if (i_rst)
			r_first <= { (LGFLEN){1'b0} };
		else if (i_wr)
		begin // Cowardly refuse to overflow
			if ((i_rd)||(~will_overflow)) // (r_first+1 != r_last)
				r_first <= r_first+{{(LGFLEN-1){1'b0}},1'b1};
			// else o_ovfl <= 1'b1;
		end
	always @(posedge i_clk)
		if (i_wr) // Write our new value regardless--on overflow or not
			fifo[r_first] <= i_data;

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
	reg	will_underflow;
	initial	will_underflow = 1'b0;
	always @(posedge i_clk)
		if (i_rst)
			will_underflow <= 1'b0;
		else if (i_wr)
			will_underflow <= (will_underflow)&&(i_rd);
		else if (i_rd)
			will_underflow <= (r_last+1==r_first);
		else
			will_underflow <= (r_last == r_first);

	initial	r_last = 0;
	always @(posedge i_clk)
		if (i_rst)
			r_last <= { (LGFLEN){1'b0} };
		else if (i_rd)
		begin
			if ((i_wr)||(~will_underflow)) // (r_first != r_last)
				r_last <= r_last+{{(LGFLEN-1){1'b0}},1'b1};
				// Last chases first
				// Need to be prepared for a possible two
				// reads in quick succession
				// o_data <= fifo[r_last+1];
			// else o_unfl <= 1'b1;
		end
	always @(posedge i_clk)
		o_data <= fifo[(i_rd)?(r_last+{{(LGFLEN-1){1'b0}},1'b1})
					:(r_last)];

	wire	[(LGFLEN-1):0]	nxt_first;
	assign	nxt_first = r_first+{{(LGFLEN-1){1'b0}},1'b1};
	assign	o_err = ((i_wr)&&(will_overflow)&&(~i_rd))
				||((i_rd)&&(will_underflow)&&(~i_wr));

	// wire	[(LGFLEN-1):0]	fill;
	// assign	fill = (r_first-r_last);
	wire	[(LGFLEN-1):0]	nxt_last;
	assign	nxt_last = r_last+{{(LGFLEN-1){1'b0}},1'b1};
	always @(posedge i_clk)
		if (i_rst)
			o_empty_n <= 1'b0;
		else
			o_empty_n <= (~i_rd)&&(r_first != r_last)
					||(i_rd)&&(r_first != nxt_last);
endmodule
