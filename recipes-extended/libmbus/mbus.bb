SUMMARY = "M-bus Library from Raditex Control"
DESCRIPTION = "libmbus is an open source library for the M-bus (Meter-Bus) protocol"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = " \
    git://github.com/rscada/libmbus.git;protocol=http \
    file://CMakeLists.txt \
    file://config.h \
"

SRC_URI[sha256sum] = "320fcda5402f2fc1593c498e7d457f8c72a74b3ff6a87e2b616da85c009a3c53"


SRCREV = "2dc3daaf7080cb77640e6caee3154585b8196a37"

PR = "r1"

inherit pkgconfig cmake

S = "${WORKDIR}/git"

do_configure:prepend() {
    install ${WORKDIR}/CMakeLists.txt ${S}
    install ${WORKDIR}/config.h ${S}
}