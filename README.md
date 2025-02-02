# meta-modberry
Techbase Modberry industrial Computer based on a Raspberry Pi Compute Module 4

This README file contains information on the contents of the meta-modberry layer.

Please see the corresponding sections below for details.

Dependencies
============

  URI: [first dependency](https://github.com/yoctoproject/poky.git)
  branch: kirkstone

  URI: [second dependency](git://git.yoctoproject.org/meta-raspberrypi)
  branch: kirkstone
  
  URI: [third dependency](https://github.com/openembedded/meta-openembedded.git)
  branch: kirkstone

  URI: [fourth dependency](https://github.com/mendersoftware/meta-mender.git)
  branch: kirkstone

  URI: [fifth dependency](git@github.com:bynacon/meta-edgecon.git)
  branch: kirkstone

  URI: [sixth dependency](git://git.yoctoproject.org/meta-security.git)
  branch: kirkstone

  URI: [seventh dependency](git://git.yoctoproject.org/meta-virtualization)
  branch: kirkstone

  URI: [eight dependency](https://github.com/bynacon/meta-ota.git), but it is private and not necessary to build a Raspberry Pi image for a Modberry.
  branch: kirkstone

Patches
=======

Please submit any patches against the meta-modberry layer to the Bynacon maintainer Ben Roethlisberger <ben.roethlisberger@bynacon.ch>

Table of Contents
=================

    I.    Adding the meta-modberry layer to your build
    II.   
    III.  Release Note of meta-edgecon


I. Adding the meta-bynacon layer to your build
=================================================

Run 'bitbake-layers add-layer meta-egecon' and all other layer how above

II. Misc
========

--- replace with specific information about the meta-bynacon layer ---

III. Release Note Numbering
===========================
Info over numbering of release notes IE 5.04.12.023:

First number => Device Version
  1. Unknown
  2. Unknown
  3. Unknown
  4. Unknown
  5. Modberry
  6. Unknown
  7. Unknown
  8. Unknown
  9. Unknown

Second number => Main release number
third number => Sub versioning number 
fourth number => Patch number

IIII. Release Note Edgecon
==========================

--- Release 5.00.00.001 ---
==============================
First commit: standard configuration for Modberry M40804W MAX with the following GPIO settings

-  GPIO00  = I2C1 (SDA1)
-  GPIO01  = I2C1 (SCL1)
-  GPIO02  = 
-  GPIO03  = 
-  GPIO04  = 
-  GPIO05  = IRQ LINE SLB9670 TPM
-  GPIO06  = IRQ LINE MCP23008 DIO
-  GPIO07  = SPI0 CE1 SLB9670
-  GPIO08  = SPI0 CE0 MCP2515
-  GPIO09  = SPI0 MISO
-  GPIO10  = SPI0 MOSI
-  GPIO11  = SPI0 SCLK
-  GPIO12  = IRQ LINE MCP2515 CAN bus
-  GPIO13  = USER BUTTON 
-  GPIO14  = TXD0 
-  GPIO15  = RXD0 
-  GPIO16  = IRQ Line SC16IS740 RS485/RS232
-  GPIO17  = RTS1 ttyAMA0 
-  GPIO18  = DI
-  GPIO19  = DI
-  GPIO20  = DI  
-  GPIO21  = DI  
-  GPIO22  = DO
-  GPIO23  = DO
-  GPIO24  = DO
-  GPIO25  = DO
-  GPIO26  = 
-  GPIO27  = LED2 (GREEN/BLUE)
-  GPIO32  = TXD1 ttyAMA0
-  GPIO33  = RXD1 ttyAMA0
-  GPIO44  = I2C0 (SDA0)
-  GPIO45  = I2C0 (SCL0)

For more information, see file modberry-m40804w-max.inf