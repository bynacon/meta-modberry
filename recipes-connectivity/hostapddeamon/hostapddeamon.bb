DESCRIPTON = "Accesspoint for ESP32"
LICENSE = "CLOSED"
PR = "r0"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://hostapd_deamon.service \
"

FILES_${PN} += " \
    ${D}${systemd_unitdir}/system/hostapd_deamon.service \
"

inherit systemd

SYSTEMD_SERVICE:${PN} = "hostapd_deamon.service"

do_install() {
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/hostapd_deamon.service ${D}${systemd_unitdir}/system
}

RDEPENDS_${PN} += "bash"

SYSTEMD_AUTO_ENABLE ??= "enable"