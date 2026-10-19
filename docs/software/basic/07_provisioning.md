# Factory Provisioning

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-PROV` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-TPM`, `BASE-FWP`, `BASE-SSH` |
| **Hardware reference** | [M40804W_MAX.md](../../hardware/M40804W_MAX.md) – section 3.1 (EEPROM AT24CS01) |
| **Risk** | `high` |

---

## 1. Purpose

This module defines how a device that runs the production image gets its per-device data in the factory: passphrases, keys, certificates and site settings. The image is the same for all devices and contains no per-device secrets. A factory script connects to the device over SSH with the Bynacon service key, generates or transfers the per-device data, and stores it in one place on the device. All other modules read their per-device data from there.

---

## 2. Scope

### In scope

- Access path of the factory script to a fresh device.
- List of provisioned items and where they come from.
- Storage location, permissions and marker of the provisioned data.
- Behavior of the device before it is provisioned.
- Re-provisioning.

### Out of scope

- The factory script itself, the Bynacon CA and the registry of devices → factory tooling (outside this layer)
- SSH server and service key → `BASE-SSH`; WireGuard configuration → `BASE-VPN`; nginx → `BASE-WEB`
- Factory subnet in `service_nets` → `BASE-FWP`
- Persistent and encrypted data partition → `BASE-ROOTFS`, `BASE-LUKS`
- Device identity key operations in the TPM → `BASE-TPM`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `modberry-provisioning` (new: directory layout, helper scripts on the device) | `meta-modberry` | build-time credentials from `secrets_kirkstone.conf` (interim) |
| `openssh-sshd` | see `BASE-SSH` | — |
| `tpm2-tools`, `openssl`, `wireguard-tools` | see `BASE-TPM`, `BASE-VPN` | — |

---

## 4. Requirements

### 4.1 Access

- `BASE-PROV-01` **MUST** The factory script connects to the device over SSH as `user` with the Bynacon service key, from the factory subnet (`BASE-FWP-03`).
- `BASE-PROV-02` **MUST** Provisioning works on the production image. A debug image is not needed.

### 4.2 Provisioned Items

- `BASE-PROV-10` **MUST** The image contains no per-device or per-installation secrets. All items of section 5.1 are provisioned per device, or per installation where section 5.1 says so (WLAN passphrases).
- `BASE-PROV-11` **MUST** Private keys (WireGuard, nginx TLS, TPM device identity) are generated on the device and never leave it. Only public keys and certificate signing requests leave the device.
- `BASE-PROV-12` **MUST** The nginx TLS certificate is signed by the Bynacon CA from a CSR generated on the device.

### 4.3 Storage

- `BASE-PROV-20` **MUST** All provisioned data is stored below one directory (`/data/provisioning/`) on the persistent data partition.
- `BASE-PROV-21` **MUST** The directory is owned by root with mode `0700`. Files are readable only by root, or by the service user that needs them.
- `BASE-PROV-22` **MUST** Services read provisioned data from this directory (directly or via symlink); configuration files in the image contain no per-device values.
- `BASE-PROV-23` **MUST** A marker file records that the device is provisioned, with provisioning version and date.

### 4.4 Behavior

- `BASE-PROV-30` **MUST** On an unprovisioned device, services that need provisioned data do not start and do not fail (`ConditionPathExists=`), so that `BASE-INIT-11` holds.
- `BASE-PROV-31` **MUST** Provisioning can be repeated. Repeating it replaces the provisioned items without leftovers.
- `BASE-PROV-32` **SHOULD** The factory script records serial number, public keys and certificate of each device in the factory registry.
- `BASE-PROV-33` **MUST** The factory script assigns the Bynacon serial number and writes it into the user area of the AT24CS01 EEPROM and into the provisioning store.
- `BASE-PROV-34` **MUST** After provisioning, the factory subnet no longer grants access (`BASE-FWP-03`). Re-provisioning is done through the VPN or from `service_nets`.

### 4.5 Factory Reset & Decommissioning

- `BASE-PROV-40` **MUST** A factory reset deletes all provisioned data: it erases the LUKS key slots of the data partition (`cryptsetup erase`), removes the TPM objects of this layer (device identity, LUKS seal, nginx key) and reformats `/data`. The device is then unprovisioned.
- `BASE-PROV-41` **MUST** A factory reset can be started only by root (via SSH) or by a physical action on the device; it cannot be started from the network without authentication.
- `BASE-PROV-42` **SHOULD** At decommissioning, the device certificate and the VPN peer are revoked in the factory registry and on the VPN server.

---

## 5. Configuration

### 5.1 Provisioned Items

| Item | Generated | Stored as | Used by |
| :-- | :-- | :-- | :-- |
| AP passphrase IoT WLAN (per installation) | device registry, per installation | `wlan/iot.psk` | `BASE-WAP-14` |
| AP passphrase guest WLAN (per installation) | device registry, per installation | `wlan/guest.psk` | `BASE-WAP-14`, `BASE-WAP-16` |
| WLAN country code (default `CH`) | factory script | `wlan/country` | `BASE-WAP-15` |
| WLAN client credentials (optional) | factory script | iwd network file | `BASE-WCLI-21` |
| Site entries of `service_nets` | factory script | `firewall/service_nets.nft` | `BASE-FWP-03` |
| nginx TLS key | in the TPM | TPM persistent handle (reference in `tls/`) | `BASE-WEB-06`, `BASE-TPM-33` |
| nginx TLS certificate | Bynacon CA from CSR | `tls/server.crt` | `BASE-WEB-07` |
| WireGuard private key | on the device | `wireguard/wg0.key` | `BASE-VPN-02` |
| WireGuard peer (endpoint, server public key, tunnel address) | factory script | `wireguard/peer.conf` | `BASE-VPN-06` |
| TPM device identity key | in the TPM | TPM persistent handle | `BASE-TPM-32` |
| Additional authorized SSH keys (optional) | factory script | `ssh/authorized_keys` | `BASE-SSH-05` |
| Serial number | factory script | EEPROM user area and `serial` | `BASE-PROV-33` |
| Marker | factory script | `provisioned` | `BASE-PROV-23` |

### 5.2 Files

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/data/provisioning/` | `root:root 0700` | `BASE-PROV-20`, `BASE-PROV-21` |
| `/data/provisioning/provisioned` | `version=<n>`, `date=<ISO 8601>` | `BASE-PROV-23` |
| `<service>.service.d/10-provisioning.conf` | `ConditionPathExists=/data/provisioning/provisioned` | `BASE-PROV-30` |

---

## 6. Interfaces to Other Modules

### Provides

- Provisioned items of section 5.1 – used by `BASE-WAP`, `BASE-WCLI`, `BASE-FWP`, `BASE-SSH`, `BASE-VPN`, `BASE-WEB`, `BASE-TPM`.
- Marker `/data/provisioning/provisioned` – used by all services with per-device data.

### Consumes

- SSH access with the Bynacon service key – owned by `BASE-SSH` (`BASE-SSH-05`).
- Factory subnet in `service_nets` – owned by `BASE-FWP` (`BASE-FWP-03`).
- TPM and OpenSSL – owned by `BASE-TPM`.
- Persistent (later encrypted) data partition `/data` – owned by `BASE-ROOTFS` / `BASE-LUKS`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-PROV-01` | `device` | Factory script from a host in `10.99.0.0/24` | SSH login as `user` with service key works |
| `BASE-PROV-02` | `device` | Run provisioning on a production image | completes without debug access |
| `BASE-PROV-10` | `rootfs` | Search the rootfs for the items of section 5.1 | none present |
| `BASE-PROV-11` | `device` | Review of the factory script; compare key fingerprints on device and in registry | only public parts in the registry |
| `BASE-PROV-12` | `device` | `openssl verify -CAfile <Bynacon CA> /data/provisioning/tls/server.crt` | `OK` |
| `BASE-PROV-20`, `-21` | `device` | `stat -c '%U:%G %a' /data/provisioning` | `root:root 700` |
| `BASE-PROV-22` | `rootfs` | `grep -r` for per-device values in `<rootfs>/etc` | none |
| `BASE-PROV-23` | `device` | `cat /data/provisioning/provisioned` | version and date |
| `BASE-PROV-30` | `device` | Boot an unprovisioned device, `systemctl --failed` | empty; hostapd, wg0, nginx not started |
| `BASE-PROV-31` | `device` | Provision twice | second run succeeds, no old items left |
| `BASE-PROV-33` | `device` | Read the EEPROM user area; `cat /data/provisioning/serial` | same serial number |
| `BASE-PROV-34` | `device` | SSH from the factory subnet after provisioning | refused |
| `BASE-PROV-40` | `device` | Factory reset, then `cryptsetup luksDump`, `tpm2_getcap handles-persistent`, `ls /data/provisioning` | no key slots; no layer TPM objects; unprovisioned |
| `BASE-PROV-41` | `device` | Try to start the reset without authentication | not possible |

---

## 8. Constraints & Risks

- **Human gate:** a production image is only accessible over SSH with the service key. If provisioning or the service key fails, the device can only be recovered by reflashing.
- `/data` does not exist yet (`BASE-ROOTFS`). Until then, `/data/provisioning/` is a directory on the writable root filesystem and is not encrypted.
- **Interim:** the AP passphrase and WLAN client credentials still come from `secrets_kirkstone.conf` at build time. They move to provisioning together with this module (`BASE-WAP-14`, `BASE-WCLI-20`).
- The factory script, the Bynacon CA and the device registry are not part of this layer. Their location and security (CA key protection) must be defined separately.
- The EEPROM (AT24CS01) is not yet implemented in the device tree (hardware specification, section 8). `BASE-PROV-33` needs the `at24` driver.
- Moving private keys out of the device is not allowed (`BASE-PROV-11`). A replaced device therefore gets new keys; peers (VPN server) must be updated.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Where does the factory script live, and where are the Bynacon CA and the device registry operated? | `BASE-PROV-12`, `BASE-PROV-32` | **Deferred:** infrastructure information. |
| 2 | Device serial number: from the AT24CS01 EEPROM (factory-programmed 128-bit serial), from the CM4, or assigned by the factory script? | `BASE-PROV-32` | **Decided:** assigned by the factory script, stored in the EEPROM user area (`BASE-PROV-33`). |
| 3 | Is the factory subnet removed from `service_nets` at the end of provisioning? | `BASE-FWP-03` | **Decided:** yes (`BASE-PROV-34`, `BASE-FWP-03`). |
| 4 | Provisioning method. | all | **Decided:** factory provisioning over SSH with the Bynacon service key from the factory subnet `10.99.0.0/24`. |
