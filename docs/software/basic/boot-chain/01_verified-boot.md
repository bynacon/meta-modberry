# Verified Boot (U-Boot FIT Signature)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-VBOOT` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-INIT` |
| **Hardware reference** | [M40804W_MAX.md](../../../hardware/M40804W_MAX.md) – section 1 (CM4) |
| **Risk** | `high` |

---

## 1. Purpose

This module makes U-Boot boot only a kernel, device tree and initramfs that are signed by Bynacon. They are packed into one FIT image. U-Boot verifies the signature with a public key that is built into U-Boot, and stops the boot if the verification fails. The private signing key stays on the build host.

---

## 2. Scope

### In scope

- FIT image with kernel, device tree(s), overlays and initramfs.
- Signature of the FIT configuration and verification in U-Boot.
- Embedding of the public key in U-Boot.
- Lock-down of U-Boot (no interactive console, no unsigned boot path).
- Handling of the signing key on the build side.

### Out of scope

- Measurement of the boot stages into the TPM → `BASE-MBOOT`
- dm-verity root hash (contained in the signed FIT) → `BASE-ROOTFS`
- Raspberry Pi secure boot of the EEPROM bootloader (OTP) → open point 1
- Boot partition layout of OTA images → OTA layer

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `u-boot` 2022.01 with `CONFIG_FIT_SIGNATURE` | `poky` + `meta-raspberrypi` + `meta-modberry` bbappend | unsigned `boot.scr` / `Image` boot |
| `kernel-fitimage.bbclass`, `uboot-sign.bbclass` | `poky` (openembedded-core) | — |
| `u-boot-tools-native`, `dtc-native` | `poky` (openembedded-core) | — |

---

## 4. Requirements

### 4.1 FIT Image

- `BASE-VBOOT-01` **MUST** Kernel, device tree, device tree overlays and initramfs are packed into one FIT image.
- `BASE-VBOOT-02` **MUST** The FIT configuration is signed (`sign-images` covers kernel, fdt and ramdisk), not only the individual images.
- `BASE-VBOOT-03` **MUST** The signature algorithm is `sha256,rsa4096` or stronger.

### 4.2 Verification

- `BASE-VBOOT-10` **MUST** The public key is embedded in the U-Boot control device tree with `required = "conf"`.
- `BASE-VBOOT-11` **MUST** U-Boot boots only a FIT image whose configuration signature verifies. If the verification fails, U-Boot stops and does not try another boot path.
- `BASE-VBOOT-12` **MUST** U-Boot in the production image has no other boot command than the verified FIT boot (no `bootz`/`booti` of unsigned images, no `boot.scr` from the boot partition, no network boot).

### 4.3 U-Boot Lock-down

- `BASE-VBOOT-20` **MUST** In the production image, the U-Boot console cannot be entered (`CONFIG_BOOTDELAY=-2`, no autoboot interrupt).
- `BASE-VBOOT-21` **MUST** The U-Boot environment cannot change the boot command in the production image (environment compiled in or only a defined list of writable variables).
- `BASE-VBOOT-22` **MAY** In the debug image, the console is available and an unsigned boot is possible.

### 4.4 Signing Key

- `BASE-VBOOT-30` **MUST** The private signing key is not stored in the image, in the layer repository or in the build configuration repository.
- `BASE-VBOOT-31` **MUST** The build reads the key from a path outside the repositories (`UBOOT_SIGN_KEYDIR`), set in the non-versioned build configuration.
- `BASE-VBOOT-32` **SHOULD** Production images are signed with a production key; development builds use a separate development key.

### 4.5 Anti-Rollback

- `BASE-VBOOT-40` **MUST** Every production FIT image carries a security version. The boot refuses a FIT whose security version is lower than the minimum version stored on the device.
- `BASE-VBOOT-41` **MUST** The minimum version is stored in a TPM NV index that can only be increased (monotonic), and is increased only after a new image has booted successfully.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| Build: machine conf | `KERNEL_CLASSES += "kernel-fitimage"`, `KERNEL_IMAGETYPE = "fitImage"`, `INITRAMFS_IMAGE`, `INITRAMFS_IMAGE_BUNDLE = "0"` | `BASE-VBOOT-01` |
| Build: machine conf | `UBOOT_SIGN_ENABLE = "1"`, `UBOOT_SIGN_KEYNAME`, `FIT_HASH_ALG = "sha256"`, `FIT_SIGN_ALG = "rsa4096"`, `UBOOT_MKIMAGE_DTCOPTS` | `BASE-VBOOT-02`, `BASE-VBOOT-03`, `BASE-VBOOT-10` |
| Build: `secrets_kirkstone.conf` (not versioned) | `UBOOT_SIGN_KEYDIR = "<path on build host>"` | `BASE-VBOOT-30`, `BASE-VBOOT-31` |
| U-Boot config fragment (`u-boot_%.bbappend`) | `CONFIG_FIT_SIGNATURE=y`, `CONFIG_RSA=y`, `CONFIG_BOOTDELAY=-2`, `CONFIG_ENV_IS_NOWHERE=y` (or restricted env) | `BASE-VBOOT-11`, `BASE-VBOOT-20`, `BASE-VBOOT-21` |
| U-Boot `CONFIG_BOOTCOMMAND` | load FIT from the boot partition, `bootm` with the default configuration | `BASE-VBOOT-11`, `BASE-VBOOT-12` |
| `config.txt` | `kernel=u-boot.bin`, no `initramfs` / `device_tree` lines for the Linux kernel | `BASE-VBOOT-12` |
| FIT configuration / initramfs | security version (e.g. property in the signed configuration); check against TPM NV index in the initramfs or U-Boot | `BASE-VBOOT-40`, `BASE-VBOOT-41` |

---

## 6. Interfaces to Other Modules

### Provides

- Verified kernel, device tree and initramfs – used by `BASE-MBOOT` (measured after verification) and `BASE-ROOTFS` (root hash in the signed FIT).
- Boot partition with the FIT image – used by the OTA layer.

### Consumes

- Device tree and overlays of the hardware – owned by the hardware specification and the kernel recipes (overlays move from `config.txt` into the FIT).
- Image variant switch – owned by `BASE-INIT` (`BASE-INIT-42`).
- Non-versioned build configuration – owned by the `scripts` repository.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-VBOOT-01` | `build` | `dumpimage -l <deploy>/fitImage` | kernel, fdt(s), ramdisk, configuration |
| `BASE-VBOOT-02`, `-03` | `build` | `dumpimage -l` | configuration `Sign algo: sha256,rsa4096`, `Sign value` present |
| `BASE-VBOOT-10` | `build` | `fdtget -t s u-boot.dtb /signature/key-<name> required` | `conf` |
| `BASE-VBOOT-11` | `device` | Replace one byte in the kernel of the FIT, boot (console) | U-Boot reports a bad signature and stops |
| `BASE-VBOOT-11` | `device` | FIT signed with a different key | boot stops |
| `BASE-VBOOT-12` | `device` | Put an unsigned `Image` and `boot.scr` on the boot partition | ignored |
| `BASE-VBOOT-20` | `device` | Press keys on the serial console during boot (production image) | no U-Boot prompt |
| `BASE-VBOOT-21` | `device` | Write `bootcmd` into the environment storage, reboot | boot command unchanged |
| `BASE-VBOOT-30` | `rootfs` | Search image and repositories for the private key | not found |
| `BASE-VBOOT-40` | `device` | Flash a correctly signed FIT with a lower security version (lab) | boot refused |
| `BASE-VBOOT-41` | `device` | `tpm2_nvread` of the index before and after an update | value increased only after a successful boot |

---

## 8. Constraints & Risks

- **Human gate:** a wrong key, a wrong U-Boot config or a broken FIT stops every boot. Recovery is only possible by reflashing the eMMC via `rpiboot`. Every change is tested on a lab device first.
- **Correction of the source specification:** `01_basic.md` says that the signing keys are stored in the TPM. With U-Boot verified boot, the private key stays on the build host and the public key is embedded in U-Boot. The TPM is not involved in the signature check.
- Without Raspberry Pi secure boot, U-Boot itself and `config.txt` are not verified (see `README.md`, section 3). Measured boot (`BASE-MBOOT`) detects their modification.
- Today, device tree overlays are loaded by the GPU firmware from `config.txt`. With a FIT image, the kernel device tree and overlays must be applied in U-Boot or merged at build time, otherwise the hardware of the board is missing.
- The OTA layer needs U-Boot environment variables to switch between root partitions. `BASE-VBOOT-21` must leave exactly these variables writable.
- `BASE-VBOOT-40`: U-Boot 2022.01 has no built-in rollback check for FIT images. The check is done in the initramfs (with the TPM) or by a U-Boot extension; the OTA layer must increase the minimum version only after a confirmed update.
- `PCI` is disabled in the U-Boot config (`0001-configs-rpi-cm4-enable-pci.patch`). This is unrelated, but the U-Boot bbappend is extended by this module and must keep it.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Use Raspberry Pi secure boot (signed `boot.img`, customer key in CM4 OTP)? Closes the gap before U-Boot, but OTP programming is irreversible and must be done in the factory. | Scope, `BASE-PROV` | **Deferred:** decided after verified and measured boot are tested on lab devices. |
| 2 | Where are the production signing key and the development key kept (HSM, build host), and who may sign? | `BASE-VBOOT-30` … `BASE-VBOOT-32` | **Deferred:** infrastructure information. |
| 3 | Merge the board overlays into the kernel device tree at build time, or apply them in U-Boot from the FIT? | `BASE-VBOOT-01` | **Decided:** merged into the kernel device tree at build time. |
| 4 | Key rotation: how is a new public key brought onto devices (U-Boot update via OTA, signed with the old key)? | `BASE-VBOOT-10` | **Deferred:** OTA layer. |
