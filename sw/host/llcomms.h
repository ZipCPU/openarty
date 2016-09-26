////////////////////////////////////////////////////////////////////////////////
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
#ifndef	LLCOMMS_H
#define	LLCOMMS_H

class	LLCOMMSI {
protected:
	int	m_fdw, m_fdr;
	LLCOMMSI(void);
public:
	unsigned long	m_total_nread, m_total_nwrit;

	virtual	~LLCOMMSI(void) { close(); }
	virtual	void	kill(void)  { this->close(); };
	virtual	void	close(void);
	virtual	void	write(char *buf, int len);
	virtual int	read(char *buf, int len);
	virtual	bool	poll(unsigned ms);

	// Tests whether or not bytes are available to be read, returns a 
	// count of the bytes that may be immediately read
	virtual	int	available(void); // { return 0; };
};

class	TTYCOMMS : public LLCOMMSI {
public:
	TTYCOMMS(const char *dev);
};

class	NETCOMMS : public LLCOMMSI {
public:
	NETCOMMS(const char *dev, const int port);
};

#endif
