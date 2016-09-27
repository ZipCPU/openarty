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
module	enetpackets(i_wb_clk, i_reset,
	i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data,
		o_wb_ack, o_wb_stall, o_wb_data,
	//
	o_net_reset_n, 
	i_net_rx_clk, i_net_col, i_net_crs, i_net_dv, i_net_rxd, i_net_rxerr,
	i_net_tx_clk, o_net_tx_en, o_net_txd,
	//
	o_rx_int, o_tx_int
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
	output	reg		o_net_tx_en;
	output	reg	[3:0]	o_net_txd;
	//
	output	wire		o_rx_int, o_tx_int;

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
	(* ASYNC_REG = "TRUE" *) reg	[(MAW+1):0]	rx_len;

	reg	tx_busy, tx_cmd, tx_cancel, tx_complete;
	reg	config_use_crc, config_use_mac;
	reg	rx_crcerr, rx_err, rx_miss, rx_clear, rx_busy, rx_valid;
	reg	rx_wb_valid, pre_ack;
	reg	[4:0]	caseaddr;
	reg	[31:0]	rx_wb_data, tx_wb_data;
	(* ASYNC_REG = "TRUE" *) reg	[47:0]	hw_mac;

	// We only need eleven of these values.  We allocate 16 in order to
	// round up to the nearest power of two.
	(* ASYNC_REG = "TRUE" *) reg	[15:0]	preamble	[0:15];

	initial	preamble[ 0] = 16'h5555;
	initial	preamble[ 1] = 16'h5555;
	initial	preamble[ 2] = 16'h5555;
	initial	preamble[ 3] = 16'h55d5;
	// The following values are never used, but must be defined and
	// initialized anyway.
	initial	preamble[11] = 16'h0000;
	initial	preamble[12] = 16'h0000;
	initial	preamble[13] = 16'h0000;
	initial	preamble[14] = 16'h0000;
	initial	preamble[15] = 16'h0000;

	initial	config_use_crc = 0;
	initial	config_use_mac = 0;
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
		if ((i_wb_stb)&&(i_wb_we)&&(i_wb_addr[(MAW+1):MAW] == 2'b11)
				&&(i_wb_addr[(MAW-1):0]==0))
		begin
			preamble[4] <= i_wb_data[31:16];
			preamble[5] <= i_wb_data[15:0];
		end
		if ((i_wb_stb)&&(i_wb_we)&&(i_wb_addr[(MAW+1):MAW] == 2'b11)
				&&(i_wb_addr[(MAW-1):1]==0)&&(!i_wb_addr[0]))
		begin
			preamble[6]  <= i_wb_data[31:16];
			preamble[10] <= i_wb_data[15:0];
		end

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
		if ((wr_ctrl)&&(wr_addr==3'b001))
		begin // TX command register

			// Reset bit must be held down to be valid
			o_net_reset_n <= (!wr_data[17]);
			config_use_crc <= (!wr_data[16]);
			config_use_mac <= (!wr_data[15]);
			tx_cmd <= (wr_data[14]);
			tx_cancel <= (tx_busy)&&(!wr_data[14]);
//		14'h0	| SW-CRCn |NET-RST|BUSY/CMD | 14 bit length(in octets)|
			tx_len <= wr_data[(MAW+1):0];
		end
		if (!o_net_reset_n)
			tx_cancel <= 1'b1;
		if (!o_net_reset_n)
			tx_cmd <= 1'b0;

		if ((wr_ctrl)&&(wr_addr==3'b010))
		begin
			hw_mac[47:32] <= wr_data[15:0];
			preamble[7] <= wr_data[15:0];
		end
		if ((wr_ctrl)&&(wr_addr==3'b011))
		begin
			hw_mac[31:0] <= wr_data[31:0];
			preamble[8]  <= wr_data[31:16];
			preamble[9]  <= wr_data[15:0];
		end
	end

	wire	[31:0]	w_tx_ctrl;
	wire	[31:0]	w_rx_ctrl;
	wire	[3:0]	w_maw;

	assign	w_maw = MAW+2; // Number of bits in the packet length field
	assign	w_tx_ctrl = { 4'h0, w_maw, {(24-18){1'b0}}, 
			!o_net_reset_n,!config_use_mac,!config_use_crc, tx_busy,
			{(14-MAW-2){1'b0}}, tx_len };

	assign	w_rx_ctrl = { 4'h0, w_maw, {(24-19){1'b0}}, rx_crcerr, rx_err,
			rx_miss, rx_busy, (rx_valid)&&(!rx_clear),
			{(14-MAW-2){1'b0}}, rx_len };

	reg	[31:0]	counter_rx_miss, counter_rx_err, counter_rx_crc;
	initial	counter_rx_miss = 32'h00;
	initial	counter_rx_err  = 32'h00;
	initial	counter_rx_crc  = 32'h00;

	// Reads from the bus ... always done, regardless of i_wb_we
	always @(posedge i_wb_clk)
	begin
		rx_wb_data  <= rxmem[i_wb_addr[(MAW-1):0]];
		rx_wb_valid <= (i_wb_addr[(MAW-1):0] <= { rx_len[(MAW+1):2] });
		tx_wb_data  <= rxmem[i_wb_addr[(MAW-1):0]];
		pre_ack <= i_wb_stb;
		caseaddr <= {i_wb_addr[(MAW+1):MAW], i_wb_addr[2:0] };

		casez(caseaddr)
		5'h00: o_wb_data <= w_tx_ctrl;
		5'h01: o_wb_data <= w_rx_ctrl;
		5'h02: o_wb_data <= {16'h00, hw_mac[47:32] };
		5'h03: o_wb_data <= hw_mac[31:0];
		5'h04: o_wb_data <= counter_rx_miss;
		5'h05: o_wb_data <= counter_rx_err;
		5'h06: o_wb_data <= counter_rx_crc;
		5'b10???: o_wb_data <= (rx_wb_valid)?rx_wb_data:32'h00;
		5'b11???: o_wb_data <= tx_wb_data;
		default: o_wb_data <= 32'h00;
		endcase
		o_wb_ack <= pre_ack;
	end

	(* ASYNC_REG = "TRUE" *) reg	r_tx_cmd, r_tx_cancel, n_config_use_mac;
	reg	n_tx_cmd, n_tx_cancel;
	always @(posedge i_net_tx_clk)
	begin // Clock transfer
		r_tx_cmd <= tx_cmd;
		n_tx_cmd <= r_tx_cmd;
		//
		r_tx_cancel <= tx_cancel;
		n_tx_cancel <= r_tx_cancel;
	end

	wire	[(MAW+2):0]	rd_tx_addr;
	assign	rd_tx_addr = n_tx_addr - 22;

	reg	[(MAW+2):0]	n_tx_addr;
	reg	[31:0]		n_tx_data, n_next_tx_data;
	(* ASYNC_REG = "TRUE" *) reg	[31:0]	n_next_preamble;
	(* ASYNC_REG = "TRUE" *) reg		n_tx_complete, n_tx_busy;
	initial	n_tx_busy  = 1'b0;
	initial	n_tx_complete  = 1'b0;
	always @(posedge i_net_tx_clk)
	begin
		n_next_tx_data  <= txmem[rd_tx_addr[(MAW-1):0]];
		n_next_preamble <= { preamble[n_tx_addr[5:2]], 16'h00 };
		if ((!n_tx_busy)||(n_tx_cancel))
		begin
			n_tx_addr <= 0;
			n_tx_data <= 32'h5555; // == preamble[0]
			if (n_tx_complete)
				n_tx_complete <= (!n_tx_cmd);
			else if (n_tx_cmd)
				n_tx_busy <= 1'b1;
			else
				n_tx_busy <= 1'b0;
			o_net_tx_en <= 1'b0;
			o_net_txd   <= 4'h0;
			n_config_use_mac <= config_use_mac;
		end else begin
			o_net_txd <= n_tx_data[31:28];
			if ((n_config_use_mac)&&(n_tx_addr < {{(MAW+3-6){1'b0}},6'h2c}))
			begin
				if (n_tx_addr[1:0]==2'b11)
					n_tx_data <= n_next_preamble;
				else
					n_tx_data <= { n_tx_data[27:0], 4'h0 };
			end else begin
				if (n_tx_addr[2:0] == 3'h7)
					n_tx_data <= n_next_tx_data;
				else
					n_tx_data <= { n_tx_data[27:0], 4'h0 };
				// If not using h/w mac, and if we are after
				// the preamble, the bump our next word
				//
				// We allow 
				//	0/0: 0x55555555
				//	1/8: 0x555555d5
				//	2/16: Destination MAC
				//	3/24: Destination MAC / Source MAC
				//	4/32: Source MAC
				//	5/40: Ethernet PORT (16'bits ignored)
				// and jump midway though the fifth word
			end
			if ((!n_config_use_mac)&&(n_tx_addr == { {(MAW+3-6){1'b0}}, 6'd40}))
				n_tx_addr <= n_tx_addr + { {(MAW+3-5){1'b0}}, 5'h4};
			else
				n_tx_addr <= n_tx_addr + 1'b1;

			if (n_tx_addr >= { tx_len,1'b0 })
			begin
				n_tx_complete <= 1'b1;
				n_tx_busy     <= 1'b0;
			end
		end
	end

	(* ASYNC_REG = "TRUE" *) reg	r_tx_busy, r_tx_complete;
	initial	r_tx_busy = 1'b0;
	always @(posedge i_wb_clk)
	begin
		r_tx_busy <= n_tx_busy;
		tx_busy <= r_tx_busy;

		r_tx_complete <= n_tx_complete;
		tx_complete <= r_tx_complete;
	end

	reg	[(MAW+2):0]	n_rx_addr;
	reg	[31:0]	n_rx_data;
	(* ASYNC_REG = "TRUE" *) reg	r_rx_clear, n_rx_err, n_rx_miss;
	reg	n_rx_inpacket, n_rx_clear;
	reg	[2:0]	n_wrong_mac;
	initial	r_rx_clear = 1'b0;
	initial	n_rx_clear = 1'b0;
	initial	n_rx_err   = 1'b0;
	initial	n_rx_inpacket = 1'b0;
	initial	n_rx_miss  = 1'b0;
	always @(posedge i_net_rx_clk)
	begin
		r_rx_clear <= rx_clear;
		n_rx_clear <= r_rx_clear;

		if (!i_net_dv)
			n_rx_addr <= 0;
		//else if ((n_config_use_mac)&&(!n_have_mac)
		//		&&(n_rx_addr== {{(MAW+2-4){1'b0}},4'hb}))
		//	n_rx_addr <= 0;
		// else if ((!n_config_use_mac)
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

		n_rx_inpacket <= (n_rx_inpacket)&&((!n_config_use_mac)
				||(n_wrong_mac == 3'h0));

		if (!i_net_dv)
		begin
			n_rx_addr <= 0;
			n_rx_inpacket <= 1'b0;
			n_rx_miss <= 1'b1;
			if ((n_rx_clear)||(!n_rx_valid))
				n_rx_inpacket <= 1'b1;
			else
				n_rx_miss <= 1'b1;
			n_rx_data <= 32'h00;
			n_rx_err  <= 1'b0;
			// n_have_mac<= 1'b0;
		end else if (n_rx_inpacket)
		begin
			n_rx_data <= { n_rx_data[27:0], i_net_rxd };
			rxmem[n_rx_addr[(MAW+2):3]] <= { n_rx_data[27:0], i_net_rxd };
			// rxmem[] <= { n_rx_data[ 3:0], i_net_rxd, 24'h00 };
			// rxmem[] <= { n_rx_data[11:0], i_net_rxd, 16'h00 };
			// rxmem[] <= { n_rx_data[19:0], i_net_rxd, 8'h00 };
			// rxmem[] <= { n_rx_data[27:0], i_net_rxd };
			n_rx_err   <= (n_rx_err)||(i_net_rxerr);
			// n_have_mac <= (n_rx_addr == {{(MAW+2){1'b0}},4'hb});

		end
	end

	reg	n_rx_valid, n_rx_busy, rx_err_stb, rx_miss_stb, n_rx_complete;
	(* ASYNC_REG = "TRUE" *) reg	[11:0]	n_rx_toggle;
	reg	[(MAW+1):0]	n_rx_len;
	initial	n_rx_busy = 1'b0;
	initial	n_rx_toggle = 12'h0f0;
	initial	n_rx_valid  = 1'b0;
	initial	n_rx_complete = 1'b0;
	always @(posedge i_net_tx_clk)
	begin
		n_rx_toggle <= { n_rx_toggle[10:0], n_rx_addr[1] };
		n_rx_complete<=((n_rx_toggle == 12'h00)||(n_rx_toggle == 12'hfff));
		if (n_rx_complete)
		begin
			n_rx_busy <= 1'b1;
			n_rx_len <= n_rx_addr[(MAW+2):1];
			n_rx_valid <= 1'b0;
		end else begin
			n_rx_busy <= 1'b0;
			n_rx_valid <= (n_rx_inpacket)&&(!n_rx_err);
		end
	end


	(* ASYNC_REG = "TRUE" *) reg	r_rx_valid, r_rx_busy;
	always @(posedge i_wb_clk)
	begin
		r_rx_valid <= n_rx_valid;
		rx_valid <= r_rx_valid;

		r_rx_busy <= n_rx_busy;
		rx_busy <= r_rx_busy;

		rx_len <= n_rx_len;

		rx_err_stb <= ((rx_busy)&&(!r_rx_busy)&&(n_rx_err));
		rx_miss_stb<= ((rx_busy)&&(!r_rx_busy)&&(n_rx_miss));
	end

	always @(posedge i_wb_clk)
		if (o_net_reset_n)
			counter_rx_miss <= 32'h0;
		else if (rx_miss_stb)
			counter_rx_miss <= counter_rx_miss + 32'h1;
	always @(posedge i_wb_clk)
		if (o_net_reset_n)
			counter_rx_err <= 32'h0;
		else if (rx_miss_stb)
			counter_rx_err <= counter_rx_err + 32'h1;

	assign	o_tx_int = !tx_busy;
	assign	o_rx_int = (rx_valid)&&(!rx_clear);
	assign	o_wb_stall = 1'b0;

	/*
	wire	[31:0]	rxdbg;
	assign	rxdbg = { {(32-MAW-3-12){1'b0}}, n_rx_addr[(MAW+2):0],
		n_rx_clear, n_rx_err, n_rx_miss, n_rx_inpacket,
		n_rx_valid, n_rx_busy, i_rx_crs, i_rx_dv,
		i_rxd };
	*/

	/*
	wire	[31:0]	txdbg;
	assign	txdbg = {
			n_tx_addr[(MAW+2):0],
		3'h0, n_tx_cancel,
		n_tx_cmd, n_tx_complete, n_tx_busy, o_net_tx_en,
		o_net_txd
		};
	*/
endmodule
