# Hardware Interface Tooling

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-HWT` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-INIT` |
| **Hardware reference** | [M40804W_MAX.md](../../hardware/M40804W_MAX.md) – sections 3.1 (I2C0), 3.2 (SPI0), 3.3 (UART) |
| **Risk** | `low` |

---

## 1. Purpose

This module provides user-space access to the hardware buses of the device: CAN, I2C, UART and SPI. It defines the diagnostic tools in the image and the udev rules that give the device nodes persistent names and restricted access permissions.

---

## 2. Scope

### In scope

- Diagnostic tools for CAN, I2C and UART.
- `fuser` to list processes that hold a file or device node open.
- Kernel support required so that the bus interfaces appear in user space after boot.
- udev rules for persistent names and access permissions of serial, CAN and SPI device nodes.

### Out of scope

- Device tree, pinmux and driver configuration of the bus controllers → hardware specification, section 8
- Network configuration of the CAN interface (bitrate, bring-up) → `BASE-NETD`
- WLAN interface renaming (`70-net-sta-interface.rules`) → `BASE-NETD`
- RS-232 / RS-485 mode switching → hardware specification, section 7
- TPM device node permissions → `BASE-TPM`
- Audit monitoring of serial and SPI access → `BASE-AUDIT`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `can-utils` | `meta-openembedded` (meta-oe) | — |
| `i2c-tools` | `meta-openembedded` (meta-oe) | — |
| `picocom` | `meta-openembedded` (meta-oe) | — |
| `fuser` (from `psmisc`) | `poky` (openembedded-core) | busybox `fuser` |
| `udev` (from `systemd`) | `poky` (openembedded-core) | `eudev` |
| `modberry-udev-rules` (new) | `meta-modberry` | — |

---

## 4. Requirements

### 4.1 Tools

- `BASE-HWT-01` **MUST** `can-utils` is installed and provides at least `candump`, `cansend` and `cangen`.
- `BASE-HWT-02` **MUST** `i2c-tools` is installed and provides at least `i2cdetect`, `i2cget` and `i2cset`.
- `BASE-HWT-03` **MUST** `picocom` is installed.
- `BASE-HWT-04` **MUST** `fuser` from `psmisc` is installed and lists the processes that hold a file or device node open.

### 4.2 Kernel Support

- `BASE-HWT-10` **MUST** The kernel module for the CAN controller defined in the hardware specification is part of the image and loads automatically from the device tree.
- `BASE-HWT-11` **MUST** The CAN controller appears as a network interface after boot without manual action.
- `BASE-HWT-12` **MUST** `i2c-dev` loads at boot, so that all I2C buses of the hardware specification are available as `/dev/i2c-*`.
- `BASE-HWT-13` **MUST** All serial interfaces of the hardware specification are available as device nodes after boot.
- `BASE-HWT-14` **MUST** No `spidev` device node exists for a SPI chip select that is bound to a kernel driver (CAN, TPM).

### 4.3 udev Rules

- `BASE-HWT-20` **MUST** udev rules assign persistent names to all serial interfaces. The names do not depend on probe order.
- `BASE-HWT-21` **MUST** udev rules assign a persistent name to the CAN interface.
- `BASE-HWT-22` **MUST** udev rules set owner, group and mode of serial and SPI device nodes. No node is world-writable.
- `BASE-HWT-23` **MUST** The rule files are installed under `/etc/udev/rules.d/` by a recipe of this layer.
- `BASE-HWT-24` **SHOULD** The persistent names follow the port labels of the hardware specification (COM1 … COM4).

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/modules-load.d/` | `i2c-dev` | `BASE-HWT-12` |
| `/etc/udev/rules.d/<nn>-modberry-serial.rules` | `SYMLINK+=`, `GROUP=`, `MODE=` per serial interface | `BASE-HWT-20`, `BASE-HWT-22` |
| `/etc/udev/rules.d/<nn>-modberry-can.rules` | `NAME=` for the CAN netdev | `BASE-HWT-21` |
| `/etc/udev/rules.d/<nn>-modberry-spi.rules` | `GROUP=`, `MODE=` for remaining `spidev*` nodes | `BASE-HWT-22` |

---

## 6. Interfaces to Other Modules

### Provides

- Persistent serial device names – used by applications and `BASE-AUDIT` (watch rules on serial interfaces).
- Persistent CAN interface name – used by `BASE-NETD` (CAN `.network` file) and `BASE-MAC` (AppArmor profiles).
- Access groups for serial and SPI nodes – used by `BASE-MAC` and the application layer.

### Consumes

- systemd-udevd and unit integration rules – owned by `BASE-INIT` (`BASE-INIT-20` … `BASE-INIT-22`).
- Device tree nodes for CAN, I2C, UART, SPI – owned by the hardware specification.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-HWT-01` | `manifest` | `can-utils` in image manifest | present |
| `BASE-HWT-02` | `manifest` | `i2c-tools` in image manifest | present |
| `BASE-HWT-03` | `manifest` | `picocom` in image manifest | present |
| `BASE-HWT-04` | `manifest` | `fuser` in image manifest | present |
| `BASE-HWT-04` | `device` | `fuser -v /dev/ttyAMA0` while `picocom` is open on it | `picocom` listed |
| `BASE-HWT-10` | `rootfs` | `find <rootfs>/lib/modules -name 'mcp251x.ko*'` | found |
| `BASE-HWT-11` | `device` | `ip -details link show type can` | one CAN interface listed |
| `BASE-HWT-12` | `device` | `ls /dev/i2c-*` | all buses of hardware spec 3.1 present |
| `BASE-HWT-13` | `device` | `ls -l /dev/ttyAMA0 /dev/ttySC0` | both present |
| `BASE-HWT-14` | `device` | `ls /dev/spidev*` | no node for the CAN or TPM chip select |
| `BASE-HWT-20` | `device` | Reboot twice, compare `ls -l /dev/<persistent names>` | same targets |
| `BASE-HWT-21` | `device` | `ip link show <can name>` | present after every boot |
| `BASE-HWT-22` | `device` | `stat -c '%U:%G %a' <nodes>` | defined owner/group, no world-write bit |
| `BASE-HWT-23` | `rootfs` | `ls <rootfs>/etc/udev/rules.d/` | layer rule files present |
| `BASE-HWT-24` | `device` | `ls -l /dev/com*` | names match hardware spec labels |

---

## 8. Constraints & Risks

- A CAN interface is a network device. udev `GROUP`/`MODE` have no effect on it. Access to raw CAN sockets is controlled by `CAP_NET_RAW`, not by file permissions.
- `spi0-2cs.dtbo` creates `spidev0.0` and `spidev0.1` by default. Both chip selects are bound to kernel drivers (CAN, TPM), so both `spidev` nodes must be disabled in the device tree (`BASE-HWT-14`).
- With `INIT_MANAGER = "systemd"`, udev is provided by systemd. The explicit `udev` entry in `IMAGE_INSTALL` of the machine conf must not pull in `eudev`.
- The machine conf installs packages that this specification does not list: `spitools`, `rpi-gpio`, `raspi-gpio`, `usbutils`, `pciutils`. `pciutils` has no use, because PCIe is not available on this hardware variant (hardware spec, section 6).

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Naming scheme for persistent serial names: `/dev/com1` … `/dev/com4`, or by function (e.g. `/dev/rs485-1`)? COM1/COM4 and COM2/COM3 share one UART each. | `BASE-HWT-20`, `BASE-HWT-24` | |
| 2 | Which groups get access to serial and SPI nodes (`dialout`, `bynacon`, a new group)? | `BASE-HWT-22` | |
| 3 | Which `spidev` nodes should exist at all? If none, the SPI udev rule is not needed. | `BASE-HWT-14`, `BASE-HWT-22` | |
| 4 | CAN bitrate and automatic bring-up at boot: owned by `BASE-NETD` – confirm. | `BASE-HWT-11` | **Decided:** owned by `BASE-NETD` (`BASE-NETD-40`, 125 kbit/s). |
| 5 | Keep, remove or add to this spec: `spitools`, `rpi-gpio`, `raspi-gpio`, `usbutils`, `pciutils`? | Components | |
