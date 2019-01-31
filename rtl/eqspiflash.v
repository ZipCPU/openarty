////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	eqspiflash.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Provide access to the flash device on an Arty, via the Extended
//		SPI interface.  Reads and writes will use the QuadSPI interface
//	(4-bits at a time) all other commands (register and otherwise) will use
//	the SPI interface (1 bit at a time).
//
// Registers:
//	0. Erase register control.  Provides status of pending writes, erases,
//		and commands (sub)sector erase operations.
//	   Bit-Fields:
//		31. WIP (Write-In-Progress), write a '1' to this bit to command
//			an erase sequence.
//		30. WriteEnabled -- set to a '1' to disable write protection and
//			to write a WRITE-ENABLE to the device.  Set to a '0' to
//			disable WRITE-ENABLE-LATCH.  (Key is required to enable
//			writes)
//		29. Quad mode read/writes enabled.  (Rest of controller will use
//			extended SPI mode, but reads and writes will use Quad
//			mode.)
//		28. Subsector erase bit (set 1 to erase a subsector, 0 to 
//			erase a full sector, maintains last value written from
//			an erase command, starts at '0')
//		27. SD ID loaded
//		26. Write protect violation--cleared upon any valid write
//		25. XIP enabled.  (Leave read mode in XIP, so you can start
//			next read faster.)
//		24. Unused
//		23..0: Address of erase sector upon erase command
//		23..14: Sector address (can only be changed w/ key)
//		23..10: Subsector address (can only be changed w/ key)
//		 9.. 0: write protect KEY bits, always read a '0', write
//			commands, such as WP disable or erase, must always
//			write with a '1be' to activate.
//	0. WEL:	All writes that do not command an erase will be used
//			to set/clear the write enable latch.
//			Send 0x06, return, if WP is clear (enable writes)
//			Send 0x04, return
//	1. STATUS
//		Send 0x05, read  1-byte
//		Send 0x01, write 1-byte: i_wb_data[7:0]
//	2. NV-CONFIG (16-bits)
//		Send 0xB5, read  2-bytes
//		Send 0xB1, write 2-bytes: i_wb_data[15:0]
//	3. V-CONFIG (8-bits)
//		Send 0x85, read  1-byte
//		Send 0x81, write 1-byte: i_wb_data[7:0]
//	4. EV-CONFIG (8-bits)
//		Send 0x65, read  1-byte
//		Send 0x61, write 1-byte: i_wb_data[7:0]
//	5. Lock (send 32-bits, rx 1 byte)
//		Send 0xE8, last-sector-addr (3b), read  1-byte
//		Send 0xE5, last-sector-addr (3b), write 1-byte: i_wb_data[7:0]
//	6. Flag Status
//		Send 0x70, read  1-byte
//		Send 0x50, to clear, no bytes to write
//	7. Asynch Read-ID: Write here to cause controller to read ID into buffer
//	8.-12.	ID buffer (20 bytes, 5 words)
//		Attempted reads before buffer is full will stall bus until 
//		buffer is read.  Writes act like the asynch-Read-ID command,
//		and will cause the controller to read the buffer.
//	13. Reset Enable
//	14. Reset Memory
//	15.	OTP control word
//			Write zero to permanently lock OTP
//			Read to determine if OTP is permanently locked
//	16.-31.	OTP (64-bytes, 16 words, buffered until write)
//		(Send DWP before writing to clear write enable latch)
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
//
// `define	QSPI_READ_ONLY
// verilator lint_off DECLFILENAME
module	eqspiflash(i_clk_82mhz, i_rst,
		// Incoming wishbone connection(s)
		//	The two strobe lines allow the data to live on a
		//	separate part of the master bus from the control 
		//	registers.  Only one strobe will ever be active at any
		//	time, no strobes will ever be active unless i_wb_cyc
		//	is also active.
		i_wb_cyc, i_wb_data_stb, i_wb_ctrl_stb, i_wb_we,
		i_wb_addr, i_wb_data,
		// Outgoing wishbone data
		o_wb_ack, o_wb_stall, o_wb_data,
		// Quad SPI connections
		o_qspi_sck, o_qspi_cs_n, o_qspi_mod, o_qspi_dat, i_qspi_dat,
		// Interrupt the CPU
		o_interrupt, o_cmd_accepted,
		// Debug the interface
		o_dbg);

	input	wire		i_clk_82mhz, i_rst;
	// Wishbone bus inputs
	input	wire		i_wb_cyc, i_wb_data_stb, i_wb_ctrl_stb, i_wb_we;
	input	wire	[21:0]	i_wb_addr;	// 24 bits of addr space
	input	wire	[31:0]	i_wb_data;
	// Wishbone bus outputs
	output	reg		o_wb_ack;
	output	wire		o_wb_stall;
	output	reg	[31:0]	o_wb_data;
	// Quad SPI connections
	output	wire		o_qspi_sck, o_qspi_cs_n;
	output	wire	[1:0]	o_qspi_mod;
	output	wire	[3:0]	o_qspi_dat;
	input	wire	[3:0]	i_qspi_dat;
	//
	output	reg		o_interrupt;
	//
	output	reg		o_cmd_accepted;
	//
	output	wire	[31:0]	o_dbg;

	initial	o_cmd_accepted = 1'b0;
	always @(posedge i_clk_82mhz)
		o_cmd_accepted <= ((i_wb_data_stb)||(i_wb_ctrl_stb))
					&&(~o_wb_stall);
	//
	// lleqspi
	//
	//	Providing the low-level SPI interface
	//
	reg	spi_wr, spi_hold, spi_spd, spi_dir, spi_recycle;
	reg	[31:0]	spi_word;
	reg	[1:0]	spi_len;
	wire	[31:0]	spi_out;
	wire		spi_valid, spi_busy, spi_stopped;
	lleqspi	lowlvl(i_clk_82mhz, spi_wr, spi_hold, spi_word, spi_len,
			spi_spd, spi_dir, spi_recycle, spi_out, spi_valid, spi_busy,
		o_qspi_sck, o_qspi_cs_n, o_qspi_mod, o_qspi_dat, i_qspi_dat);
	assign	spi_stopped = (o_qspi_cs_n)&&(~spi_busy)&&(~spi_wr);


	//
	// Bus module
	//
	//	Providing a shared interface to the WB bus
	//
	// Wishbone data (returns)
	wire		bus_wb_ack, bus_wb_stall;
	wire	[31:0]	bus_wb_data;
	// Latched request data
	wire		bus_wr;
	wire	[21:0]	bus_addr;
	wire	[31:0]	bus_data;
	wire	[21:0]	bus_sector;
	// Strobe commands
	wire	bus_ack;
	wire	bus_readreq, bus_piperd, bus_ereq, bus_wreq,
			bus_pipewr, bus_endwr, bus_ctreq, bus_idreq,
			bus_other_req,
	// Live parameters
			w_xip, w_quad, w_idloaded, w_leave_xip;
	reg		bus_wip;
	qspibus	preproc(i_clk_82mhz, i_rst,
			i_wb_cyc, i_wb_data_stb, i_wb_ctrl_stb,
				i_wb_we, i_wb_addr, i_wb_data,
				bus_wb_ack, bus_wb_stall, bus_wb_data,
			bus_wr, bus_addr, bus_data, bus_sector,
				bus_readreq, bus_piperd,
					bus_wreq, bus_ereq,
					bus_pipewr, bus_endwr,
				bus_ctreq, bus_idreq, bus_other_req, bus_ack,
			w_xip, w_quad, w_idloaded, bus_wip, spi_stopped);

	//
	// Read flash module
	//
	//	Providing a means of (and the logic to support) reading from
	//	the flash
	//
	wire		rd_data_ack;
	wire	[31:0]	rd_data;
	//
	wire		rd_bus_ack;
	//
	wire		rd_qspi_req;
	wire		rd_qspi_grant;
	//
	wire		rd_spi_wr, rd_spi_hold, rd_spi_spd, rd_spi_dir, 
			rd_spi_recycle;
	wire	[31:0]	rd_spi_word;
	wire	[1:0]	rd_spi_len;
	//
	readqspi	rdproc(i_clk_82mhz, bus_readreq, bus_piperd,
					bus_other_req,
				bus_addr, rd_bus_ack,
				rd_qspi_req, rd_qspi_grant,
				rd_spi_wr, rd_spi_hold, rd_spi_word, rd_spi_len,
				rd_spi_spd, rd_spi_dir, rd_spi_recycle,
					spi_out, spi_valid,
					spi_busy, spi_stopped, rd_data_ack, rd_data,
					w_quad, w_xip, w_leave_xip);

	//
	// Write/Erase flash module
	//
	//	Logic to write (program) and erase the flash.
	//
	// Wishbone bus return
	wire		ew_data_ack;
	// Arbiter interaction
	wire		ew_qspi_req;
	wire		ew_qspi_grant;
	// Bus controller return
	wire		ew_bus_ack;
	// SPI control wires
	wire		ew_spi_wr, ew_spi_hold, ew_spi_spd, ew_spi_dir;
	wire	[31:0]	ew_spi_word;
	wire	[1:0]	ew_spi_len;
	//
	wire		w_ew_wip;
	//
	writeqspi	ewproc(i_clk_82mhz, bus_wreq,bus_ereq,
					bus_pipewr, bus_endwr,
					bus_addr, bus_data,
				ew_bus_ack, ew_qspi_req, ew_qspi_grant,
				ew_spi_wr, ew_spi_hold, ew_spi_word, ew_spi_len,
					ew_spi_spd, ew_spi_dir,
					spi_out, spi_valid, spi_busy, spi_stopped,
				ew_data_ack, w_quad, w_ew_wip);

	//
	// Control module
	//
	//	Logic to read/write status and configuration registers
	//
	// Wishbone bus return
	wire		ct_data_ack;
	wire	[31:0]	ct_data;
	// Arbiter interaction
	wire		ct_qspi_req;
	wire		ct_grant;
	// Bus controller return
	wire		ct_ack;
	// SPI control wires
	wire		ct_spi_wr, ct_spi_hold, ct_spi_spd, ct_spi_dir;
	wire	[31:0]	ct_spi_word;
	wire	[1:0]	ct_spi_len;
	//
	ctrlspi		ctproc(i_clk_82mhz,
				bus_ctreq, bus_wr, bus_addr[3:0], bus_data, bus_sector,
				ct_qspi_req, ct_grant,
				ct_spi_wr, ct_spi_hold, ct_spi_word, ct_spi_len,
					ct_spi_spd, ct_spi_dir,
					spi_out, spi_valid, spi_busy, spi_stopped,
				ct_ack, ct_data_ack, ct_data, w_leave_xip, w_xip, w_quad);
	assign	ct_spi_hold = 1'b0;
	assign	ct_spi_spd  = 1'b0;

	//
	// ID/OTP module
	//
	//	Access to ID and One-Time-Programmable registers, but to read
	//	and to program (the OTP), and to finally lock (OTP) registers.
	//
	// Wishbone bus return
	wire		id_data_ack;
	wire	[31:0]	id_data;
	// Arbiter interaction
	wire		id_qspi_req;
	wire		id_qspi_grant;
	// Bus controller return
	wire		id_bus_ack;
	// SPI control wires
	wire		id_spi_wr, id_spi_hold, id_spi_spd, id_spi_dir;
	wire	[31:0]	id_spi_word;
	wire	[1:0]	id_spi_len;
	//
	wire		w_id_wip;
	//
	idotpqspi	idotp(i_clk_82mhz, bus_idreq,
				bus_wr, bus_addr[4:0], bus_data, id_bus_ack,
				id_qspi_req, id_qspi_grant,
				id_spi_wr, id_spi_hold, id_spi_word, id_spi_len,
					id_spi_spd, id_spi_dir,
					spi_out, spi_valid, spi_busy, spi_stopped,
				id_data_ack, id_data, w_idloaded, w_id_wip);

	// Arbitrator
	reg		owned;
	reg	[1:0]	owner;
	initial		owned = 1'b0;
	always @(posedge i_clk_82mhz) // 7 inputs (spi_stopped is the CE)
		if ((~owned)&&(spi_stopped))
		begin
			casez({rd_qspi_req,ew_qspi_req,id_qspi_req,ct_qspi_req})
			4'b1???: begin owned<= 1'b1; owner <= 2'b00; end
			4'b01??: begin owned<= 1'b1; owner <= 2'b01; end
			4'b001?: begin owned<= 1'b1; owner <= 2'b10; end
			4'b0001: begin owned<= 1'b1; owner <= 2'b11; end
			default: begin owned<= 1'b0; owner <= 2'b00; end
			endcase
		end else if ((owned)&&(spi_stopped))
		begin
			casez({rd_qspi_req,ew_qspi_req,id_qspi_req,ct_qspi_req,owner})
			6'b0???00: owned<= 1'b0;
			6'b?0??01: owned<= 1'b0;
			6'b??0?10: owned<= 1'b0;
			6'b???011: owned<= 1'b0;
			default: begin ; end
			endcase
		end

	assign	rd_qspi_grant = (owned)&&(owner == 2'b00);
	assign	ew_qspi_grant = (owned)&&(owner == 2'b01);
	assign	id_qspi_grant = (owned)&&(owner == 2'b10);
	assign	ct_grant      = (owned)&&(owner == 2'b11);

	// Module controller
	always @(posedge i_clk_82mhz)
	case(owner)
	2'b00: begin
		spi_wr      <= (owned)&&(rd_spi_wr);
		spi_hold    <= rd_spi_hold;
		spi_word    <= rd_spi_word;
		spi_len     <= rd_spi_len;
		spi_spd     <= rd_spi_spd;
		spi_dir     <= rd_spi_dir;
		spi_recycle <= rd_spi_recycle;
		end
	2'b01: begin
		spi_wr	    <= (owned)&&(ew_spi_wr);
		spi_hold    <= ew_spi_hold;
		spi_word    <= ew_spi_word;
		spi_len     <= ew_spi_len;
		spi_spd     <= ew_spi_spd;
		spi_dir     <= ew_spi_dir;
		spi_recycle <= 1'b1; // Long recycle time
		end
	2'b10: begin
		spi_wr	    <= (owned)&&(id_spi_wr);
		spi_hold    <= id_spi_hold;
		spi_word    <= id_spi_word;
		spi_len     <= id_spi_len;
		spi_spd     <= id_spi_spd;
		spi_dir     <= id_spi_dir;
		spi_recycle <= 1'b1; // Long recycle time
		end
	2'b11: begin
		spi_wr	    <= (owned)&&(ct_spi_wr);
		spi_hold    <= ct_spi_hold;
		spi_word    <= ct_spi_word;
		spi_len     <= ct_spi_len;
		spi_spd     <= ct_spi_spd;
		spi_dir     <= ct_spi_dir;
		spi_recycle <= 1'b1; // Long recycle time
		end
	endcase

	reg	last_wip;
	initial	bus_wip = 1'b0;
	initial	last_wip = 1'b0;
	initial o_interrupt = 1'b0;
	always @(posedge i_clk_82mhz)
	begin
		bus_wip <= w_ew_wip || w_id_wip;
		last_wip <= bus_wip;
		o_interrupt <= ((~bus_wip)&&(last_wip));
	end


	// Now, let's return values onto the wb bus
	always @(posedge i_clk_82mhz)
	begin
		// Ack our internal bus controller.  This means the command was
		// accepted, and the bus can go on to looking for the next 
		// command.  It controls the i_wb_stall line, just not the
		// i_wb_ack line.

		// Ack the wishbone with any response
		o_wb_ack <= (bus_wb_ack)|(rd_data_ack)|(ew_data_ack)|(id_data_ack)|(ct_data_ack);
		o_wb_data <= (bus_wb_ack)?bus_wb_data
			: (id_data_ack) ? id_data : spi_out;
	end

	assign	o_wb_stall = bus_wb_stall;
	assign	bus_ack = (rd_bus_ack|ew_bus_ack|id_bus_ack|ct_ack);
		
	assign	o_dbg = {
		i_wb_cyc, i_wb_ctrl_stb, i_wb_data_stb, o_wb_ack, bus_ack, //5
		//
		(spi_wr)&&(~spi_busy), spi_valid, spi_word[31:25],
		spi_out[7:2],
		//
		o_qspi_cs_n, o_qspi_sck, o_qspi_mod,	// 4 bits
		o_qspi_dat, i_qspi_dat			// 8 bits
		};

	// verilator lint_off UNUSED
	wire	[63:0]	unused;
	assign	unused = { rd_data, ct_data };
endmodule
