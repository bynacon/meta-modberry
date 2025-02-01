DESCRIPTON = "Accesspoint for ESP32"
LICENSE = "CLOSED"
PR = "r0"

inherit systemd

SYSTEMD_AUTO_ENABLE:${PN} = "enable"
SYSTEMD_SERVICE:${PN} = "hostapd.service"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://hostapd.conf \
    file://hostapd \
"

FILES_${PN} += " \
    ${sysconfdir}/hostapd.conf \
    ${sysconfdir}/default/hostapd \
"

do_install:append() {

    install -d ${D}${sysconfdir}/default ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/hostapd.conf ${D}${sysconfdir}/
    install -m 0644 ${WORKDIR}/hostapd ${D}${sysconfdir}/default
}

RDEPENDS_${PN} += "bash"
