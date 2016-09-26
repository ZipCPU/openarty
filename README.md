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

I currently have all the hardware on my desk.

The design builds, as of 20160910, at an 81.25 MHz clock speed.

- ZipCPU: The ZipCPU should be fully functional at the current clock speed.  I'd like to boost it to twice this speed, but that may remain a longer term project.
- Flash: the flash controller has now passedd all of the tests given it, both simulated and live.  It can read and write the flash, and so it can place configurations onto the flash as desired.  As built, though, the controller is optimized for a 200MHz clock speed, and a 100MHz bus speed.  It's being run at an 81.25MHz clock speed though (40.625MHz bus speed), so some performance improvement might yet be achieved.
- SDRAM: I intend to implement work from the DDR3 SDRAM controller for the Arty.  For now, the project builds with a Xilinx Memory Interface Generated (MIG) core, and a pipelind wishbone to AXI translator.
- NET: The entire network functionality has now been built.  It is waiting for testing and the faults that will be found during said testing.
- SD: The SDSPI controller has been integrated into the device, yet not tested yet.  I don't expect issues with it, as it is a proven controller.  Work remains to turn this from a SPI controller to an SDIO based driver.
- OLEDRGB: the driver is built, and has been integrated into the project, but testing hasn't started yet.

So ... it's a work in progress.


