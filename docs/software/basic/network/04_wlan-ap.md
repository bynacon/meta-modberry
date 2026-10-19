# WLAN Access Point (hostapd)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-WAP` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-HWT`, `BASE-NETD`, `BASE-FW`, `BASE-PROV` |
| **Hardware reference** | [M40804W_MAX.md](../../../hardware/M40804W_MAX.md) – CM4 WLAN (BCM43455) |
| **Risk** | `medium` |

---

## 1. Purpose

This module provides the IoT WLAN with hostapd. It connects sensors and actuators (e.g. ESP32 devices) and is part of the IoT segment. The network uses WPA3 and client isolation, and has the same SSID on all devices. In service mode, a second access point gives a service technician local access with a time-limited passkey. Otherwise the on-board radio runs only the IoT access point. Addresses and DNS are provided by `BASE-DNS`.

---

## 2. Scope

### In scope

- Virtual AP interfaces `wlan0_iot` and `wlan0_svc` (service AP) and their `.netdev` / `.network` files.
- Time-limited passkey of the service AP.
- hostapd configuration and security settings.
- Use of the on-board radio.
- hostapd control interface for event scripts.

### Out of scope

- DHCP and DNS for the AP clients → `BASE-DNS`
- hostapd event scripts and MAC bans → `BASE-IDS`
- Firewall rules and isolation between segments → `BASE-FWP`
- Segments, bridge `br-iot`, subnets → `BASE-NETD`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `hostapd` | `meta-openembedded` (meta-oe) | `hostapddeamon` (wrapper service) |
| `linux-firmware-rpidistro-bcm43455` | `meta-raspberrypi` | — |
| `iw` | `poky` (openembedded-core) | — (diagnostics only) |

---

## 4. Requirements

### 4.1 Interface & Service

- `BASE-WAP-01` **MUST** The AP interface `wlan0_iot` is a virtual interface on the on-board radio, created by a systemd-networkd `.netdev` file.
- `BASE-WAP-02` **MUST** hostapd is started by its upstream systemd unit. No wrapper service starts or restarts hostapd.
- `BASE-WAP-03` **MUST** hostapd starts only after `wlan0_iot` and `br-iot` exist.
- `BASE-WAP-04` **MUST** The device provides one WLAN network, the IoT WLAN, with the SSID `bynacon-iot`. The SSID is the same on all devices, so that clients roam between devices.
- `BASE-WAP-05` **MUST** `wlan0_iot` is a member of the bridge `br-iot`.
- `BASE-WAP-06` **MUST** The on-board radio (BCM43455) runs exactly one interface, the IoT AP. Only during service mode it runs a second interface, the service AP (`BASE-WAP-40`). It never runs a client or mesh interface.
- `BASE-WAP-07` **MUST** The device has no WLAN client and no WLAN mesh. The on-board radio never runs a client or mesh interface.
- `BASE-WAP-08` **MUST** The image uses a fixed, tested version of the BCM43455 firmware (`linux-firmware-rpidistro-bcm43455`); a firmware update requires the verification of open point 5 again.

### 4.2 Security

- `BASE-WAP-10` **MUST** The network uses WPA3-Personal (SAE) only. WPA2 is not offered.
- `BASE-WAP-11` **MUST** Protected Management Frames are required (`ieee80211w=2`).
- `BASE-WAP-12` **MUST** Client isolation is enabled (`ap_isolate=1`).
- `BASE-WAP-13` **MUST** WEP, WPA-TKIP and WPS are disabled.
- `BASE-WAP-14` **MUST** The passphrase is not stored in the image, the layer repository or the build configuration. It is provisioned per installation (site): all devices of one installation share it, different installations have different passphrases (`BASE-PROV`).
- `BASE-WAP-15` **MUST** The country code is provisioned per device (`BASE-PROV`). Default is `CH`.

### 4.3 Control Interface

- `BASE-WAP-30` **MUST** The hostapd control interface is accessible only to root and to the group used by `BASE-IDS`.

### 4.4 Service AP

- `BASE-WAP-40` **MUST** While the service mode is active (`BASE-HWT-33`), the on-board radio runs a second AP `wlan0_svc` with the SSID `bynacon-service-<last 6 characters of the serial number>`. Outside service mode, `wlan0_svc` does not exist.
- `BASE-WAP-41` **MUST** The passkey of the service AP is derived from a per-device service secret (`BASE-PROV`) and the current time window, like TOTP (RFC 6238 with HMAC-SHA-256, 30-minute windows, 16 characters Base32 = 80 bits). The Bynacon service tool computes the same passkey from the secret in the device registry.
- `BASE-WAP-42` **MUST** The service AP accepts the passkeys of the current and the previous time window, and no other passkey. A passkey is therefore valid for at most 60 minutes, and never longer than the service mode lasts.
- `BASE-WAP-43` **MUST** The service AP uses WPA2-Personal with SHA-256 key management (`WPA-PSK-SHA256`), CCMP and required PMF (`ieee80211w=2`); no SAE runs on the second interface. It admits exactly one client, is not bridged, and forms the service segment `172.30.30.0/29` (`BASE-NETD`).
- `BASE-WAP-44` **MUST** When the service mode ends, the service AP is stopped and all its clients are disconnected.
- `BASE-WAP-45` **MUST** If the system time is not synchronized and the RTC time is invalid, the service AP does not start; the reason is logged.
- `BASE-WAP-46` **MUST** Every start and stop of the service AP and every client association is logged to the journal.
- `BASE-WAP-47` **MUST** The IoT AP has priority. While the service AP runs, a watchdog checks the IoT AP (hostapd state, `nl80211` errors such as `MLME command failed`, sudden loss of most associated stations). At the first sign of a problem it stops the service AP, so that the radio returns to one interface, and logs the reason.
- `BASE-WAP-48` **MUST** Both APs use the same fixed channel with 20 MHz bandwidth: 1, 6 or 11, provisioned per installation (`BASE-PROV`), default 6. Automatic channel selection and DFS channels are not used, and Wi-Fi power save is off on the on-board radio.
- `BASE-WAP-49` **MUST** The service AP runs as a separate hostapd instance and starts only when the IoT AP reports state `ENABLED`. A failure of the service AP instance does not affect the IoT AP instance.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/systemd/network/50-wlan0_iot.netdev` | `Kind=wlan`, `[WLAN] PhysicalDevice=0`, `Type=ap` | `BASE-WAP-01`, `BASE-WAP-06` |
| `/etc/systemd/network/50-wlan0_iot.network` | `Bridge=br-iot` | `BASE-WAP-05` |
| `/etc/hostapd.conf` | `interface=wlan0_iot`, `bridge=br-iot`, `ssid=bynacon-iot` | `BASE-WAP-04`, `BASE-WAP-05` |
| `/etc/hostapd.conf` | `wpa=2`, `wpa_key_mgmt=SAE`, `rsn_pairwise=CCMP`, `ieee80211w=2`, `sae_require_mfp=1` | `BASE-WAP-10`, `BASE-WAP-11` |
| `/etc/hostapd.conf` | `ap_isolate=1`, `wps_state=0`, no `wep_key*`, no `TKIP` | `BASE-WAP-12`, `BASE-WAP-13` |
| `/etc/hostapd.conf` | `country_code=` from `/data/provisioning/wlan/country`, `ieee80211d=1` | `BASE-WAP-15` |
| `/etc/hostapd.conf` | `ctrl_interface=/run/hostapd`, `ctrl_interface_group=<group>`, mode `0600` | `BASE-WAP-14`, `BASE-WAP-30` |
| hostapd passphrase | `sae_password=` from `/data/provisioning/wlan/iot.psk` (config generated by an `ExecStartPre=` helper) | `BASE-WAP-14` |
| `hostapd.service.d/` | `After=` / `BindsTo=` the `wlan0_iot` device | `BASE-WAP-03` |
| `/etc/systemd/network/51-wlan0_svc.netdev` / `.network` | `Kind=wlan`, `PhysicalDevice=0`, `Type=ap`; `Address=172.30.30.1/29`; not bridged | `BASE-WAP-40`, `BASE-WAP-43` |
| `modberry-service-ap.service` | `WantedBy=` / `PartOf=modberry-service-mode.target`; generates `/run/hostapd-svc.conf` and starts a second hostapd instance on `wlan0_svc` | `BASE-WAP-40`, `BASE-WAP-44` |
| `/run/hostapd-svc.conf` | `ssid=bynacon-service-<serial>`, `wpa=2`, `wpa_key_mgmt=WPA-PSK-SHA256`, `rsn_pairwise=CCMP`, `ieee80211w=2`, `max_num_sta=1`, `wpa_psk_file=/run/hostapd-svc.psk` | `BASE-WAP-41`, `BASE-WAP-43` |
| `/run/hostapd-svc.psk` | two lines `00:00:00:00:00:00 <passkey>` (current and previous window), mode `0600`, rewritten at each window change | `BASE-WAP-42` |
| `/etc/hostapd.conf`, `/run/hostapd-svc.conf` | same `channel=` from `/data/provisioning/wlan/channel` (1, 6 or 11; default 6), `ht_capab` 20 MHz, no `acs`; `iw dev wlan0_iot set power_save off` | `BASE-WAP-48` |
| `modberry-service-ap-watchdog.service` | `PartOf=modberry-service-mode.target`; watches `hostapd_cli -i wlan0_iot status` and the kernel log; stops `modberry-service-ap.service` on errors | `BASE-WAP-47` |
| Build: machine/distro conf | `PREFERRED_VERSION_linux-firmware-rpidistro` fixed to the tested version | `BASE-WAP-08` |
| `/data/provisioning/wlan/service.secret` | per-device secret, mode `0600` | `BASE-WAP-41` |

---

## 6. Interfaces to Other Modules

### Provides

- AP interface `wlan0_iot` – used by `BASE-NETD` (bridge member), `BASE-DNS`, `BASE-FWP` and `BASE-IDS`.
- Service AP `wlan0_svc` and the service segment – used by `BASE-NETD` (address plan), `BASE-DNS` (DHCP), `BASE-FWP` (column SVC), `BASE-WEB` (`allow`), `BASE-IDS`.
- hostapd control interface – used by `BASE-IDS` (event scripts via `hostapd_cli`).

### Consumes

- Bridge `br-iot`, subnet, `.netdev` convention – owned by `BASE-NETD`.
- Passphrase, country code and service secret – owned by `BASE-PROV`.
- Service mode – owned by `BASE-HWT` (`BASE-HWT-33`).
- Synchronized time – owned by `BASE-TIME`.
- Firewall framework – owned by `BASE-FW`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-WAP-01` | `device` | `iw dev` | `wlan0_iot` type AP on `phy0` |
| `BASE-WAP-02` | `manifest` | `hostapddeamon` in image manifest | absent |
| `BASE-WAP-02` | `device` | `systemctl is-active hostapd` | `active` |
| `BASE-WAP-03` | `device` | Reboot 5×, `systemctl status hostapd` | started without error every time |
| `BASE-WAP-04` | `device` | Scan from a phone near two devices | one SSID `bynacon-iot` |
| `BASE-WAP-05` | `device` | `bridge link` | `wlan0_iot` is a port of `br-iot` |
| `BASE-WAP-06` | `device` | `iw dev` | exactly one interface on `phy0` |
| `BASE-WAP-07` | `rootfs` | `.netdev` files and packages of the image | no client or mesh interface; no `iwd`, no `wpa-supplicant` |
| `BASE-WAP-08` | `build` | `bitbake -e <image> \| grep PREFERRED_VERSION_linux-firmware-rpidistro` | fixed version |
| `BASE-WAP-10` | `device` | Connect a WPA3 client; `hostapd_cli -i wlan0_iot all_sta`; connect a WPA2-only client | `AKMSuiteSelector=000fac-8`; WPA2 refused |
| `BASE-WAP-11` | `rootfs` | `grep ieee80211w <rootfs>/etc/hostapd.conf` | `2` |
| `BASE-WAP-12` | `device` | Two clients ping each other | no answer |
| `BASE-WAP-13` | `rootfs` | `grep -E 'wep_key\|TKIP\|wps_state=[12]' <rootfs>/etc/hostapd.conf` | no match |
| `BASE-WAP-14` | `rootfs` | `grep -E 'wpa_passphrase=\|sae_password=' <rootfs>/etc/hostapd.conf`; `git grep` in the layer and scripts repos | no passphrase |
| `BASE-WAP-15` | `device` | `iw reg get` | provisioned country (default `CH`) |
| `BASE-WAP-30` | `device` | `stat -c '%U:%G %a' /run/hostapd/*` | `root:<group>`, not world-accessible |
| `BASE-WAP-40` | `device` | Hold the user button for 5 s; scan; wait 30 minutes | `bynacon-service-<serial>` visible during service mode only |
| `BASE-WAP-41` | `device` | Compute the passkey with the service tool, connect | connected |
| `BASE-WAP-42` | `device` | Connect with the passkey of a window two windows old | refused |
| `BASE-WAP-43` | `device` | `hostapd_cli -i wlan0_svc get_config`; connect a second client; `bridge link` | `WPA-PSK-SHA256`, PMF required; second client refused; `wlan0_svc` not bridged |
| `BASE-WAP-44` | `device` | Stay connected until the service mode ends | client disconnected, `wlan0_svc` removed |
| `BASE-WAP-45` | `device` | Clear the RTC, no uplink (lab), start service mode | service AP not started, reason in the journal |
| `BASE-WAP-46` | `device` | `journalctl -u modberry-service-ap` after a session | start, association, stop logged |
| `BASE-WAP-47` | `device` | Service mode active; kill the IoT hostapd instance (lab) | service AP stopped within seconds, reason logged; IoT AP restarted |
| `BASE-WAP-48` | `device` | `iw dev`; `iw dev wlan0_iot get power_save` | both APs on the same fixed channel, 20 MHz; power save off |
| `BASE-WAP-49` | `device` | Kill the service hostapd instance during service mode | IoT AP keeps running, sensors stay connected |

---

## 8. Constraints & Risks

- `BASE-WAP-02`: `hostapddeamon` starts hostapd via `systemctl start` from a oneshot unit; it is removed.
- `BASE-WAP-04`, `BASE-WAP-14`: all installations use the SSID `bynacon-iot` with different passphrases. A client near two installations may try the wrong one; with SAE it fails to authenticate and retries.
- `BASE-WAP-06`: `brcmfmac` is a FullMAC driver; the firmware supports at most two virtual interfaces, and SAE is offloaded to the firmware. With parallel virtual interfaces, firmware crashes and missing authentication answers (`nl80211: MLME command failed`) are known. One interface is the most stable configuration.
- `BASE-WAP-10`: SAE in AP mode with `brcmfmac` must be tested on the device (open point 5). All ESP32 devices need ESP-IDF ≥ 4.3 with WPA3 SAE enabled.
- `BASE-WAP-14`: **interim** – until `BASE-PROV` is implemented, the passphrase comes from the non-versioned `secrets_kirkstone.conf` and is written into the image (`/etc/hostapd.conf`, mode `0600`). The old passphrase is in the Git history and must be changed.
- `BASE-WAP-15`: today's config uses `country_code=DE`; the default is `CH`.
- `BASE-WAP-40`, `BASE-WAP-43`: during service mode, the on-board radio runs two virtual interfaces. SAE (with firmware offload) runs only on the IoT AP; the service AP uses WPA2-PSK. This avoids the known SAE offload problems with parallel interfaces, but does not remove every risk of the second interface. `BASE-WAP-47` protects the IoT AP; adding the interface can interrupt beaconing briefly, so sensors may reconnect once.
- `BASE-WAP-41`, `BASE-WAP-45`: the passkey depends on correct time on both sides. Without a battery-backed RTC (`BASE-TIME` open point 4) and without uplink, the device cannot compute the passkey after a power loss.
- `BASE-WAP-41`: the service secret must never leave the device registry except into the Bynacon service tool; a leaked secret allows passkeys for that device only.
- `BASE-WAP-43`: WPA2-PSK allows an offline attack on a captured handshake. With an 80-bit random passkey that is valid for at most 60 minutes, this is not practical.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Security mode. | `BASE-WAP-10`, `BASE-WAP-11` | **Decided:** WPA3-only (SAE). |
| 2 | SSID scheme (per device or fixed)? | `BASE-WAP-04` | **Decided:** the same SSID on all devices; passphrase per installation. |
| 3 | Country of operation. | `BASE-WAP-15` | **Decided:** provisioned per device, default `CH`. |
| 4 | WLAN networks of the device. | `BASE-WAP-04` | **Decided:** IoT WLAN only; no guest WLAN. |
| 5 | Does `brcmfmac` run the IoT AP with SAE stably, and IoT AP (SAE) + service AP (WPA2-PSK) during service mode? | `BASE-WAP-10`, `BASE-WAP-40` | **Deferred:** test on the device → verification task. |
| 6 | SSID name. | `BASE-WAP-04` | **Decided:** `bynacon-iot`. |
| 7 | Use of the on-board radio. | `BASE-WAP-06`, `BASE-WAP-07` | **Decided:** only the IoT AP, and the service AP in service mode; no WLAN client, no mesh. |
| 8 | WLAN mesh between devices. | Scope | **Decided:** not planned. The same SSID on all devices serves roaming. |
| 9 | Local service access over WLAN. | `BASE-WAP-40` … `BASE-WAP-46` | **Decided:** service AP on the on-board radio in service mode, TOTP-like passkey; replaces the USB service port. |
| 10 | Security and radio of the service AP. | `BASE-WAP-07`, `BASE-WAP-43` | **Decided:** always on the on-board radio; WPA2-PSK (SHA-256) with PMF; stabilized by `BASE-WAP-47` … `BASE-WAP-49`. |
| 11 | WLAN channel. | `BASE-WAP-48` | **Decided:** fixed channel 1, 6 or 11, provisioned per installation, default 6. |
