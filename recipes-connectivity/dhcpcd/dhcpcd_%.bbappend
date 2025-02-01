DESCRIPTON = "Accesspoint for ESP32"
LICENSE = "CLOSED"
PR = "r0"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://dhcpcd.conf \
"

FILES_${PN} += " \
    ${sysconfdir}/dhcpcd.conf \
"
do_install:append() {
    install -m 0644 ${WORKDIR}/dhcpcd.conf ${D}${sysconfdir}/
}