# Audit & File Integrity (auditd, AIDE)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-AUDIT` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-HWT`, `BASE-TPM`, `BASE-LOG` |
| **Hardware reference** | [M40804W_MAX.md](../../../hardware/M40804W_MAX.md) – sections 3.2 (SPI0, TPM), 3.3 (UART) |
| **Risk** | `low` |

---

## 1. Purpose

This module records security-relevant events and detects unauthorized changes to the system. The Linux audit subsystem logs every access to the serial interfaces and to the TPM. AIDE builds a cryptographic baseline of critical system files and reports every modification in scheduled checks.

---

## 2. Scope

### In scope

- auditd and the audit rules of the base system.
- Monitoring of access to the serial interfaces and the TPM.
- AIDE baseline, scheduled checks and reporting.
- Protection of the audit log and the AIDE database.

### Out of scope

- Reaction to detected events (bans, alerts) → `BASE-IDS`, application layer
- Persistent device names of the serial interfaces → `BASE-HWT`
- Integrity of the read-only root filesystem at block level (dm-verity) → `BASE-ROOTFS`
- AppArmor denial messages → `BASE-MAC` (logged, evaluated here only as input)

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `audit` (`auditd`, `auditctl`, `augenrules`) 3.0.8 | `meta-openembedded` (meta-oe) | — |
| `aide` 0.17.4 | `meta-security` (recipes-ids) | — |
| `modberry-audit-rules` (new) | `meta-modberry` | — |
| Kernel: `CONFIG_AUDIT`, `CONFIG_AUDITSYSCALL` | `linux-raspberrypi` config fragment | — |

---

## 4. Requirements

### 4.1 Audit Subsystem

- `BASE-AUDIT-01` **MUST** auditd runs from early boot. The kernel is started with `audit=1`, so that processes started before auditd are also audited.
- `BASE-AUDIT-02` **MUST** The audit rules of this module are installed under `/etc/audit/rules.d/` and loaded by `augenrules` at boot.
- `BASE-AUDIT-03` **MUST** Every open, read and write access to the serial interfaces of the hardware specification is logged, with the persistent names of `BASE-HWT` and the kernel names.
- `BASE-AUDIT-04` **MUST** Every access to the TPM device nodes (`/dev/tpm0`, `/dev/tpmrm0`) is logged.
- `BASE-AUDIT-05` **MUST** Changes to the audit configuration, user and group files (`/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/sudoers*`) and to `/data/provisioning/` are logged.
- `BASE-AUDIT-06` **SHOULD** In the production image, the audit rules are immutable after loading (`-e 2`).

### 4.2 Audit Log

- `BASE-AUDIT-10` **MUST** The audit log is stored persistently on the data partition and is readable only by root.
- `BASE-AUDIT-11` **MUST** The audit log has a size limit with rotation, and auditd does not stop the system when the limit is reached (`disk_full_action`, `max_log_file_action` set to rotate / suspend logging, not `halt`).
- `BASE-AUDIT-12` **SHOULD** Audit events are also available in the journal, so that `BASE-LOG` can forward them.

### 4.3 File Integrity (AIDE)

- `BASE-AUDIT-20` **MUST** AIDE builds a baseline database of the critical files (section 5.2) at first boot.
- `BASE-AUDIT-21` **MUST** A systemd timer runs an AIDE check at a fixed interval and at every boot.
- `BASE-AUDIT-22` **MUST** Every detected modification is logged to the journal with severity `warning` or higher.
- `BASE-AUDIT-23` **MUST** The AIDE database is stored on the data partition and is readable and writable only by root.
- `BASE-AUDIT-24` **MUST** The baseline is updated only by a defined procedure (after an OTA update or provisioning), not automatically after a failed check.

---

## 5. Configuration

### 5.1 Audit Rules

| Rule | Key | Req. |
| :-- | :-- | :-- |
| `-w /dev/ttyAMA0 -p rwa -k serial` (and every serial node and persistent name) | `serial` | `BASE-AUDIT-03` |
| `-w /dev/tpm0 -p rwa -k tpm`, `-w /dev/tpmrm0 -p rwa -k tpm` | `tpm` | `BASE-AUDIT-04` |
| `-w /etc/passwd -p wa -k identity` (and `shadow`, `group`, `sudoers`, `sudoers.d/`) | `identity` | `BASE-AUDIT-05` |
| `-w /etc/audit/ -p wa -k audit-config` | `audit-config` | `BASE-AUDIT-05` |
| `-w /data/provisioning/ -p wa -k provisioning` | `provisioning` | `BASE-AUDIT-05` |
| `-e 2` (production image only) | — | `BASE-AUDIT-06` |

### 5.2 AIDE Scope

<!-- Proposal, to be confirmed (open point 2). -->

| Path | Check |
| :-- | :-- |
| `/boot` (boot partition), `/usr/bin`, `/usr/sbin`, `/usr/lib`, `/lib` | content hash, permissions, owner |
| `/etc` | content hash, permissions, owner (excluding files that change at runtime, e.g. `resolv.conf`, `adjtime`) |
| `/data/provisioning/` | permissions and owner only (contents change at re-provisioning) |

### 5.3 Files

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `cmdline.txt` (via `rpi-cmdline.bbappend`) | `audit=1`, `audit_backlog_limit=8192` | `BASE-AUDIT-01` |
| `/etc/audit/rules.d/50-modberry.rules` | rules of section 5.1 | `BASE-AUDIT-02` … `BASE-AUDIT-06` |
| `/etc/audit/auditd.conf` | `log_file = /data/audit/audit.log`, `max_log_file`, `num_logs`, `max_log_file_action = rotate`, `disk_full_action = suspend` | `BASE-AUDIT-10`, `BASE-AUDIT-11` |
| `/etc/aide.conf` | `database_in = file:/data/aide/aide.db`, scope of section 5.2 | `BASE-AUDIT-20`, `BASE-AUDIT-23` |
| `aide-init.service` | `ConditionPathExists=!/data/aide/aide.db`, runs `aide --init` once | `BASE-AUDIT-20` |
| `aide-check.timer` / `.service` | `OnBootSec=`, `OnUnitActiveSec=` | `BASE-AUDIT-21` |

---

## 6. Interfaces to Other Modules

### Provides

- Audit events with keys `serial`, `tpm`, `identity`, `audit-config`, `provisioning` – used by `BASE-IDS` and the application layer.
- AIDE check results in the journal – used by `BASE-LOG` / `BASE-LOGDB`.

### Consumes

- Persistent serial device names – owned by `BASE-HWT` (`BASE-HWT-20`).
- TPM device nodes – owned by `BASE-TPM`.
- Journal – owned by `BASE-LOG`.
- Persistent data partition `/data` – owned by `BASE-ROOTFS` / `BASE-LUKS`.
- Image variant switch – owned by `BASE-INIT` (`BASE-INIT-42`).

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-AUDIT-01` | `device` | `cat /proc/cmdline`; `auditctl -s` | contains `audit=1`; `enabled 1` (or `2`) |
| `BASE-AUDIT-02` | `device` | `auditctl -l` | rules of section 5.1 loaded |
| `BASE-AUDIT-03` | `device` | `picocom /dev/ttyAMA0`, then `ausearch -k serial` | event with process and user |
| `BASE-AUDIT-04` | `device` | `tpm2_getrandom 8`, then `ausearch -k tpm` | event present |
| `BASE-AUDIT-05` | `device` | `touch /data/provisioning/x`, then `ausearch -k provisioning` | event present |
| `BASE-AUDIT-06` | `device` | `auditctl -D` on the production image | refused (`enabled 2`) |
| `BASE-AUDIT-10` | `device` | `stat -c '%U %a' /data/audit/audit.log` | `root 600` |
| `BASE-AUDIT-11` | `device` | Fill the log beyond `max_log_file` | rotation; system keeps running |
| `BASE-AUDIT-12` | `device` | `journalctl _TRANSPORT=audit` | audit events present |
| `BASE-AUDIT-20` | `device` | First boot: `ls -l /data/aide/aide.db` | database present |
| `BASE-AUDIT-21` | `device` | `systemctl list-timers aide-check.timer` | scheduled |
| `BASE-AUDIT-22` | `device` | Modify a file in `/etc`, run the check | warning in the journal naming the file |
| `BASE-AUDIT-23` | `device` | `stat -c '%U %a' /data/aide/aide.db` | `root 600` |
| `BASE-AUDIT-24` | `device` | After a detected change, run the check again | change still reported |

---

## 8. Constraints & Risks

- **Baseline at first boot:** a change made before the first boot (e.g. in the image file) is part of the baseline and is not detected. With dm-verity (`BASE-ROOTFS`), the read-only root filesystem is protected at block level; AIDE then mainly protects `/etc` overlays, `/boot` and `/data`.
- An attacker with root access can modify the AIDE database. Protecting the database (e.g. a hash sealed in the TPM, or a copy off the device) is not part of this module (open point 3).
- auditd writes to the eMMC for every watched access. Frequent accesses to the serial interfaces (e.g. Modbus polling) produce many events. Watch rules on `r` may need to be reduced to `wa` plus `open` (open point 1).
- `-e 2` prevents any change of the audit rules until the next reboot, also for legitimate debugging. It applies only to the production image.
- `/data` does not exist yet. Until `BASE-ROOTFS` is implemented, the paths of this module are on the writable root filesystem.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Log every read/write on the serial interfaces (high volume with Modbus polling), or only open and attribute changes? | `BASE-AUDIT-03`, `BASE-AUDIT-04` | |
| 2 | Confirm the AIDE scope (section 5.2) and the check interval (proposal: daily and at every boot). | `BASE-AUDIT-20`, `BASE-AUDIT-21` | |
| 3 | Is the AIDE database protected against modification (hash sealed in the TPM, upload off the device)? | `BASE-AUDIT-23` | |
| 4 | Who updates the baseline after an OTA update – the OTA layer, or a procedure of this module? | `BASE-AUDIT-24` | |
