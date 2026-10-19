# Logging

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-LOG` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-TIME` |
| **Hardware reference** | — |
| **Risk** | `low` |

---

## 1. Purpose

This module collects and routes the logs of the system on the device. systemd-journald collects the logs of all services and the kernel and stores them persistently. syslog-ng reads these logs and routes them by facility and severity. The transfer into the database is specified in `BASE-LOGDB`.

---

## 2. Scope

### In scope

- Persistent journal storage.
- syslog-ng as structured log router, including kernel messages.
- Routing by facility and severity.

### Out of scope

- Transfer of log entries into PostgreSQL → `BASE-LOGDB`
- Persistence of `/var/log` on the data partition → `BASE-ROOTFS`
- Audit logs of `auditd` → `BASE-AUDIT`
- Log-based intrusion detection (Fail2Ban, PSAD) → `BASE-IDS`
- Forwarding of logs to a remote server → not specified

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `systemd` (journald) | `poky` (openembedded-core) | — |
| `syslog-ng` | `meta-openembedded` (meta-oe) | `busybox-syslog`, `sysklogd` |

---

## 4. Requirements

### 4.1 journald

- `BASE-LOG-01` **MUST** journald collects the logs of all systemd services and the kernel.
- `BASE-LOG-02` **MUST** journald stores the journal persistently (`Storage=persistent`).
- `BASE-LOG-03` **MUST** The persistent journal is stored under `/var/log/journal`. Persistence of this path across reboots and its location on the data partition are owned by `BASE-ROOTFS`.
- `BASE-LOG-04` **SHOULD** The journal size is limited, to protect the eMMC.

### 4.2 syslog-ng

- `BASE-LOG-10` **MUST** syslog-ng is installed and starts at boot.
- `BASE-LOG-11` **MUST** syslog-ng reads all entries from journald, including kernel messages (`_TRANSPORT=kernel`).
- `BASE-LOG-12` **MUST** syslog-ng routes the entries by facility and severity.
- `BASE-LOG-13` **MUST** Exactly one syslog daemon runs on the system.
- `BASE-LOG-14` **MUST** The syslog-ng configuration includes the files of `/etc/syslog-ng/conf.d/`, so that `BASE-LOGDB` can add its destination without changing the main configuration.
- `BASE-LOG-15` **MUST** syslog-ng writes no local log files. Its only persistent destination is the database (`BASE-LOGDB`).

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/systemd/journald.conf` | `Storage=persistent` | `BASE-LOG-02` |
| `/etc/systemd/journald.conf` | `SystemMaxUse=64M` | `BASE-LOG-04` |
| `/etc/syslog-ng/syslog-ng.conf` | source `systemd-journal()` | `BASE-LOG-11` |
| `/etc/syslog-ng/syslog-ng.conf` | filters by `facility()` and `level()` | `BASE-LOG-12` |
| `/etc/syslog-ng/syslog-ng.conf` | `@include "/etc/syslog-ng/conf.d/*.conf"` | `BASE-LOG-14` |

---

## 6. Interfaces to Other Modules

### Provides

- Persistent journal – used by `BASE-IDS` (Fail2Ban, PSAD read logs) and `BASE-AUDIT`.
- syslog-ng source `s_journal` and the facility/severity filters – used by `BASE-LOGDB`.
- Include directory `/etc/syslog-ng/conf.d/` – used by `BASE-LOGDB`.

### Consumes

- journald and service integration rules – owned by `BASE-INIT`.
- Correct system time – owned by `BASE-TIME` (`BASE-TIME-20`).
- Persistent `/var/log` – owned by `BASE-ROOTFS`. Until `BASE-ROOTFS` is implemented, the root filesystem is writable and `/var/log` is persistent on it.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-LOG-01` | `device` | `journalctl -k -b \| head` and `journalctl -u chronyd -b` | entries present |
| `BASE-LOG-02` | `rootfs` | `grep '^Storage' <rootfs>/etc/systemd/journald.conf` | `Storage=persistent` |
| `BASE-LOG-03` | `device` | Reboot, `journalctl --list-boots` | more than one boot listed |
| `BASE-LOG-04` | `device` | `journalctl --disk-usage` | below the configured limit |
| `BASE-LOG-10` | `manifest` | `syslog-ng` in image manifest | present |
| `BASE-LOG-10` | `device` | `systemctl is-active syslog-ng` | `active` |
| `BASE-LOG-11` | `device` | `logger -t hwtest test` and `echo test > /dev/kmsg`, then `syslog-ng-ctl stats` | counters of the journal source increase |
| `BASE-LOG-12` | `rootfs` | Review of filters in `syslog-ng.conf` | filters by facility and level exist |
| `BASE-LOG-13` | `manifest` | `busybox-syslog`, `sysklogd`, `rsyslog` in image manifest | absent |
| `BASE-LOG-14` | `rootfs` | `grep '@include' <rootfs>/etc/syslog-ng/syslog-ng.conf` | includes `conf.d` |
| `BASE-LOG-15` | `rootfs` | `grep -E 'file\(' <rootfs>/etc/syslog-ng/syslog-ng.conf` | no file destination |

---

## 8. Constraints & Risks

- journald and syslog-ng both store the logs once `BASE-LOGDB` is implemented. This doubles the write load on the eMMC.
- Until `BASE-ROOTFS` is implemented, the journal is on the root filesystem. With a read-only root filesystem, `BASE-LOG-03` depends on `BASE-ROOTFS`.
- syslog-ng in busybox-based images conflicts with `busybox-syslog`. It must be removed explicitly (`BASE-LOG-13`).

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Maximum journal size (`SystemMaxUse`)? | `BASE-LOG-04` | **Decided:** `SystemMaxUse=64M`. |
| 2 | Is a persistent journal needed once syslog-ng writes into the database, or is `Storage=volatile` enough? (Fail2Ban and PSAD read the journal.) | `BASE-LOG-02` | **Decided:** persistent journal (Fail2Ban reads it). |
| 3 | Does syslog-ng also write local files (e.g. `/var/log/messages`) next to the database, or only the database? | `BASE-LOG-12` | **Decided:** no local files (`BASE-LOG-15`). |
