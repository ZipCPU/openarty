////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	oledsim.cpp
//
// Project:	OpenArty, an entirely open SoC based upon the Arty platform
//
// Purpose:	The goal of this module is very specifically to simulate the 
//		PModOLEDrgb using a GTKMM controlled window.  I'm doing this on
//	an Linux computer with X-Windows, although one GTKMM selling point is
//	that it should work in Windows as well.  I won't vouch for that, as I
//	haven't tested under windows.
//
//	Either way, this controller only implements *some* of the OLED commands.
//	There were just too many commands for me to be able to write them in the
//	short order that I needed to get a test up and running.  Therefore, this
//	simulator will validate all commands and assure you they are valid
//	commands, but it will only respond to some.  For specifics, see the
//	do_command() section below.
//
//	You may notice a lot of assert() calls within this code.  This is half
//	the purpose of the code: to verify that interactions, when the take
//	place, are valid.  The sad problem and effect of this is simply that
//	when bugs are present, the error/warning messages are not that complete.
//	If you find yourself dealing with such an error, please feel free to
//	explain the assert better before asserting, and then send your 
//	contributions back to me so that others can benefit from your work.
//	(Don't you love the GPL?)
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2020, Gisselquist Technology, LLC
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
#include "oledsim.h"

const	int	OLEDSIM::OLED_HEIGHT = 64, OLEDSIM::OLED_WIDTH = 96;

const	int	MICROSECOND = 81,
		tMINRESET = 3  * MICROSECOND, // 3 uS
		tCYCLE = 13, // 150 * NANOSECOND, clock cycle time 
		tAS    =  4, // 40 * NANOSECOND, address setup time
		tAH    =  4, // 40 * NANOSECOND, address hold time
		tCSS   =  7, // 75 * NANOSECOND, chip select setup
		tCSH   =  5, // 60 * NANOSECOND, chip select hold
		tCLKL  =  7, // 75 * NANOSECOND, time the clock must be low
		tCLKH  =  7; // 75 * NANOSECOND, time the clock must be high

void	OLEDSIM::on_realize() {
	Gtk::DrawingArea::on_realize();

	// We'll be doing all of our drawing on an off-screen bit map.  Here,
	// let's allocate that pixel map ...
	m_pix = Cairo::ImageSurface::create(Cairo::FORMAT_RGB24,
			OLED_WIDTH, OLED_HEIGHT);

	// and a graphics context to be used when drawing to it.
	m_gc = Cairo::Context::create(m_pix);

	// We'll start the pixel map filled with all black, as this is what
	// my device looks like when I'm not doing anything with it.
	m_gc->set_source_rgb(0.0,0.0,0.0); // Black
	m_gc->rectangle(0, 0, OLED_WIDTH, OLED_HEIGHT);
	m_gc->fill();
}

void	OLEDSIM::get_preferred_width_vfunc(int &min, int &nw) const {
	// GTKMM wants to know how big we want our window to be.
	// Let's request a window twice as big as we need, but insist that
	// it never be smaller than one pixel output per one pixel input.
	//
	min = OLED_WIDTH;
	nw = OLED_WIDTH * 2;
}

void	OLEDSIM::get_preferred_height_vfunc(int &min, int &nw) const {
	//
	// Same thing as above, but this time for height, not width.
	//
	min = OLED_HEIGHT;
	nw = OLED_HEIGHT * 2;
}

void	OLEDSIM::get_preferred_width_for_height_vfunc(int h, int &min, int &nw) const {
	min = OLED_WIDTH;
	int k = (h+(OLED_HEIGHT/2))/OLED_HEIGHT;
	if (k <= 0)
		k = 1;
	nw = OLED_WIDTH * k;
}

void	OLEDSIM::get_preferred_height_for_width_vfunc(int w, int &min, int &nw) const {
	min = OLED_HEIGHT;
	int k = (w+(OLED_WIDTH/2))/OLED_WIDTH;
	if (k <= 0)
		k = 1;
	nw = OLED_HEIGHT * k;
}

/*
 * This is our simulation function.  This is the function that gets called at 
 * every tick of our controller within Verilator.  At each tick (and not twice
 * per tick), the outputs are gathered and sent our way.  Here, we just decode
 * the power and reset outputs, and send everything else to handle_io().
 */
void	OLEDSIM::operator()(const int iopwr, const int rstn, const int dpwr,
		const int csn, const int sck, const int dcn, const int mosi) {
	if (!iopwr) {
		if (m_state != OLED_OFF) {
fprintf(stderr, "OLEDSIM::TURN-OFF\n");
			m_state = OLED_OFF;
			clear_to(0.0);
			queue_draw_area(0,0,get_width(), get_height());
		}
		assert(!dpwr);
	} else if (!rstn) {
		if (m_state != OLED_RESET) {
fprintf(stderr, "OLEDSIM::ENTER-RESET\n");
			m_state = OLED_RESET;
			m_locked = true;
			clear_to(0.1);
			m_reset_clocks = 0;
			queue_draw_area(0,0,get_width(), get_height());
		} if (m_reset_clocks < tMINRESET)
			m_reset_clocks++;
		assert(csn);
		assert(sck);
	} else if (dpwr) {
		if (m_state != OLED_POWERED) {
fprintf(stderr, "OLEDSIM::POWER-UP\n");
			m_state = OLED_POWERED;
			queue_draw_area(0,0,get_width(), get_height());
			if (!csn) {
				printf("OLED-ERR: CSN=%d, SCK=%d, DCN=%d, MOSI=%d, from %d,%d,%d\n",
				csn, sck, dcn, mosi,
				m_last_csn, m_last_sck, m_last_dcn);
			}
			assert(csn); // Can't power up with SPI active.
		}

		handle_io(csn, sck, dcn, mosi);
	} else {
		if (m_state != OLED_VIO) {
fprintf(stderr, "OLEDSIM::VIO\n");
			m_state = OLED_VIO;
			queue_draw_area(0,0,get_width(), get_height());
		}
		handle_io(csn, sck, dcn, mosi);
	}
}

/* handle_io()
 *
 * We only enter this function if the I/O is powered up and the device is out
 * of reset.  The device may (or may not) be on.  Our purpose here is to decode
 * the SPI commands into a byte sequence, kept in m_data with a length given by
 * m_idx.  Once a command has completed, we call do_command() to actually
 * process the values received, the arguments, etc. and do something with them.
 *
 */
void	OLEDSIM::handle_io(const int csn, const int sck, const int dcn, const int mosi) {
	if ((csn != m_last_csn)||(sck != m_last_sck)||(dcn != m_last_dcn))
		printf("OLED: HANDLE-IO(%d,%d,%d,%d) @[%d]%d\n",
			csn, sck, dcn, mosi, m_idx, m_bitpos);
	if (csn) {
		// CSN is high when the chip isn't selected.
		if (!m_last_csn) {
			// If the chip was just selected, it then means that our
			// command just completed.  Let's process it here.
			printf("OLED: Ending a command\n");
			assert(m_idx > 0);
			assert((m_bitpos&7)==0);
			do_command(m_last_dcn, m_idx, m_data);

			m_bitpos = 0;
			m_idx    = 0;
			for(int i=0; i<8; i++)
				m_data[i] = 0;
			assert(m_last_sck);
		} if (!sck)
			printf("OLED: CSN = %d, SCK = %d, DCN = %d, MOSI = %d, from %d, %d, %d\n",
				csn, sck, dcn, mosi,
				m_last_csn, m_last_sck, m_last_dcn);
		assert(sck);
		m_bitpos = 0;
		m_idx    = 0;
	} else {
		if (m_last_csn) {
			assert((sck)&&(m_last_sck));
			assert(m_last_sck);
			printf("OLED: Starting a command\n");
		}

		/*
		if (m_last_dcn != dcn) {
			m_address_counts = 0;
		} m_address_counts++;
		*/

		if ((sck)&&(!m_last_sck)) {
			m_bitpos++;
			m_data[m_idx] = (m_data[m_idx]<<1)|mosi;
			printf("OLED: Accepted bit: m_data[%d] = %02x\n",
				m_idx, m_data[m_idx]);
			if (m_bitpos >= 8) {
				m_idx++;
				m_bitpos &= 7;
			}
			assert(m_idx < 3+4+4);
			// assert(m_address_count > tCSS);
		} else if ((!sck)&&(m_last_sck)) {
		}
	}

	m_last_csn = csn;
	m_last_sck = sck;
	m_last_dcn = dcn;
}

void	OLEDSIM::do_command(const int dcn, const int len, char *data) {
fprintf(stderr, "DO-COMMAND\n");
	assert(len > 0);
	assert(len <= 11);

	printf("OLED: RECEIVED CMD(%02x) ", data[0]&0x0ff);
	if (len > 1) {
		printf(" - ");
		for(int i=1; i<len-1; i++)
			printf("%02x:", data[i]&0x0ff);
		printf("%02x", data[len-1]&0x0ff);
		printf("\n");
	}
	
	if (dcn) {
		// Do something with the pixmap
		double	dr, dg, db;

		if (m_format == OLED_65kCLR) {
			int	r, g, b;
			assert(len == 2);
			r =  (data[0]>>3)&0x01f;
			g = ((data[0]<<3)&0x038)|((data[1]>>5)&0x07);
			b = ((data[1]   )&0x01f);

			dr = r / 31.0;
			dg = g / 63.0;
			db = b / 31.0;
		} else {
			printf("OLED: UNSUPPORTED COLOR FORMAT!\n");
			dr = dg = db = 0.0;
		} set_gddram(m_col, m_row, dr, dg, db);
		if (!m_vaddr_inc) {
			m_col++;
			if (m_col > m_col_end) {
				m_col = m_col_start;
				m_row++;
				if (m_row > m_row_end)
					m_row = m_row_start;
			}
		} else {
			m_row++;
			if (m_row > m_row_end) {
				m_row = m_row_start;
				m_col++;
				if (m_col > m_col_end)
					m_col = m_col_start;
			}
		}
	} else if (m_locked) {
		if ((len == 2)&&((data[0]&0x0ff) == 0x0fd)&&(data[1] == 0x12)) {
			m_locked = false;
			printf("OLED: COMMANDS UNLOCKED\n");
		} else {
			printf("OLED: COMMAND IGNORED, IC LOCKED\n");
		}
	} else {
		// Command word
		switch((data[0])&0x0ff) {
		case 0x15: // Setup column start and end address
			assert(len == 3);
			assert((data[1]&0x0ff) <= 95);
			assert((data[2]&0x0ff) <= 95);
			m_col_start = data[1]&0x0ff;
			m_col_end   = data[2]&0x0ff;
			assert(m_col_end >= m_col_start);
			m_col = m_col_start;
			break;
		case 0x75: // Setup row start and end address
			assert(len == 3);
			assert((data[1]&0x0ff) <= 63);
			assert((data[2]&0x0ff) <= 63);
			assert(m_row_end >= m_row_start);
			m_row_start = data[1]&0x0ff;
			m_row_end   = data[2]&0x0ff;
			break;
		case 0x81: // Set constrast for all color "A" segment
			assert(len == 2);
			break;
		case 0x82: // Set constrast for all color "B" segment
			assert(len == 2);
			break;
		case 0x83: // Set constrast for all color "C" segment
			assert(len == 2);
			break;
		case 0x87: // Set master current attenuation factor
			assert(len == 2);
			break;
		case 0x8a: // Set second pre-charge speed, color A
			assert(len == 2);
			break;
		case 0x8b: // Set second pre-charge speed, color B
			assert(len == 2);
			break;
		case 0x8c: // Set second pre-charge speed, color C
			assert(len == 2);
			break;
		case 0xa0: // Set driver remap and color depth
			assert(len == 2);
			m_vaddr_inc = (data[1]&1)?true:false;
			// m_fliplr = (data[1]&2)?true:false;
			if ((data[1] & 0x0c0)==0)
				m_format = OLED_256CLR;
			else if ((data[1] & 0x0c0)==0x40)
				m_format = OLED_65kCLR;
			// else if ((data[1] & 0x0c0)==0x80)
				// m_format = OLED_65kCLRTWO;
			
			break;
		case 0xa1: // Set display start line register by row
			assert(len == 2);
			break;
		case 0xa2: // Set vertical offset by com
			assert(len == 2);
			break;
		case 0xa4: // Set display mode
		case 0xa5: // Fallthrough
		case 0xa6: // Fallthrough
		case 0xa7: // Fallthrough
			assert(len == 1);
			break;
		case 0xa8: // Set multiplex ratio
			assert(len == 2);
			break;
		case 0xab: // Dim Mode setting
			assert(len == 6);
			break;
		case 0xad:
			assert(len == 2);
			assert((data[1]&0x0fe)==0x08e);
			break;
		case 0xac:
		case 0xae:
		case 0xaf:
			assert(len == 1);
			break;
		case 0xb0: // Power save mode
			assert((len == 2)&&((data[1] == 0x1a)||(data[1] == 0x0b)));
			break;
		case 0xb1: // Phase 1 and 2 period adjustment
			assert(len == 2);
			break;
		case 0xb3: // Displaky clock divider/oscillator frequency
			assert(len == 2);
			break;
		case 0xb8: // Set gray scale table
			assert(0 && "Gray scale table not implemented");
			break;
		case 0xb9: // Enable Linear Gray Scale table
			assert(len == 1);
			break;
		case 0xbb: // Set pre-charge level
			assert(len == 2);
			break;
		case 0xbc: // NOP
		case 0xbd: // NOP
			assert(len == 1);
		case 0xbe: // Set V_COMH
			assert(len == 2);
			break;
		case 0xe3: // NOP
			assert(len == 1);
			break;
		case 0xfd: // Set command lock
			assert(len == 2);
			if (data[1] == 0x16) {
				m_locked = true;
				printf("OLED: COMMANDS NOW LOCKED\n");
			}
			break;
		case 0x21: // Draw Line
			assert(len == 8);
			break;
		case 0x22: // Draw Rectangle
			assert(len == 11);
			break;
		case 0x23: // Copy
			assert(len == 7);
			break;
		case 0x24: // Dim Window
			assert(len == 5);
			break;
		case 0x25: // Clear Window
			assert(len == 5);
			break;
		case 0x26: // Fill Enable/Disable
			assert(len == 2);
			// if (data[0]&1)
			//	m_drect_fills = 1;
			assert((data[1] & 0x10)==0);
			break;
		case 0x27: // Continuous horizontal and vertical scrolling setup
			assert(len == 6);
			break;
		case 0x2e: // Deactivate scrolling
			assert(len == 1);
			// m_scrolling = false;
			break;
		case 0x2f: // Activate scrolling
			assert(len == 1);
			// m_scrolling = true;
			break;
		default:
			printf("OLED: UNKNOWN COMMAND, data[0] = %02x\n", data[0] & 0x0ff);
			assert(0);
			break;
		}
	}
}

/*
 * set_gddram()
 *
 * Set graphics display DRAM.
 *
 * Here is the heart of drawing on the device, or at least pixel level drawing.
 * The device allows other types of drawing, such as filling rectangles and
 * such.  Here, we just handle the setting of pixels.
 *
 * You'll note that updates to the drawing area are only queued if the device
 * is in powered mode.
 *
 * At some point, I may wish to implement scrolling.  If/when that happens,
 * the GDDRAM will not be affected, but the area that needs to be redrawn will
 * be.  Hence this routine will need to be adjusted at that time.
 */
void	OLEDSIM::set_gddram(const int col, const int row,
		const double dr, const double dg, const double db) {
	// Set our color to that given by the rgb (double) parameters.
	m_gc->set_source_rgb(dr, dg, db);

	printf("OLED: Setting pixel[%2d,%2d]\n", col, row);
	int	drow; //  dcol;
	drow = row + m_display_start_row;
	if (drow >= OLED_HEIGHT)
		drow -= OLED_HEIGHT;
	m_gc->rectangle(col, row, 1, 1);
	m_gc->fill();

	if (m_state == OLED_POWERED) {
		// Need to adjust the invalidated area if scrolling is taking
		// place.
		double	kw, kh;
		int	t, l;
		kw = get_width()/(double)OLED_WIDTH;
		kh = get_height()/(double)OLED_HEIGHT;

		t = row * kh-1;
		l = col * kw-1;
		queue_draw_area(l, t, (int)(kw)+1, (int)(kh)+1);
	}
}

/*
 * clear_to()
 *
 * Clears the simulated device to a known grayscale value.  Examples are 
 * 0.0 for black, or 0.1 for a gray that is nearly black.  Note that this
 * call does *not* invalidate our window.  Perhaps it should, but for now that
 * is the responsibility of whatever function calls this function.
 */
void	OLEDSIM::clear_to(double v) {
	// How do we apply this to our pixmap?
	m_gc->set_source_rgb(v, v, v);
	m_gc->rectangle(0, 0, OLED_WIDTH, OLED_HEIGHT);
	m_gc->fill();
}

bool	OLEDSIM::on_draw(CONTEXT &gc) {
fprintf(stderr, "ON-DRAW\n");
	gc->save();
	if (m_state == OLED_POWERED) {
		// Scrolling will be implemented here
		gc->scale(get_width()/(double)OLED_WIDTH,
				get_height()/(double)OLED_HEIGHT);
		gc->set_source(m_pix, 0, 0);
		gc->paint();
	} else {
		if ((m_state == OLED_VIO)||(m_state == OLED_RESET))
			gc->set_source_rgb(0.1,0.1,0.1); // DARK gray
		else
			gc->set_source_rgb(0.0,0.0,0.0); // Black
		// gc->rectangle(0, 0, OLED_WIDTH, OLED_HEIGHT);
		gc->rectangle(0, 0, get_width(), get_height());
		gc->fill();
	} gc->restore();

	return true;
}

OLEDWIN::OLEDWIN(void) {
fprintf(stderr, "Setting up OLEDWIN\n");
	m_sim = new OLEDSIM();
	m_sim->set_size_request(OLEDSIM::OLED_WIDTH, OLEDSIM::OLED_HEIGHT);
	set_border_width(0);
	add(*m_sim);
	show_all();
	Gtk::Window::set_title(Glib::ustring("OLED Simulator"));
	fprintf(stderr, "Window all set up\n");
}

