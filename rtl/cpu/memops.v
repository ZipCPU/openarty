////////////////////////////////////////////////////////////////////////////////
//
// Filename:	memops.v
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	A memory unit to support a CPU.
//
//	In the interests of code simplicity, this memory operator is
//	susceptible to unknown results should a new command be sent to it
//	before it completes the last one.  Unpredictable results might then
//	occurr.
//
//	BIG ENDIAN
//		Note that this core assumes a big endian bus, with the MSB
//		of the bus word being the least bus address
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
module	memops #(
		// {{{
		parameter	ADDRESS_WIDTH=28,
		parameter	DATA_WIDTH=32,	// CPU's register width
		parameter	BUS_WIDTH=32,
		parameter [0:0]	OPT_LOCK=1'b1,
				WITH_LOCAL_BUS=1'b1,
				OPT_ALIGNMENT_ERR=1'b1,
				OPT_LOWPOWER=1'b0,
				OPT_LITTLE_ENDIAN = 1'b0,
		localparam	AW=ADDRESS_WIDTH
`ifdef	FORMAL
		, parameter	F_LGDEPTH = 2
`endif
		// }}}
	) (
		// {{{
		input	wire			i_clk, i_reset,
		// CPU interface
		// {{{
		input	wire			i_stb, i_lock,
		input	wire	[2:0]		i_op,
		input	wire	[31:0]		i_addr,
		input	wire [DATA_WIDTH-1:0]	i_data,
		input	wire	[4:0]		i_oreg,
		// CPU outputs
		output	wire			o_busy,
		output	reg			o_rdbusy,
		output	reg			o_valid,
		output	reg			o_err,
		output	reg	[4:0]		o_wreg,
		output	reg [DATA_WIDTH-1:0]	o_result,
		// }}}
		// Wishbone
		// {{{
		output	wire			o_wb_cyc_gbl,
		output	wire			o_wb_cyc_lcl,
		output	reg			o_wb_stb_gbl,
		output	reg			o_wb_stb_lcl,
		output	reg			o_wb_we,
		output	reg	[AW-1:0]	o_wb_addr,
		output	reg	[BUS_WIDTH-1:0]	o_wb_data,
		output	reg [BUS_WIDTH/8-1:0]	o_wb_sel,
		// Wishbone inputs
		input	wire			i_wb_stall, i_wb_ack, i_wb_err,
		input	wire	[BUS_WIDTH-1:0]	i_wb_data
		// }}}
		// }}}
	);

	// Declarations
	// {{{
	localparam	WBLSB = $clog2(BUS_WIDTH/8);
`ifdef	FORMAL
	wire	[(F_LGDEPTH-1):0]	f_nreqs, f_nacks, f_outstanding;
`endif

	wire		misaligned;
	reg		r_wb_cyc_gbl, r_wb_cyc_lcl;
	reg	[2+WBLSB-1:0]	r_op;
	wire		lock_gbl, lock_lcl;
	wire		lcl_bus, gbl_stb, lcl_stb;

	reg	[BUS_WIDTH/8-1:0]	oword_sel;
	wire	[BUS_WIDTH/8-1:0]	pre_sel;
	wire	[BUS_WIDTH-1:0]		pre_result;

	wire	[1:0]		oshift2;
	wire	[WBLSB-1:0]	oshift;

	// }}}

	// misaligned
	// {{{
	generate if (OPT_ALIGNMENT_ERR)
	begin : GENERATE_ALIGNMENT_ERR
		reg	r_misaligned;

		always @(*)
		casez({ i_op[2:1], i_addr[1:0] })
		4'b01?1: r_misaligned = i_stb; // Words must be halfword aligned
		4'b0110: r_misaligned = i_stb; // Words must be word aligned
		4'b10?1: r_misaligned = i_stb; // Halfwords must be aligned
		// 4'b11??: r_misaligned <= 1'b0; Byte access are never misaligned
		default: r_misaligned = 1'b0;
		endcase

		assign	misaligned = r_misaligned;
	end else begin : NO_MISALIGNMENT_ERR
		assign	misaligned = 1'b0;
	end endgenerate
	// }}}

	// lcl_stb, gbl_stb
	// {{{
	assign	lcl_bus = (WITH_LOCAL_BUS)&&(i_addr[31:24]==8'hff);
	assign	lcl_stb = (i_stb)&&( lcl_bus)&&(!misaligned);
	assign	gbl_stb = (i_stb)&&(!lcl_bus)&&(!misaligned);
	// }}}

	// r_wb_cyc_gbl, r_wb_cyc_lcl
	// {{{
	initial	r_wb_cyc_gbl = 1'b0;
	initial	r_wb_cyc_lcl = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		r_wb_cyc_gbl <= 1'b0;
		r_wb_cyc_lcl <= 1'b0;
	end else if ((r_wb_cyc_gbl)||(r_wb_cyc_lcl))
	begin
		if ((i_wb_ack)||(i_wb_err))
		begin
			r_wb_cyc_gbl <= 1'b0;
			r_wb_cyc_lcl <= 1'b0;
		end
	end else begin // New memory operation
		// Grab the wishbone
		r_wb_cyc_lcl <= (lcl_stb);
		r_wb_cyc_gbl <= (gbl_stb);
	end
	// }}}

	// o_wb_stb_gbl
	// {{{
	initial	o_wb_stb_gbl = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_wb_stb_gbl <= 1'b0;
	else if ((i_wb_err)&&(r_wb_cyc_gbl))
		o_wb_stb_gbl <= 1'b0;
	else if (gbl_stb)
		o_wb_stb_gbl <= 1'b1;
	else if (o_wb_cyc_gbl)
		o_wb_stb_gbl <= (o_wb_stb_gbl)&&(i_wb_stall);
	//  }}}

	// o_wb_stb_lcl
	// {{{
	initial	o_wb_stb_lcl = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_wb_stb_lcl <= 1'b0;
	else if ((i_wb_err)&&(r_wb_cyc_lcl))
		o_wb_stb_lcl <= 1'b0;
	else if (lcl_stb)
		o_wb_stb_lcl <= 1'b1;
	else if (o_wb_cyc_lcl)
		o_wb_stb_lcl <= (o_wb_stb_lcl)&&(i_wb_stall);
	// }}}

	// o_wb_we, o_wb_data, o_wb_sel
	// {{{
	always @(*)
	begin
		oword_sel = 0;

		casez({ OPT_LITTLE_ENDIAN, i_op[2:1], i_addr[1:0] })
		5'b00???: oword_sel[3:0] = 4'b1111;
		5'b0100?: oword_sel[3:0] = 4'b1100;
		5'b0101?: oword_sel[3:0] = 4'b0011;
		5'b01100: oword_sel[3:0] = 4'b1000;
		5'b01101: oword_sel[3:0] = 4'b0100;
		5'b01110: oword_sel[3:0] = 4'b0010;
		5'b01111: oword_sel[3:0] = 4'b0001;
		//
		// verilator coverage_off
		5'b10???: oword_sel[3:0] = 4'b1111;
		5'b1100?: oword_sel[3:0] = 4'b0011;
		5'b1101?: oword_sel[3:0] = 4'b1100;
		5'b11100: oword_sel[3:0] = 4'b0001;
		5'b11101: oword_sel[3:0] = 4'b0010;
		5'b11110: oword_sel[3:0] = 4'b0100;
		5'b11111: oword_sel[3:0] = 4'b1000;
		// verilator coverage_on
		//
		default: oword_sel[3:0] = 4'b1111;
		endcase
	end

	// pre_sel
	// {{{
	generate if (BUS_WIDTH == 32)
	begin : COPY_PRESEL
		assign	pre_sel = oword_sel;
	end else if (OPT_LITTLE_ENDIAN)
	begin : GEN_LILPRESEL
		wire	[WBLSB-3:0]	shift;

		assign	shift = i_addr[WBLSB-1:2];
		assign	pre_sel = oword_sel << (4 * i_addr[WBLSB-1:2]);
	end else begin : GEN_PRESEL
		wire	[WBLSB-3:0]	shift;

		assign	shift = {(WBLSB-2){1'b1}} ^ i_addr[WBLSB-1:2];
		assign	pre_sel = oword_sel << (4 * shift);
	end endgenerate
	// }}}

	assign	oshift  = i_addr[WBLSB-1:0];
	assign	oshift2 = i_addr[1:0];

	initial	o_wb_we   = 1'b0;
	initial	o_wb_data = 0;
	initial	o_wb_sel  = 0;
	always @(posedge i_clk)
	if (i_stb)
	begin
		o_wb_we   <= i_op[0];
		if (OPT_LOWPOWER)
		begin
			if (lcl_bus)
			begin
				// {{{
				o_wb_data <= 0;
				casez({ OPT_LITTLE_ENDIAN, i_op[2:1] })
				3'b010: o_wb_data[31:0] <= { i_data[15:0], {(16){1'b0}} } >> (8*oshift2);
				3'b011: o_wb_data[31:0] <= { i_data[ 7:0], {(24){1'b0}} } >> (8*oshift2);
				3'b00?: o_wb_data[31:0] <= i_data[31:0];
				//
				// verilator coverage_off
				3'b110: o_wb_data <= { {(BUS_WIDTH-16){1'b0}}, i_data[15:0] } << (8*oshift2);
				3'b111: o_wb_data <= { {(BUS_WIDTH-8){1'b0}},  i_data[ 7:0] } << (8*oshift2);
				3'b10?: o_wb_data <= { {(BUS_WIDTH-32){1'b0}}, i_data[31:0] } << (8*oshift2);
				// verilator coverage_on
				//
				endcase
				// }}}
			end else begin
				// {{{
				casez({ OPT_LITTLE_ENDIAN, i_op[2:1] })
				3'b010: o_wb_data <= { i_data[15:0], {(BUS_WIDTH-16){1'b0}} } >> (8*oshift);
				3'b011: o_wb_data <= { i_data[ 7:0], {(BUS_WIDTH- 8){1'b0}} } >> (8*oshift);
				3'b00?: o_wb_data <= { i_data[31:0], {(BUS_WIDTH-32){1'b0}} } >> (8*oshift);
				//
				3'b110: o_wb_data <= { {(BUS_WIDTH-16){1'b0}}, i_data[15:0] } << (8*oshift);
				3'b111: o_wb_data <= { {(BUS_WIDTH-8){1'b0}},  i_data[ 7:0] } << (8*oshift);
				3'b10?: o_wb_data <= { {(BUS_WIDTH-32){1'b0}}, i_data[31:0] } << (8*oshift);
				//
				endcase
				// }}}
			end
		end else
			casez({ i_op[2:1] })
			2'b10: o_wb_data <= { (BUS_WIDTH/16){ i_data[15:0] } };
			2'b11: o_wb_data <= { (BUS_WIDTH/ 8){ i_data[7:0] } };
			default: o_wb_data <= {(BUS_WIDTH/32){i_data}};
			endcase

		if (lcl_bus)
		begin
			o_wb_addr <= i_addr[2 +: (AW+2>32 ? (32-2) : AW)];
			o_wb_sel <= oword_sel;
		end else begin
			o_wb_addr <= i_addr[WBLSB +: (AW+WBLSB>32 ? (32-WBLSB) : AW)];
			o_wb_sel <= pre_sel;
		end

		r_op <= { i_op[2:1] , i_addr[WBLSB-1:0] };
	end else if ((OPT_LOWPOWER)&&(!o_wb_cyc_gbl)&&(!o_wb_cyc_lcl))
	begin
		o_wb_we   <= 1'b0;
		o_wb_addr <= 0;
		o_wb_data <= {(BUS_WIDTH){1'b0}};
		o_wb_sel  <= {(BUS_WIDTH/8){1'b0}};
	end
	// }}}

	// o_valid
	// {{{
	initial	o_valid = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_valid <= 1'b0;
	else
		o_valid <= (((o_wb_cyc_gbl)||(o_wb_cyc_lcl))
				&&(i_wb_ack)&&(!o_wb_we));
	// }}}

	// o_err
	// {{{
	initial	o_err = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_err <= 1'b0;
	else if ((r_wb_cyc_gbl)||(r_wb_cyc_lcl))
		o_err <= i_wb_err;
	else if ((i_stb)&&(!o_busy))
		o_err <= misaligned;
	else
		o_err <= 1'b0;
	// }}}

	assign	o_busy = (r_wb_cyc_gbl)||(r_wb_cyc_lcl);

	// o_rdbusy
	// {{{
	initial	o_rdbusy = 1'b0;
	always @(posedge i_clk)
	if (i_reset|| ((o_wb_cyc_gbl || o_wb_cyc_lcl)&&(i_wb_err || i_wb_ack)))
		o_rdbusy <= 1'b0;
	else if (i_stb && !i_op[0] && !misaligned)
		o_rdbusy <= 1'b1;
	else if (o_valid)
		o_rdbusy <= 1'b0;
	// }}}

	always @(posedge i_clk)
	if (i_stb)
		o_wreg    <= i_oreg;

	// o_result
	// {{{
	generate if (OPT_LITTLE_ENDIAN)
	begin : LILEND_RESULT

		assign	pre_result = i_wb_data >> (8*r_op[$clog2(BUS_WIDTH/8)-1:0]);

	end else begin : BIGEND_RESULT

		assign	pre_result = i_wb_data << (8*r_op[$clog2(BUS_WIDTH/8)-1:0]);

	end endgenerate

	always @(posedge i_clk)
	if ((OPT_LOWPOWER)&&(!i_wb_ack))
		o_result <= 32'h0;
	else if (o_wb_cyc_lcl && (BUS_WIDTH != 32))
	begin
		// The Local bus is naturally (and only) a 32-bit bus
		casez({ OPT_LITTLE_ENDIAN, r_op[WBLSB +: 2], r_op[1:0] })
		5'b?01??: o_result <= i_wb_data[31:0];
		//
		// Big endian
		5'b0100?: o_result <= { 16'h00, i_wb_data[31:16] };
		5'b0101?: o_result <= { 16'h00, i_wb_data[15: 0] };
		5'b01100: o_result <= { 24'h00, i_wb_data[31:24] };
		5'b01101: o_result <= { 24'h00, i_wb_data[23:16] };
		5'b01110: o_result <= { 24'h00, i_wb_data[15: 8] };
		5'b01111: o_result <= { 24'h00, i_wb_data[ 7: 0] };
		//
		// Little endian : Same bus result, just grab a different bits
		//   from the bus return to send back to the CPU.
		// verilator coverage_off
		5'b1100?: o_result <= { 16'h00, i_wb_data[15: 0] };
		5'b1101?: o_result <= { 16'h00, i_wb_data[31:16] };
		5'b11100: o_result <= { 24'h00, i_wb_data[ 7: 0] };
		5'b11101: o_result <= { 24'h00, i_wb_data[15: 8] };
		5'b11110: o_result <= { 24'h00, i_wb_data[23:16] };
		5'b11111: o_result <= { 24'h00, i_wb_data[31:24] };
		// verilator coverage_on
		default: o_result <= i_wb_data[31:0];
		endcase
	end else begin
		casez({ OPT_LITTLE_ENDIAN, r_op[$clog2(BUS_WIDTH/8) +: 2] })
		// Word
		//
		// Big endian
		3'b00?: o_result <= pre_result[BUS_WIDTH-1:BUS_WIDTH-32];
		3'b010: o_result <= { 16'h00, pre_result[BUS_WIDTH-1:BUS_WIDTH-16] };
		3'b011: o_result <= { 24'h00, pre_result[BUS_WIDTH-1:BUS_WIDTH-8] };
		//
		// Little endian : Same bus result, just grab a different bits
		//   from the bus return to send back to the CPU.
		// verilator coverage_off
		3'b10?: o_result <= pre_result[31: 0];
		3'b110: o_result <= { 16'h00, pre_result[15: 0] };
		3'b111: o_result <= { 24'h00, pre_result[ 7: 0] };
		// verilator coverage_on
		//
		// Just to have an (unused) default
		// default: o_result <= pre_result[31:0]; (Messes w/ coverage)
		endcase
	end
	// }}}

	// lock_gbl and lock_lcl
	// {{{
	generate
	if (OPT_LOCK)
	begin : GEN_LOCK
		// {{{
		reg	r_lock_gbl, r_lock_lcl;

		initial	r_lock_gbl = 1'b0;
		initial	r_lock_lcl = 1'b0;

		always @(posedge i_clk)
		if (i_reset)
		begin
			r_lock_gbl <= 1'b0;
			r_lock_lcl <= 1'b0;
		end else if (((i_wb_err)&&((r_wb_cyc_gbl)||(r_wb_cyc_lcl)))
				||(misaligned))
		begin
			// Kill the lock if
			//	there's a bus error, or
			//	User requests a misaligned memory op
			r_lock_gbl <= 1'b0;
			r_lock_lcl <= 1'b0;
		end else begin
			// Kill the lock if
			//	i_lock goes down
			//	User starts on the global bus, then switches
			//	  to local or vice versa
			r_lock_gbl <= (i_lock)&&((r_wb_cyc_gbl)||(lock_gbl))
					&&(!lcl_stb);
			r_lock_lcl <= (i_lock)&&((r_wb_cyc_lcl)||(lock_lcl))
					&&(!gbl_stb);
		end

		assign	lock_gbl = r_lock_gbl;
		assign	lock_lcl = r_lock_lcl;

		assign	o_wb_cyc_gbl = (r_wb_cyc_gbl)||(lock_gbl);
		assign	o_wb_cyc_lcl = (r_wb_cyc_lcl)||(lock_lcl);
		// }}}
	end else begin : NO_LOCK
		// {{{
		assign	o_wb_cyc_gbl = (r_wb_cyc_gbl);
		assign	o_wb_cyc_lcl = (r_wb_cyc_lcl);

		assign	{ lock_gbl, lock_lcl } = 2'b00;

		// Make verilator happy
		// verilator lint_off UNUSED
		wire	[2:0]	lock_unused;
		assign	lock_unused = { i_lock, lock_gbl, lock_lcl };
		// verilator lint_on  UNUSED
		// }}}
	end endgenerate
	// }}}

`ifdef	VERILATOR
	always @(posedge i_clk)
	if ((r_wb_cyc_gbl)||(r_wb_cyc_lcl))
		assert(!i_stb);
`endif


	// Make verilator happy
	// {{{
	// verilator coverage_off
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, pre_result };
	generate if (AW < 22)
	begin : TOO_MANY_ADDRESS_BITS

		wire	[(21-AW):0] unused_addr;
		assign	unused_addr = i_addr[23:(AW+2)];

	end endgenerate
	// verilator lint_on  UNUSED
	// verilator coverage_on
	// }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal properties
// {{{
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef	FORMAL
// Formal properties for this module are maintained elsewhere
`endif
endmodule
