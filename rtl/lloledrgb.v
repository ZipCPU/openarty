////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	lloledrgb.v
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	This is a low-level SPI output (not input) controller
//		designed to command interactions between an upper level
//	controller and a PModOLEDrgb.  As a result, this is a one-bit
//	(traditional, not quad) SPI controller, it has no MISO input bits,
//	and it also controls a DCN bits (output data at active high, vs
//	output control at active low).
//
//	This particular implementation was taken from a low-level QSPI
//	controller.  For those who wish to compare, the low-level QSPI
//	controller is very similar to the low-level EQSPI controller that is
//	also a part of the OpenArty project.
//
//	Interfacing with the controller works as follows: If the controller
//	is idle, set the values you wish to send and strobe the i_wr bit.
//	Once the last bit has been committed to the interface, but before it
//	closes the connection by setting CS_N high, it will check the i_wr bit
//	again.  If that bit is high, the busy bit will be dropped for one
//	cycle, new data will be accepted, and the controller will continue
//	with the new(er) data as though it was still part of the last 
//	transmission (without lowering cs_n).
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2024, Gisselquist Technology, LLC
// {{{
// This file is part of the OpenArty project.
//
// The OpenArty project is free software and gateware, licensed under the terms
// of the 3rd version of the GNU General Public License as published by the
// Free Software Foundation.
//
// This project is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
`default_nettype	none
// }}}
module	lloledrgb #(
		parameter	CTRBITS = 8
	) (
		// {{{
		input	wire		i_clk,
		// Module interface
		// Chip interface
		//	Can send info
		//		i_wr = 1,
		//			i_word = { 1'b0, 32'info to send },
		//			i_len = # of bytes in word-1
		input	wire		i_wr, i_dbit,
		input	wire	[31:0]	i_word,
		input	wire	[1:0]	i_len,	// 0=>8bits, 1=>16 bits, 2=>24 bits, 3=>32 bits
		output	reg		o_busy,
		// OLED interface
		// Interface with the OLED lines
		output	reg		o_sck, o_cs_n, o_mosi, o_dbit
		// }}}
	);

	// Local declarations
	// {{{
	localparam [2:0]	OLED_IDLE =	3'h0,
				OLED_START =	3'h1,
				OLED_BITS =	3'h2,
				OLED_READY =	3'h3,
				OLED_STOP =	3'h4,
				OLED_STOP_B =	3'h5,
				OLED_STOP_C =	3'h6;

	// Modes
	/*
	localparam [1:0]	OLED_MOD_SPI =	2'b00,
				OLED_MOD_QOUT =	2'b10,
				OLED_MOD_QIN =	2'b11;
	*/

	reg	[5:0]	spi_len;
	reg	[31:0]	r_word;
	reg	[2:0]	state;
	reg	[(CTRBITS-1):0]	counter;
	reg	last_counter, pre_last_counter;
	// }}}

	// Timing notes
	// {{{
	//	Tick	Clk	BSY/WR	CS_n	BIT/MO	STATE
	//	 0	1	0/0	1	 -	
	//	 1	1	0/1	1	 -
	//	 2	1	1/0	0	 -	OLED_START
	//	 3	0	1/0	0	 -	OLED_START
	//	 4	0	1/0	0	 0	OLED_BITS
	//	 5	1	1/0	0	 0	OLED_BITS
	//	 6	0	1/0	0	 1	OLED_BITS
	//	 7	1	1/0	0	 1	OLED_BITS
	//	 8	0	1/0	0	 2	OLED_BITS
	//	 9	1	1/0	0	 2	OLED_BITS
	//	10	0	1/0	0	 3	OLED_BITS
	//	11	1	1/0	0	 3	OLED_BITS
	//	12	0	1/0	0	 4	OLED_BITS
	//	13	1	1/0	0	 4	OLED_BITS
	//	14	0	1/0	0	 5	OLED_BITS
	//	15	1	1/0	0	 5	OLED_BITS
	//	16	0	1/0	0	 6	OLED_BITS
	//	17	1	1/1	0	 6	OLED_BITS
	//	18	0	1/1	0	 7	OLED_READY
	//	19	1	0/1	0	 7	OLED_READY
	//	20	0	1/0/V	0	 8	OLED_BITS
	//	21	1	1/0	0	 8	OLED_BITS
	//	22	0	1/0	0	 9	OLED_BITS
	//	23	1	1/0	0	 9	OLED_BITS
	//	24	0	1/0	0	10	OLED_BITS
	//	25	1	1/0	0	10	OLED_BITS
	//	26	0	1/0	0	11	OLED_BITS
	//	27	1	1/0	0	11	OLED_BITS
	//	28	0	1/0	0	12	OLED_BITS
	//	29	1	1/0	0	12	OLED_BITS
	//	30	0	1/0	0	13	OLED_BITS
	//	31	1	1/0	0	13	OLED_BITS
	//	32	0	1/0	0	14	OLED_BITS
	//	33	1	1/0	0	14	OLED_BITS
	//	34	0	1/0	0	15	OLED_READY
	//	35	1	1/0	0	15	OLED_READY
	//	36	1	1/0/V	0	 -	OLED_STOP
	//	37	1	1/0	0	 -	OLED_STOPB
	//	38	1	1/0	1	 -	OLED_IDLE
	//	39	1	0/0	1	 -
	// }}}

	initial	state = OLED_IDLE;
	initial	o_sck   = 1'b1;
	initial	o_cs_n  = 1'b1;
	initial	o_mosi  = 1'b0;
	initial	o_busy  = 1'b0;

	always @(posedge i_clk) // Clock cycle time > 150 ns > 300 ticks
		last_counter <= (counter == {{(CTRBITS-1){1'b0}},1'b1});
	always @(posedge i_clk)
		pre_last_counter <= (counter == {{(CTRBITS-2){1'b0}},2'b10});
	always @(posedge i_clk)
	if (state == OLED_IDLE)
		counter <= {(CTRBITS){1'b1}};
	else
		counter <= counter + {(CTRBITS){1'b1}};

	always @(posedge i_clk)
	if ((state == OLED_IDLE)&&(o_sck))
	begin
		o_cs_n <= 1'b1;
		o_busy  <= 1'b0;
		r_word <= i_word;
		spi_len<= { 1'b0, i_len, 3'b000 } + 6'h8;
		o_sck <= 1'b1;
		o_dbit <= i_dbit;
		if (i_wr)
		begin
			state <= OLED_START;
			o_cs_n <= 1'b0;
			o_busy <= 1'b1;
		end
	end else if (state == OLED_START)
	begin // We come in here with sck high, stay here 'til sck is low
		o_sck <= 1'b0;
		if (o_sck == 1'b0)
		begin
			state <= OLED_BITS;
			spi_len<= spi_len - 6'h1;
			r_word <= { r_word[30:0], 1'b0 };
		end
		o_cs_n <= 1'b0;
		o_busy <= 1'b1;
		o_mosi <= r_word[31];
	end else if (!last_counter)
	begin
		o_busy <= (!pre_last_counter)||(!o_sck)
			||(state != OLED_READY)||(~i_wr);
	end else if (!o_sck)
	begin
		o_sck <= 1'b1;
		o_busy <= 1'b1;
	end else if (state == OLED_BITS)
	begin
		// Should enter into here with at least a spi_len
		// of one, perhaps more
			o_sck <= 1'b0;
	o_busy <= 1'b1;
		o_mosi <= r_word[31];
		r_word <= { r_word[30:0], 1'b0 };
		spi_len <= spi_len - 6'h1;
		if (spi_len == 6'h1)
			state <= OLED_READY;
	end else if (state == OLED_READY)
	begin
		o_cs_n <= 1'b0;
		o_busy <= 1'b1;
		// This is the state on the last clock (both low and
		// high clocks) of the data.  Data is valid during
		// this state.  Here we chose to either STOP or
		// continue and transmit more.
		o_sck <= 1'b0;
		if((!o_busy)&&(i_wr))// Acknowledge a new request
		begin
			state <= OLED_BITS;
			o_busy <= 1'b1;
			o_sck <= 1'b0;

			// Set up the first bits on the bus
			o_mosi <= i_word[31];
			r_word <= { i_word[30:0], 1'b0 };
			spi_len<= { 1'b0, i_len, 3'b111 };

			// Read a bit upon any transition
		end else begin
			o_sck <= 1'b1;
			state <= OLED_STOP;
			o_busy <= 1'b1;
		end
	end else if (state == OLED_STOP)
	begin
		o_sck   <= 1'b1; // Stop the clock
		o_busy  <= 1'b1; // Still busy till port is clear
		state <= OLED_STOP_B;
	end else if (state == OLED_STOP_B)
	begin
		o_cs_n <= 1'b1;	// Deselect CS
		o_sck <= 1'b1;
		// Do I need this????
		// spi_len <= 3; // Minimum CS high time before next cmd
		state <= OLED_STOP_C;
		o_mosi <= 1'b1;
		o_busy <= 1'b1;
	end else // if (state == OLED_STOP_C)
	begin
		// Keep us in idle for at least a full clock period.
		o_cs_n <= 1'b1;	// Deselect CS
		o_sck <= 1'b1;
		// Do I need this????
		// spi_len <= 3; // Minimum CS high time before next cmd
		state <= OLED_IDLE;
		o_mosi <= 1'b1;
		o_busy <= 1'b1;
	end
endmodule

