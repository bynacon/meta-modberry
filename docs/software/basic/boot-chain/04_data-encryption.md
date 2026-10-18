# Data Partition Encryption (LUKS, TPM-sealed key)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-LUKS` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-TPM`, `BASE-MBOOT`, `BASE-ROOTFS` |
| **Hardware reference** | — |
| **Risk** | `high` |

---

## 1. Purpose

This module encrypts the data partition with LUKS2. The key is sealed in the TPM against the expected PCR values of the boot chain. The TPM releases it only if the device booted the expected, verified software. If the eMMC is removed or the boot chain is modified, the data stays unreadable.

---

## 2. Scope

### In scope

- LUKS2 encryption of the data partition.
- Creation of the key at first boot and sealing in the TPM.
- Unlocking at boot.
- Resealing when the PCR values change through an update.
- Recovery key.

### Out of scope

- Partition layout and mount of `/data` → `BASE-ROOTFS`
- PCR measurements → `BASE-MBOOT`
- TPM driver and tools → `BASE-TPM`
- Triggering of resealing during an OTA update → OTA layer (uses the procedure of this module)

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `cryptsetup` 2.4.3 | `meta-openembedded` (meta-oe) | — |
| `systemd` with `PACKAGECONFIG` `cryptsetup` and `tpm2` (`systemd-cryptsetup`, `systemd-cryptenroll`) | `poky` (openembedded-core) | own unseal scripts with `tpm2-tools` (see open point 1) |
| Kernel: `CONFIG_DM_CRYPT`, `CONFIG_CRYPTO_XTS`, `CONFIG_CRYPTO_AES_ARM64_NEON_BLK` (or `CONFIG_CRYPTO_ADIANTUM`, open point 5) | `linux-raspberrypi` config fragment | — |

---

## 4. Requirements

### 4.1 Encryption

- `BASE-LUKS-01` **MUST** The data partition is a LUKS2 volume with `aes-xts-plain64` and a 512-bit key.
- `BASE-LUKS-02` **MUST** The volume key is generated on the device at first boot from the kernel random source (seeded by the TPM RNG, `BASE-TPM-04`). It is never stored in plain text on any partition.

### 4.2 TPM Sealing

- `BASE-LUKS-10` **MUST** A LUKS key slot is bound to the TPM with a policy on the PCRs of `BASE-MBOOT` (proposal: 4, 5, 8, 9, 11; see open point 2).
- `BASE-LUKS-11` **MUST** At boot, the data partition is unlocked automatically if the PCR values match. No user input is required.
- `BASE-LUKS-12` **MUST** If the PCR values do not match, the data partition stays locked, the boot continues without `/data`, and the failure is logged. Services that need `/data` do not start (`BASE-ROOTFS-31`).
- `BASE-LUKS-13` **MUST** The TPM object is protected against dictionary attacks (TPM lockout settings) and, if a PIN is used, by the PIN (open point 3).

### 4.3 Updates & Recovery

- `BASE-LUKS-20` **MUST** A procedure reseals the key against the reference PCR values of a new image (`BASE-MBOOT-20`) before the new image is activated.
- `BASE-LUKS-21` **MUST** A recovery key slot exists. The recovery key is generated at provisioning and stored outside the device (factory registry, `BASE-PROV-32`).
- `BASE-LUKS-22` **MUST** The recovery key never stays on the device in plain text after provisioning.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| First-boot unit `modberry-data-init.service` | `cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512`, then `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=<list>` | `BASE-LUKS-01`, `BASE-LUKS-02`, `BASE-LUKS-10` |
| `/etc/crypttab` | `data UUID=<uuid> - tpm2-device=auto,nofail` | `BASE-LUKS-11`, `BASE-LUKS-12` |
| Build: `systemd_%.bbappend` | `PACKAGECONFIG:append = " cryptsetup tpm2"` | Components |
| Reseal helper `modberry-luks-reseal` | `systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=<list>` against the new reference values | `BASE-LUKS-20` |
| Provisioning step | `systemd-cryptenroll --recovery-key`, key handed to the factory script | `BASE-LUKS-21`, `BASE-LUKS-22` |

---

## 6. Interfaces to Other Modules

### Provides

- Unlocked block device `/dev/mapper/data` – used by `BASE-ROOTFS` (mounted at `/data`).
- Reseal procedure – used by the OTA layer before activating a new image.
- Recovery key – handed to `BASE-PROV` for the factory registry.

### Consumes

- PCR values and reference values – owned by `BASE-MBOOT`.
- Data partition – owned by `BASE-ROOTFS`.
- TPM and RNG – owned by `BASE-TPM`.
- Factory registry – owned by `BASE-PROV`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-LUKS-01` | `device` | `cryptsetup luksDump <data partition>` | `LUKS2`, `aes-xts-plain64`, 512 bits |
| `BASE-LUKS-02` | `device` | Search boot and root partitions for key material | none |
| `BASE-LUKS-10` | `device` | `systemd-cryptenroll <data partition>` | `tpm2` slot with the PCR list |
| `BASE-LUKS-11` | `device` | Reboot, `findmnt /data` | mounted without input |
| `BASE-LUKS-12` | `device` | Boot a debug image with a different kernel (lab) | `/data` locked; boot completes; failure in the journal |
| `BASE-LUKS-12` | `device` | Read the eMMC in another device | data partition not readable |
| `BASE-LUKS-20` | `device` | Install a new image with the reseal procedure, reboot | `/data` unlocked |
| `BASE-LUKS-21` | `device` | Unlock with the recovery key after a PCR change (lab) | unlocked |
| `BASE-LUKS-22` | `device` | Search the device for the recovery key after provisioning | not found |

---

## 8. Constraints & Risks

- **Human gate:** a wrong PCR policy or a missing reseal before an update locks the data partition on every device that installs the update. Without the recovery key, the data is lost.
- `BASE-LUKS-12` keeps the device reachable when unlocking fails (SSH via the service key, `BASE-RACC-14`). This requires that SSH host keys and authorized keys are available without `/data`; with the `/etc` overlay on `/data` (`BASE-ROOTFS-20`), this needs a fallback (open point 4).
- The source specification names `tpm2-tools` for unsealing. `systemd-cryptenroll` / `systemd-cryptsetup` (systemd 250, kirkstone) do the same with less own code. See open point 1.
- The BCM2711 (Cortex-A72) has no ARMv8 crypto extensions, so there are no hardware AES instructions. AES-XTS runs in NEON software and costs CPU time; throughput on the eMMC must be measured. Adiantum (`xchacha12,aes-adiantum-plain64`) is designed for CPUs without AES instructions and is usually faster (open point 5).
- Until `BASE-MBOOT` exists, sealing against PCRs gives no protection. This module is implemented after `BASE-MBOOT`.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | `systemd-cryptenroll` / `systemd-cryptsetup` (recommended), or own unseal scripts with `tpm2-tools` as in the source specification? | `BASE-LUKS-10`, `BASE-LUKS-11` | |
| 2 | Which PCRs are part of the policy? More PCRs = more protection, but every change of these components needs a reseal. | `BASE-LUKS-10`, `BASE-LUKS-20` | |
| 3 | TPM PIN in addition to the PCR policy? Requires input at boot – not possible for an unattended device. | `BASE-LUKS-13` | |
| 4 | Where are SSH host keys and authorized keys stored, so that the device stays reachable when `/data` is locked? | `BASE-LUKS-12`, `BASE-RACC-13` | |
| 5 | Cipher: `aes-xts-plain64` (as in `BASE-LUKS-01`) or Adiantum? Decide after a throughput measurement on the device. | `BASE-LUKS-01` | |
