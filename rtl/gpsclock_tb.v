////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	gpsclock_tb.v
// {{{
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	Provide a test bench, internal to an FPGA, whereby the GPS
//		clock module can be tested.
//
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
module	gpsclock_tb #(
		parameter	DW=32, RW=64,
		parameter	CLOCK_FREQUENCY_HZ = 81_250_000
	) (
		// {{{
		input	wire			i_clk, i_lcl_pps,
		output	reg			o_pps,	// To our lcl circuitry
		// Wishbone Configuration interface
		input	wire			i_wb_cyc, i_wb_stb, i_wb_we,
			input	wire	[2:0]		i_wb_addr,
		input	wire	[(DW-1):0]	i_wb_data,
		input	wire	[(DW/8-1):0]	i_wb_sel,
		output	wire			o_wb_stall,
		output	reg			o_wb_ack,
		output	reg	[(DW-1):0]	o_wb_data,
		// Status and timing outputs
		input	wire [(RW-1):0]	i_err, // Fraction of a second err
					i_count, // Fraction of a second
					i_step // 2^RW / clock speed (in Hz)
		// }}}
	);

	// Local declarations
	// {{{
	reg	[31:0]	r_jump, r_maxcount;
	reg		r_halt;
	reg	[31:0]	r_err, r_lcl;
	reg	[63:0]	r_count, r_step;
	reg	[31:0]	r_ctr;
	reg	[31:0]	lcl_counter;
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Wishbone access ...
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	initial	r_jump = 0; 
	initial	r_maxcount = CLOCK_FREQUENCY_HZ;
	always @(posedge i_clk)
		if ((i_wb_stb)&&(i_wb_we))
		begin
			case(i_wb_addr)
			3'b000: r_maxcount <= i_wb_data;
			3'b001: r_jump     <= i_wb_data;
			// 2'b11: r_def_step <= i_wb_data;
			default: begin end
			// r_defstep <= i_wb_data;
			endcase
		end else
			r_jump <= 32'h00;

	initial	r_lcl = 32'h000;
	initial	r_halt = 1'b0;
	always @(posedge i_clk)
	case (i_wb_addr)
		3'b000: o_wb_data <= r_maxcount;
		3'b001: begin o_wb_data <= r_lcl; r_halt <= 1'b1; end // { 31'h00, r_halt };
		3'b010: begin o_wb_data <= i_err[63:32]; r_halt <= 1'b1; end
		3'b011: o_wb_data <= r_err[31:0];
		3'b100: o_wb_data <= r_count[63:32];
		3'b101: o_wb_data <= r_count[31:0];
		3'b110: o_wb_data <= r_step[63:32];
		3'b111: begin o_wb_data <= r_step[31:0]; r_halt <= 1'b0; end
		// default: o_wb_data <= 0;
	endcase

	initial	o_wb_ack = 1'b0;
	always @(posedge i_clk)
		o_wb_ack <= i_wb_stb;

	assign	o_wb_stall = 1'b0;
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Generate a PPS signal
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	always @(posedge i_clk)
	if (r_ctr >= r_maxcount-1)
		r_ctr <= r_ctr+1-r_maxcount+r_jump;
	else
		r_ctr <= r_ctr+1+r_jump;
	always @(posedge i_clk)
	if (r_ctr >= r_maxcount-1)
		o_pps <= 1'b1;
	else
		o_pps <= 1'b0;

	always @(posedge i_clk)
	lcl_counter <= lcl_counter + 32'h001;

	always @(posedge i_clk)
	if ((!r_halt)&&(i_lcl_pps))
	begin
		r_err   <= i_err[31:0];
		r_count <= i_count;
		r_step  <= i_step;
		r_lcl   <= lcl_counter;
	end
	// }}}

	// Make Verilator happy
	// {{{
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, i_wb_cyc, i_wb_sel };
	// verilator lint_on UNUSED
	// }}}
endmodule

