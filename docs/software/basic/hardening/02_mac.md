# Mandatory Access Control (AppArmor)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-MAC` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-INIT`, and every module whose services it confines |
| **Hardware reference** | — |
| **Risk** | `medium` |

---

## 1. Purpose

This module confines the network-facing and privileged services of the device with AppArmor. Each service gets its own profile, which allows only the filesystem paths, network sockets and device nodes that the service needs. A compromised service can then not access the rest of the system.

---

## 2. Scope

### In scope

- AppArmor as the Linux Security Module of the device.
- One profile per confined service, and the list of confined services.
- Profile modes (complain, enforce) and the transition between them.
- Logging of denials.

### Out of scope

- Implementation of the confined services → owning modules
- Audit rules for device access → `BASE-AUDIT`
- Container profiles of Docker → application layer (open point 3)

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `apparmor` (parser, utils, systemd unit) | `meta-security` (recipes-mac) | — |
| `modberry-apparmor-profiles` (new) | `meta-modberry` | — |
| Kernel: `CONFIG_SECURITY_APPARMOR`, `CONFIG_SECURITYFS` | `linux-raspberrypi` config fragment | — |

---

## 4. Requirements

### 4.1 Framework

- `BASE-MAC-01` **MUST** AppArmor is the active Linux Security Module. The distro conf enables the distro feature `apparmor`; the kernel is started with AppArmor enabled.
- `BASE-MAC-02` **MUST** Profiles are loaded at boot by `apparmor.service`, before the confined services start.
- `BASE-MAC-03` **MUST** Profiles are installed under `/etc/apparmor.d/` by the recipe of this module, one file per service.

### 4.2 Profiles

- `BASE-MAC-10` **MUST** Every service of section 5.1 runs under its own profile.
- `BASE-MAC-11` **MUST** A profile allows only the filesystem paths, network socket types and device nodes that the service needs. Write access is limited to the service's own state, runtime and log paths.
- `BASE-MAC-12` **MUST** Access to `/data/provisioning/` is allowed only to the services that need a specific item, and only to that item (`BASE-PROV-21`).
- `BASE-MAC-13` **MUST** Access to `/dev/tpm*` is allowed only to services in the `tss` group (`BASE-TPM-41`).

### 4.3 Modes

- `BASE-MAC-20` **MUST** In the production image, all profiles of section 5.1 are in enforce mode.
- `BASE-MAC-21` **MAY** In the debug image, profiles are in complain mode.
- `BASE-MAC-22` **MUST** A new or changed profile runs in complain mode on a test device until it has run through a defined test cycle without denials, before it is set to enforce.

### 4.4 Logging

- `BASE-MAC-30` **MUST** AppArmor denials are logged to the journal (kernel audit messages), so that `BASE-AUDIT` and `BASE-IDS` can evaluate them.

---

## 5. Configuration

### 5.1 Confined Services

<!-- Proposal, to be confirmed (open point 1). -->

| Service | Owner module | Main permissions |
| :-- | :-- | :-- |
| `sshd` | `BASE-RACC` | TCP 22, `/etc/ssh/`, authorized keys, PTY, spawning the login shell (unconfined child) |
| `nginx` | `BASE-RACC` | TCP 80/443, TLS key and certificate in `/data/provisioning/tls/`, upstream socket |
| `hostapd` | `BASE-WAP` | nl80211 netlink, `/etc/hostapd.conf`, passphrases in `/data/provisioning/wlan/`, `/run/hostapd/` |
| `dnsmasq` | `BASE-WAP` | UDP 53/67, `/etc/dnsmasq.conf`, `/etc/dnsmasq.d/`, lease file |
| `chronyd` | `BASE-TIME` | UDP 123, TCP 4460 out, `/dev/rtc0`, `/var/lib/chrony/` |
| `syslog-ng` | `BASE-LOG` | journal read, `/etc/syslog-ng/`, own log files, PostgreSQL socket (`BASE-LOGDB`) |
| `iwd` | `BASE-WCLI` | nl80211 netlink, `/var/lib/iwd/` |
| `fail2ban-server` | `BASE-IDS` | journal read, `nft` with the ban sets only |
| provisioning helper | `BASE-PROV` | `/data/provisioning/`, TPM, `cryptsetup` (recovery key) |

### 5.2 Files

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| Build: distro conf `modberry` | `DISTRO_FEATURES:append = " apparmor"` | `BASE-MAC-01` |
| `cmdline.txt` (via `rpi-cmdline.bbappend`) | `apparmor=1 security=apparmor` (or `lsm=` list) | `BASE-MAC-01` |
| `/etc/apparmor.d/<binary path with dots>` | one profile per service | `BASE-MAC-03`, `BASE-MAC-10` |
| Profile header | `flags=(enforce)` in production, `flags=(complain)` with `MODBERRY_DEBUG = "1"` | `BASE-MAC-20`, `BASE-MAC-21` |

---

## 6. Interfaces to Other Modules

### Provides

- AppArmor framework and profiles – used by all modules of section 5.1.
- Denial messages in the journal – used by `BASE-AUDIT` and `BASE-IDS`.

### Consumes

- Paths, ports and device nodes of each confined service – owned by the modules of section 5.1. A change of these modules requires a profile update.
- Provisioning layout `/data/provisioning/` – owned by `BASE-PROV`.
- Image variant switch `MODBERRY_DEBUG` – owned by `BASE-INIT`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-MAC-01` | `device` | `cat /sys/kernel/security/lsm`; `aa-enabled` | contains `apparmor`; `Yes` |
| `BASE-MAC-02` | `device` | `systemctl show -p Before apparmor.service` | before the confined services |
| `BASE-MAC-03` | `rootfs` | `ls <rootfs>/etc/apparmor.d/` | one profile per service of section 5.1 |
| `BASE-MAC-10` | `device` | `aa-status` | every service of section 5.1 listed with its profile |
| `BASE-MAC-11` | `device` | Test: from a shell in the confined context (`aa-exec -p <profile>`), read `/etc/shadow`, write `/etc` | denied |
| `BASE-MAC-12` | `device` | `aa-exec -p <dnsmasq profile> cat /data/provisioning/tls/server.key` | denied |
| `BASE-MAC-20` | `device` | `aa-status` on the production image | all profiles in enforce mode |
| `BASE-MAC-22` | `device` | Test cycle in complain mode, `journalctl -k \| grep apparmor="ALLOWED"` | no entries before switching to enforce |
| `BASE-MAC-30` | `device` | Provoke a denial, `journalctl -k \| grep apparmor="DENIED"` | entry present |

---

## 8. Constraints & Risks

- AppArmor requires the distro feature `apparmor` (`REQUIRED_DISTRO_FEATURES` of the recipe). It belongs in the distro conf (`BASE-INIT-02`).
- The Raspberry Pi kernel does not enable AppArmor by default. Kernel config and kernel command line must both be set.
- Profiles that are too strict break services at runtime, not at build time. `BASE-MAC-22` reduces this risk.
- Every change of a confined service (new path, new port) needs a matching profile change. This module comes last in the implementation order for that reason.
- Docker uses its own AppArmor profile (`docker-default`) for containers. It is not covered by this module.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Confirm the list of confined services (section 5.1). Add Thread services (`otbr-agent`, `ot-daemon`), `fail2ban`, the provisioning helper? | `BASE-MAC-10` | **Decided:** section 5.1 plus `fail2ban` and the provisioning helper; Thread services follow with the Thread stack. |
| 2 | Profiles written from scratch, or derived from the upstream `apparmor-profiles` and adapted? | `BASE-MAC-03` | **Decided:** derived from the upstream profiles where available, adapted. |
| 3 | Are the Docker containers of the application layer confined (own profiles instead of `docker-default`)? | Scope | **Deferred:** application layer. |
