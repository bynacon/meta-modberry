# Measured Boot (TPM PCRs)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-MBOOT` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-TPM`, `BASE-VBOOT` |
| **Hardware reference** | [M40804W_MAX.md](../../../hardware/M40804W_MAX.md) – section 3.2 (SPI0, TPM) |
| **Risk** | `high` |

---

## 1. Purpose

This module records the boot state of the device in the TPM. Each boot stage – bootloader, kernel, device tree, initramfs – is measured into a TPM PCR before it is executed. The resulting PCR values identify the boot state. `BASE-LUKS` seals the data partition key against these values, and remote attestation can prove the boot state to a server.

---

## 2. Scope

### In scope

- Measurement of the boot stages into defined PCRs.
- PCR allocation of the device.
- Event log of the measurements.
- Reference values ("golden PCRs") per image and remote attestation support.

### Out of scope

- Signature verification → `BASE-VBOOT`
- Sealing and unsealing of the LUKS key → `BASE-LUKS`
- TPM driver and tools in Linux → `BASE-TPM`
- Attestation server → infrastructure (outside this layer)

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `u-boot` with TPM2 SPI driver and measured boot | `poky` + `meta-modberry` bbappend | — |
| `tpm2-tools` (`tpm2_pcrread`, `tpm2_quote`, `tpm2_eventlog`) | `meta-security` (meta-tpm), see `BASE-TPM` | — |
| `modberry-pcr-reference` (new: build step that computes reference values) | `meta-modberry` | — |

---

## 4. Requirements

### 4.1 Measurements

- `BASE-MBOOT-01` **MUST** U-Boot initializes the TPM and measures the FIT image components (kernel, device tree, initramfs) and the kernel command line before it executes them.
- `BASE-MBOOT-02` **MUST** The measurements use the PCRs of section 5.1 and the SHA-256 bank.
- `BASE-MBOOT-03` **MUST** A component is measured only after its signature has been verified (`BASE-VBOOT-11`).
- `BASE-MBOOT-04` **MUST** U-Boot extends a separator into the boot PCRs after the last measurement, so that later stages cannot reproduce the expected values.
- `BASE-MBOOT-05` **SHOULD** U-Boot itself and `config.txt` are measured by the earliest stage that can do so (see section 8).

### 4.2 Event Log

- `BASE-MBOOT-10` **MUST** U-Boot passes a TCG event log of its measurements to Linux.
- `BASE-MBOOT-11` **MUST** The event log is readable in Linux (`/sys/kernel/security/tpm0/binary_bios_measurements`) and replays to the current PCR values.

### 4.3 Reference Values & Attestation

- `BASE-MBOOT-20` **MUST** The build computes the expected PCR values of each production image and publishes them as build artifact.
- `BASE-MBOOT-21` **MUST** The device can produce a TPM quote over the boot PCRs, signed with an attestation key derived from the device identity (`BASE-TPM-32`).

---

## 5. Configuration

### 5.1 PCR Allocation

<!-- Proposal following the TCG PC Client convention, to be confirmed (open point 1). -->

| PCR | Content | Measured by |
| :-- | :-- | :-- |
| 0 | U-Boot binary (if a stage before U-Boot can measure it) | — (see section 8) |
| 1 | U-Boot configuration, `config.txt`, `cmdline.txt` | U-Boot |
| 4 | Kernel image of the FIT | U-Boot |
| 5 | Device tree and overlays of the FIT | U-Boot |
| 8 | Kernel command line | U-Boot |
| 9 | Initramfs of the FIT | U-Boot |
| 11 | Separator after the last boot measurement | U-Boot |

### 5.2 Files

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| U-Boot config fragment | `CONFIG_TPM=y`, `CONFIG_TPM_V2=y`, `CONFIG_TPM2_TIS_SPI=y`, `CONFIG_MEASURED_BOOT=y`, `CONFIG_CMD_TPM=y` | `BASE-MBOOT-01` |
| U-Boot control device tree | TPM node on SPI0 CS1 (per hardware specification), `linux,sml-base` / `linux,sml-size` for the event log | `BASE-MBOOT-01`, `BASE-MBOOT-10` |
| Build artifact | `<image>.pcrs.json` with the SHA-256 PCR values of section 5.1 | `BASE-MBOOT-20` |

---

## 6. Interfaces to Other Modules

### Provides

- PCR values of section 5.1 – used by `BASE-LUKS` (sealing policy).
- Event log and quotes – used by the attestation infrastructure.
- Reference PCR values per image – used by `BASE-LUKS` (resealing after an update) and by the OTA layer.

### Consumes

- Verified FIT image – owned by `BASE-VBOOT`.
- TPM driver, tools and device identity – owned by `BASE-TPM`.
- TPM chip select and interrupt – owned by the hardware specification.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-MBOOT-01` | `device` | `tpm2_pcrread sha256:4,5,8,9` | values ≠ 0 |
| `BASE-MBOOT-02` | `device` | `tpm2_pcrread sha256` | measurements only in the PCRs of section 5.1 |
| `BASE-MBOOT-03` | `device` | Boot a FIT with a bad signature (lab) | boot stops before a measurement of that FIT |
| `BASE-MBOOT-04` | `device` | Try to extend PCR 4 from Linux to the reference value | not possible to reach the reference value |
| `BASE-MBOOT-10`, `-11` | `device` | `tpm2_eventlog /sys/kernel/security/tpm0/binary_bios_measurements` | events listed; replayed PCRs equal `tpm2_pcrread` |
| `BASE-MBOOT-20` | `build` | Compare `<image>.pcrs.json` with `tpm2_pcrread` on a device running this image | equal |
| `BASE-MBOOT-21` | `device` | `tpm2_quote` over the boot PCRs, verify with the public attestation key | valid |
| — | `device` | Change `cmdline.txt` or the kernel, reboot | PCR values differ from the reference |

---

## 8. Constraints & Risks

- **No measurement before U-Boot:** the CM4 boot ROM and GPU firmware do not access the TPM. The first measuring stage is U-Boot, so U-Boot itself and the GPU firmware are not measured (`BASE-MBOOT-05`, PCR 0 stays empty). See `README.md`, section 3.
- **U-Boot version:** measured boot for FIT/`bootm` (`CONFIG_MEASURED_BOOT`) and the event log hand-over must be checked in U-Boot 2022.01 (kirkstone). A newer U-Boot or backported patches may be needed.
- U-Boot needs its own TPM driver and a device tree node for the SLB9670. The GPIO05 interrupt conflict of the hardware specification does not matter for U-Boot (polling).
- Every change of kernel, device tree, initramfs or command line changes the PCR values. `BASE-LUKS` must reseal the key before such an update is activated, otherwise the data partition is not unlocked.
- The source specification mentions "TPM PCR timestamping" (`BASE-TIME` open point 5). PCRs have no timestamps; timestamps exist only in attestation quotes.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Confirm the PCR allocation (section 5.1). | `BASE-MBOOT-02` | **Decided:** section 5.1. |
| 2 | Is remote attestation used (attestation server), or are the PCRs only used for LUKS sealing? | `BASE-MBOOT-21`, Scope | **Decided:** device side prepared (`BASE-MBOOT-21`); attestation server later. |
| 3 | U-Boot 2022.01 sufficient, or update / backport for measured boot? | `BASE-MBOOT-01` | **Deferred:** to be checked → verification task. |
