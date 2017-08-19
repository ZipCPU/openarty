////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbucompress.v
//
// Project:	FPGA library
//
// Purpose:	When reading many words that are identical, it makes no sense
//		to spend the time transmitting the same thing over and over
//	again, especially on a slow channel.  Hence this routine uses a table
//	lookup to see if the word to be transmitted was one from the recent
//	past.  If so, the word is replaced with an address of the recently
//	transmitted word.  Mind you, the table lookup takes one clock per table
//	entry, so even if a word is in the table it might not be found in time.
//	If the word is not in the table, or if it isn't found due to a lack of
//	time, the word is placed into the table while incrementing every other
//	table address.
//
//	Oh, and on a new address--the table is reset and starts over.  This way,
//	any time the host software changes, the host software will always start
//	by issuing a new address--hence the table is reset for every new piece
//	of software that may wish to communicate.
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
// All input words are valid codewords.  If we can, we make them
// better here.
module	wbucompress(i_clk, i_stb, i_codword, o_stb, o_cword, i_busy);
	parameter	DW=32, CW=36, TBITS=10;
	input	wire			i_clk, i_stb;
	input	wire	[(CW-1):0]	i_codword;
	output	wire			o_stb;
	output	wire	[(CW-1):0]	o_cword;
	input	wire			i_busy;

	//
	//
	// First stage is to compress the address.
	// This stage requires one clock.
	//
	//	ISTB,ICODWORD
	//	ISTB2,IWRD2	ASTB,AWORD
	//	ISTB3,IWRD3	ASTB2,AWRD2	I_BUSY(1)
	//	ISTB3,IWRD3	ASTB2,AWRD2	I_BUSY(1)
	//	ISTB3,IWRD3	ASTB2,AWRD2	I_BUSY(1)
	//	ISTB3,IWRD3	ASTB2,AWRD2	
	//	ISTB4,IWRD4	ASTB3,AWRD3	I_BUSY(2)
	//	ISTB4,IWRD4	ASTB3,AWRD3	I_BUSY(2)
	//	ISTB4,IWRD4	ASTB3,AWRD3	I_BUSY(2)
	reg		a_stb;
	reg	[35:0]	a_addrword;
	wire	[31:0]	w_addr;
	assign	w_addr = i_codword[31:0];
	always @(posedge i_clk)
		if ((i_stb)&&(~a_stb))
		begin
			if (i_codword[35:32] != 4'h2)
			begin
				a_addrword <= i_codword;
			end else if (w_addr[31:6] == 26'h00)
				a_addrword <= { 6'hc, w_addr[ 5:0], 24'h00 };
			else if (w_addr[31:12] == 20'h00)
				a_addrword <= { 6'hd, w_addr[11:0], 18'h00 };
			else if (w_addr[31:18] == 14'h00)
				a_addrword <= { 6'he, w_addr[17:0], 12'h00 };
			else if (w_addr[31:24] == 8'h00)
				a_addrword <= { 6'hf, w_addr[23:0],  6'h00 };
			else begin
				a_addrword <= i_codword;
			end
		end
	initial	a_stb = 1'b0;
	always @(posedge i_clk)
		if ((i_stb)&&(~a_stb))
			a_stb <= i_stb;
		else if (~i_busy)
			a_stb <= 1'b0;


	//
	//
	// The next stage attempts to replace data codewords with previous
	// codewords that may have been sent.  The memory is only allowed
	// to be as old as the last new address command.  In this fashion,
	// any program that wishes to talk to the device can start with a
	// known compression table by simply setting the address and then
	// reading from the device.
	//

	// We start over any time a new value shows up, and 
	// the follow-on isn't busy and can take it.  Likewise,
	// we reset the writer on the compression any time a
	// i_clr value comes through (i.e., ~i_cyc or new
	// address)

	wire	w_accepted;
	assign	w_accepted = (a_stb)&&(~i_busy);

	reg		r_stb;
	always @(posedge i_clk)
		r_stb <= a_stb;

	wire	[35:0]	r_word;
	assign	r_word = a_addrword;


	//
	// First step of the compression is keeping track of a compression
	// table.  And the first part of that is keeping track of what address
	// to write into the compression table, and whether or not the entire
	// table is full or not.  This logic follows:
	//
	reg	[(TBITS-1):0]	tbl_addr;
	reg			tbl_filled;
	// First part, write the compression table
	always @(posedge i_clk)
		// If we send a new address, then reset the table to empty
		if (w_accepted)
		begin
			// Reset on new address (0010xx) and on new compressed
			// addresses (0011ll).
			if (o_cword[35:33]==3'h1)
				tbl_addr <= 0;
			// Otherwise, on any valid return result that wasn't
			// from our table, for whatever reason (such as didn't
			// have the clocks to find it, etc.), increment the
			// address to add another value into our table
			else if (o_cword[35:33] == 3'b111)
				tbl_addr <= tbl_addr + {{(TBITS-1){1'b0}},1'b1};
		end
	always @(posedge i_clk)
		if ((w_accepted)&&(o_cword[35:33]==3'h1)) // on new address
			tbl_filled <= 1'b0;
		else if (tbl_addr == 10'h3ff)
			tbl_filled <= 1'b1;

	// Now that we know where we are writing into the table, and what
	// values of the table are valid, we need to actually write into
	// the table.
	//
	// We can keep this logic really simple by writing on every clock
	// and writing junk on many of those clocks, but we'll need to remember
	// that the value of the table at tbl_addr is unreliable until tbl_addr
	// changes.
	//
	reg	[31:0]	compression_tbl	[0:((1<<TBITS)-1)];
	// Write new values into the table
	always @(posedge i_clk)
		compression_tbl[tbl_addr] <= { r_word[32:31], r_word[29:0] };

	// Now that we have a working table, can we use it?
	// On any new word, we'll start looking through our codewords.
	// If we find any that matches, we're there.  We might (or might not)
	// make it through the table first.  That's irrelevant.  We just look
	// while we can.
	reg			tbl_match, nxt_match; // <= (nxt_rd_addr == tbl_addr);
	reg	[(TBITS-1):0]	rd_addr;
	reg	[(TBITS-1):0]	nxt_rd_addr;
	initial	rd_addr = 0;
	initial	tbl_match = 0;
	always @(posedge i_clk)
	begin
		nxt_match <= ((nxt_rd_addr-tbl_addr)=={{(TBITS-1){1'b0}},1'b1});
		if ((w_accepted)||(~a_stb))
		begin
			// Keep in mind, if a write was just accepted, then
			// rd_addr will need to be reset on the next clock
			// when (~a_stb).  Hence this must be a two clock
			// update
			rd_addr <= tbl_addr + {(TBITS){1'b1}};
			nxt_rd_addr = tbl_addr + { {(TBITS-1){1'b1}}, 1'b0 };
			tbl_match <= 1'b0;
		end else if ((~tbl_match)&&(~match)
				&&((~nxt_rd_addr[TBITS-1])||(tbl_filled)))
		begin
			rd_addr <= nxt_rd_addr;
			nxt_rd_addr = nxt_rd_addr - { {(TBITS-1){1'b0}}, 1'b1 };
			tbl_match <= nxt_match;
		end
	end

	reg	[1:0]		pmatch;
	reg			dmatch, // Match, on clock 'd'
				vaddr;	// Was the address valid then?
	reg	[(DW-1):0]	cword;
	reg	[(TBITS-1):0]	caddr, maddr;
	always @(posedge i_clk)
	begin
		cword <= compression_tbl[rd_addr];
		caddr <= rd_addr;

		dmatch <= (cword == { r_word[32:31], r_word[29:0] });
		maddr  <= tbl_addr - caddr;

		vaddr <= ( {1'b0, caddr} < {tbl_filled, tbl_addr} )
			&&(caddr != tbl_addr);
	end

	always @(posedge i_clk)
		if ((w_accepted)||(~a_stb))
			pmatch <= 0; // rd_addr is set on this clock
		else
			// cword is set on the next clock, pmatch = 3'b001
			// dmatch is set on the next clock, pmatch = 3'b011
			pmatch <= { pmatch[0], 1'b1 };

	reg		match;
	reg	[(TBITS-1):0]	matchaddr;
	always @(posedge i_clk)
		if((w_accepted)||(~a_stb)||(~r_stb))// Reset upon any write
			match <= 1'b0;
		else if (~match)
		begin
			// To be a match, the table must not be empty,
			match <= (vaddr)&&(dmatch)&&(r_word[35:33]==3'b111)
					&&(pmatch == 2'b11);
		end

	reg	zmatch, hmatch, fmatch;
	always @(posedge i_clk)
		if (~match)
		begin
			matchaddr <= maddr;
			fmatch    <= (maddr < 10'h521);
			zmatch    <= (maddr == 10'h1);
			hmatch    <= (maddr < 10'd10);
		end

	// Did we find something?
	wire	[9:0]		adr_dbld;
	wire	[2:0]		adr_hlfd;
	assign	adr_hlfd = matchaddr[2:0]- 3'd2;
	assign	adr_dbld = matchaddr- 10'd10;
	reg	[(CW-1):0]	r_cword; // Record our result
	always @(posedge i_clk)
	begin
		if ((~a_stb)||(~r_stb)||(w_accepted))//Reset whenever word gets written
		begin
			r_cword <= r_word;
		end else if ((match)&&(fmatch)) // &&(r_word == a_addrword))
		begin
			r_cword <= r_word;
			if (zmatch) // matchaddr == 1
				r_cword[35:30] <= { 5'h3, r_word[30] };
			else if (hmatch) // 2 <= matchaddr <= 9
				r_cword[35:30] <= { 2'b10, adr_hlfd, r_word[30] };
			else // if (adr_diff < 10'd521)
				r_cword[35:24] <= { 2'b01, adr_dbld[8:6],
						r_word[30], adr_dbld[5:0] };
		end else
			r_cword <= r_word;
	end

	// Can we do this without a clock delay?
	assign	o_stb = a_stb;
	assign	o_cword = (r_stb)?(r_cword):(a_addrword);
endmodule

