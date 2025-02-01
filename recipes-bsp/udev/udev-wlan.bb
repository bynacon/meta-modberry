DESCRIPTON = "change name of wlan0 to wlan0_sta => station mode"
LICENSE = "CLOSED"
PR = "r0"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
   file://70-net-sta-interface.rules \
"

FILES_${PN} += " \
   ${sysconfdir}/udev/rules.d/70-net-sta-interface.rules \
"

do_install() {
   install -d ${D}${sysconfdir}/udev/rules.d
   install -D -m 644 ${WORKDIR}/70-net-sta-interface.rules ${D}${sysconfdir}/udev/rules.d/70-net-sta-interface.rules
}

RDEPENDS:${PN} += "udev"