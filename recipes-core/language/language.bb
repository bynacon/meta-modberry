DESCRIPTION = "Add es language support"
FILESEXTRAPATHS:prepend := "${THISDIR}:"
LICENSE = "CLOSED"
SRC_URI = " \
    file://locale.conf \
    file://vconsole.conf \
    file://locale.sh"

S = "${WORKDIR}"

do_install(){
    install -d ${D}${sysconfdir}/profile.d/
    install -m 0644 ${S}/locale.conf ${D}${sysconfdir}
    install -m 0644 ${S}/vconsole.conf ${D}${sysconfdir}
    install -m 0755 ${S}/locale.sh ${D}${sysconfdir}/profile.d/
}

FILES_${PN} ="${sysconfdir}/*"