DESCRIPTON = ""
LICENSE = "CLOSED"
PR = "r0"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://interfaces \
"

FILES_${PN} += " \
    ${sysconfdir}/network/interfaces \
"

do_install:append() {
    install -m 0644 ${WORKDIR}/interfaces ${D}${sysconfdir}/network/
}