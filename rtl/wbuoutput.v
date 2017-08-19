////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbuoutput.v
//
// Project:	FPGA library
//
// Purpose:	Converts 36-bit codewords into bytes to be placed on the serial
//		output port.  The codewords themselves are the results of bus
//	transactions, which are then (hopefully) compressed within here and
//	carefully arranged into "lines" for visual viewing (if necessary).
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2017, Gisselquist Technology, LLC
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
module	wbuoutput(i_clk, i_rst, i_stb, i_codword,
		i_wb_cyc, i_int, i_bus_busy,
		o_stb, o_char, i_tx_busy, o_fifo_err);
	parameter	LGOUTPUT_FIFO = 10;
	input	wire		i_clk, i_rst;
	input	wire		i_stb;
	input	wire	[35:0]	i_codword;
	// Not Idle indicators
	input	wire		i_wb_cyc, i_int, i_bus_busy;
	// Outputs to our UART transmitter
	output	wire		o_stb;
	output	wire	[7:0]	o_char;
	// Miscellaneous I/O: UART transmitter busy, and fifo error
	input	wire		i_tx_busy;
	output	wire		o_fifo_err;

	wire		fifo_rd, dw_busy, fifo_empty_n, fifo_err;
	wire	[35:0]	fifo_codword;

	wire		cw_stb, cw_busy, cp_stb, dw_stb, ln_stb, ln_busy,
			cp_busy, byte_busy;
	wire	[35:0]	cw_codword, cp_word;
	wire	[6:0]	dw_bits, ln_bits;

	generate
	if (LGOUTPUT_FIFO < 2)
	begin

		assign	fifo_rd = i_stb;
		assign	fifo_codword = i_codword;
		assign	fifo_err = 1'b0;

	end else begin

		assign	fifo_rd = (fifo_empty_n)&&(~cw_busy);
		wbufifo #(36,LGOUTPUT_FIFO)
			busoutfifo(i_clk, i_rst, i_stb, i_codword,
				fifo_rd, fifo_codword, fifo_empty_n,
				fifo_err);

	end endgenerate

	assign	o_fifo_err = fifo_err;

	wbuidleint	buildcw(i_clk, fifo_rd, fifo_codword,
				i_wb_cyc, i_bus_busy, i_int,
				cw_stb, cw_codword, cw_busy, cp_busy);
	// assign	o_dbg = dw_busy; // Always asserted ... ???
	// assign	o_dbg = { dw_busy, ln_busy, fifo_rd };
	// Stuck: dw_busy and ln_busy get stuck high after read attempt,
	//	fifo_rd is low
	// assign	o_dbg = { fifo_rd, cp_stb, cw_stb };
	// cw_stb and cp_stb get stuck high after one read

	//
	// cw_busy & cw_stb, not cp_stb, but dw_busy
	//

// `define	SKIP_COMPRESS
`ifdef	SKIP_COMPRESS
	assign	cp_stb = cw_stb;
	assign	cp_word = cw_codword;
	assign	cp_busy = dw_busy;
`else
	assign	cp_busy = cp_stb;
	wbucompress	packit(i_clk, cw_stb, cw_codword,
				cp_stb, cp_word, dw_busy);
`endif

	wbudeword	deword(i_clk, cp_stb, cp_word, ln_busy,
					dw_stb, dw_bits, dw_busy);

	wbucompactlines	linepacker(i_clk, dw_stb, dw_bits,
			ln_stb, ln_bits,
			(i_wb_cyc||i_bus_busy||fifo_empty_n||cw_busy),
			byte_busy, ln_busy);

	wbusixchar	mkbytes(i_clk, ln_stb, ln_bits, o_stb, o_char, byte_busy, i_tx_busy);

endmodule
