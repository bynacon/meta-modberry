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

# Interim: passphrase from conf/secrets.conf of the build directory (not versioned).
# Target: per-device provisioning (BASE-WAP-14).
AP_PASSPHRASE ?= ""

do_install:append() {

    # BitBake expands ${AP_PASSPHRASE}; the length check runs in the shell.
    ap_passphrase="${AP_PASSPHRASE}"
    if [ ${#ap_passphrase} -lt 8 ]; then
        bbfatal "AP_PASSPHRASE is not set or shorter than 8 characters (see scripts/Yocto/secrets_kirkstone.conf.example)"
    fi

    install -d ${D}${sysconfdir}/default ${D}${systemd_unitdir}/system/
    install -m 0600 ${WORKDIR}/hostapd.conf ${D}${sysconfdir}/
    sed -i -e 's#[@]AP_PASSPHRASE[@]#${AP_PASSPHRASE}#' ${D}${sysconfdir}/hostapd.conf
    install -m 0644 ${WORKDIR}/hostapd ${D}${sysconfdir}/default
}

RDEPENDS_${PN} += "bash"
