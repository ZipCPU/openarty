////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wboledrgb.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To provide a *very* simplified controller for a PMod OLEDrgb.
//		This controller implements four registers (described below),
//	although it might feel like only two in practice.  As with all of our
//	other wishbone work, all transactions are 32-bits--even though, as an
//	example, the data word for the device is only ever 16-bits long.
//
//	The device control, outlined below, is also colored by two facts:
//	1. There is no means to read from the device.  Sure, the chip on the 
//		PMod has a full read/write bus, but it hasn't been entirely
//		wired to the PMod pins.  This was probably done so that the
//		interface could handle the paucity of pins available, but for
//		whatever reason, there's no way to read from the device.
//	2. The device is controlled by a SPI port, but with an extra wire that
//		determines whether or not you are writing to the control or the
//		data port on the device.  Hence the four wire SPI protocol has
//		lost the MISO wire and gained a Data / Control (N) (or dcn)
//		wire.
//	3. As implemented, the device also has two power control wires and a
//		reset wire.  The reset wire is negative logic.  Without setting
//		the PMOD-Enable wire high, the board has no power.  The
//		VCCEN pin is not to be set high without PMOD-Enable high.
//		Finally, setting reset low (with PMod-Enable high), places the
//		device into a reset condition.
//
//	The design of the controller, as with the design of other controllers
//	we have built, is focused around the design principles:
//	1. Use the bottom 23 bits of a word for the command, if possible.
//		Such commands can be loaded into registers with simple LDI
//		instructions.  Even better, restrict any status results from the
//		device to 18 bits, so that instructions that use immediates
//		such as TEST #,Rx, can use these immediates.
//	2. Protect against inadvertant changes to the power port.  For this,
//		we insist that a minimum of two bits be high to change the
//		power port bits, and that just reading from the port and
//		writing back with a changed power bit is not sufficient to
//		change the power.
//	3. Permit atomic changes to the individual power control bits,
//		by outlining which exact bits change upon any write, and
//		permitting only the bits specified to change.
//	4. Don't stall the bus.  So, if a command comes in and the
//		device is busy, we'll ignore the command.  It is up to the
//		user to make certain the device isn't fed faster than it is
//		able.  (Perhaps the user wishes to add a FIFO?)
//	5. Finally, build this so that either a FIFO or DMA could control it.
//
// Registers:
//	0. Control	-- There are several types of control commands to/from
//		the device, all separated and determined by how many bytes are
//		to be sent to the device for the said command.  Commands written
//		to the control port of the device are initiated by writes
//		to this register.
//
//		- Writes of all { 24'h00, data[7:0] } send the single byte
//			data[7:0] to the device.
//		- Writes of     { 16'h01, data[15:0] } send two bytes,
//			data[15:0], to the device.
//		- Writes of     {  4'h2, 4'hx, data[23:0] } send three bytes,
//			data[23:0], to the device.
//		- Writes of     {  4'h3, 4'hx, data[23:0] } send four bytes,
//			data[23:0], then r_a[31:24] to the device.
//		- Writes of     {  4'h3, 4'hx, data[23:0] } send five bytes,
//			data[23:0], then r_a[31:16] to the device.
//		- Writes of     {  4'h3, 4'hx, data[23:0] } send six bytes,
//			data[23:0], then r_a[31:8] to the device.
//		- Writes of     {  4'h3, 4'hx, data[23:0] } send seven bytes,
//			data[23:0], then r_a[31:0] to the device.
//		- Writes of     {  4'h3, 4'hx, data[23:0] } send eight bytes,
//			data[23:0], r_a[31:16], then r_b[31:24] to the device.
//		- Writes of     {  4'h3, 4'hx, data[23:0] } send nine bytes,
//			data[23:0], r_a[31:16], then r_b[31:16] to the device.
//		- Writes of     {  4'h3, 4'hx, data[23:0] } send ten bytes,
//			data[23:0], r_a[31:16], then r_b[31:8] to the device.
//		- Writes of     {  4'h3, 4'hx, data[23:0] } send eleven bytes,
//			data[23:0], r_a[31:16], then r_b[31:0] to the device.
//
//	1. A	This register is used, just like the B register below, for
//		setting up commands that send multiple bytes to the device.
//		Be aware that the high order bits/bytes will be sent first.
//		This is one of the few registers that may be read with meaning.
//		Once the word is written, however, the register is cleared.
//
//	2. B	This is the same as the A register, save on writes the A
//		register will be written first before any bits from the B
//		register.  As with the A register, this value is cleared upon
//		any write--regardless of whether its value is used in the
//		write.
//
//	3. Data	--- This is both the data and the power control register.
//
//		To write data to the graphics data RAM within the device,
//		simply write a 16'bit word: { 16'h00, data[15:0] } to this
//		port.
//
//		To change the three power bits, {reset, vccen, pmoden},
//		you must also set a 1'b1 in the corresponding bit position from
//		bit 16-18.  Hence a:
//
//		32'h010001 sets the pmod enable bit, whereas 32'h010000 clears
//			it.
//		32'h020002 sets the vcc bit, whereas 32'h010000 clears it.
//
//		Multiple of the power bits can be changed at once.  Each 
//		respective bit is only changed if it's change enable bit is
//		also high.
//		
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2019, Gisselquist Technology, LLC
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
`default_nettype	none
//
module	wboledrgb(i_clk, i_cyc, i_stb, i_we, i_addr, i_data,
			o_ack, o_stall, o_data,
		o_sck, o_cs_n, o_mosi, o_dbit,
		o_pwr, o_int);
	parameter	CBITS=4, // 2^4*13ns -> 208ns/clock > 150ns min
			EXTRA_BUS_CLOCK = 0;
	input	wire		i_clk, i_cyc, i_stb, i_we;
	input	wire	[1:0]	i_addr;
	input	wire	[31:0]	i_data;
	output	reg		o_ack;
	output	wire		o_stall;
	output	reg	[31:0]	o_data;
	output	wire		o_sck, o_cs_n, o_mosi, o_dbit;
	output	reg	[2:0]	o_pwr;
	output	wire		o_int;

	reg		dev_wr, dev_dbit;
	reg	[31:0]	dev_word;
	reg	[1:0]	dev_len;
	wire		dev_busy;
	lloledrgb	#(CBITS)
		lwlvl(i_clk, dev_wr, dev_dbit, dev_word, dev_len, dev_busy,
			o_sck, o_cs_n, o_mosi, o_dbit);

	wire		wb_stb, wb_we;
	wire	[31:0]	wb_data;
	wire	[1:0]	wb_addr;

	// I've thought about bumping this from a clock at <= 100MHz up to a 
	// clock near 200MHz.  Doing so requires an extra clock to come off
	// the bus--the bus fanout is just too wide otherwise.  However,
	// if you don't need to ... why take the extra clock cycle?  Hence
	// this little snippet of code allows the rest of the controller
	// to work at 200MHz or 100MHz as need be.
	generate
	if (EXTRA_BUS_CLOCK != 0)
	begin
		reg		r_wb_stb, r_wb_we;
		reg	[31:0]	r_wb_data;
		reg	[1:0]	r_wb_addr;
		always @(posedge i_clk)
			r_wb_stb <= i_stb;
		always @(posedge i_clk)
			r_wb_we <= i_we;
		always @(posedge i_clk)
			r_wb_data <= i_data;
		always @(posedge i_clk)
			r_wb_addr <= i_addr;

		assign	wb_stb  = r_wb_stb;
		assign	wb_we   = r_wb_we;
		assign	wb_data = r_wb_data;
		assign	wb_addr = r_wb_addr;
	end else begin
		assign	wb_stb  = i_stb;
		assign	wb_we   = i_we;
		assign	wb_data = i_data;
		assign	wb_addr = i_addr;
	end endgenerate



	reg		r_busy;
	reg	[3:0]	r_len;


	//
	// Handle registers A & B.  These are set either upon a write, or
	// cleared (set to zero) upon any command to the control register.
	//
	reg	[31:0]	r_a, r_b;
	always @(posedge i_clk)
		if ((wb_stb)&&(wb_we))
		begin
			if (wb_addr[1:0]==2'b01)
				r_a <= wb_data;
			if (wb_addr[1:0]==2'b10)
				r_b <= wb_data;
		end else if (r_cstb)
		begin
			r_a <= 32'h00;
			r_b <= 32'h00;
		end

	//
	// Handle reads from our device.  These really aren't all that 
	// interesting, but ... we can do them anyway.  We attempt to provide
	// some sort of useful value here.  For example, upon reading r_a or
	// r_b, you can read the current value(s) of those register(s).
	always @(posedge i_clk)
	begin
		case (wb_addr)
		2'b00: o_data <= { 13'h00, o_pwr, 8'h00, r_len, 1'b0, o_dbit, !o_cs_n, r_busy };
		2'b01: o_data <= r_a;
		2'b10: o_data <= r_b;
		2'b11: o_data <= { 16'h00, 13'h0, o_pwr };
		endcase
	end

	initial	o_ack = 1'b0;
	always @(posedge i_clk)
		o_ack <= wb_stb;
	assign	o_stall = 1'b0;

	reg	r_cstb, r_dstb, r_pstb, r_pre_busy;
	reg	[18:0]	r_data;
	initial	r_cstb = 1'b0;
	initial	r_dstb = 1'b0;
	initial	r_pstb = 1'b0;
	initial	r_pre_busy = 1'b0; // Used to clear the interrupt a touch earlier

	// The control strobe.  This will be true if we need to command a 
	// control interaction.
	always @(posedge i_clk)
		r_cstb <= (wb_stb)&&(wb_we)&&(wb_addr[1:0]==2'b00);

	// The data strobe, true if we need to command a data interaction.
	always @(posedge i_clk)
		r_dstb <= (wb_stb)&&(wb_we)&&(wb_addr[1:0]==2'b11)&&(wb_data[18:16]==3'h0);

	// The power strobe.  True if we are about to adjust the power and/or
	// reset bits.
	always @(posedge i_clk) // Power strobe, change power settings
		r_pstb <= (wb_stb)&&(wb_we)&&(wb_addr[1:0]==2'b11)&&(wb_data[18:16]!=3'h0);

	// Pre-busy: true if either r_cstb or r_dstb is true, and true on the
	// same clock they are true.  This is to support our interrupt, by
	// clearing the interrupt one clock earlier--lest the DMA decide to send
	// two words our way instead of one.
	always @(posedge i_clk)
		r_pre_busy <= (wb_stb)&&(wb_we)&&
				((wb_addr[1:0]==2'b11)||(wb_addr[1:0]==2'b00));

	// But ... to use these strobe values, we are now one more clock
	// removed from the bus.  We need something that matches this, so let's
	// delay our bus data one more clock 'til the time when we actually use
	// it.
	always @(posedge i_clk)
		r_data <= wb_data[18:0];

	initial	o_pwr = 3'h0;
	always @(posedge i_clk)
		if (r_pstb)
			o_pwr <= ((o_pwr)&(~r_data[18:16]))
				|((r_data[2:0])&(r_data[18:16]));

	// Sadly, because our commands can have a whole slew of different 
	// lengths, and because these lengths can be ... difficult to 
	// decipher from the command (especially the first two lengths),
	// this quick case statement is needed to decode the amount of bytes
	// that will be sent.
	reg	[3:0]	b_len;
	always @(posedge i_clk)
		casez(wb_data[31:28])
		4'b0000: b_len <= (wb_data[16])? 4'h2:4'h1;
		4'b0001: b_len <= 4'h2;
		4'b0010: b_len <= 4'h3;
		4'b0011: b_len <= 4'h4;
		4'b0100: b_len <= 4'h5;
		4'b0101: b_len <= 4'h6;
		4'b0110: b_len <= 4'h7;
		4'b0111: b_len <= 4'h8;
		4'b1000: b_len <= 4'h9;
		4'b1001: b_len <= 4'ha;
		4'b1010: b_len <= 4'hb;
		default: b_len <= 4'h0;
		endcase

	//
	// On the next clock, we're going to set our data register to
	// whatever's in register A, and B, and ... something of the data
	// written to the control register.  Because this must all be 
	// written on the most-significant bits of a word, we pause a moment
	// here to move the control word that was writen to our bus up
	// by an amount given by the length of our message.  That way, you 
	// can write to the bottom bits of the register, and yet still end
	// up in the top several bits of the following register.
	//
	reg	[23:0]	c_data;
	always @(posedge i_clk)
		if (wb_data[31:29] != 3'h0)
			c_data <= wb_data[23:0];
		else if (wb_data[16])
			c_data <= { wb_data[15:0], 8'h00 };
		else
			c_data <= { wb_data[7:0], 16'h00 };

	//
	// Finally, after massaging the incoming data off our bus, we finally
	// get to controlling the lower level controller and sending the
	// data to the device itself.
	//
	// The basic idea is this: we use r_busy to know if we are in the
	// middle of an operation, or whether or not we will be responsive to
	// the bus.  r_sreg holds the data we wish to send, and r_len the
	// number of bytes within r_sreg that remain to be sent.  The controller
	// will accept up to 32-bits at a time, so once we issue a command
	// (dev_wr & !dev_busy), we transition to either the next command.
	// Once all the data has been sent, and the device is now idle, we
	// clear r_busy and therefore become responsive to the bus again.
	//
	//
	reg	[87:0]	r_sreg; // Composed of 24-bits, 32-bits, and 32-bits
	initial	r_busy = 1'b0;
	initial	dev_wr = 1'b1;
	always @(posedge i_clk)
	begin
		dev_wr <= 1'b0;
		if ((~r_busy)&&(r_cstb))
		begin
			dev_dbit <= 1'b0;
			r_sreg <= { c_data[23:0], r_a, r_b };
			r_len <= b_len;
			r_busy <= (b_len != 4'h0);
		end else if ((~r_busy)&&(r_dstb))
		begin
			dev_dbit <= 1'b1;
			r_sreg <= { r_data[15:0], 72'h00 };
			r_len <= 4'h2;
			r_busy <= 1'b1;
		end else if ((r_busy)&&(!dev_busy))
		begin
			// Issue the command to write up to 32-bits at a time
			dev_wr <= (r_len != 4'h0);
			dev_word <= r_sreg[87:56];
			r_sreg <= { r_sreg[55:0], 32'h00 };
			dev_len <= (r_len > 4'h4)? 2'b11:(r_len[1:0]+2'b11);
			if (dev_wr)
				r_len <= (r_len > 4'h4) ? (r_len-4'h4):0;
			r_busy <= (dev_wr)||(r_len != 4'h0)&&(!dev_wr);
		end else if (r_busy) // & dev_busy
		begin
			dev_wr <= (r_len != 4'h0);
			dev_len <= (r_len > 4'h4)? 2'b11:(r_len[1:0]+2'b11);
		end
	end

	//
	// Here, we pick a self-clearing interrupt input.  This will set the
	// interrupt any time we are idle, and will automatically clear itself
	// any time we become busy.  This should be sufficient to allow the
	// DMA controller to send things to the card.
	//
	// Of course ... if you are not running in any sort of interrupt mode,
	// you *could* just ignore this line and poll the busy bit instead.
	//
	assign	o_int = (~r_busy)&&(!r_pre_busy);

	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = i_cyc;
	// verilator lint_on  UNUSED
endmodule
