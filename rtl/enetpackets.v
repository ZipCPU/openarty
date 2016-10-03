////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	enetpackets.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To communicate between the Ethernet PHY, and thus to coordinate
//		(and direct/arrange for) the transmission, and receiption, of 
//	packets via the Ethernet interface.
//
//
//	Using this interface requires four registers to be properly configured.
//	These are the receive and transmit control registers, as well as the
//	hardware MAC register(s).
//
//
//	To use the interface, after the system has been alive for a full
//	second, drop the reset line.  Do this by writing to the transmit
//	register a value with zero length, zero command, and the RESET bit as
//	zero.
//
//	This interface is big endian.  Therefore, the most significant byte
//	in each word will be transmitted first.  If the interface references
//	a number of octets less than a multiple of four, the least significant
//	octets in the last word will not be transmitted/were not received.
//
//	To transmit,
//		1. set the source MAC address in the two mac registers.  These
//			are persistent across packets, so once set (whether for
//			transmit or receive) they need not be set again.
//		2. Fill the packet buffer with your packet.  In general, the
//			first 32-bit word must contain the hardware MAC address
//			of your destination, spilling into the 16-bits of the
//			next word.  The bottom 16-bits of that second word
//			must also contain the EtherType (0x0800 for IP,
//			0x0806 for ARP, etc.)  The third word will begin your
//			user data.
//		3. Write a 0x4000 plus the number of bytes in your buffer to
//			the transmit command register.  If your packet is less
//			than 64 bytes, it will automatically be paddedd to 64
//			bytes before being sent.
//		4. Once complete, the controller will raise an interrupt
//			line to note that the interface is idle.
//	OPTIONS:
//		You can turn off the internal insertion of the hardware source
//		MAC by turning the respective bit on in the transmit command
//		register.  If you do this, half of the second word and all the
//		third word must contain the hardware MAC.  The third word must
//		contain the EtherType, both in the top and bottom sixteen bits.
//		The Fourth word will begin user data.
//
//		You can also turn off the automatic insertion of the FCS, or
//		ethernet CRC.  Doing this means that you will need to both 
//		guarantee for yourself that the packet has a minimum of 64
//		bytes in length, and that the last four bytes contain the
//		CRC.
//
//	To Receive: 
//		The receiver is always on.  Receiving is really just a matter
//		of pulling the received packet from the interface, and resetting
//		the interface for the next packet.
//
//		If the VALID bit is set, the receive interface has a valid
//		packet within it.  Write a zero to this bit to reset the
//		interface to accept the next packet.
//
//		If a packet with a CRC error is received, the CRC error bit
//		will be set.  Likewise if a packet has been missed, usually 
//		because the buffer was full when it started, the miss bit
//		will be set.  Finally, if an error occurrs while receiving
//		a packet, the error bit will be set.  These bits may be cleared
//		by writing a one to each of them--something that may be done
//		when clearing the interface for the next packet.
//	OPTIONS:
//		The same options that apply to the transmitter apply to the
//		receiver:
//
//		HWMAC.  If the hardware MAC is turned on, the receiver will
//		only accept packets to either 1) our network address, or 2)
//		a broadcast address.  Further, the first two words will be
//		adjusted to contain the source MAC and the EtherType, so that
//		the user information begins on the third word.  If this feature
//		is turned off, all packets will be received, and the first
//		three words will contain the destination and then source
//		MAC.  The fourth word will contain the EtherType in the lowest,
//		16 bits, meaning user data will begin on the fifth word.
//
//		HWCRC.  If the HWCRC is turned on, the receiver will only
//		detect packets that pass their CRC check.  Further, the packet
//		length (always in octets) will not include the CRC.  However,
//		the CRC will still be left/written to packet memory either way.
//
// Registers:
//	0	Receiver control
//		13'h0	|CRCerr|MISS|ERR|BUSY|VALID |14-bit length (in octets)|
//
//	1	Transmitter control
//		14'h0	|NET_RST|SW-MAC-CHK|SW-CRCn|BUSY/CMD | 14 bit length(in octets)|
//
//	2	// MAC address (high) ??
//	3	// MAC address (low)  ??
//	4	Number of receive packets missed
//	5	Number of receive packets ending in error
//	6	Number of receive packets with invalid CRCs
//	7	(Number of transmit collisions ??)
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2016, Gisselquist Technology, LLC
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
// `define	RX_SYNCHRONOUS_WITH_WB_CLK
`ifdef	RX_SYNCHRONOUS_WITH_WB_CLK
`define	RXCLK	i_wb_clk
`else
`define	RXCLK	i_net_rx_clk
`endif
// `define	TX_SYNCHRONOUS_WITH_WB_CLK
`ifdef	TX_SYNCHRONOUS_WITH_WB_CLK
`define	TXCLK	i_wb_clk
`else
`define	TXCLK	i_net_tx_clk
`endif
module	enetpackets(i_wb_clk, i_reset,
	i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data,
		o_wb_ack, o_wb_stall, o_wb_data,
	//
	o_net_reset_n, 
	i_net_rx_clk, i_net_col, i_net_crs, i_net_dv, i_net_rxd, i_net_rxerr,
	i_net_tx_clk, o_net_tx_en, o_net_txd,
	//
	o_rx_int, o_tx_int,
	//
	o_debug
	);
	parameter	MEMORY_ADDRESS_WIDTH = 14; // Log_2 octet width:11..14
	localparam	MAW =((MEMORY_ADDRESS_WIDTH>14)? 14:
			((MEMORY_ADDRESS_WIDTH<11)? 11:MEMORY_ADDRESS_WIDTH))-2;
	input			i_wb_clk, i_reset;
	//
	input			i_wb_cyc, i_wb_stb, i_wb_we;
	input	[(MAW+1):0]	i_wb_addr; // 1-bit for ctrl/data, 1 for tx/rx
	input	[31:0]		i_wb_data;
	//
	output	reg		o_wb_ack;
	output	wire		o_wb_stall;
	output	reg	[31:0]	o_wb_data;
	//
	output	reg		o_net_reset_n;
	//
	input			i_net_rx_clk, i_net_col, i_net_crs, i_net_dv;
	input		[3:0]	i_net_rxd;
	input			i_net_rxerr;
	//
	input			i_net_tx_clk;
	output	wire		o_net_tx_en;
	output	wire	[3:0]	o_net_txd;
	//
	output	wire		o_rx_int, o_tx_int;
	//
	output	wire	[31:0]	o_debug;

	reg	wr_ctrl;
	reg	[2:0]	wr_addr;
	reg	[31:0]	wr_data;
	always @(posedge i_wb_clk)
	begin
		wr_ctrl<=((i_wb_stb)&&(i_wb_we)&&(i_wb_addr[(MAW+1):MAW] == 2'b00));
		wr_addr <= i_wb_addr[2:0];
		wr_data <= i_wb_data;
	end

	reg	[31:0]	txmem	[0:((1<<MAW)-1)];
	reg	[31:0]	rxmem	[0:((1<<MAW)-1)];

	reg	[(MAW+1):0]	tx_len;

`ifdef	RX_SYNCHRONOUS_WITH_WB_CLK
	wire	[(MAW+1):0]	rx_len;
`else
	(* ASYNC_REG = "TRUE" *) reg	[(MAW+1):0]	rx_len;
`endif

	reg	tx_cmd, tx_cancel;
`ifdef	TX_SYNCHRONOUS_WITH_WB_CLK
	wire	tx_busy, tx_complete;
`else
	reg	tx_busy, tx_complete;
`endif
	reg	config_hw_crc, config_hw_mac;
	reg	rx_crcerr, rx_err, rx_miss, rx_clear;
`ifdef	RX_SYNCHRONOUS_WITH_WB_CLK
	wire	rx_valid, rx_busy;
`else
	reg	rx_valid, rx_busy;
`endif
	reg	rx_wb_valid, pre_ack, pre_cmd, tx_nzero_cmd;
	reg	[4:0]	caseaddr;
	reg	[31:0]	rx_wb_data, tx_wb_data;

	reg	[47:0]	hw_mac;

	initial	config_hw_crc = 0;
	initial	config_hw_mac = 0;
	initial	o_net_reset_n = 1'b0;
	initial	tx_cmd    = 1'b0;
	initial	tx_cancel = 1'b0;
	initial	rx_crcerr = 1'b0;
	initial	rx_err    = 1'b0;
	initial	rx_miss   = 1'b0;
	initial	rx_clear  = 1'b0;
	always @(posedge i_wb_clk)
	begin
		// if (i_wb_addr[(MAW+1):MAW] == 2'b10)
			// Writes to rx memory not allowed here
		if ((i_wb_stb)&&(i_wb_we)&&(i_wb_addr[(MAW+1):MAW] == 2'b11))
			txmem[i_wb_addr[(MAW-1):0]] <= i_wb_data;

		if ((wr_ctrl)&&(wr_addr==3'b000))
		begin // RX command register
			rx_crcerr<= (!wr_data[18])&&(!rx_crcerr);
			rx_err   <= (!wr_data[17])&&(!rx_err);
			rx_miss  <= (!wr_data[16])&&(!rx_miss);
			// busy bit cannot be written to
			rx_clear <= rx_clear || (!wr_data[14]);
			// Length bits are cleared when invalid
		end

		if ((tx_busy)||(tx_cancel))
			tx_cmd <= 1'b0;
		if (!tx_busy)
			tx_cancel <= 1'b0;
		pre_cmd <= 1'b0;
		if ((wr_ctrl)&&(wr_addr==3'b001))
		begin // TX command register

			// Reset bit must be held down to be valid
			o_net_reset_n <= (!wr_data[17]);
			config_hw_mac <= (!wr_data[16]);
			config_hw_crc <= (!wr_data[15]);
			pre_cmd <= (wr_data[14]);
			tx_cancel <= (tx_busy)&&(!wr_data[14]);
//		14'h0	| SW-CRCn |NET-RST|BUSY/CMD | 14 bit length(in octets)|
			tx_len <= wr_data[(MAW+1):0];
		end 
		tx_nzero_cmd <= ((pre_cmd)&&(tx_len != 0));
		if (tx_nzero_cmd)
			tx_cmd <= 1'b1;
		if (!o_net_reset_n)
			tx_cancel <= 1'b1;
		if (!o_net_reset_n)
			tx_cmd <= 1'b0;

		if ((wr_ctrl)&&(wr_addr==3'b010))
		begin
			hw_mac[47:32] <= wr_data[15:0];
		end
		if ((wr_ctrl)&&(wr_addr==3'b011))
		begin
			hw_mac[31:0] <= wr_data[31:0];
		end
	end

	wire	[31:0]	w_tx_ctrl;
	wire	[31:0]	w_rx_ctrl;
	wire	[3:0]	w_maw;

	assign	w_maw = MAW+2; // Number of bits in the packet length field
	assign	w_rx_ctrl = { 4'h0, w_maw, {(24-19){1'b0}}, rx_crcerr, rx_err,
			rx_miss, rx_busy, (rx_valid)&&(!rx_clear),
			{(14-MAW-2){1'b0}}, rx_len };

	assign	w_tx_ctrl = { 4'h0, w_maw, {(24-18){1'b0}}, 
			!o_net_reset_n,!config_hw_mac,
			!config_hw_crc, tx_busy,
				{(14-MAW-2){1'b0}}, tx_len };

	reg	[31:0]	counter_rx_miss, counter_rx_err, counter_rx_crc;
`ifdef	TX_SYNCHRONOUS_WITH_WB_CLK
	reg	[31:0]	counter_tx_clk;
`else
	wire	[31:0]	counter_tx_clk;
`endif
	initial	counter_rx_miss = 32'h00;
	initial	counter_rx_err  = 32'h00;
	initial	counter_rx_crc  = 32'h00;

	// Reads from the bus ... always done, regardless of i_wb_we
	always @(posedge i_wb_clk)
	begin
		rx_wb_data  <= rxmem[i_wb_addr[(MAW-1):0]];
		rx_wb_valid <= (i_wb_addr[(MAW-1):0] <= { rx_len[(MAW+1):2] });
		tx_wb_data  <= txmem[i_wb_addr[(MAW-1):0]];
		pre_ack <= i_wb_stb;
		caseaddr <= {i_wb_addr[(MAW+1):MAW], i_wb_addr[2:0] };

		casez(caseaddr)
		5'h00: o_wb_data <= w_rx_ctrl;
		5'h01: o_wb_data <= w_tx_ctrl;
		5'h02: o_wb_data <= {16'h00, hw_mac[47:32] };
		5'h03: o_wb_data <= hw_mac[31:0];
		5'h04: o_wb_data <= counter_rx_miss;
		5'h05: o_wb_data <= counter_rx_err;
		5'h06: o_wb_data <= counter_rx_crc;
		5'h07: o_wb_data <= counter_tx_clk;
		5'b10???: o_wb_data <= (rx_wb_valid)?rx_wb_data:32'h00;
		5'b11???: o_wb_data <= tx_wb_data;
		default: o_wb_data <= 32'h00;
		endcase
		o_wb_ack <= pre_ack;
	end

	/////////////////////////////////////
	//
	//
	//
	// Transmitter code
	//
	//
	//
	/////////////////////////////////////
`ifdef	TX_SYNCHRONOUS_WITH_WB_CLK
	reg	[(MAW+1):0]	n_tx_len;
	wire	n_tx_cmd, n_tx_cancel;
	assign	n_tx_cmd = tx_cmd;
	assign	n_tx_cancel = tx_cancel;
`else
	(* ASYNC_REG = "TRUE" *) reg	[(MAW+1):0]	n_tx_len;
	(* ASYNC_REG = "TRUE" *) reg r_tx_cmd, r_tx_cancel;
	reg	n_tx_cmd, n_tx_cancel;
	always @(posedge `TXCLK)
	begin
		r_tx_cmd    <= tx_cmd;
		r_tx_cancel <= tx_cancel;

		n_tx_cmd    <= r_tx_cmd;
		n_tx_cancel <= r_tx_cancel;
	end
`endif

`ifdef	TX_SYNCHRONOUS_WITH_WB_CLK
	reg	last_tx_clk, tx_clk_stb;
	(* ASYNC_REG = "TRUE" *) reg	r_tx_clk;
	always @(posedge i_wb_clk)
		r_tx_clk <= i_net_tx_clk;
	always @(posedge i_wb_clk)
		last_tx_clk <= r_tx_clk;
	always @(posedge i_wb_clk)
		tx_clk_stb <= (r_tx_clk)&&(!last_tx_clk);

	always @(posedge i_wb_clk)
		if (!o_net_reset_n)
			counter_tx_clk <= 32'h00;
		else if (tx_clk_stb)
			counter_tx_clk <= counter_tx_clk + 32'h01;
`else
	wire	tx_clk_stb, last_tx_clk;

	assign	tx_clk_stb = 1'b1;
	assign	last_tx_clk= 1'b0;
	assign	counter_tx_clk = 32'h00;
`endif

	wire	[(MAW+2):0]	rd_tx_addr;
	assign	rd_tx_addr = (n_tx_addr+8);

	reg	[(MAW+2):0]	n_tx_addr;
	reg	[31:0]		n_tx_data, n_next_tx_data;
`ifdef	TX_SYNCHRONOUSH_WITH_WB
	reg		n_tx_complete, n_tx_busy,
			n_tx_config_hw_mac, n_tx_config_hw_crc;
`else
	(* ASYNC_REG = "TRUE" *) reg	n_tx_complete, n_tx_busy,
					n_tx_config_hw_mac, n_tx_config_hw_crc;
`endif
	(* ASYNC_REG = "TRUE" *) reg r_tx_crs;
	reg	n_tx_crs;
	always @(posedge `TXCLK)
	begin
		r_tx_crs <= i_net_crs;
		n_tx_crs <= r_tx_crs;
	end

	wire	[31:0]	n_remap_tx_data;
	assign	n_remap_tx_data[31:28] = n_next_tx_data[27:24];
	assign	n_remap_tx_data[27:24] = n_next_tx_data[31:28];
	assign	n_remap_tx_data[23:20] = n_next_tx_data[19:16];
	assign	n_remap_tx_data[19:16] = n_next_tx_data[23:20];
	assign	n_remap_tx_data[15:12] = n_next_tx_data[11: 8];
	assign	n_remap_tx_data[11: 8] = n_next_tx_data[15:12];
	assign	n_remap_tx_data[ 7: 4] = n_next_tx_data[ 3: 0];
	assign	n_remap_tx_data[ 3: 0] = n_next_tx_data[ 7: 4];

	reg		r_txd_en;
	reg	[3:0]	r_txd;
	initial	r_txd_en = 1'b0;

	initial	n_tx_busy  = 1'b0;
	initial	n_tx_complete  = 1'b0;
	always @(posedge `TXCLK)
	begin
		if (tx_clk_stb)
		begin
			// While this operation doesn't strictly need to 
			// operate *only* if tx_clk_stb is true, by doing so
			// our code stays compatible with both synchronous
			// to wishbone and synchronous to tx clk options.
			n_next_tx_data  <= txmem[(!n_tx_busy)?0:rd_tx_addr[(MAW+2):3]];
		end


		if (n_tx_cancel)
			n_tx_busy <= 1'b0;
		else if (!n_tx_busy)
			n_tx_busy <= (n_tx_cmd)&&(!i_net_crs);
		else if (n_tx_addr >= { n_tx_len,1'b0 })
			n_tx_busy     <= 1'b0;

		if (!n_tx_busy)
		begin
			n_tx_addr  <= {{(MAW+2){1'b0}},1'b1};
			n_tx_data <= { n_remap_tx_data[27:0], 4'h0 };
			if (n_tx_complete)
				n_tx_complete <= (!n_tx_cmd);
			r_txd_en <= (!n_tx_complete)&&(n_tx_cmd)&&(!i_net_crs);
			r_txd  <= n_remap_tx_data[31:28];
			n_tx_config_hw_mac <= config_hw_mac;
			n_tx_config_hw_crc <= config_hw_crc;
			n_tx_len <= tx_len;
		end else if (!r_txd_en)
			r_txd_en <= (!n_tx_crs);
		else if (tx_clk_stb) begin
			n_tx_addr <= n_tx_addr + 1'b1;
			r_txd <= n_tx_data[31:28];
			if (n_tx_addr[2:0] == 3'h7)
				n_tx_data <= n_remap_tx_data;
			else
				n_tx_data <= { n_tx_data[27:0], 4'h0 };
			if (n_tx_addr >= { n_tx_len,1'b0 })
				n_tx_complete <= 1'b1;
			r_txd_en <= (n_tx_addr < { n_tx_len, 1'b0 });
		end
	end

	wire	n_tx_config_hw_preamble;
	assign	n_tx_config_hw_preamble = 1'b1;

	wire		w_macen, w_paden, w_crcen;
	wire	[3:0]	w_macd,  w_padd,  w_crcd;

`ifndef	TX_BYPASS_HW_MAC
	addemac	txmaci(`TXCLK, tx_clk_stb, n_tx_config_hw_mac, n_tx_cancel,
				hw_mac, r_txd_en, r_txd, w_macen, w_macd);
`else
	assign	w_macen = r_txd_en;
	assign	w_macd  = r_txd;
`endif

`ifndef	TX_BYPASS_PADDING
	addepad	txpadi(`TXCLK, tx_clk_stb, 1'b1, n_tx_cancel,
				w_macen, w_macd, w_paden, w_padd);
`else
	assign	w_paden = w_macen;
	assign	w_padd  = w_macd;
`endif

`ifndef	TX_BYPASS_HW_CRC
	addecrc	txcrci(`TXCLK, tx_clk_stb, n_tx_config_hw_crc, n_tx_cancel,
				w_paden, w_padd, w_crcen, w_crcd);
`else
	assign	w_crcen = w_macen;
	assign	w_crcd  = w_macd;
`endif

	addepreamble txprei(`TXCLK, tx_clk_stb, n_tx_config_hw_preamble, n_tx_cancel,
				w_crcen, w_crcd, o_net_tx_en, o_net_txd);

`ifdef	TX_SYNCRONOUS_WITH_WB_CLK
	assign	tx_busy = n_tx_busy;
	assign	tx_complete = n_tx_complete;
`else
	(* ASYNC_REG = "TRUE" *) reg	r_tx_busy, r_tx_complete;
	always @(posedge i_wb_clk)
	begin
		r_tx_busy <= (n_tx_busy || o_net_tx_en || w_crcen || w_macen || w_paden);
		tx_busy <= r_tx_busy;

		r_tx_complete <= n_tx_complete;
		tx_busy <= r_tx_busy;
	end
`endif





	/////////////////////////////////////
	//
	//
	//
	// Receiver code
	//
	//
	//
	/////////////////////////////////////
`ifdef	RX_SYNCHRONOUS_WITH_WB_CLK
	reg	last_rx_clk, rx_clk_stb;
	(* ASYNC_REG="TRUE" *) reg r_rx_clk;
	always @(posedge i_wb_clk)
		r_rx_clk <= i_net_rx_clk;
	always @(posedge i_wb_clk)
		last_rx_clk <= r_rx_clk;
	always @(posedge i_wb_clk)
		rx_clk_stb <= (r_rx_clk)&&(!last_rx_clk);

`else
	wire	rx_clk_stb, last_rx_clk;
	assign	rx_clk_stb = 1'b1;
	assign	last_rx_clk = 1'b0;
`endif

	reg	n_rx_first_clk;
	reg	[(MAW+2):0]	n_rx_addr;
	reg	[31:0]	n_rx_data;
	reg	n_rx_err, n_rx_miss;
	reg	n_rx_inpacket;
	reg	[2:0]	n_wrong_mac;
	initial	n_rx_err   = 1'b0;
	initial	n_rx_inpacket = 1'b0;
	initial	n_rx_miss  = 1'b0;

	reg	n_rx_wr;
	reg	[(MAW-1):0]	n_rx_wad;
	reg	[31:0]		n_rx_wdat;

`ifdef	RX_SYNCHRONOUS_WITH_WB_CLK
	wire	n_rx_clear;
	reg	n_rx_config_hw_mac;
	assign	n_rx_clear = rx_clear;
`else
	(* ASYNC_REG = "TRUE" *) reg n_rx_config_hw_mac;
	(* ASYNC_REG = "TRUE" *) reg r_rx_clear;
	reg	n_rx_clear;
	always @(posedge `RXCLK)
	begin
		r_rx_clear <= n_rx_clear;
		n_rx_clear <= r_rx_clear;
	end
`endif

	always @(posedge `RXCLK)
	begin
		n_rx_wr <= 1'b0;
		if (rx_clk_stb)
		begin
			if (!i_net_dv)
				n_rx_addr <= 0;
			if (!i_net_dv)
				n_rx_config_hw_mac <= config_hw_mac;
		//else if ((n_config_hw_mac)&&(!n_have_mac)
		//		&&(n_rx_addr== {{(MAW+2-4){1'b0}},4'hb}))
		//	n_rx_addr <= 0;
		// else if ((!n_config_hw_mac)
		// 		&&(n_rx_addr == {{(MAW+2-4){1'b0}},4'ha}))
		//	n_rx_addr <= n_rx_addr + 3'h5;
			else if (n_rx_addr == {{(MAW+3-4){1'b0}},4'ha})
				n_rx_addr <= n_rx_addr + {{(MAW+3-3){1'b0}}, 3'h5};
			else
				n_rx_addr <= n_rx_addr + 1'b1;

			n_wrong_mac[0] <= (n_rx_addr == {{(MAW+3-5){1'b0}},5'h4})
					&&(n_rx_data[15:0] != hw_mac[47:32]);
			n_wrong_mac[1] <= (n_rx_addr == {{(MAW+3-5){1'b0}},5'h8})
					&&(n_rx_data[15:0] != hw_mac[31:16]);
			n_wrong_mac[2] <= (n_rx_addr == {{(MAW+3-5){1'b0}},5'h10})
					&&(n_rx_data[15:0] != hw_mac[15:0]);

			n_rx_inpacket <= (n_rx_inpacket)&&((!n_rx_config_hw_mac)
					||(n_wrong_mac == 3'h0));

			// We'll do our write on the next clock, so we can
			// have a clock to stuff our bits properly.
			//
			// However, we have to be careful that we *only*
			// do the write if we are clear to write a new packet.
			n_rx_wad <= n_rx_addr[(MAW+2):3];
			case(n_rx_addr[2:0])
			3'h0: n_rx_wdat <= { i_net_rxd, 28'h00 };
			3'h1: n_rx_wdat <= { n_rx_data[ 3:0], i_net_rxd, 24'h00 };
			3'h2: n_rx_wdat <= { n_rx_data[ 7:0], i_net_rxd, 20'h00 };
			3'h3: n_rx_wdat <= { n_rx_data[11:0], i_net_rxd, 16'h00 };
			3'h4: n_rx_wdat <= { n_rx_data[15:0], i_net_rxd, 12'h00 };
			3'h5: n_rx_wdat <= { n_rx_data[19:0], i_net_rxd,  8'h00 };
			3'h6: n_rx_wdat <= { n_rx_data[23:0], i_net_rxd,  4'h00 };
			3'h7: n_rx_wdat <= { n_rx_data[27:0], i_net_rxd };
			endcase

			// Now, things can do ... on the first clock of the
			// packet ...
			// if ((first_clk)&&(i_net_dv))
			if (!i_net_dv)
				n_rx_data <= 32'h00;
			else
				n_rx_data <= { n_rx_data[27:0], i_net_rxd };

			if (!i_net_dv)
				n_rx_first_clk <= 1'b1;
			else
				n_rx_first_clk <= 1'b0;

			if (!i_net_dv)
			begin
				n_rx_inpacket <= 1'b0;
				n_rx_miss <= 1'b0;
				n_rx_data <= 32'h00;
				n_rx_err  <= 1'b0;
				// n_have_mac<= 1'b0;
			end else if((n_rx_inpacket)||((n_rx_first_clk)&&((n_rx_clear)||(!n_rx_valid))))
			begin
				n_rx_wr <= 1'b1;
				n_rx_inpacket <= 1'b1;
				n_rx_err   <= (n_rx_err)||(i_net_rxerr);
			end else
				n_rx_miss <= 1'b1;

			if (n_rx_wr)
				rxmem[n_rx_wad] <= n_rx_wdat;
		end
	end

	reg	n_rx_valid, n_rx_busy, rx_err_stb, rx_miss_stb, n_rx_complete,
			n_last_rx_complete;

`ifdef	RX_SYNCHRONOUS_WITH_WB_CLK
	reg	[31:0]	n_rx_toggle;
	initial	n_rx_toggle = 32'h0;
`else
	reg	[11:0]	n_rx_toggle;
	initial	n_rx_toggle = 12'h0;
`endif
	reg	[(MAW+1):0]	n_rx_len;
	initial	n_rx_busy = 1'b0;
	initial	n_rx_valid  = 1'b0;
	initial	n_rx_complete = 1'b1;
	initial	n_last_rx_complete = 1'b1;
	always @(posedge `RXCLK)
	begin
`ifdef	RX_SYNCHRONOUS_WITH_WB_CLK
		n_rx_toggle <= { n_rx_toggle[30:0], n_rx_addr[1] };
		n_rx_complete<=((n_rx_toggle == 32'h00)||(n_rx_toggle == 32'hffffffff));
`else
		n_rx_toggle <= { n_rx_toggle[10:0], n_rx_addr[1] };
		n_rx_complete<=((n_rx_toggle == 12'h00)||(n_rx_toggle == 12'hfff));
`endif
		n_last_rx_complete <= n_rx_complete;

		n_rx_busy <= (!n_rx_complete)||(i_net_dv);
		if ((n_rx_complete)&&(!n_last_rx_complete))
		begin
			n_rx_len <= n_rx_addr[(MAW+2):1];
			n_rx_valid <= (!n_rx_miss)&&(!n_rx_err);
		end else if (!n_rx_complete) begin
			n_rx_valid <= (n_rx_valid)&&(!n_rx_clear);
		end
	end

`ifdef	RX_SYNCHRONOUS_WITH_WB_CLK
	assign	rx_busy  = n_rx_busy;
	assign	rx_valid = n_rx_valid;
	assign	rx_len   = n_rx_len;

	reg	r_rx_busy;
	always @(posedge i_wb_clk)
	begin
		r_rx_busy <= rx_busy;
		rx_err_stb <= ((rx_busy)&&(!r_rx_busy)&&(n_rx_err));
		rx_miss_stb<= ((rx_busy)&&(!r_rx_busy)&&(n_rx_miss));
	end
`else
	reg	r_rx_busy, r_rx_valid;
	always @(posedge `RXCLK)
	begin
		r_rx_valid <= n_rx_valid;
		rx_valid <= r_rx_valid;

		r_rx_busy <= n_rx_busy;
		rx_busy <= r_rx_busy;

		rx_len <= n_rx_len;
	end

`endif
	always @(posedge `RXCLK)
		if (o_net_reset_n)
			counter_rx_miss <= 32'h0;
		else if (rx_miss_stb)
			counter_rx_miss <= counter_rx_miss + 32'h1;
	always @(posedge `RXCLK)
		if (o_net_reset_n)
			counter_rx_err <= 32'h0;
		else if (rx_err_stb)
			counter_rx_err <= counter_rx_err + 32'h1;

	assign	o_tx_int = !tx_busy;
	assign	o_rx_int = (rx_valid)&&(!rx_clear);
	assign	o_wb_stall = 1'b0;

	wire	[31:0]	rxdbg;
	assign	rxdbg = { i_net_dv, rx_clk_stb,
			{(30-MAW-3-12){1'b0}}, n_rx_addr[(MAW+2):0],
		n_rx_clear, n_rx_err, n_rx_miss, n_rx_inpacket,	// 4 bits
		n_rx_valid, n_rx_busy, i_net_crs, i_net_dv,	// 4 bits
		i_net_rxd };					// 4 bits


	wire	[31:0]	txdbg;
	assign	txdbg = { n_tx_cmd, i_net_dv, rx_busy, n_rx_err, i_net_rxd,
			{(24-(MAW+3)-10){1'b0}}, 
			n_tx_addr[(MAW+2):0],
		tx_clk_stb, n_tx_cancel,
		n_tx_cmd, n_tx_complete, n_tx_busy, o_net_tx_en,
		o_net_txd
		};

	assign	o_debug = txdbg;
endmodule
