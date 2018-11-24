# Description

The purpose of the OpenArty project is to implement a [ZipCPU](http://zipcpu.com/about/zipcpu.html) on an Arty platform, together with open source drivers for all of the Arty peripherals.  In my case, that will include drivers for additional PMods that I have purchased for the project.  Hence the OpenArty platform with support:

1. [Generic flash driver](rtl/qflexpress.v), to include access to all of the [flash's functionality](sw/host/flashdrvr.h) such as being able to read its ID as well as being able to read and set the one time programmable memory.  This in addition to being flash manufacturer agnostic.  Further, when complete, a [ZipCPU](http://zipcpu.com/about/zipcpu.html) will launch code automatically from the flash on startup.
2. DDR3 SDRAM (Done)
3. The Internal Configuration Access Port (ICAPE2), to allow for dynamic (not partial) reconfiguration (Done)
4. Ethernet (Done)
5. SD Card.  The program currently uses the SDSPI controller, although I intend to upgrade to a full SDIO controller with (hopefully) the same identical or nearly identical interface.
6. OLEDrgb display. (Done)
7. GPS clock module, and external USB-UART. (Done)
8. This leaves one open PMOD port which ... I haven't decided what to connect it to.

As a demonstration project, I'd love to implement an NTP server within the device.  This is a long term goal, however, and a lot needs to be accomplished before I can get there.  Still, a $130 NTP server isn't a bad price for an NTP server in your lab.  ($99 for the Arty, $25 for the GPS receiver IIRC)

# Current Status

This version of the OpenArty project is built around [AutoFPGA](https://github.com/ZipCPU/autofpga).  It is designed to be highly reconfigurable, so that you can add (or remove) peripherals quickly and easily.  My specific goal is to use [AutoFPGA](https://github.com/ZipCPU/autofpga) to create a project that doesn't require all of the peripherals I've used, but may be instead built with only those peripherals on the board.

The design builds, as of 201823, at an 81.25 MHz clock speed.  As of this writing, the design builds only.  I now need to go back and verify that all the peripherals still work following the transition to [AutoFPGA](https://github.com/ZipCPU/autofpga) and the [generic flash driver](rtl/qflexpress.v).

So ... it's a (new) work in progress.

# Repository

Due to the ongoing issues with [OpenCores](http://opencores.org/project/openarty), the [official OpenArty repository](https://github.com/ZipCPU/openarty)
is being kept on [GitHub](https://github.com), under the [ZipCPU username](https://github.com/ZipCPU).

# License

Gisselquist Technology, LLC, is pleased to provide you with this entire
OpenArty project under the [GPLv3 license](doc/gpl-v3.0.pdf).  If this doesn't work for you,
please contact me.
