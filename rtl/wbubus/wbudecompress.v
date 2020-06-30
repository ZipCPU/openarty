////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbudecompress.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Compression via this interface is simply a lookup table.
//		When writing, if requested, rather than writing a new 36-bit
//	word, we may be asked to repeat a word that's been written recently.
//	That's the goal of this routine: if given a word's (relative) address
//	in the write stream, we use that address, else we expect a full 32-bit
//	word to come in to be written.
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
module	wbudecompress(i_clk, i_stb, i_word, o_stb, o_word);
	input	wire		i_clk, i_stb;
	input	wire	[35:0]	i_word;
	output	reg		o_stb;
	output	reg	[35:0]	o_word;

	reg	[7:0]	wr_addr;
	reg	[31:0]	compression_tbl	[0:255];
	reg	[35:0]	r_word;
	reg	[7:0]	cmd_addr;
	reg	[24:0]	r_addr;
	wire	[31:0]	w_addr;
	reg	[9:0]	rd_len;
	reg	[31:0]	cword;
	reg	[2:0]	r_stb;
	wire		cmd_write_not_compressed;

	// Clock zero
	//	{ o_stb, r_stb } = 0
	assign	cmd_write_not_compressed = (i_word[35:33] == 3'h3);


	// Clock one: { o_stb, r_stb } = 4'h1 when done
	initial	wr_addr = 8'h0;
	always @(posedge i_clk)
	if ((i_stb)&&(cmd_write_not_compressed))
		wr_addr <= wr_addr + 8'h1;

	always @(posedge i_clk)
	if (i_stb)
		compression_tbl[wr_addr] <= { i_word[32:31], i_word[29:0] };

	always @(posedge i_clk)
	if (i_stb)
		r_word <= i_word;


	// Clock two, calculate the table address ... 1 is the smallest address
	//	{ o_stb, r_stb } = 4'h2 when done
	always @(posedge i_clk)
	if (i_stb)
		cmd_addr <= wr_addr - { i_word[32:31], i_word[29:24] };

	// Let's also calculate the address, in case this is a compressed
	// address word

	always @(posedge i_clk)
	if (i_stb)
	case(i_word[32:30])
	3'b000: r_addr <= { 19'h0, i_word[29:24] };
	3'b010: r_addr <= { 13'h0, i_word[29:18] };
	3'b100: r_addr <= {  7'h0, i_word[29:12] };
	3'b110: r_addr <= {  1'h0, i_word[29: 6] };
	3'b001: r_addr <= { {(19){ i_word[29]}}, i_word[29:24] };
	3'b011: r_addr <= { {(13){ i_word[29]}}, i_word[29:18] };
	3'b101: r_addr <= { {( 7){ i_word[29]}}, i_word[29:12] };
	3'b111: r_addr <= { {( 1){ i_word[29]}}, i_word[29: 6] };
	endcase

	assign	w_addr = { {(7){r_addr[24]}}, r_addr };

	always @(posedge i_clk)
	if (i_stb)
	begin
		if (!i_word[34])
			rd_len <= 10'h01 + { 6'h00, i_word[33:31] };
		else
			rd_len <= 10'h09 + { 1'b0,i_word[33:31],i_word[29:24] };
	end

	// Clock three, read the table value
	//	{ o_stb, r_stb } = 4'h4 when done
	// Maintaining ...
	//	r_word (clock 1)
	//	r_addr, rd_len (clock 2)
	always @(posedge i_clk)
		cword <= compression_tbl[cmd_addr];


	// Pipeline the strobe signal to create an output strobe, 3 clocks later
	initial	r_stb = 0;
	always @(posedge i_clk)
		r_stb <= { r_stb[1:0], i_stb };

	// Clock four, now that the table value is valid, let's set our output
	// word.
	//	{ o_stb, r_stb } = 4'h8 when done
	initial	o_stb = 0;
	always @(posedge i_clk)
		o_stb <= r_stb[2];
	// Maintaining ...
	//	r_word		(clock 1)
	//	r_addr, rd_len	(clock 2)
	//	cword		(clock 3)
	//		Any/all of these can be pipelined for faster operation
	// However, speed is really limited by the speed of the I/O port.  At
	// it's fastest, it's 1 bit per clock, 48 clocks per codeword therefore,
	// thus ... things will hold still for much longer than just 5 clocks.
	always @(posedge i_clk)
	if (r_word[35:30] == 6'b101110)
		o_word <= r_word;
	else casez(r_word[35:30])
	// Set address from something compressed ... unsigned
	6'b001??0: o_word <= { 4'h0, w_addr[31:0] };
	// Set a new address as a signed offset from the last (set) one
	//	(The last address is kept further down the chain,
	//	we just mark here that the address is to be set
	//	relative to it, and by how much.)
	6'b001??1: o_word <= { 3'h1, w_addr[31:30], 1'b1, w_addr[29:0]};
	// Write a value to the bus, with the value given from our
	// codeword table
	6'b010???: o_word <=
		{ 3'h3, cword[31:30], r_word[30], cword[29:0] };
	// Read, highly compressed length (1 word)
	6'b1?????: o_word <= { 5'b11000, r_word[30], 20'h00, rd_len };
	// Read, two word (3+9 bits) length ... same encoding
	// 6'b1?????: o_word <= { 5'b11000, r_word[30], 20'h00, rd_len };
	default: o_word <= r_word;
	endcase

`ifdef	FORMAL
// Formal properties for this module are maintained elsewhere
`endif
endmodule

