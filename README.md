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

  URI: [fourth dependency](https://github.com/mendersoftware/meta-mender.git), but it isn’t necessary to build an image without OTA (Machine: modberry-m40804w-max_basic.conf).
  branch: kirkstone

  URI: [fifth dependency](git@github.com:bynacon/meta-edgecon.git), but it is private and not necessary to build a Raspberry Pi image for a Modberry without OTA (Machine: modberry-m40804w-max_basic.conf).
  branch: kirkstone

  URI: [sixth dependency](git://git.yoctoproject.org/meta-security.git)
  branch: kirkstone

  URI: [seventh dependency](git://git.yoctoproject.org/meta-virtualization)
  branch: kirkstone

  URI: [eight dependency](https://github.com/bynacon/meta-ota.git), but it is private and not necessary to build a Raspberry Pi image for a Modberry without OTA (Machine: modberry-m40804w-max_basic.conf).
  branch: kirkstone

Patches
=======

Please submit any patches against the meta-modberry layer to the Bynacon maintainer Ben Roethlisberger <ben.roethlisberger@bynacon.ch>

Table of Contents
=================

    I.    Adding the meta-modberry layer to your build
    II.   Misc
    III.  Release Note Numbering
    IV.   Release Notes Modberry


I. Adding the meta-modberry layer to your build
===============================================

Run 'bitbake-layers add-layer meta-modberry' and add all other dependencies as listed above.

II. Misc
========

--- replace with specific information about the meta-modberry layer ---

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

IV. Release Notes Modberry
==========================

--- Release 5.00.00.001 ---
==============================
First commit: standard configuration for Modberry M40804W MAX. Base GPIO assignments defined.
For detailed hardware specifications, pinouts, and implementations, please refer exclusively to the central hardware documentation: `docs/hardware/README.md`.