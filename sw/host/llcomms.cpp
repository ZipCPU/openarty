//
//
// Filename: 	llcomms.cpp
//
// Project:	UART to WISHBONE FPGA library
//
// Purpose:	This is the C++ program on the command side that will interact
//		with a UART on an FPGA, both sending and receiving characters.
//		Any bus interaction will call routines from this lower level
//		library to accomplish the actual connection to and
//		transmission to/from the board.
//
// Creator:	Dan Gisselquist
//		Gisselquist Tecnology, LLC
//
// Copyright:	2015
//
//
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <netinet/in.h>
#include <netdb.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <arpa/inet.h> 
#include <assert.h> 
#include <strings.h> 
#include <poll.h> 
#include <ctype.h> 

#include "llcomms.h"

LLCOMMSI::LLCOMMSI(void) {
	m_fdw = -1;
	m_fdr = -1;
	m_total_nread = 0l;
	m_total_nwrit = 0l;
}

void	LLCOMMSI::write(char *buf, int len) {
	int	nw;
	nw = ::write(m_fdw, buf, len);
	m_total_nwrit += nw;
	assert(nw == len);
}

int	LLCOMMSI::read(char *buf, int len) {
	int	nr;
	nr = ::read(m_fdr, buf, len);
	m_total_nread += nr;
	return nr;
}

void	LLCOMMSI::close(void) {
	if(m_fdw>=0)
		::close(m_fdw);
	if((m_fdr>=0)&&(m_fdr != m_fdw))
		::close(m_fdr);
	m_fdw = m_fdr = -1;
}

bool	LLCOMMSI::poll(unsigned ms) {
	struct	pollfd	fds;

	fds.fd = m_fdr;
	fds.events = POLLIN;
	::poll(&fds, 1, ms);

	if (fds.revents & POLLIN) {
		return true;
	} else return false;
}

int	LLCOMMSI::available(void) {
	return poll(0)?1:0;
}

TTYCOMMS::TTYCOMMS(const char *dev) {
	m_fdr = ::open(dev, O_RDWR | O_NONBLOCK);
	if (m_fdr < 0) {
		printf("\n Error : Could not open %s\n", dev);
		perror("O/S Err:");
		exit(-1);
	}

	if (isatty(m_fdr)) {
		struct termios tb;
		tcgetattr(m_fdr, &tb);
		cfmakeraw(&tb);
		// tb.c_iflag &= (~(IXON|IXOFF));
		tb.c_cflag &= (~(CRTSCTS));
		tcsetattr(m_fdr, TCSANOW, &tb);
		tcflow(m_fdr, TCOON);
	}

	m_fdw = m_fdr;
}

NETCOMMS::NETCOMMS(const char *host, const int port) {
	struct sockaddr_in serv_addr; 
	struct	hostent	*hp;

	if ((m_fdr = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
		printf("\n Error : Could not create socket \n");
		exit(-1);
	} 

	memset(&serv_addr, '0', sizeof(serv_addr)); 

	hp = gethostbyname(host);
	if (hp == NULL) {
		printf("Could not get host entity for %s\n", host);
		perror("O/S Err:");
		exit(-1);
	}
	bcopy(hp->h_addr, &serv_addr.sin_addr.s_addr, hp->h_length);

	serv_addr.sin_family = AF_INET;
	serv_addr.sin_port = htons(port); 

	if (connect(m_fdr,(struct sockaddr *)&serv_addr, sizeof(serv_addr))< 0){
		perror("Connect Failed Err");
		exit(-1);
	} 

	m_fdw = m_fdr;
}

