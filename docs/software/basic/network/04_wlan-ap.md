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
- WLAN client uplink (USB WLAN adapter) → `BASE-WCLI`

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
- `BASE-WAP-07` **MUST** Further WLAN roles (client uplink, mesh) use a separate USB WLAN adapter (`BASE-USB-05`), never the on-board radio.

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
- `BASE-WAP-41` **MUST** The passkey of the service AP is derived from a per-device service secret (`BASE-PROV`) and the current time window, like TOTP (RFC 6238 with HMAC-SHA-256, 30-minute windows, 16 characters Base32). The Bynacon service tool computes the same passkey from the secret in the device registry.
- `BASE-WAP-42` **MUST** The service AP accepts the passkeys of the current and the previous time window, and no other passkey. A passkey is therefore valid for at most 60 minutes, and never longer than the service mode lasts.
- `BASE-WAP-43` **MUST** The service AP uses WPA3-Personal (SAE) with PMF, admits at most two clients and is not bridged. It forms the service segment `172.30.30.0/29` (`BASE-NETD`).
- `BASE-WAP-44` **MUST** When the service mode ends, the service AP is stopped and all its clients are disconnected.
- `BASE-WAP-45` **MUST** If the system time is not synchronized and the RTC time is invalid, the service AP does not start; the reason is logged.
- `BASE-WAP-46` **MUST** Every start and stop of the service AP and every client association is logged to the journal.

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
| `/run/hostapd-svc.conf` | `ssid=bynacon-service-<serial>`, `wpa_key_mgmt=SAE`, `ieee80211w=2`, `max_num_sta=2`, two `sae_password=` lines (current and previous window) | `BASE-WAP-41` … `BASE-WAP-43` |
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
| `BASE-WAP-07` | `rootfs` | `.netdev` / iwd configuration of the image | no client or mesh interface on `phy0` |
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
| `BASE-WAP-43` | `device` | Connect three clients; `bridge link` | third client refused; `wlan0_svc` not bridged |
| `BASE-WAP-44` | `device` | Stay connected until the service mode ends | client disconnected, `wlan0_svc` removed |
| `BASE-WAP-45` | `device` | Clear the RTC, no uplink (lab), start service mode | service AP not started, reason in the journal |
| `BASE-WAP-46` | `device` | `journalctl -u modberry-service-ap` after a session | start, association, stop logged |

---

## 8. Constraints & Risks

- `BASE-WAP-02`: `hostapddeamon` starts hostapd via `systemctl start` from a oneshot unit; it is removed.
- `BASE-WAP-04`, `BASE-WAP-14`: all installations use the SSID `bynacon-iot` with different passphrases. A client near two installations may try the wrong one; with SAE it fails to authenticate and retries.
- `BASE-WAP-06`: `brcmfmac` is a FullMAC driver; the firmware supports at most two virtual interfaces, and SAE is offloaded to the firmware. With parallel virtual interfaces, firmware crashes and missing authentication answers (`nl80211: MLME command failed`) are known. One interface is the most stable configuration.
- `BASE-WAP-07`: `brcmfmac` does not support mesh point mode (802.11s). A mesh needs a USB WLAN adapter with a `mac80211` driver that supports mesh point and software SAE (e.g. `mt76`).
- `BASE-WAP-10`: SAE in AP mode with `brcmfmac` must be tested on the device (open point 5). All ESP32 devices need ESP-IDF ≥ 4.3 with WPA3 SAE enabled.
- `BASE-WAP-14`: **interim** – until `BASE-PROV` is implemented, the passphrase comes from the non-versioned `secrets_kirkstone.conf` and is written into the image (`/etc/hostapd.conf`, mode `0600`). The old passphrase is in the Git history and must be changed.
- `BASE-WAP-15`: today's config uses `country_code=DE`, the WLAN client config `country=CH`.
- `BASE-WAP-40`: during service mode, the on-board radio runs two virtual interfaces with SAE. This is the combination for which firmware crashes are known; it is limited to the 30 minutes of the service mode and must be tested (open point 5). If the IoT AP fails, it is restarted by systemd (`BASE-INIT-23`).
- `BASE-WAP-41`, `BASE-WAP-45`: the passkey depends on correct time on both sides. Without a battery-backed RTC (`BASE-TIME` open point 4) and without uplink, the device cannot compute the passkey after a power loss.
- `BASE-WAP-41`: the service secret must never leave the device registry except into the Bynacon service tool; a leaked secret allows passkeys for that device only.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Security mode. | `BASE-WAP-10`, `BASE-WAP-11` | **Decided:** WPA3-only (SAE). |
| 2 | SSID scheme (per device or fixed)? | `BASE-WAP-04` | **Decided:** the same SSID on all devices; passphrase per installation. |
| 3 | Country of operation. | `BASE-WAP-15` | **Decided:** provisioned per device, default `CH`. |
| 4 | WLAN networks of the device. | `BASE-WAP-04` | **Decided:** IoT WLAN only; no guest WLAN. |
| 5 | Does `brcmfmac` run the IoT AP with SAE stably, and IoT AP + service AP with SAE during service mode? | `BASE-WAP-10`, `BASE-WAP-40` | **Deferred:** test on the device → verification task. |
| 6 | SSID name. | `BASE-WAP-04` | **Decided:** `bynacon-iot`. |
| 7 | Use of the on-board radio. | `BASE-WAP-06`, `BASE-WAP-07` | **Decided:** only the IoT AP; client uplink and mesh only with a USB WLAN adapter. |
| 9 | Local service access over WLAN. | `BASE-WAP-40` … `BASE-WAP-46` | **Decided:** service AP on the on-board radio in service mode, TOTP-like passkey; replaces the USB service port. |
| 8 | WLAN mesh between devices (802.11s or batman-adv over a USB adapter): scope, adapter model, backhaul? | Scope | **Deferred:** specified when the USB WLAN adapter is chosen. |
