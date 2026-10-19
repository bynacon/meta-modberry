# Kernel Hardening & Watchdog

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-KERN` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
| **Depends on** | `BASE-INIT` |
| **Hardware reference** | [M40804W_MAX.md](../../../hardware/M40804W_MAX.md) – CM4 (BCM2711 watchdog) |
| **Risk** | `medium` |

---

## 1. Purpose

This module hardens the kernel through `sysctl` parameters and makes the device recover by itself when it hangs. The hardware watchdog of the CM4 resets the device if the system or a critical service stops responding.

---

## 2. Scope

### In scope

- Kernel parameters via `/etc/sysctl.d/`.
- Hardware watchdog: device tree, kernel driver, feeding by systemd.
- Service watchdogs for critical services.

### Out of scope

- IP forwarding per interface → `BASE-NETD` (`BASE-NETD-14`)
- Linux Security Modules (AppArmor) → `BASE-MAC`
- Audit subsystem → `BASE-AUDIT`
- Kernel lockdown and module signing → not specified (see open point 4)

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `procps` (`sysctl`) | `poky` (openembedded-core) | busybox `sysctl` |
| `systemd` (watchdog support) | `poky` (openembedded-core) | `watchdog` daemon (see open point 1) |
| `modberry-sysctl` (new) | `meta-modberry` | — |
| Kernel: `bcm2835_wdt`, `CONFIG_SECURITY_YAMA` | `linux-raspberrypi` | — |

---

## 4. Requirements

### 4.1 Kernel Parameters

- `BASE-KERN-01` **MUST** The layer installs its kernel parameters as one file under `/etc/sysctl.d/`. They are applied at boot by `systemd-sysctl`.
- `BASE-KERN-02` **MUST** `kernel.kptr_restrict = 2`.
- `BASE-KERN-03` **MUST** `kernel.dmesg_restrict = 1`.
- `BASE-KERN-04` **MUST** `kernel.yama.ptrace_scope = 2`.
- `BASE-KERN-05` **MUST** `net.ipv4.conf.all.rp_filter = 1` and `net.ipv4.conf.default.rp_filter = 1`.
- `BASE-KERN-06` **MUST** `net.ipv4.conf.all.accept_redirects = 0` and `net.ipv4.conf.default.accept_redirects = 0`.
- `BASE-KERN-07` **SHOULD** The IPv6 and send equivalents are set: `net.ipv6.conf.all.accept_redirects = 0`, `net.ipv4.conf.all.send_redirects = 0`, `net.ipv4.conf.all.accept_source_route = 0`.
- `BASE-KERN-08` **MUST** No other module sets the parameters of this module to a different value.
- `BASE-KERN-09` **MUST** Further hardening parameters: `kernel.unprivileged_bpf_disabled = 1`, `net.core.bpf_jit_harden = 2`, `kernel.kexec_load_disabled = 1`, `fs.protected_symlinks = 1`, `fs.protected_hardlinks = 1`, `fs.protected_fifos = 2`, `fs.protected_regular = 2`.

### 4.2 Hardware Watchdog

- `BASE-KERN-10` **MUST** The hardware watchdog of the BCM2711 is enabled in the device tree and available as `/dev/watchdog0`.
- `BASE-KERN-11` **MUST** systemd feeds the hardware watchdog during operation (`RuntimeWatchdogSec`). If systemd stops responding, the watchdog resets the device.
- `BASE-KERN-12` **MUST** The watchdog also covers reboot and shutdown (`RebootWatchdogSec`), so that a hanging shutdown ends in a reset.
- `BASE-KERN-13` **MUST** Only one process opens `/dev/watchdog0`.

### 4.3 Service Watchdogs

- `BASE-KERN-20` **MUST** Critical services that support `sd_notify` watchdog messages have `WatchdogSec=` set. If such a service stops responding, systemd restarts it (`BASE-INIT-23`).
- `BASE-KERN-21` **SHOULD** If a critical service fails repeatedly and reaches its start limit, the device reboots (`StartLimitAction=reboot`).
- `BASE-KERN-22` **MUST** Critical services are `systemd-networkd`, `nftables` and `sshd`. Further services are added by their modules (e.g. Thread).

### 4.4 Kernel Modules

- `BASE-KERN-30` **MUST** The kernel loads only signed modules (`CONFIG_MODULE_SIG_FORCE`). Modules are signed at build time with a key that is kept like the signing key of `BASE-VBOOT` (`BASE-VBOOT-30`, `BASE-VBOOT-31`).

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/sysctl.d/60-modberry-hardening.conf` | parameters of section 4.1 | `BASE-KERN-01` … `BASE-KERN-07` |
| `config.txt` (via `rpi-config_git.bbappend`) | `dtparam=watchdog=on` | `BASE-KERN-10` |
| `/etc/systemd/system.conf.d/10-watchdog.conf` | `RuntimeWatchdogSec=15s`, `RebootWatchdogSec=2min` | `BASE-KERN-11`, `BASE-KERN-12` |
| `<critical>.service.d/10-watchdog.conf` | `WatchdogSec=`, `StartLimitAction=reboot` | `BASE-KERN-20`, `BASE-KERN-21` |
| Kernel config fragment | `CONFIG_BCM2835_WDT=y`, `CONFIG_SECURITY_YAMA=y` | `BASE-KERN-04`, `BASE-KERN-10` |
| Kernel config fragment | `CONFIG_MODULE_SIG=y`, `CONFIG_MODULE_SIG_FORCE=y`, `CONFIG_MODULE_SIG_SHA512=y`, `CONFIG_MODULE_SIG_KEY` from the non-versioned key directory | `BASE-KERN-30` |

---

## 6. Interfaces to Other Modules

### Provides

- Hardened kernel parameters – baseline for all modules.
- Watchdog policy (`WatchdogSec=`, `StartLimitAction=`) – applied to critical services of other modules.

### Consumes

- systemd and service rules – owned by `BASE-INIT`.
- Per-interface forwarding – owned by `BASE-NETD`.
- List of critical services – open point 2.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-KERN-01` | `rootfs` | `ls <rootfs>/etc/sysctl.d/` | `60-modberry-hardening.conf` present |
| `BASE-KERN-02` … `-07` | `device` | `sysctl kernel.kptr_restrict kernel.dmesg_restrict kernel.yama.ptrace_scope net.ipv4.conf.all.rp_filter net.ipv4.conf.all.accept_redirects …` | values of section 4.1 |
| `BASE-KERN-03` | `device` | `dmesg` as `user` | permission denied |
| `BASE-KERN-08` | `device` | `systemd-analyze cat-config sysctl.d` | no later file overrides the values |
| `BASE-KERN-09` | `device` | `sysctl kernel.unprivileged_bpf_disabled fs.protected_regular …` | values of `BASE-KERN-09` |
| `BASE-KERN-10` | `device` | `ls /dev/watchdog0`; `cat /sys/class/watchdog/watchdog0/identity` | present; `Broadcom BCM2835 Watchdog timer` |
| `BASE-KERN-11` | `device` | `systemctl show -p RuntimeWatchdogUSec`; `echo c > /proc/sysrq-trigger` (test device) | `15s`; device resets |
| `BASE-KERN-12` | `device` | `systemctl show -p RebootWatchdogUSec` | `2min` |
| `BASE-KERN-13` | `device` | `fuser /dev/watchdog0` | only PID 1 |
| `BASE-KERN-20` | `device` | `systemctl show -p WatchdogUSec <critical service>` | > 0 |
| `BASE-KERN-21` | `device` | Kill a critical service repeatedly (test device) | device reboots after the start limit |
| `BASE-KERN-30` | `device` | `insmod` of an unsigned test module | `Key was rejected by service` |

---

## 8. Constraints & Risks

- `config.txt` contains `#dtparam=watchdog=off` today. The hardware watchdog is not active.
- A too short `RuntimeWatchdogSec` causes resets under high load (e.g. during a long `fsck` or a TPM operation). 15 s is a starting value and must be verified on the device.
- `StartLimitAction=reboot` on a service that fails at every boot causes a reboot loop. It is applied only to services that are known to start reliably, and only after the start limit (`BASE-INIT-25`).
- `net.ipv4.conf.all.rp_filter = 1` (strict) can drop packets when the default route changes between `lan0` and `wlan1_sta` (`BASE-NETD-31`). This must be tested with the uplink fallback.
- The source specification names the `watchdog` daemon. With systemd as PID 1, systemd can feed the hardware watchdog itself. Both must not open the device at the same time (`BASE-KERN-13`).

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | systemd feeds the watchdog (recommended), or the `watchdog` daemon from the source spec (adds checks such as load, memory, ping)? | `BASE-KERN-11`, Components | **Decided:** systemd feeds the watchdog; no `watchdog` daemon. |
| 2 | Which services are critical (`WatchdogSec`, `StartLimitAction=reboot`)? Proposal: `systemd-networkd`, `nftables`, `sshd`, `otbr-agent`. | `BASE-KERN-20`, `BASE-KERN-21` | **Decided:** `systemd-networkd`, `nftables`, `sshd` (`BASE-KERN-22`); Thread services follow with the Thread stack. |
| 3 | Further kernel parameters (e.g. `kernel.unprivileged_bpf_disabled = 1`, `net.core.bpf_jit_harden = 2`, `fs.protected_*`, `kernel.kexec_load_disabled = 1`)? Docker may need some of them relaxed. | `BASE-KERN-07` | **Decided:** yes (`BASE-KERN-09`); relaxations for Docker are defined by the application layer. |
| 4 | Kernel lockdown and kernel module signing? Relevant together with the boot chain (`BASE-VBOOT`). | Scope | **Decided:** module signing yes (`BASE-KERN-30`). **Deferred:** lockdown, after tests. |
