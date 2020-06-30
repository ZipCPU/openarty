zlogow = 62;
zlogol = 14;
zlogob =  6;
zlogoh = 5;
module	zipcpulogo() {
	linear_extrude(height=zlogoh) {
		union() {
			// Z
			polygon(points=[
				[0,0],
				[8,0],
				[10,2],
				[4,2],
				[16,14],
				[6,14],
				[4,12],
				[12,12] ]);
			// Dot on the 'i'
			polygon(points=[
				[10,4],
				[12,4],
				[14,6],
				[12,6] ]);
			// The 'p'
			polygon(points=[
				[4,-6],
				[6,-6],
				[12,0],
				[18,0],
				[22,4],
				[22,6],
				[16,6],
				[14,4],
				[20,4],
				[18,2],
				[12,2] ]);
			// The C
			polygon(points=[
				[28,0],
				[28,2],
				[34,8],
				[42,8],
				[40,6],
				[34,6],
				[30,2],
				[36,2],
				[34,0] ]);
			// The P
			polygon(points=[
				[36,0],
				[38,0],
				[40,2],
				[46,2],
				[50,6],
				[50,8],
				[44,8],
				[42,6],
				[48,6],
				[46,4],
				[40,4]]);
			// The U
			polygon(points=[
				[48,0],
				[54,0],
				[62,8],
				[60,8],
				[54,2],
				[50,2],
				[56,8],
				[54,8],
				[48,2]]);
		}
	}
}

// zipcpulogo();
// translate([0,-zlogob,-zlogoh]) color("red") cube([zlogow, zlogol+zlogob, zlogoh]);

