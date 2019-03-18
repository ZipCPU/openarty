////////////////////////////////////////////////////////////////////////////////
//
// Filename:	syscalls.c
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	
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
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
#include <sys/errno.h>
#include <stdint.h>
#include <sys/unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/times.h>
#include <reent.h>
#include <stdio.h>
#include "board.h"
#include "bootloader.h"
#include "zipcpu.h"

#ifdef	_BOARD_HAS_BUSCONSOLE
#define	_ZIP_HAS_WBUART
#define	_ZIP_HAS_UARTTX
#define	_ZIP_HAS_UARTRX
#define	UARTRX	_uart->u_rx
#define	UARTTX	_uart->u_tx
#endif

//
// TXBUSY: Something is still going out the port
#define	TXBUSY	(_uart->u_tx & 0x0100)

// TXWAIT: The FIFO is full, and so nothing can be sent out the TX port
#define	TXWAIT	((_uart->u_fifo & 0x010000)==0)

// UARTTX: The register to write to in order send a value
#define	UARTTX	_uart->u_tx

// UARTRX: The register to read from in order to read a value
#define	UARTRX	_uart->u_rx

void
_outbyte(char v) {
#ifdef	UARTTX
	if (v == '\n') {
		// Depend upon the WBUART, not the PIC
		while(TXWAIT)
			;
		UARTTX = (unsigned)'\r';
	}

	// Depend upon the WBUART, not the PIC
	while(TXWAIT)
		;
	uint8_t c = v;
	UARTTX = c;
#endif
}

int
_inbyte(void) {
#ifdef	UARTRX
	const	int	echo = 1, cr_into_nl = 1;
	static	int	last_was_cr = 0;
	int	rv;

	// Character translations:
	// 1. All characters should be echoed
	// 2. \r's should quietly be turned into \n's
	// 3. \r\n's should quietly be turned into \n's
	// 4. \n's should be passed as is
	// Insist on at least one character
	rv = UARTRX;
	if (rv & 0x0100)
		rv = -1;
	else if ((cr_into_nl)&&(rv == '\r')) {
		rv = '\n';
		last_was_cr = 1;
	} else if ((cr_into_nl)&&(rv == '\n')) {
		if (last_was_cr) {
			rv = -1;
			last_was_cr = 0;
		}
	} else
		last_was_cr = 0;

	if ((rv != -1)&&(echo))
		_outbyte(rv);
	return rv;
#else
	return -1;
#endif
}

int
_close_r(struct _reent *reent, int file) {
	reent->_errno = EBADF;

	return -1;	/* Always fails */
}

char	*__env[1] = { 0 };
char	**environ = __env;

int
_execve_r(struct _reent *reent, const char *name, char * const *argv, char * const *env)
{
	reent->_errno = ENOSYS;
	return -1;
}

int
_fork_r(struct _reent *reent)
{
	reent->_errno = ENOSYS;
	return -1;
}

int
_fstat_r(struct _reent *reent, int file, struct stat *st)
{
	if ((STDOUT_FILENO == file)||(STDERR_FILENO == file)
		||(STDIN_FILENO == file)) {
		st->st_mode = S_IFCHR;
		return 0;
#ifdef	_ZIP_HAS_SDCARD_NOTYET
	} else if (SDCARD_FILENO == file) {
		st->st_mode = S_IFBLK;
#endif
	} else {
		reent->_errno = EBADF;
		return -1;
	}
}

int
_getpid_r(struct _reent *reent)
{
	return 1;
}

int
_gettimeofday_r(struct _reent *reent, struct timeval *ptimeval, void *ptimezone)
{
#ifdef	_BOARD_HAS_RTC
	if (ptimeval) {
		uint32_t	now, date;
		unsigned	s, m, h, tod;

		now = _rtc->r_clock;

#ifdef	_BOARD_HAS_RTCDATE
		unsigned	d, y, c, yy, days_since_epoch;
		int		ly;

		date= *_rtcdate;

		d = ( date     &0x0f)+((date>> 4)&0x0f)*10;
		m = ((date>> 8)&0x0f)+((date>>12)&0x0f)*10;
		y = ((date>>16)&0x0f)+((date>>20)&0x0f)*10;
		c = ((date>>24)&0x0f)+((date>>28)&0x0f)*10;

		ly = 0;
		if ((y&3)==0) {
			if (y!=0)
				ly = 1;
			else if ((y&3)==0)
				ly = 1;
		}

		days_since_epoch = d;
		if (m>1) {
			days_since_epoch += 31;
			if (m>2) {
				days_since_epoch += 28;
				if (ly) days_since_epoch++;
				if (m>3)  { days_since_epoch += 31;
				if (m>4)  { days_since_epoch += 30;
				if (m>5)  { days_since_epoch += 31;
				if (m>6)  { days_since_epoch += 30;
				if (m>7)  { days_since_epoch += 31;
				if (m>8)  { days_since_epoch += 31;
				if (m>9)  { days_since_epoch += 30;
				if (m>10) { days_since_epoch += 31;
				if (m>11)   days_since_epoch += 30;
		}}}}}}}}}}

		for(yy=1970; yy<(c*100+y); yy++) {
			if ((yy&3)==0)
				days_since_epoch += 366;
			else
				days_since_epoch += 365;
		}

		ptimeval->tv_sec  = days_since_epoch * 86400l;
#else
		ptimeval->tv_sec  = 0;
#endif

		s = ( now     &0x0f)+((now>> 4)&0x0f)*10;
		m = ((now>> 8)&0x0f)+((now>>12)&0x0f)*10;
		h = ((now>>16)&0x0f)+((now>>20)&0x0f)*10;
		tod = (h * 60 + m) * 60;
		ptimeval->tv_sec += tod;

		ptimeval->tv_usec = 0;
	}
	return 0;
#else
	reent->_errno = ENOSYS;
	return -1;
#endif
}

int
_isatty_r(struct _reent *reent, int file)
{
	if ((STDIN_FILENO == file)
			||(STDOUT_FILENO == file)
			||(STDERR_FILENO==file))
		return 1;
	return 0;
}

int
_kill_r(struct _reent *reent, int pid, int sig)
{
	reent->_errno = ENOSYS;
	return -1;
}

int
_link_r(struct _reent *reent, const char *existing, const char *new)
{
	reent->_errno = ENOSYS;
	return -1;
}

_off_t
_lseek_r(struct _reent *reent, int file, _off_t ptr, int dir)
{
#ifdef	_ZIP_HAS_SDCARD_NOTYET
	if (SDCARD_FILENO == file) {
		switch(dir) {
		case SEEK_SET:	rootfs_offset = ptr;
		case SEEK_CUR:	rootfs_offset += ptr;
		case SEEK_END:	rootfs_offset = rootfs->nsectors * rootfs->sectorsize - ptr;
		default:
			reent->_errno = EINVAL; return -1;
		} return rootfs_offset;
	}
#endif
	reent->_errno = ENOSYS;
	return -1;
}

int
_open_r(struct _reent *reent, const char *file, int flags, int mode)
{
#ifdef	_ZIP_HAS_SDCARD_NOTYET
	if (strcmp(file, "/dev/sdcard")==0) {
		return SDCARD_FILENO;
	} else {
		reent->_errno = EACCES;
		return -1;
	}
#endif
	reent->_errno = ENOSYS;
	return -1;
}

int
_read_r(struct _reent *reent, int file, void *ptr, size_t len)
{
#ifdef	UARTRX
	if (STDIN_FILENO == file)
	{
		int	nr = 0, rv;
		char	*chp = ptr;

		while((rv=_inbyte()) &0x0100)
			;
		*chp++ = (char)rv;
		nr++;

		// Now read out anything left in the FIFO
		while((nr < len)&&(((rv=_inbyte()) & 0x0100)==0)) {
			*chp++ = (char)rv;
			nr++;
		}

		// if (rv & 0x01000) _uartrx = 0x01000;
		return nr;
	}
#endif
#ifdef	_ZIP_HAS_SDCARD_NOTYET
	if (SDCARD_FILENO == file)
	{
	}
#endif
	errno = ENOSYS;
	return -1;
}

int
_readlink_r(struct _reent *reent, const char *path, char *buf, size_t bufsize)
{
	reent->_errno = ENOSYS;
	return -1;
}

int
_stat_r(struct _reent *reent, const char *path, struct stat *buf) {
	reent->_errno = EIO;
	return -1;
}

int
_unlink_r(struct _reent *reent, const char *path)
{
	reent->_errno = EIO;
	return -1;
}

int
_times(struct tms *buf) {
	errno = EACCES;
	return -1;
}

int
_write_r(struct _reent * reent, int fd, const void *buf, size_t nbytes) {
	if ((STDOUT_FILENO == fd)||(STDERR_FILENO == fd)) {
		const	char *cbuf = buf;
		for(int i=0; i<nbytes; i++)
			_outbyte(cbuf[i]);
		return nbytes;
	}
#ifdef	_ZIP_HAS_SDCARD_NOTYET
	if (SDCARD_FILENO == file)
	{
	}
#endif

	reent->_errno = EBADF;
	return -1;
}

int
_wait(int *status) {
	errno = ECHILD;
	return -1;
}

int	*heap = _top_of_heap;

void *
_sbrk_r(struct _reent *reent, int sz) {
	int	*prev = heap;

	heap += sz;
	return	prev;
}

__attribute__((__noreturn__))
void	_exit(int rcode) {
	extern void	_hw_shutdown(int rcode) _ATTRIBUTE((__noreturn__));

#ifdef	_BOARD_HAS_BUSCONSOLE
	// Problem: Once u_tx & 0x100 goes low, there may still be a character
	// or two in the bus console's pipeline.  These may prevent a newline
	// from completing before we issue the exit command.
	//
	// Solution: Just to make sure any newline finishes, send a final
	// non-newline character.  This character will still be transmitting
	// once we are complete, but any last newline will at least have been
	// received
	_outbyte(' ');
	_outbyte(' ');
#endif

	// Wait for any serial ports to flush their buffers
#ifdef	TXBUSY
	while(TXBUSY)
		;
#else
// #error	"No console"
#endif
	_hw_shutdown(rcode);
}
