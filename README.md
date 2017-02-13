# Description

The purpose of the OpenArty project is to implement a ZipCPU on an Arty platform, together with open source drivers for all of the Arty peripherals.  In my case, that will include drivers for additional PMods that I have purchased for the project.  Hence the OpenArty platform with support:

1. EQSPI flash, to include all of the flash's functionality such as being able to read its ID as well as being able to read and set the one time programmable memory.  Further, when complete, a ZipCPU will launch code automatically from the flash on startup.
2. DDR3 SDRAM
3. The Internal Configuration Access Port (ICAPE2), to allow for dynamic (not partial) reconfiguration
4. Ethernet
5. SD Card.  The program currently uses the SDSPI controller, although I intend to upgrade to a full SDIO controller with (hopefully) the same identical or nearly identical interface.
6. OLEDrgb display.
7. GPS clock module, and external USB-UART.
8. This leaves one open PMOD port which ... I haven't decided what to connect it to.

As a demonstration project, I'd love to implement an NTP server within the device.  This is a long term goal, however, and a lot needs to be accomplished before I can get there.  Still, a $130 NTP server isn't a bad price for an NTP server in your lab.  ($99 for the Arty, $25 for the GPS receiver IIRC)

# Current Status

This version of the OpenArty project is designed to support an 8-bit byte branch of the ZipCPU.  Once the ZipCPU is proven here and in some other locations, the 8-bit branch of the ZipCPU will become the master.

The design builds, as of 201710, at an 81.25 MHz clock speed, with the ZipCPU 8-bit byte updates.  As of this writing, the design builds only.  It has yet to be tested on the hardware (again--the trunk works on the hardware).

- ZipCPU: The ZipCPU should be fully functional at the current clock speed.  I'd like to boost it to twice this speed, but that may remain a longer term project.
- Flash: Working completely.  An option remains to increase the clock speed from one half of the system clock 81.25MHz, up to the actual system clock speed or perhaps even twice that speed.
- SDRAM: I would still like to implement the work from the DDR3 SDRAM controller for the Arty.  For now, the project builds with a Xilinx Memory Interface Generated (MIG) core, and a pipelind wishbone to AXI translator.
- NET: Working on the trunk using a simple program that can send and receive ARP packets, respond to ARP requests, respond to pings, and even ping a local host.
- SD: The SDSPI controller has been integrated into the device, yet not tested yet.  I don't expect issues with it, as it is a proven controller--just not one proven (yet) in this platform.  Work remains to turn this from a SPI controller to an SDIO based driver.
- OLEDRGB: Working on the trunk

So ... it's a work in progress.

# Repository

Due to the ongoing issues with OpenCores, the official OpenArty repository
is being kept on GitHub, under the ZipCPU username.

# License

Gisselquist Technology, LLC, is pleased to provide you with this entire
OpenArty project under the GPLv3 license.  If this doesn't work for you,
please contact me.
