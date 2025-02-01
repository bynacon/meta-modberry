DESCRIPTON = "Accesspoint for ESP32"
LICENSE = "CLOSED"
PR = "r0"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://dnsmasq.conf \
"

FILES_${PN} += " \
    ${sysconfdir}/dnsmasq.conf \
"
do_install:append() {
    install -m 0644 ${WORKDIR}/dnsmasq.conf ${D}${sysconfdir}/
}