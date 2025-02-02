FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://10-eth0-config.network \
    file://10-wlan0ap-config.network \
    file://10-wlan0sta-config.network \
    file://timesyncd.conf \
"
FILES:${PN} += " \
    ${sysconfdir}/systemd/network/10-eth0-config.network \
    ${sysconfdir}/systemd/network/10-wlan0ap-config.network \
    ${sysconfdir}/systemd/network/10-wlan0sta-config.network \
    ${sysconfdir}/systemd/timesyncd.conf \  
"

do_install:append () {
    install -d ${D}${sysconfdir}/systemd/network
    install -m 0644 ${WORKDIR}/10-eth0-config.network ${D}${sysconfdir}/systemd/network
    install -m 0644 ${WORKDIR}/10-wlan0ap-config.network ${D}${sysconfdir}/systemd/network
    install -m 0644 ${WORKDIR}/10-wlan0sta-config.network ${D}${sysconfdir}/systemd/network
    install -m 0644 ${WORKDIR}/timesyncd.conf ${D}${sysconfdir}/systemd
}