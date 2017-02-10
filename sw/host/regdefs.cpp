////////////////////////////////////////////////////////////////////////////////
//
// Filename:	regdefs.cpp
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
//
#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <ctype.h>
#include "regdefs.h"

const	REGNAME	raw_bregs[] = {
	{ R_VERSION,	"VERSION"		},
	{ R_ICONTROL,	"ICONTROL"		},
	{ R_ICONTROL,	"INT"			},
	{ R_ICONTROL,	"PIC"			},
	{ R_BUSERR,	"BUSERR"		},
	{ R_BUSERR,	"BUS"			},
	{ R_PWCOUNT,	"PWRCOUNT"		},
	{ R_BTNSW,	"BTNSW"			},
	{ R_BTNSW,	"BTNS"			},
	{ R_BTNSW,	"BTN"			},
	{ R_BTNSW,	"SW"			},
	{ R_BTNSW,	"SWITCHES"		},
	{ R_BTNSW,	"SWITCH"		},
	{ R_LEDS,	"LEDS"			},
	{ R_LEDS,	"LED"			},
	{ R_UART_SETUP,	"UARTSETUP"		},
	{ R_UART_SETUP,	"UART"			},
	{ R_UART_SETUP,	"AUXSETUP"		},
	{ R_UART_SETUP,	"AUX"			},
	{ R_GPS_SETUP,	"GPSSETUP"		},
	{ R_GPS_SETUP,	"GPSUART"		},
	{ R_CLR0,	"CLRLED0"		},
	{ R_CLR1,	"CLRLED1"		},
	{ R_CLR2,	"CLRLED2"		},
	{ R_CLR3,	"CLRLED3"		},
	{ R_CLR0,	"CLR0"			},
	{ R_CLR1,	"CLR1"			},
	{ R_CLR2,	"CLR2"			},
	{ R_CLR3,	"CLR3"			},
	{ R_DATE,	"DATE"			},
	{ R_GPIO,	"GPIO"			},
	{ R_UARTRX,	"AUXRX"			},
	{ R_UARTRX,	"RX"			},
	{ R_UARTTX,	"AUXTX"			},
	{ R_UARTTX,	"TX"			},
	//
	{ R_GPSRX,		"GPSRX"		},
	{ R_GPSTX,		"GPSTX"		},
	// Scope registers--these scopes may or may not be present depending
	// upon your current configuration.
	{ R_QSCOPE,	"SCOPE"			},	// Scope zero
	{ R_QSCOPE,	"SCOP"			},
	{ R_QSCOPED,	"SCOPDATA"		},
	{ R_QSCOPED,	"SCDATA"		},
	{ R_QSCOPED,	"SCOPED"		},
	{ R_QSCOPED,	"SCOPD"			},
	{ R_CPUSCOPE,	"CPUSCOPE"		},
	{ R_CPUSCOPED,	"CPUSCOPD"		},
	{ R_CPUSCOPED,	"CPUSCOPED"		},
	{ R_GPSCOPE,	"GPSSCOPE"		},	// Scope one
	{ R_GPSCOPE,	"GPSSCOP"		},
	{ R_GPSCOPED,	"GPSSCDATA"		},
	{ R_GPSCOPED,	"GPSSCD"		},
	{ R_GPSCOPED,	"GPSDATA"		},
	{ R_CFGSCOPE,	"CFGSCOPE"		},	// Scope one
	{ R_CFGSCOPE,	"CFGSCOP"		},
	{ R_CFGSCOPED,	"CFGSCDATA"		},
	{ R_CFGSCOPED,	"CFGSCD"		},
	{ R_BUSSCOPE,	"BUSSCOPE"		},	// Scope one
	{ R_BUSSCOPED,	"BUSSCOPD"		},
	{ R_RAMSCOPE,	"RAMSCOPE"		},	// Scope two
	{ R_RAMSCOPE,	"RAMSCOP"		},
	{ R_RAMSCOPED,	"RAMSCOPD"		},
	{ R_NETSCOPE,	"NETSCOPE"		},	// Scope three
	{ R_NETSCOPE,	"NETSCOP"		},
	{ R_NETSCOPED,	"NETSCOPED"		},
	{ R_NETSCOPED,	"NETSCOPD"		},
	// RTC registers
	{ R_CLOCK,	"CLOCK"			},
	{ R_CLOCK,	"TIME"			},
	{ R_TIMER,	"TIMER"			},
	{ R_STOPWATCH,	"STOPWACH"		},
	{ R_STOPWATCH,	"STOPWATCH"		},
	{ R_CKALARM,	"CKALARM"		},
	{ R_CKALARM,	"ALARM"			},
	// SDCard registers
	{ R_SDCARD_CTRL, "SDCARD"		},
	{ R_SDCARD_DATA, "SDDATA"		},
	{ R_SDCARD_FIFOA, "SDFIF0"		},
	{ R_SDCARD_FIFOA, "SDFIFO"		},
	{ R_SDCARD_FIFOA, "SDFIFA"		},
	{ R_SDCARD_FIFOA, "SDFIFO0"		},
	{ R_SDCARD_FIFOA, "SDFIFOA"		},
	{ R_SDCARD_FIFOB, "SDFIF1"		},
	{ R_SDCARD_FIFOB, "SDFIFB"		},
	{ R_SDCARD_FIFOB, "SDFIFO1"		},
	{ R_SDCARD_FIFOB, "SDFIFOB"		},
	// GPS control loop control
	{ R_GPS_ALPHA,	"ALPHA"			},
	{ R_GPS_BETA,	"BETA"			},
	{ R_GPS_GAMMA,	"GAMMA"			},
	{ R_GPS_STEP,	"GPSSTEP"		},
	// Network packet interface (not built yet)
	// OLED Control
	{ R_OLED_CMD,	"OLED"			},
	{ R_OLED_CDATA,	"OLEDCA"		},
	{ R_OLED_CDATB,	"OLEDCB"		},
	{ R_OLED_DATA,	"ODATA"			},
	// Unused section
	// GPS Testbench
	{ R_GPSTB_FREQ,		"GPSFREQ"	},
	{ R_GPSTB_JUMP,		"GPSJUMP"	},
	{ R_GPSTB_ERRHI,	"ERRHI"		},
	{ R_GPSTB_ERRLO,	"ERRLO"		},
	{ R_GPSTB_COUNTHI,	"CNTHI"		},
	{ R_GPSTB_COUNTLO,	"CNTLO"		},
	{ R_GPSTB_STEPHI,	"STEPHI"	},
	{ R_GPSTB_STEPLO,	"STEPLO"	},
	// Ethernet, packet control registers
	{ R_NET_RXCMD, 		"RXCMD"		},
	{ R_NET_RXCMD, 		"NETRX"		},
	{ R_NET_TXCMD, 		"TXCMD"		},
	{ R_NET_TXCMD, 		"NETTX"		},
	{ R_NET_MACHI, 		"MACHI"		},
	{ R_NET_MACLO, 		"MACLO"		},
	{ R_NET_RXMISS, 	"NETMISS"	},
	{ R_NET_RXERR, 		"NETERR"	},
	{ R_NET_RXCRC, 		"NETXCRC"	},
	// Ethernet  MDIO registers
	{ R_MDIO_BMCR,		"BMCR"		},
	{ R_MDIO_BMSR,		"BMSR"		},
	{ R_MDIO_PHYIDR1,	"PHYIDR1"	},
	{ R_MDIO_PHYIDR2,	"PHYIDR2"	},
	{ R_MDIO_ANAR,		"ANAR"		},
	{ R_MDIO_ANLPAR,	"ANLPAR"	},
	{ R_MDIO_ANER,		"ANER"		},
	{ R_MDIO_ANNPTR,	"ANNPTR"	},
	{ R_MDIO_PHYSTS,	"PHYSTS"	},
	{ R_MDIO_FCSCR,		"FCSCR"		},
	{ R_MDIO_RECR,		"RECR"		},
	{ R_MDIO_PCSR,		"PCSR"		},
	{ R_MDIO_RBR,		"RBR"		},
	{ R_MDIO_LEDCR,		"LEDCR"		},
	{ R_MDIO_PHYCR,		"PHYCR"		},
	{ R_MDIO_BTSCR,		"BTSCR"		},
	{ R_MDIO_CDCTRL,	"CDCTRL"	},
	{ R_MDIO_EDCR,		"EDCR"		},
	//
	// Flash configuration register names
	{ R_QSPI_EREG,	"QSPIEREG"		},
	{ R_QSPI_EREG,	"QSPIE"			},
	{ R_QSPI_STAT,	"QSPIS"			},
	{ R_QSPI_NVCONF,"QSPINVCF"		},
	{ R_QSPI_NVCONF,"QSPINV"		},
	{ R_QSPI_VCONF,	"QSPIVCNF"		},
	{ R_QSPI_VCONF,	"QSPIV"			},
	{ R_QSPI_EVCONF,"QSPIEVCF"		},
	{ R_QSPI_EVCONF,"QSPIEV"		},
	{ R_QSPI_LOCK,	"QSPILOCK"		},
	{ R_QSPI_FLAG,	"QSPIFLAG"		},
	{ R_QSPI_ID,	"QSPIID"		},
	{ R_QSPI_IDA,	"QSPIIDA"		},
	{ R_QSPI_IDB,	"QSPIIDB"		},
	{ R_QSPI_IDC,	"QSPIIDC"		},
	{ R_QSPI_IDD,	"QSPIIDD"		},
	{ R_QSPI_OTPWP, "QSPIOTPWP"		},
	{ R_QSPI_OTP,	"QSPIOTP"		},
	//
	{ R_CFG_CRC,	"FPGACRC"		},
	{ R_CFG_FAR,	"FPGAFAR"		},
	{ R_CFG_FDRI,	"FPGAFDRI"		},
	{ R_CFG_FDRO,	"FPGAFDRO"		},
	{ R_CFG_CMD,	"FPGACMD"		},
	{ R_CFG_CTL0,	"FPGACTL0"		},
	{ R_CFG_MASK,	"FPGAMASK"		},
	{ R_CFG_STAT,	"FPGASTAT"		},
	{ R_CFG_LOUT,	"FPGALOUT"		},
	{ R_CFG_COR0,	"FPGACOR0"		},
	{ R_CFG_MFWR,	"FPGAMFWR"		},
	{ R_CFG_CBC,	"FPGACBC"		},
	{ R_CFG_IDCODE,	"FPGAIDCODE"		},
	{ R_CFG_AXSS,	"FPGAAXSS"		},
	{ R_CFG_COR0,	"FPGACOR1"		},
	{ R_CFG_WBSTAR,	"WBSTAR"		},
	{ R_CFG_TIMER,	"CFGTIMER"		},
	{ R_CFG_BOOTSTS,"BOOTSTS"		},
	{ R_CFG_CTL1,	"FPGACTL1"		},
	{ R_CFG_BSPI,	"FPGABSPI"		},
	//
	{ R_ZIPCTRL,	"ZIPCTRL"		},
	{ R_ZIPCTRL,	"ZIPC"			},
	{ R_ZIPCTRL,	"CPU"			},
	{ R_ZIPCTRL,	"CPUC"			},
	{ R_ZIPDATA,	"ZIPDATA"		},
	{ R_ZIPDATA,	"ZIPD"			},
	{ R_ZIPDATA,	"CPUD"			},
	{ EQSPIFLASH,	"FLASH"			},
	{ MEMBASE,	"BLKRAM"		},
	{ MEMBASE,	"MEM"			},
	{ RAMBASE,	"DDR3SDRAM"		},
	{ RAMBASE,	"SDRAM"			},
	{ RAMBASE,	"RAM"			}
};

#define	RAW_NREGS	(sizeof(raw_bregs)/sizeof(bregs[0]))

const	REGNAME	*bregs = raw_bregs;
const	int	NREGS = RAW_NREGS;

unsigned	addrdecode(const char *v) {
	if (isalpha(v[0])) {
		for(int i=0; i<NREGS; i++)
			if (strcasecmp(v, bregs[i].m_name)==0)
				return bregs[i].m_addr;
		fprintf(stderr, "Unknown register: %s\n", v);
		exit(-2);
	} else
		return strtoul(v, NULL, 0); 
}

const	char *addrname(const unsigned v) {
	for(int i=0; i<NREGS; i++)
		if (bregs[i].m_addr == v)
			return bregs[i].m_name;
	return NULL;
}

