FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " \
  file://wpa_supplicant-wlan0_sta.conf \
"

FILES:${PN}:append = " \
  ${sysconfdir}/wpa_supplicant/wpa_supplicant-wlan0_sta.conf \
"

WIFI_SSID ?= ""
WIFI_PASSKEY ?= ""

do_install:append() {

  install -d ${D}${sysconfdir}/wpa_supplicant

  sed -i -e 's#[@]WIFI_PASSKEY[@]#${WIFI_PASSKEY}#' ${WORKDIR}/wpa_supplicant-wlan0_sta.conf
	sed -i -e 's#[@]WIFI_SSID[@]#${WIFI_SSID}#' ${WORKDIR}/wpa_supplicant-wlan0_sta.conf

	install -m 0755 ${WORKDIR}/wpa_supplicant-wlan0_sta.conf ${D}${sysconfdir}/wpa_supplicant/
}