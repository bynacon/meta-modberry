# TPM & Cryptography

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-TPM` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-INIT` |
| **Hardware reference** | [M40804W_MAX.md](../../hardware/M40804W_MAX.md) – sections 1 (TPM), 3.2 (SPI0) |
| **Risk** | `medium` |

---

## 1. Purpose

This module makes the hardware TPM available to the operating system and to applications. It provides the TPM2 software stack, the TPM2 command-line tools, and the OpenSSL integration that binds device keys to the TPM. All modules that seal secrets, measure the boot state or hold device keys build on it.

---

## 2. Scope

### In scope

- Kernel driver and device nodes for the TPM.
- TPM2 Software Stack (`tpm2-tss`) with the ESYS, FAPI and TCTI interfaces.
- TPM2 command-line tools (`tpm2-tools`).
- OpenSSL as TLS library for all encrypted connections, and its binding to TPM-resident keys.
- Access permissions for TPM device nodes.

### Out of scope

- Signature keys and verification of boot artifacts → `BASE-VBOOT`
- PCR measurement policy of the boot stages → `BASE-MBOOT`
- dm-verity root hash storage → `BASE-ROOTFS`
- LUKS key sealing and unsealing → `BASE-LUKS`
- TLS configuration of individual services → `BASE-WEB` (nginx), `BASE-VPN` (WireGuard), application layer (MQTT)
- Audit monitoring of the SPI TPM interface → `BASE-AUDIT`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `tpm2-tss` 3.2.3 (`libtss2`, `libtss2-tcti-device`, FAPI) | `meta-security` (meta-tpm) | — |
| `tpm2-tools` | `meta-security` (meta-tpm) | — |
| `openssl` | `poky` (openembedded-core) | — |
| `tpm2-openssl` 1.1.0 | `meta-security` (meta-tpm) | OpenSSL TPM engine (`tpm2-tss-engine`) |
| Kernel: `tpm_tis_spi` | `linux-raspberrypi` + `9670.cfg`, loaded via `KERNEL_MODULE_AUTOLOAD` | `slb9670` (systemd service that runs `modprobe`) – **removed** |
| — | — | `libtss2-tcti-mssim` (TPM simulator TCTI) – **removed** |
| — | — | `tpm2-abrmd` (kernel resource manager is used), `tpm2-pkcs11` (not needed) |

---

## 4. Requirements

### 4.1 Kernel & Device

- `BASE-TPM-01` **MUST** The TPM defined in the hardware specification is bound by the kernel driver `tpm_tis_spi` via the device tree.
- `BASE-TPM-02` **MUST** `/dev/tpm0` and `/dev/tpmrm0` exist after boot without a manual action. The driver is loaded via `KERNEL_MODULE_AUTOLOAD` (`/etc/modules-load.d/`), not via a custom service.
- `BASE-TPM-03` **MUST** The TPM interrupt line of the hardware specification is used. Polling mode is not used.
- `BASE-TPM-04` **SHOULD** The TPM is available as a hardware random number source (`hw_random`).

### 4.2 TPM2 Software Stack

- `BASE-TPM-10` **MUST** `tpm2-tss` is installed with the ESYS, FAPI and TCTI interfaces.
- `BASE-TPM-11` **MUST** The device TCTI accesses the TPM through the resource manager (`/dev/tpmrm0`), not through `/dev/tpm0`.
- `BASE-TPM-12` **MUST** A FAPI configuration and profile are installed, so that FAPI works without manual setup.
- `BASE-TPM-13` **MUST** The image contains no TPM simulator TCTI.

### 4.3 TPM2 Tools

- `BASE-TPM-20` **MUST** `tpm2-tools` is installed and supports key generation, sealing, PCR read-out and quotes for remote attestation.

### 4.4 OpenSSL

- `BASE-TPM-30` **MUST** OpenSSL is the TLS library for all encrypted connections of the base system (HTTPS, MQTT-TLS, VPN handshake).
- `BASE-TPM-31` **MUST** OpenSSL can use private keys that are stored in the TPM.
- `BASE-TPM-32` **MUST** The private key of the device identity is generated in the TPM and cannot be exported.
- `BASE-TPM-33` **MUST** The private TLS key of nginx is a TPM key (`BASE-WEB-06`). The WireGuard key stays a file, because WireGuard cannot use TPM keys.

### 4.5 Access Control

- `BASE-TPM-40` **MUST** `/dev/tpm0` and `/dev/tpmrm0` are owned by `tss:tss` and not world-accessible.
- `BASE-TPM-41` **MUST** Only system users that are explicitly added to the `tss` group can access the TPM.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| Kernel config fragment `9670.cfg` | `CONFIG_TCG_TIS_SPI`, `CONFIG_HW_RANDOM_TPM` | `BASE-TPM-01`, `BASE-TPM-04` |
| Device tree overlay `slb9670-tpm` | chip select and interrupt per hardware spec | `BASE-TPM-01`, `BASE-TPM-03` |
| Build: machine conf | `KERNEL_MODULE_AUTOLOAD:rpi += " tpm_tis_spi"` → `/etc/modules-load.d/tpm_tis_spi.conf` | `BASE-TPM-02` |
| Build: `recipes-security/tpm2-tss/tpm2-tss_%.bbappend` | `PACKAGECONFIG:append = " fapi"` (disabled by default in kirkstone) | `BASE-TPM-10`, `BASE-TPM-12` |
| Build: distro conf `modberry` | `DISTRO_FEATURES:append = " tpm2"`, `MACHINE_FEATURES:append = " tpm2"` (today in `local_kirkstone.conf`) | `BASE-TPM-10` |
| `/etc/tpm2-tss/fapi-config.json` | `tcti: "device:/dev/tpmrm0"`, profile name | `BASE-TPM-11`, `BASE-TPM-12` |
| `/etc/ssl/openssl.cnf` | TPM provider loaded next to the default provider | `BASE-TPM-31` |
| `/lib/udev/rules.d/tpm-udev.rules` (shipped by `tpm2-tss`) | `OWNER="tss"`, `GROUP="tss"`, `MODE="0660"` | `BASE-TPM-40` |

---

## 6. Interfaces to Other Modules

### Provides

- `/dev/tpmrm0` and the TSS2 libraries – used by `BASE-MBOOT`, `BASE-ROOTFS`, `BASE-LUKS`.
- `tpm2-tools` for sealing and PCR operations – used by `BASE-LUKS` (unseal at boot) and `BASE-MBOOT`.
- OpenSSL with TPM key support – used by `BASE-WEB` (nginx) and the application layer (MQTT-TLS).
- Device identity key in the TPM – used by `BASE-PROV`, `BASE-MBOOT` (attestation) and the application layer.
- Group `tss` – used by `BASE-MAC` (AppArmor profiles of TPM consumers).

### Consumes

- Service integration rules – owned by `BASE-INIT` (`BASE-INIT-20` … `BASE-INIT-22`).
- SPI0 chip select and interrupt line – owned by the hardware specification.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-TPM-01` | `device` | `readlink /sys/class/tpm/tpm0/device/driver` | `…/tpm_tis_spi` |
| `BASE-TPM-02` | `device` | `ls -l /dev/tpm0 /dev/tpmrm0` after a clean boot | both present |
| `BASE-TPM-02` | `rootfs` | `cat <rootfs>/etc/modules-load.d/tpm_tis_spi.conf` | `tpm_tis_spi` |
| `BASE-TPM-02` | `manifest` | `slb9670` in image manifest | absent |
| `BASE-TPM-03` | `device` | `grep -i tpm /proc/interrupts` | IRQ listed, counter increases |
| `BASE-TPM-04` | `device` | `cat /sys/class/misc/hw_random/rng_available` | contains `tpm-rng-0` |
| `BASE-TPM-10` | `manifest` | `libtss2`, `libtss2-tcti-device` in image manifest | present |
| `BASE-TPM-11` | `device` | `tpm2_getcap properties-fixed` with default TCTI | works, uses `/dev/tpmrm0` |
| `BASE-TPM-12` | `device` | `tss2_list` | works without manual FAPI setup |
| `BASE-TPM-13` | `manifest` | `libtss2-tcti-mssim`, `tpm2-abrmd`, `tpm2-pkcs11` in image manifest | absent |
| `BASE-TPM-20` | `device` | `tpm2_pcrread sha256` | PCR values listed |
| `BASE-TPM-30` | `manifest` | `openssl` in image manifest | present |
| `BASE-TPM-31` | `device` | `openssl list -providers` | TPM provider listed and active |
| `BASE-TPM-32` | `device` | Sign test data with the identity key via OpenSSL; try to export the key | signing works, export fails |
| `BASE-TPM-40` | `device` | `stat -c '%U:%G %a' /dev/tpm0 /dev/tpmrm0` | `tss tss 660` |
| `BASE-TPM-41` | `device` | `tpm2_getrandom 8` as a user without `tss` group | permission denied |

---

## 8. Constraints & Risks

- **Kirkstone ships OpenSSL 3.0.** OpenSSL engines are deprecated there. The source spec names `ENGINE_load_tpm2`; this module uses the `tpm2-openssl` provider instead. The recipe `tpm2-openssl_1.1.0.bb` exists in `meta-security` (kirkstone).
- `tpm2-tss` builds without FAPI by default in kirkstone (`PACKAGECONFIG ??= ""`). FAPI must be enabled explicitly; it adds `curl` and `json-c` to the image.
- **Fixed:** the former `slb9670-rpi.service` ran `modprobe tpm_tis_spi` with `Type=simple` and `Restart=always`, so the unit restarted until the start limit and then failed (`BASE-INIT-11`, `BASE-INIT-24`). It also enabled itself with a broken symlink into `${D}` (`BASE-INIT-21`). The recipe `recipes-bsp/tpm/` and its `IMAGE_INSTALL` entry have been removed. The driver is loaded via the device tree compatible `infineon,slb9670` and, in addition, via `KERNEL_MODULE_AUTOLOAD`. If the module is already loaded, the autoload entry has no effect.
- **Fixed:** `libtss2-tcti-mssim` has been removed from `IMAGE_INSTALL` (`BASE-TPM-13`). `tpm2-openssl` has been added (`BASE-TPM-31`). FAPI is enabled via `recipes-security/tpm2-tss/tpm2-tss_%.bbappend`. **Not yet built.**
- `tpm2-openssl` only installs the provider module `${libdir}/ossl-modules/tpm2.so`. It does not change `openssl.cnf`. Loading the provider (`BASE-TPM-31`) is still open.
- `DISTRO_FEATURES tpm2` and `MACHINE_FEATURES tpm2` are set in `scripts/Yocto/local_kirkstone.conf` today. They move into the distro conf of this layer together with `BASE-INIT-02`.
- **Fixed:** `9670.cfg` and the board device tree patch were applied only for the override `modberry-m40804w-max-m`. This was the name of a machine conf that was renamed in commit `3192f4a`. The machine conf now sets `MACHINEOVERRIDES =. "modberry-m40804w-max:"`, and the kernel bbappend uses this override. **Not yet built:** the board patch (CAN, SC16IS740, MCP23008, MCP3424) is now applied for the first time since the rename and must be verified with a build and on the device.
- **Fixed:** the machine conf comments for the chip selects were swapped. They now match the hardware specification and the overlays (TPM CS1, CAN CS0).
- The hardware specification assigns GPIO05 as the interrupt line to both the TPM (section 3.2) and the DS2482S 1-wire bridge (section 3.1). The conflict is marked as open in the hardware specification. `BASE-TPM-03` is blocked until it is resolved.
- The current overlay `slb9670-tpm-overlay.dts` has no `interrupts` property. The TPM runs in polling mode today.
- Provisioning operations such as `tpm2_clear`, setting the owner hierarchy auth, or creating the device identity key cannot be undone without losing sealed data. They need a human gate and are not part of the image build.
- `tpm2-abrmd` and `tpm2-pkcs11` are still in `IMAGE_INSTALL` of the machine conf and are removed with this module.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Confirm the `tpm2-openssl` provider instead of the OpenSSL engine named in the source spec. Check that the recipe exists in `meta-security` (kirkstone). | `BASE-TPM-31`, Components | **Decided:** `tpm2-openssl` 1.1.0 from `meta-security` (kirkstone), recipe verified. |
| 2 | Kernel resource manager (`/dev/tpmrm0`) or `tpm2-abrmd`? Recommendation: kernel resource manager, remove `tpm2-abrmd`. | `BASE-TPM-11` | **Decided:** kernel resource manager `/dev/tpmrm0`; `tpm2-abrmd` removed. |
| 3 | Is `tpm2-pkcs11` (currently installed) needed, e.g. for WireGuard or SSH keys in the TPM? | Components | **Decided:** not needed; removed. |
| 4 | Which keys are TPM-resident: device identity only, or also the TLS server keys of nginx and the WireGuard private key? (WireGuard cannot use TPM keys directly.) | `BASE-TPM-32` | **Decided:** device identity and nginx TLS key (`BASE-TPM-33`); WireGuard key is a file. |
| 5 | When and by whom is the device identity key created (factory provisioning, first boot)? | `BASE-TPM-32` | **Decided:** at factory provisioning (`BASE-PROV`). |
| 6 | GPIO05 conflict between TPM and DS2482S (hardware spec). To be verified against the schematic. | `BASE-TPM-03` | **Deferred:** needs the schematic → verification task. |
