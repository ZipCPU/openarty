include <zipcpu.scad>
// include <artylogo.scad>

module arty() {
	// Top left is power, right side is the FMC connector
	raw_width  = 109.1;
	raw_length =  87.25;
	raw_height_above_board = 10.3;
	zh = 2;
	tol = 0.1;

	module cutout(x, y, w, h, v) {
		ex = 1.5;
		translate([x-ex/2,y-ex/2,-tol/2])
			cube([w+ex,h+ex,v+tol]);
	}

	module keepit(x, y, w, h, v) {
		ex = -1.5;
		translate([x-ex/2,y-ex/2,-tol/2])
			cube([w+ex,h+ex,v+tol]);
	}

	module layer(n) {
		base = (n==0) ? 0
			: (n == 1) ? 1.5
			: (n == 2) ? 3.35
			: (n == 3) ? 5.0
			: (n == 4) ? 6.8
			: (n == 5) ? 11.0
			: raw_height_above_board;

		ztmp = (n==0) ? 1.5
			: (n == 1) ? 3.35
			: (n == 2) ? 5.0
			: (n == 3) ? 6.8
			: (n == 4) ? 11.0
			: raw_height_above_board;

		zh = ztmp - base;

		above = raw_height_above_board;
		//

		// External power
		// Power plug
		cutout(0,26.75-8.96,15.25,8.96,above);
		// Power jumper
		// cutout(7.86-4.97,26.75+1.5,4.97,5,above);
		cutout(0,26.75+1.5-3,8,11,above);
		// Startup jumper
		cutout(raw_width-8.5,raw_length-14.13,5.2,2.6,above);
		// CK-Reset jumper
		cutout(raw_width-8.45,raw_length-33.24,5,2.6,above);
		// SPI jumper
		cutout(raw_width-8.5,raw_length-46.93,5,7.5,above);
		// Ethernet port
		cutout(0,53.34-16.95,26.19,16.95,above);
		//
		// Arduino header
		// Top lower
		cutout(103.1-42.65, 67.71-5, 42.65,4.51,above);
		// Top upper
		cutout(103.1-47.70, 67.71-2.41, 47.70,2.5,above);
		//
		// Bottom upper
		cutout(103.0-28.20, 21.96-4.36, 28.20, 4.36,above);
		// Bottom lower
		cutout(103.0-38.35, 21.96-5.1, 38.35,  2.36,above);
		//
		// 4 Switches
		cutout(67.2-29.75, 3, 5.7, 11.45,above);
		cutout(67.2-21.79, 3, 5.7, 11.45,above);
		cutout(67.2-13.55, 3, 5.7, 11.45,above);
		cutout(67.2- 5.63, 3, 5.7, 11.45,above);
		// 4x Buttons
		cutout(raw_width-36.36,5.45,4.55,4.55,above);
		cutout(raw_width-27.31,5.45,4.55,4.55,above);
		cutout(raw_width-18.45,5.45,4.55,4.55,above);
		cutout(raw_width-10.26,5.45,4.55,4.55,above);
		// Program Button
		cutout(3.7,raw_length-7.3,4.55,4.55,above);
		// Reset Button
		cutout(raw_width-8.55,raw_length-7.3,4.7,4.7,above);

		// 4 color LED's
		cutout( 8.0,2.76,2,1.6,above);
		cutout(15.1,2.76,2,1.6,above);
		cutout(22.0,2.76,2,1.6,above);
		cutout(29.0,2.76,2,1.6,above);
		// 4 regular LED's
		cutout( 8.0,9.95,2,1.6,above);
		cutout(15.1,9.95,2,1.6,above);
		cutout(22.0,9.95,2,1.6,above);
		cutout(29.0,9.95,2,1.6,above);

		translate([0,0,base]) {
			// pad platform
			if (n == 0) {
				//
				// Set up some pads to connect to the board
				// itself
				//
				difference() {
					color("black") {
						cube([raw_width,raw_length,zh]);
					}
					translate([0,0,-zh/2]) { union() {
					nh = zh*2;
					// Between PMOD's
					keepit(12.3,raw_length-13.5,95,14,nh);

					// Right edge
					keepit(raw_width-5.6,0,7,79.8,nh);

					// Bottom arduino header
					keepit(55, 12.2, raw_width-55, 18.8,above);
					// Top arduino header
					keepit(53.5, 53, raw_width-55, raw_length-52,above);
					// Below switches
					keepit(34.5, -1, raw_width-30, 3.75,above);
					// Left of LEDs
					keepit(-1, -1, 8.1, 13.6,above);
					// Above LED's, near power/enet
					keepit(3.40, 11.6, 19.2-3.4, 46-11.6,above);

					// Left edge
					// Left edge, above ethernet port
					keepit(11, 58-6.35, 17, 6.35,above);
					// Left edge, below USB port
					keepit(-2, 53, 3.8, 8.8,above);
					// Left edge, above USB port
					keepit(-2, 69, 7, 78-69,above);
				}}}
			}

			// 3.4
			if (n <= 1) {
				// Micro USB port
				cutout(0,raw_length-26.0, 5.5, 8,zh);
				//
				// 3R3 on top + Cap on the side
				cutout(40,60,12,11,zh);
				//
				// Lower under "A" blob
				cutout(41,20.36-4.5,5,4.5,zh);
				//
				// Chip on top, between pmods
				cutout(24,58, 37-24,74-58,zh);
			}

			// 5.0mm
			if (n <= 2) {
				// 5.0mm
				//
				// PMod row across the top
				cutout(12.3,raw_length-14,15.6,14,zh);
				cutout(35.2,raw_length-14,15.6,14,zh);
				cutout(58.0,raw_length-14,15.6,14,zh);
				cutout(80.5,raw_length-14,15.6,14,zh);
				//
				// under A blob
				cutout(41,23.5,9.0,8.0,zh);
				//
				// Cap left
				cutout(52.9-3.35,25.5-3.5,2.65,3.5,zh);
				// Cap right
				cutout(raw_width-8,37.96-2.65,3.35,2.65,zh);
			}

			/*
			// 6.8mm
			if (n <= 3) {
				// Big USB port
				cutout(raw_width-38.15,raw_length-14.3,13.2,14.3,zh);
			}

			// 11mm 
			if (n <= 4) {
				// Top of VGA
				// cutout(76.37-30.73,raw_length-4.55,30.73,4.55,zh);
				cutout(76.37-30.73,raw_length-7.8,30.73,7.8,zh);
				cutout(68.6-16.15,raw_length-16.0,16.15,16.0,zh);
			}
			*/
		}
	}

	module	embossZip() {
		s = 1.1;
		depth = 1.5;
		translate([raw_width/2+9, raw_length/2+8, raw_height_above_board+zlogoh/2-depth]) {
			rotate([0,0,0]) scale([s,s,1]) {
				translate([-zlogow/2,(zlogob-zlogol)/2,
							-zlogoh/2])
						zipcpulogo();
			}
		}
	}

	module	embossArty() {
/*
		s = 1.2;
		depth = 1.5;
		translate([raw_width/2, raw_length/2-15,
			   raw_height_above_board+artylogo_h/2-depth]) {
			rotate([0,0,0]) scale([s,s,1]) {
				translate([-artylogo_w/2,
						(-artylogo_l)/2,
							-artylogo_h/2])
						artylogo();
			}
		}
*/
	}

	difference() {
		cube([raw_width,raw_length,raw_height_above_board]);
		layer(0);
		layer(1);
		layer(2);
		layer(3);
		layer(4);
		layer(5);
		embossZip();
		// embossBasys3();
	}

}

translate([122,2,12]) {
	rotate([0,180,0])
		arty();
}

/*
translate([122,2,12]) { // ... 0-30
	rotate([0,180,0]) {
		difference() {
			arty();
			translate([30,-2,-2])
			 	cube([120,92,15]);
	// raw_width  = 109.1;
	raw_length =  87.25;
	// raw_height_above_board = 10.3;
		}
	}
}

translate([120,2,12]) { // ... 30-58
	rotate([0,180,0]) {
		difference() {
			arty();
			translate([-2,-2,-2])
			 	cube([32,92,15]);
			translate([58,-2,-2])
			 	cube([120,92,15]);
	// raw_width  = 109.1;
	raw_length =  87.25;
	// raw_height_above_board = 10.3;
		}
	}
}

translate([116,2,12]) { ///... 58-86
	rotate([0,180,0]) {
		difference() {
			arty();
			translate([-2,-2,-2])
			 	cube([58,92,15]);
			translate([86,-2,-2])
			 	cube([120,92,15]);
	// raw_width  = 109.1;
	raw_length =  87.25;
	// raw_height_above_board = 10.3;
		}
	}
}

translate([114,2,12]) { ///... 86 - end
	rotate([0,180,0]) {
		difference() {
			arty();
			translate([-2,-2,-2])
			 	cube([88,92,15]);
	// raw_width  = 109.1;
	raw_length =  87.25;
	// raw_height_above_board = 10.3;
		}
	}
}
*/
