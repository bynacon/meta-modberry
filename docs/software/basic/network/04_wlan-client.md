# WLAN Client (iwd)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-WCLI` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-NETD` |
| **Hardware reference** | [M40804W_MAX.md](../../../hardware/M40804W_MAX.md) – CM4 WLAN (BCM43455) |
| **Risk** | `low` |

---

## 1. Purpose

This module connects the device as a client to an existing WLAN, which serves as fallback uplink when LAN0 is not available. iwd handles scanning, authentication and roaming with native WPA3 support. The IP configuration of the client interface is done by systemd-networkd.

---

## 2. Scope

### In scope

- iwd as WLAN client daemon.
- Restriction of iwd to the client interface.
- Allowed security modes.
- Storage of WLAN credentials.

### Out of scope

- IP configuration and uplink role of `wlan0_sta` → `BASE-NETD`
- WLAN access point → `BASE-WAP`
- Provisioning UI for WLAN credentials → application layer

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `iwd` | `meta-openembedded` (meta-oe) | `wpa-supplicant` |
| Kernel crypto options for iwd | `linux-raspberrypi` config fragment | — |

---

## 4. Requirements

### 4.1 Daemon

- `BASE-WCLI-01` **MUST** iwd is the only WLAN client daemon. `wpa-supplicant` is not part of the image.
- `BASE-WCLI-02` **MUST** iwd manages only the client interface `wlan0_sta`. It does not touch the AP interfaces (`wlan0_iot`, `wlan0_guest`).
- `BASE-WCLI-03` **MUST** iwd does not configure IP addresses (`EnableNetworkConfiguration=false`). IP configuration is done by `BASE-NETD`.

### 4.2 Security

- `BASE-WCLI-10` **MUST** iwd supports WPA3-Personal (SAE) and WPA2-Personal.
- `BASE-WCLI-11` **MUST** iwd does not connect to open or WEP networks.
- `BASE-WCLI-12` **SHOULD** iwd prefers WPA3 when the network offers WPA2/WPA3 transition mode.

### 4.3 Credentials

- `BASE-WCLI-20` **MUST** WLAN credentials are not stored in the layer repository or in the versioned build configuration (`local.conf`).
- `BASE-WCLI-21` **MUST** Credentials are stored by iwd under `/var/lib/iwd/` with mode `0600`, owned by root.
- `BASE-WCLI-22` **MUST** `/var/lib/iwd/` is persistent across reboots and located on the encrypted data partition.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/iwd/main.conf` | `[General] EnableNetworkConfiguration=false` | `BASE-WCLI-03` |
| `/etc/iwd/main.conf` | `[Settings] AlwaysRandomizeAddress=false` (stable MAC for DHCP) | `BASE-NETD-23` |
| `iwd.service.d/10-interface.conf` | `ExecStart=` with `--interfaces=wlan0_sta` | `BASE-WCLI-02` |
| Kernel config fragment | `CONFIG_CRYPTO_USER_API_SKCIPHER`, `CONFIG_CRYPTO_USER_API_HASH`, `CONFIG_KEY_DH_OPERATIONS`, `CONFIG_CRYPTO_ECB`, `CONFIG_CRYPTO_CMAC`, `CONFIG_PKCS8_PRIVATE_KEY_PARSER` … | `BASE-WCLI-10` |
| `/var/lib/iwd/` | mode `0700`, files `0600` | `BASE-WCLI-21` |

---

## 6. Interfaces to Other Modules

### Provides

- Connected client interface `wlan0_sta` – used by `BASE-NETD` (DHCP, uplink).

### Consumes

- Interface name `wlan0_sta` and IP configuration – owned by `BASE-NETD`.
- Persistent, encrypted storage for `/var/lib/iwd/` – owned by `BASE-ROOTFS` / `BASE-LUKS`.
- Service integration rules – owned by `BASE-INIT`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-WCLI-01` | `manifest` | `wpa-supplicant` in image manifest | absent |
| `BASE-WCLI-01` | `device` | `systemctl is-active iwd` | `active` |
| `BASE-WCLI-02` | `device` | `iwctl device list` | only `wlan0_sta` |
| `BASE-WCLI-03` | `device` | `networkctl status wlan0_sta` | managed by networkd |
| `BASE-WCLI-10` | `device` | Connect to a WPA3-only test network | connected |
| `BASE-WCLI-11` | `device` | `iwctl station wlan0_sta connect <open network>` | refused |
| `BASE-WCLI-12` | `device` | Connect to a transition-mode network, `iwctl station wlan0_sta show` | security `WPA3-Personal` |
| `BASE-WCLI-20` | `rootfs` | `grep -r WIFI_ <layer> <local.conf>`; `ls <rootfs>/var/lib/iwd/` | no credentials |
| `BASE-WCLI-21` | `device` | `stat -c '%U %a' /var/lib/iwd/*.psk` | `root 600` |
| `BASE-WCLI-22` | `device` | `findmnt -T /var/lib/iwd` | encrypted data partition |

---

## 8. Constraints & Risks

- **Interim credential handling:** `WIFI_SSID` and `WIFI_PASSKEY` are no longer in `scripts/Yocto/local_kirkstone.conf`. They come from the non-versioned `secrets_kirkstone.conf` (copied to `conf/secrets.conf` by `Build_kirkstone.sh`). `wpa-supplicant_%.bbappend` still writes them into the image, now with mode `0600`. `BASE-WCLI-20` is only partly met until provisioning at runtime exists (open point 1).
- **The old credentials are in the Git history** of the `scripts` repository (GitHub). They must be changed.
- iwd needs several kernel crypto options that are not all enabled in the default Raspberry Pi kernel config. Without them, iwd fails at runtime, not at build time.
- iwd manages every WLAN interface by default. Without `--interfaces`, it would also take over the AP interface.
- iwd has no option to refuse open networks globally. `BASE-WCLI-11` is met by provisioning only protected networks; the check verifies the behavior.
- Until `BASE-LUKS` exists, `BASE-WCLI-22` can only be met on an unencrypted persistent partition.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | How are WLAN credentials provisioned? | `BASE-WCLI-20`, `BASE-WCLI-21` | **Decided:** optional item of factory provisioning (`BASE-PROV`). |
| 2 | Is WPA2/WPA3-Enterprise (802.1X) needed in company networks? | `BASE-WCLI-10` | |
| 3 | Is the WLAN client needed in every installation, or only when no LAN uplink exists? | Scope | **Decided:** fallback uplink when LAN0 is not available (`BASE-NETD-30`). |
