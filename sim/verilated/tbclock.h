////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	tbclock.h
//
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2017, Gisselquist Technology, LLC
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
#ifndef	TBCLOCK_H
#define	TBCLOCK_H

class	TBCLOCK	{
	unsigned long	m_increment_ps, m_now_ps, m_last_edge_ps, m_ticks;

public:
	TBCLOCK(void) {
		m_increment_ps = 10000; // 10 ns;

		m_now_ps = m_increment_ps+1;
		m_last_edge_ps = 0;
		m_ticks = 0;
	}

	TBCLOCK(unsigned long increment_ps) {
		init(increment_ps);
	}

	unsigned long ticks(void) { return m_ticks; }

	void	init(unsigned long increment_ps) {
		set_interval_ps(increment_ps);

		// Start with the clock low, waiting on a positive edge
		m_now_ps = m_increment_ps+1;
		m_last_edge_ps = 0;
	}

	unsigned long	time_to_tick(void) {
		unsigned long	ul;
		if (m_last_edge_ps > m_now_ps) {
			// Should never happen
			ul = m_last_edge_ps - m_now_ps;
			ul /= m_increment_ps;
			return m_now_ps + ul * m_increment_ps;
		} else // if (m_last_edge + m_interval_ps > m_now) {
			return (m_last_edge_ps +   m_increment_ps - m_now_ps);
	}

	void	set_interval_ps(unsigned long interval_ps) {
		// Divide the clocks interval by two, so we can have a
		// period for raising the clock, and another for lowering
		// the clock.
		m_increment_ps = (interval_ps>>1)&-2l;
		assert(m_increment_ps > 0);
	}

	int	advance(unsigned long itime) {
		m_now_ps += itime;
		if (m_now_ps >= m_last_edge_ps + 2*m_increment_ps) {
			m_last_edge_ps += 2*m_increment_ps;
			m_ticks++;
			return 1;
		} else if (m_now_ps >= m_last_edge_ps + m_increment_ps)
			return 0;
		else
			return 1;
	}

	bool	rising_edge(void) {
		if (m_now_ps == m_last_edge_ps)
			return true;
		return false;
	}

	bool	falling_edge(void) {
		if (m_now_ps == m_last_edge_ps + m_increment_ps)
			return true;
		return false;
	}
};
#endif
