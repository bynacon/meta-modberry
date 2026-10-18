# Root Filesystem Integrity (dm-verity, read-only root, overlay)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-ROOTFS` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-VBOOT`, `BASE-MBOOT` |
| **Hardware reference** | — |
| **Risk** | `high` |

---

## 1. Purpose

This module makes the root filesystem read-only and verifies every block that is read from it. dm-verity checks the blocks against a hash tree whose root hash is part of the signed FIT image. Writes that are needed at runtime go to a temporary overlay; data that must survive a reboot is stored on the separate data partition. This module also defines the partition layout and which paths are persistent.

---

## 2. Scope

### In scope

- Partition layout of the basic image.
- dm-verity on the root partition and the location of the root hash.
- Read-only root filesystem and writable overlays.
- Mount of the data partition at `/data` and the list of persistent paths.
- initramfs that sets up dm-verity.

### Out of scope

- Encryption of the data partition → `BASE-LUKS`
- Signature of the FIT image that contains the root hash → `BASE-VBOOT`
- Partition layout of OTA images (A/B) → OTA layer
- File integrity monitoring of the writable paths → `BASE-AUDIT`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `dm-verity-img.bbclass` | `meta-security` | writable ext4 root |
| `dm-verity-image-initramfs` (or own initramfs based on it) | `meta-security` | — |
| `cryptsetup` 2.4.3 (`veritysetup`) | `meta-openembedded` (meta-oe) | — |
| `overlayfs.bbclass`, `overlayfs-etc` | `poky` (openembedded-core) | — |
| `modberry-image.wks` (new) | `meta-modberry` | `sdimg-raspberrypi.wks` |

---

## 4. Requirements

### 4.1 Partition Layout

- `BASE-ROOTFS-01` **MUST** The basic image has the partitions of `README.md`, section 2: boot (vfat), rootfs (ext4 with dm-verity hash tree), data.
- `BASE-ROOTFS-02` **MUST** The data partition is created and formatted at first boot if it does not exist, and grows to the remaining size of the eMMC.

### 4.2 dm-verity

- `BASE-ROOTFS-10` **MUST** The root filesystem is mounted through a dm-verity device. Every block read from it is verified against the hash tree.
- `BASE-ROOTFS-11` **MUST** The root hash is part of the signed FIT image (kernel command line or initramfs), so that it is covered by `BASE-VBOOT`.
- `BASE-ROOTFS-12` **MUST** A verification error makes the device reboot (`restart_on_corruption`), it does not continue with corrupted data.
- `BASE-ROOTFS-13` **MUST** The root filesystem is mounted read-only.

### 4.3 Writable Paths

- `BASE-ROOTFS-20` **MUST** `/etc` is writable through an overlay whose upper layer is on the data partition (`overlayfs-etc`), so that configuration created at runtime persists.
- `BASE-ROOTFS-21` **MUST** `/tmp`, `/run` and `/var/volatile` are tmpfs.
- `BASE-ROOTFS-22` **MUST** The paths of section 5.1 are persistent on the data partition. No other path of the root filesystem is writable.
- `BASE-ROOTFS-23` **MUST** The data partition is mounted with `nodev,nosuid`; paths that contain no executables are mounted or bound with `noexec`.

### 4.4 Boot Process

- `BASE-ROOTFS-30` **MUST** An initramfs, contained in the signed FIT image, sets up dm-verity and mounts the root filesystem.
- `BASE-ROOTFS-31` **MUST** The data partition is available before the services that use it start (`RequiresMountsFor=`).

---

## 5. Configuration

### 5.1 Persistent Paths

| Path on the device | Storage on `/data` | Used by |
| :-- | :-- | :-- |
| `/data/provisioning/` | itself | `BASE-PROV` |
| `/etc` (upper layer) | `/data/overlay/etc/` | all modules (`BASE-ROOTFS-20`) |
| `/var/log/journal/` | `/data/log/journal/` | `BASE-LOG-03` |
| `/data/audit/`, `/data/aide/` | themselves | `BASE-AUDIT` |
| `/var/lib/iwd/` | `/data/lib/iwd/` | `BASE-WCLI-22` |
| `/var/lib/chrony/` | `/data/lib/chrony/` | `BASE-TIME` (NTS cookies, drift) |
| `/etc/ssh/ssh_host_*` | via `/etc` overlay | `BASE-RACC-13` |
| `/var/lib/misc/` (dnsmasq leases) | `/data/lib/misc/` | `BASE-WAP` |
| syslog-ng disk buffer | `/data/lib/syslog-ng/` | `BASE-LOGDB-06` |
| application data (database, Docker) | `/data/app/` | application layer |

### 5.2 Files

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| Build: image recipe | `inherit dm-verity-img`, `DM_VERITY_IMAGE`, `DM_VERITY_IMAGE_TYPE = "ext4"`, `IMAGE_FEATURES += "read-only-rootfs overlayfs-etc"` | `BASE-ROOTFS-10`, `BASE-ROOTFS-13`, `BASE-ROOTFS-20` |
| Build: `modberry-image.wks` | boot (vfat), rootfs (`ext4.verity`); data created at first boot | `BASE-ROOTFS-01` |
| Kernel command line in the FIT | `root=/dev/dm-0`, verity table or root hash, `dm-verity.restart_on_corruption` | `BASE-ROOTFS-11`, `BASE-ROOTFS-12` |
| `/etc/fstab` / mount units | `/data` with `nodev,nosuid`; bind mounts of section 5.1 | `BASE-ROOTFS-22`, `BASE-ROOTFS-23` |
| Build: machine/image conf | `OVERLAYFS_ETC_MOUNT_POINT = "/data"`, `OVERLAYFS_ETC_DEVICE`, `OVERLAYFS_ETC_FSTYPE` | `BASE-ROOTFS-20` |

---

## 6. Interfaces to Other Modules

### Provides

- Persistent data partition `/data` and the path list of section 5.1 – used by `BASE-PROV`, `BASE-LOG`, `BASE-LOGDB`, `BASE-AUDIT`, `BASE-WCLI`, `BASE-TIME`, `BASE-WAP`, `BASE-RACC`, application layer.
- Read-only, verified root filesystem – baseline for `BASE-AUDIT` (AIDE scope).
- Partition layout – used by `BASE-LUKS` (data partition) and the OTA layer.

### Consumes

- Signed FIT image with initramfs and command line – owned by `BASE-VBOOT`.
- Encrypted block device of the data partition – owned by `BASE-LUKS` (once implemented).

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-ROOTFS-01` | `device` | `lsblk -f` | boot vfat, rootfs, data |
| `BASE-ROOTFS-02` | `device` | First boot of a fresh image, `df -h /data` | data partition created, fills the eMMC |
| `BASE-ROOTFS-10` | `device` | `dmsetup table`; `veritysetup status` | verity target on the root partition, `verified` |
| `BASE-ROOTFS-11` | `build` | `dumpimage -l fitImage` / command line of the FIT | root hash contained in the signed configuration |
| `BASE-ROOTFS-12` | `device` | Flip a byte in the root partition (lab), read the affected file | device reboots |
| `BASE-ROOTFS-13` | `device` | `touch /usr/bin/x` | `Read-only file system` |
| `BASE-ROOTFS-20` | `device` | Create a file in `/etc`, reboot | file still present |
| `BASE-ROOTFS-21` | `device` | `findmnt /tmp /run /var/volatile` | `tmpfs` |
| `BASE-ROOTFS-22` | `device` | Write test in every path of section 5.1, reboot | data persists |
| `BASE-ROOTFS-23` | `device` | `findmnt -o OPTIONS /data` | contains `nodev,nosuid` |
| `BASE-ROOTFS-31` | `device` | `systemctl show -p RequiresMountsFor <service>` for services of section 5.1 | contains `/data` |

---

## 8. Constraints & Risks

- **Human gate:** a wrong root hash or verity table makes every boot fail. Recovery by reflashing via `rpiboot`.
- **Correction of the source specification:** `01_basic.md` says that the root hash is stored in the TPM and verified at mount time. This module puts the root hash into the signed FIT image (`BASE-ROOTFS-11`): it is then covered by the signature and needs no TPM access before mount. See open point 1.
- A read-only root filesystem breaks every component that writes outside the paths of section 5.1. All modules must declare their persistent paths here before this module is enabled.
- Docker needs a writable `/var/lib/docker` with enough space; it belongs on `/data/app/` (application layer).
- The OTA layer typically needs A/B root partitions. The layout of section 2 of `README.md` is the basic layout; the OTA layout must meet `BASE-ROOTFS-10` … `BASE-ROOTFS-31`.
- `overlayfs-etc` in kirkstone mounts the overlay early via a custom init (`/sbin/init` wrapper). This must be checked together with the initramfs of `BASE-ROOTFS-30`.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Root hash in the signed FIT (recommended), or in a TPM NV index as in the source specification? | `BASE-ROOTFS-11` | |
| 2 | Confirm the persistent paths (section 5.1). Are there more (e.g. Thread dataset of `ot-daemon`, `/var/lib/fail2ban`)? | `BASE-ROOTFS-22` | |
| 3 | Size of the root partition (room for future images)? | `BASE-ROOTFS-01` | |
