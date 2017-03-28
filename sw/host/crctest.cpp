//
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <strings.h>
#include <ctype.h>
#include <string.h>
#include <signal.h>
#include <assert.h>

unsigned	calccrc(const int bytelen, const unsigned *buf) {
	const unsigned int	taps = 0xedb88320u;
#ifdef	DONT_INVERT
	unsigned int	crc = 0;
#else
	unsigned int	crc = 0xffffffff; // initial value
#endif
	int	bidx;
	int	bp = 0;

	for(bidx = 0; bidx<bytelen; bidx++) {
		unsigned char	byte = buf[(bidx>>2)]>>(24-((bidx&3)<<3));

		// printf("CRC[%2d]: %02x ([%2d]0x%08x)\n", bidx, byte, (bidx>>2), buf[(bidx>>2)]);

		for(int bit=8; --bit>= 0; byte >>= 1) {
			if ((crc ^ byte) & 1) {
				crc >>= 1;
				crc ^= taps;
			} else
				crc >>= 1;
		} bp++;
	}
#ifndef	DONT_INVERT
	crc ^= 0xffffffff;
#endif
	// Now, we need to reverse these bytes
	// ABCD
	unsigned a,b,c,d;
	a = (crc>>24); // &0x0ff;
	b = (crc>>16)&0x0ff;
	c = (crc>> 8)&0x0ff;
	d = crc; // (crc    )&0x0ff;
	crc = (d<<24)|(c<<16)|(b<<8)|a;

	// printf("%d bytes processed\n", bp);
	return crc;
}

int main(int argc, char **argv) {
	unsigned packet[32];

	for(int i=0; i<32; i++)
		packet[i] = 0;
	packet[ 0] = 0x000ae6f0;
	packet[ 1] = 0x05a30012;
	packet[ 2] = 0x34567890;
	packet[ 3] = 0x08004500;
	packet[ 4] = 0x0030b3fe;
	packet[ 5] = 0x00008011;
	packet[ 6] = 0x72ba0a00;
	packet[ 7] = 0x00030a00;
	packet[ 8] = 0x00020400;
	packet[ 9] = 0x0400001c;
	packet[10] = 0x894d0001;
	packet[11] = 0x02030405;
	packet[12] = 0x06070809;
	packet[13] = 0x0a0b0c0d;
	packet[14] = 0x0e0f1011;
	packet[15] = 0x12130000;

	packet[16] = calccrc(15*4+2, packet);

	for(int i=0; i<16; i++)
		printf("PKT[%3d] = 0x%08x\n", i, packet[i]);
	printf("PKT[CRC] = 0x%08x\n", packet[16]);
}

