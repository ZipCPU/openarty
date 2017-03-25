////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	oledsim.h
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	To simulate the interaction between the OLED board and my
//		logic.  This simulator tries to read from the SPI generated
//	by the logic, verify that the SPI interaction is valid, and then
//	draws the OLED memory to the screen so you can see how the OLED
//	would work ... even without having an OLED connected.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2016, Gisselquist Technology, LLC
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
#ifndef	OLEDSIM_H
#define	OLEDSIM_H

#include <gtkmm.h>
#include <assert.h>

#define	OLED_OFF	1
#define	OLED_RESET	2
#define	OLED_VIO	3
#define	OLED_POWERED	4
#define	OLED_65kCLR	0
#define	OLED_256CLR	1

class	OLEDSIM : public Gtk::DrawingArea {
public:
	typedef		Cairo::RefPtr<Cairo::Context>	CAIROGC;
	typedef const	Cairo::RefPtr<Cairo::Context>	CONTEXT;
	typedef 	Cairo::RefPtr<Cairo::ImageSurface>	CAIROIMG;

private:
	CAIROIMG	m_pix;
	CAIROGC		m_gc;

	int	m_state, m_reset_clocks; // , m_address_counts;

	int	m_last_csn, m_last_sck, m_last_dcn;

	int	m_idx, m_bitpos;
	char	m_data[16];

	bool	m_vaddr_inc, m_locked;
	int	m_format;
	int	m_col_start, m_col_end, m_col;
	int	m_row_start, m_row_end, m_row, m_display_start_row;


	void	do_command(const int dcn, const int len, char *data);
	void	handle_io(const int, const int, const int, const int);
	void	clear_to(const double v);
	void	set_gddram(const int, const int, const double, const double, const double);
public:
	static const int	OLED_HEIGHT, OLED_WIDTH;

	OLEDSIM(void) : Gtk::DrawingArea() {

		set_has_window(true);
		Widget::set_can_focus(false);
		set_size_request(OLED_WIDTH, OLED_HEIGHT);

		m_state = OLED_OFF;
		m_locked = true;
		m_last_csn = 1;
		m_last_sck = 1;
		m_last_dcn = 1;
		m_format = OLED_65kCLR;
		m_display_start_row = 0;
		m_vaddr_inc = false;
		m_col = 0; m_row = 0;
		m_col_start = 0; m_row_start = 0;
		m_col_end = 95; m_row_end = 63;
	}

	void	get_preferred_width_vfunc(int &min, int &nw) const;
	void	get_preferred_height_vfunc(int &min, int &nw) const;
	void	get_preferred_height_for_width_vfunc(int w, int &min, int &nw) const;
	void	get_preferred_width_for_height_vfunc(int h, int &min, int &nw) const;

	virtual	void	on_realize();
	virtual	bool	on_draw(CONTEXT &gc);
	void	operator()(const int iopwr, const int rstn, const int dpwr,
			const int csn, const int sck, const int dcn, const int mosi);
};

class	OLEDWIN : public Gtk::Window {
private:
	OLEDSIM	*m_sim;

public:
	OLEDWIN(void);
	~OLEDWIN(void) { delete m_sim; }
	void	operator()(int iopwr, int rstn, int dpwr,
			int sck, int csn, int dcn, int mosi) {
		(*m_sim)(iopwr, rstn, dpwr, sck, csn, dcn, mosi);
	}
};

#endif
