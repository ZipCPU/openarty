////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	ledbouncer.v
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	
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
module	ledbouncer(i_clk, o_leds);
	parameter	NLEDS=8, CTRBITS=25;
	input	wire		i_clk;
	output	reg	[(NLEDS-1):0]	o_leds;

	reg	[(NLEDS-1):0]	led_owner;
	reg		led_dir;

	reg	[(CTRBITS-1):0]	led_ctr;
	reg			led_clk;
	always @(posedge i_clk)
		{ led_clk, led_ctr } <= led_ctr + {{(CTRBITS-2){1'b0}},2'b11};

	initial	led_owner = { {(NLEDS-1){1'b0}}, 1'b1};
	always @(posedge i_clk)
		if (led_owner == 0)
		begin
			led_owner <= { {(NLEDS-1){1'b0}}, 1'b1 };
			led_dir   <= 1'b1; // Left, or shift up
		end else if ((led_clk)&&(led_dir)) // Go left
		begin
			if (led_owner == { 1'b1, {(NLEDS-1){1'b0}} })
				led_dir <= !led_dir;
			else
				led_owner <= { led_owner[(NLEDS-2):0], 1'b0 };
		end else if (led_clk) begin
			if (led_owner == { {(NLEDS-1){1'b0}}, 1'b1 })
				led_dir <= !led_dir;
			else
				led_owner <= { 1'b0, led_owner[(NLEDS-1):1] };
		end

	reg	[4:0]	led_pwm [0:(NLEDS-1)];
	genvar	k;
	generate for(k=0; k<(NLEDS); k=k+1)
		always@(posedge i_clk)
			if (led_clk)
			begin
				if (led_owner[k])
					led_pwm[k] <= 5'h1f;
				else if (led_pwm[k] > 5'h1c)
					led_pwm[k] <= 5'h1c;
				else if (led_pwm[k] > 5'h17)
					led_pwm[k] <= 5'h17;
				else if (led_pwm[k] > 5'h0f)
					led_pwm[k] <= 5'h0f;
				else if (led_pwm[k] > 5'h0b)
					led_pwm[k] <= 5'h0b;
				else if (led_pwm[k] > 5'h07)
					led_pwm[k] <= 5'h07;
				else if (led_pwm[k] > 5'h05)
					led_pwm[k] <= 5'h05;
				else if (led_pwm[k] > 5'h03)
					led_pwm[k] <= 5'h03;
				else if (led_pwm[k] > 5'h01)
					led_pwm[k] <= 5'h01;
				else
					led_pwm[k] <= 5'h00;
			end
	endgenerate

	wire	[4:0]	br_ctr;
	assign	br_ctr = { led_ctr[0], led_ctr[1], led_ctr[2], led_ctr[3], 
			led_ctr[4] };

	generate for(k=0; k<(NLEDS); k=k+1)
		always @(posedge i_clk)
			o_leds[k] <= (led_pwm[k] == 5'h1f)? 1'b1
				:((led_pwm[k] == 5'h00) ? 1'b0
				: (br_ctr[4:0] <= led_pwm[k][4:0]));
	endgenerate

endmodule

