# WLAN Access Point

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-WAP` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-NETD`, `BASE-FW`, `BASE-PROV` |
| **Hardware reference** | [M40804W_MAX.md](../../../hardware/M40804W_MAX.md) – CM4 WLAN (BCM43455) |
| **Risk** | `medium` |

---

## 1. Purpose

This module provides two WLAN networks on the device. The IoT WLAN connects sensors and actuators (e.g. ESP32 devices, including their OTA updates) and is part of the IoT segment. The guest WLAN gives guest devices internet access without access to sensors and actuators. hostapd runs both networks with WPA3 security and client isolation. dnsmasq assigns addresses and forwards DNS queries in the IoT and guest segments.

---

## 2. Scope

### In scope

- Virtual AP interfaces `wlan0_iot` and `wlan0_guest` and their `.netdev` / `.network` files.
- hostapd configuration and security settings for both networks.
- dnsmasq as DHCP server and DNS forwarder for the IoT segment (`br-iot`) and the guest segment.
- dnsmasq include directory for other modules.
- hostapd control interface for event scripts.

### Out of scope

- hostapd event scripts and MAC bans → `BASE-IDS`
- Firewall rules, NAT for guests and isolation between segments → `BASE-FW`
- Segments, bridge `br-iot`, subnets and interface names → `BASE-NETD`
- OTA server for ESP32 devices → application layer
- DNS64 extension of dnsmasq → `THREAD-NAT64`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `hostapd` | `meta-openembedded` (meta-oe) | `hostapddeamon` (wrapper service) |
| `dnsmasq` | `meta-openembedded` (meta-networking) | networkd `DHCPServer=` |
| `linux-firmware-rpidistro-bcm43455` | `meta-raspberrypi` | — |
| `iw` | `poky` (openembedded-core) | — (diagnostics only) |

---

## 4. Requirements

### 4.1 Interfaces & Service

- `BASE-WAP-01` **MUST** The AP interfaces are virtual interfaces on the WLAN radio, created by systemd-networkd `.netdev` files.
- `BASE-WAP-02` **MUST** hostapd is started by its upstream systemd unit. No wrapper service starts or restarts hostapd.
- `BASE-WAP-03` **MUST** hostapd starts only after the AP interfaces and `br-iot` exist.
- `BASE-WAP-04` **MUST** The device provides two networks with separate SSIDs: IoT (`wlan0_iot`) and guest (`wlan0_guest`).
- `BASE-WAP-05` **MUST** `wlan0_iot` is a member of the bridge `br-iot`. `wlan0_guest` is not bridged.
- `BASE-WAP-06` **MUST** If the hardware cannot run both networks at the same time, the IoT network has priority (see section 8).

### 4.2 Security

- `BASE-WAP-10` **MUST** Both networks use WPA3-Personal (SAE) only. WPA2 is not offered.
- `BASE-WAP-11` **MUST** Protected Management Frames are required (`ieee80211w=2`).
- `BASE-WAP-12` **MUST** Client isolation is enabled on both networks (`ap_isolate=1`).
- `BASE-WAP-13` **MUST** WEP, WPA-TKIP and WPS are disabled.
- `BASE-WAP-14` **MUST** The passphrases are not stored in the image, the layer repository or the build configuration. They are provisioned per device (`BASE-PROV`).
- `BASE-WAP-15` **MUST** The country code is provisioned per device (`BASE-PROV`). Default is `CH`.
- `BASE-WAP-16` **MUST** The IoT and guest networks have different passphrases.

### 4.3 DHCP & DNS

- `BASE-WAP-20` **MUST** dnsmasq is the only DHCP server in the IoT and guest segments.
- `BASE-WAP-21` **MUST** dnsmasq serves DHCP and DNS only on `br-iot` and `wlan0_guest` and does not listen on any other interface.
- `BASE-WAP-22` **MUST** dnsmasq forwards DNS queries of IoT and guest clients to the resolver of the device (`systemd-resolved`, `BASE-NETD-25`).
- `BASE-WAP-23` **MUST** dnsmasq includes `/etc/dnsmasq.d/*.conf`, so that other modules extend it without changing the main configuration.

### 4.4 Control Interface

- `BASE-WAP-30` **MUST** The hostapd control interface is accessible only to root and to the group used by `BASE-IDS`.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/systemd/network/50-wlan0_iot.netdev` | `Kind=wlan`, `[WLAN] PhysicalDevice=0`, `Type=ap` | `BASE-WAP-01` |
| `/etc/systemd/network/50-wlan0_iot.network` | `Bridge=br-iot` | `BASE-WAP-05` |
| `/etc/systemd/network/50-wlan0_guest.netdev` | `Kind=wlan`, `[WLAN] PhysicalDevice=0`, `Type=ap` | `BASE-WAP-01` |
| `/etc/systemd/network/50-wlan0_guest.network` | static `Address=` from the address plan, no `DHCPServer=`, no `IPMasquerade=` | `BASE-WAP-20` |
| `/etc/hostapd.conf` | first BSS `interface=wlan0_iot`, `bridge=br-iot`, `ssid=<iot>`; second BSS `bss=wlan0_guest`, `ssid=<guest>` | `BASE-WAP-04`, `BASE-WAP-05` |
| `/etc/hostapd.conf` (per BSS) | `wpa=2`, `wpa_key_mgmt=SAE`, `rsn_pairwise=CCMP`, `ieee80211w=2`, `sae_require_mfp=1` | `BASE-WAP-10`, `BASE-WAP-11` |
| `/etc/hostapd.conf` (per BSS) | `ap_isolate=1`, `wps_state=0`, no `wep_key*`, no `TKIP` | `BASE-WAP-12`, `BASE-WAP-13` |
| `/etc/hostapd.conf` | `country_code=` from `/data/provisioning/wlan/country`, `ieee80211d=1` | `BASE-WAP-15` |
| `/etc/hostapd.conf` | `ctrl_interface=/run/hostapd`, `ctrl_interface_group=<group>`, mode `0600` | `BASE-WAP-30`, `BASE-WAP-14` |
| `/etc/dnsmasq.conf` | `interface=br-iot`, `interface=wlan0_guest`, `bind-interfaces`, one `dhcp-range=` per segment | `BASE-WAP-20`, `BASE-WAP-21` |
| `/etc/dnsmasq.conf` | `conf-dir=/etc/dnsmasq.d/,*.conf` | `BASE-WAP-23` |
| `/etc/dnsmasq.conf` | `no-resolv`, `server=127.0.0.53` | `BASE-WAP-22` |
| hostapd passphrases | `sae_password=` per BSS from `/data/provisioning/wlan/iot.psk` and `guest.psk` (config generated by an `ExecStartPre=` helper) | `BASE-WAP-14`, `BASE-WAP-16` |
| `hostapd.service.d/` | `After=` / `BindsTo=` the AP interface devices | `BASE-WAP-03` |

---

## 6. Interfaces to Other Modules

### Provides

- AP interfaces `wlan0_iot`, `wlan0_guest` – used by `BASE-NETD` (bridge member, address plan), `BASE-FW` and `BASE-IDS`.
- DHCP and DNS in the IoT and guest segments – used by sensors, actuators and guest devices.
- dnsmasq instance and include directory `/etc/dnsmasq.d/` – used by `THREAD-NAT64` (DNS64).
- hostapd control interface – used by `BASE-IDS` (event scripts via `hostapd_cli`).

### Consumes

- Bridge `br-iot`, subnets, interface names, `.netdev` convention – owned by `BASE-NETD`.
- Firewall openings for DHCP (67/udp) and DNS (53), guest NAT and isolation – owned by `BASE-FW`.
- Persistent data partition for provisioned passphrases – owned by `BASE-ROOTFS` / `BASE-LUKS`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-WAP-01` | `device` | `iw dev` | `wlan0_iot`, `wlan0_guest` type AP on `phy0` |
| `BASE-WAP-02` | `manifest` | `hostapddeamon` in image manifest | absent |
| `BASE-WAP-02` | `device` | `systemctl is-active hostapd` | `active` |
| `BASE-WAP-03` | `device` | Reboot 5×, `systemctl status hostapd` | started without error every time |
| `BASE-WAP-04` | `device` | Scan from a phone | both SSIDs visible |
| `BASE-WAP-05` | `device` | `bridge link` | `wlan0_iot` is a port of `br-iot`, `wlan0_guest` is not |
| `BASE-WAP-06` | `device` | `iw list` → "valid interface combinations" | documented result; IoT network runs in every supported combination |
| `BASE-WAP-10` | `device` | Connect a WPA3-capable client; `hostapd_cli -i <if> all_sta` | `AKMSuiteSelector=000fac-8` (SAE) |
| `BASE-WAP-10` | `device` | Connect a WPA2-only client | refused |
| `BASE-WAP-11` | `rootfs` | `grep ieee80211w <rootfs>/etc/hostapd.conf` | `2` for each BSS |
| `BASE-WAP-12` | `device` | Two clients in the same network ping each other | no answer |
| `BASE-WAP-13` | `rootfs` | `grep -E 'wep_key\|TKIP\|wps_state=[12]' <rootfs>/etc/hostapd.conf` | no match |
| `BASE-WAP-14` | `rootfs` | `grep -E 'wpa_passphrase=\|sae_password=' <rootfs>/etc/hostapd.conf`; `git grep` in the layer and scripts repos | no passphrase |
| `BASE-WAP-15` | `device` | `iw reg get` | country of operation |
| `BASE-WAP-16` | `rootfs` | Compare the passphrases of both BSS | different |
| `BASE-WAP-20` | `rootfs` | `grep -E 'DHCPServer\|IPMasquerade' <rootfs>/etc/systemd/network/*` | no match |
| `BASE-WAP-21` | `device` | `ss -lunp \| grep dnsmasq` | bound only to `br-iot` and `wlan0_guest` addresses |
| `BASE-WAP-22` | `device` | Guest client: `nslookup example.com <device>` | resolved |
| `BASE-WAP-23` | `rootfs` | `grep conf-dir <rootfs>/etc/dnsmasq.conf` | `/etc/dnsmasq.d/` |
| `BASE-WAP-30` | `device` | `stat -c '%U:%G %a' /run/hostapd/*` | `root:<group>`, not world-accessible |

---

## 8. Constraints & Risks

- **Interim credential handling (until `BASE-PROV` is implemented):** the passphrase is no longer in the repository. It comes from `conf/secrets.conf` of the build directory (copied by `scripts/Yocto/Build_kirkstone.sh` from the non-versioned `secrets_kirkstone.conf`). It is still written into the image (`/etc/hostapd.conf`, mode `0600`), so `BASE-WAP-14` is only partly met until per-device provisioning exists. The build fails if `AP_PASSPHRASE` is missing or shorter than 8 characters.
- **The old passphrase is in the Git history** of `meta-modberry` (GitHub). It must be changed on all devices.
- **Two AP networks plus a WLAN client on one radio:** the BCM43455 (`brcmfmac`) usually supports one AP plus one client interface at the same time. Two AP interfaces plus a client are probably not supported. This must be checked with `iw list` on the device. Options if it is not supported: guest WLAN only while the WLAN client is not used, or a second WLAN radio (USB). `BASE-WAP-06` gives the IoT network priority.
- All AP interfaces must use the channel of the WLAN client while it is connected.
- **WPA3-only depends on the radio firmware:** SAE in AP mode with `brcmfmac` (BCM43455) must be tested on the device first. If the firmware does not support it, `BASE-WAP-10` cannot be met with the on-board radio and needs a new decision (transition mode or a second radio).
- **WPA3-only excludes older ESP32 firmware:** all ESP32 devices need ESP-IDF ≥ 4.3 with WPA3 SAE enabled.
- Today, networkd (`DHCPServer=yes`, `IPMasquerade=both`) and dnsmasq both run on the AP. With this module, DHCP is done only by dnsmasq and NAT only by `BASE-FW`.
- `hostapddeamon` starts hostapd via `systemctl start` from a oneshot unit. It is not needed and is removed.
- Today's config uses `country_code=DE`, while the WLAN client config uses `country=CH`.
- The passphrase is substituted with `sed` using `#` as delimiter. Passphrases that contain `#`, `&` or `\` break the substitution.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Security mode. | `BASE-WAP-10`, `BASE-WAP-11` | **Decided:** WPA3-only (SAE) on both networks. |
| 2 | Provisioning of the passphrases. Are the SSIDs per device? | `BASE-WAP-14` | **Partly decided:** factory provisioning (`BASE-PROV`). SSID scheme still open. |
| 3 | Country of operation. | `BASE-WAP-15` | **Decided:** provisioned per device, default `CH`. |
| 4 | Does dnsmasq also resolve local names (e.g. the device itself, the OTA server) for IoT clients? | `BASE-WAP-22` | |
| 5 | Does LAN1 also get DHCP from dnsmasq (it is part of `br-iot`), or do wired sensors/actuators use static addresses? | `BASE-WAP-20`, `BASE-WAP-21` | |
| 6 | Two networks (IoT and guest). | `BASE-WAP-04` | **Decided:** IoT and guest WLAN, if the hardware supports it. |
| 7 | Interim credential handling. | `BASE-WAP-14` | **Decided:** passphrase from non-versioned `secrets_kirkstone.conf`; per-device provisioning follows. |
