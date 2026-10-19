# Hardware Interface Tooling

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-HWT` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
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
| `libgpiod-tools` (`gpiomon`) | `meta-openembedded` (meta-oe) | — |
| `modberry-serviceport` (new: command and units) | `meta-modberry` | — |
| `udev` (from `systemd`) | `poky` (openembedded-core) | `eudev` |
| `modberry-udev-rules` (new, also creates group `fieldbus`) | `meta-modberry` | — |
| `usbutils`, `raspi-gpio` | `poky`, `meta-raspberrypi` | — |
| — | — | `pciutils` (no PCIe), `spitools` (no `spidev`), `rpi-gpio` |

---

## 4. Requirements

### 4.1 Tools

- `BASE-HWT-01` **MUST** `can-utils` is installed and provides at least `candump`, `cansend` and `cangen`.
- `BASE-HWT-02` **MUST** `i2c-tools` is installed and provides at least `i2cdetect`, `i2cget` and `i2cset`.
- `BASE-HWT-03` **MUST** `picocom` is installed.
- `BASE-HWT-04` **MUST** `fuser` from `psmisc` is installed and lists the processes that hold a file or device node open.
- `BASE-HWT-05` **MUST** `usbutils` and `raspi-gpio` are installed for diagnostics.
- `BASE-HWT-06` **MUST** `pciutils`, `spitools` and `rpi-gpio` are not part of the image.

### 4.2 Kernel Support

- `BASE-HWT-10` **MUST** The kernel module for the CAN controller defined in the hardware specification is part of the image and loads automatically from the device tree.
- `BASE-HWT-11` **MUST** The CAN controller appears as a network interface after boot without manual action.
- `BASE-HWT-12` **MUST** `i2c-dev` loads at boot, so that all I2C buses of the hardware specification are available as `/dev/i2c-*`.
- `BASE-HWT-13` **MUST** All serial interfaces of the hardware specification are available as device nodes after boot.
- `BASE-HWT-14` **MUST** No `spidev` device node exists. Both chip selects of SPI0 are bound to kernel drivers (CAN, TPM).

### 4.3 udev Rules

- `BASE-HWT-20` **MUST** udev rules assign one persistent name per UART: `/dev/serial-com14` (`ttyAMA0`, COM1/COM4) and `/dev/serial-com23` (`ttySC0`, COM2/COM3). The names do not depend on probe order.
- `BASE-HWT-21` **MUST** udev rules assign a persistent name to the CAN interface.
- `BASE-HWT-22` **MUST** udev rules set the serial device nodes to `root:fieldbus`, mode `0660`. No node is world-writable.
- `BASE-HWT-23` **MUST** The rule files are installed under `/etc/udev/rules.d/` by a recipe of this layer.
- `BASE-HWT-24` **MUST** The group `fieldbus` is created by the recipe of this module. `user` and the services of the application layer that access field buses are members.
- `BASE-HWT-25` **MUST** Both UARTs can be switched between RS-232 and RS-485 by software, through the Linux RS-485 API (`TIOCSRS485`, `struct serial_rs485`). In RS-485 mode, the kernel driver controls the transmit direction with RTS (`ttyAMA0`: GPIO17; `ttySC0`: RTS of the SC16IS740).
- `BASE-HWT-26` **MUST** No component switches the RS-485 direction by direct register or GPIO access through `/dev/mem` or `/dev/gpiomem`.

### 4.4 Service Port

- `BASE-HWT-30` **MUST** `ttyAMA0` (COM1/COM4) can be used as service port. When the service port is on, the device writes the kernel log and the journal to `ttyAMA0`. The service port offers no login (`BASE-INIT-40`).
- `BASE-HWT-31` **MUST** Service port and field bus use of `ttyAMA0` exclude each other. While the service port is on, `ttyAMA0` and `/dev/serial-com14` are not accessible to the group `fieldbus`. While it is off, the device writes nothing to `ttyAMA0`.
- `BASE-HWT-32` **MUST** root switches the service port on and off with a command (`modberry-serviceport on|off|status`). The state is stored persistently on the data partition and applied at boot.
- `BASE-HWT-33` **MUST** Pressing the user button (GPIO13) switches the service port on for 30 minutes. Afterwards it returns to the stored state.
- `BASE-HWT-34` **MUST** In the production image, the service port is off by default.
- `BASE-HWT-35` **MUST** Every change of the service port state (command, button, timeout) is logged to the journal with the trigger.
- `BASE-HWT-36` **MAY** In the debug image, the service port is on by default and offers a login (`BASE-INIT-41`).

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/modules-load.d/` | `i2c-dev` | `BASE-HWT-12` |
| `/etc/udev/rules.d/60-modberry-serial.rules` | `KERNEL=="ttyAMA0", SYMLINK+="serial-com14"`; `KERNEL=="ttySC0", SYMLINK+="serial-com23"`; `GROUP="fieldbus", MODE="0660"` | `BASE-HWT-20`, `BASE-HWT-22` |
| `/etc/udev/rules.d/<nn>-modberry-can.rules` | `NAME=` for the CAN netdev | `BASE-HWT-21` |
| Device tree / pinmux | GPIO17 as RTS of the PL011 UART (`ttyAMA0`); SC16IS740 RTS wired to the transceiver; no `linux,rs485-enabled-at-boot-time` (the application selects the mode) | `BASE-HWT-25` |
| `/usr/sbin/modberry-serviceport` | `on` / `off` / `status`; state in `/data/serviceport/state` | `BASE-HWT-32` |
| `modberry-serviceport.service` | when on: `chown root:root`, `chmod 0600` on `ttyAMA0`, then `journalctl -f -o short-precise` (kernel and system) to `ttyAMA0` at 115200 baud; `Restart=on-failure` | `BASE-HWT-30`, `BASE-HWT-31` |
| `modberry-serviceport-button.service` | waits for GPIO13 (`gpiomon`), starts the service port for 30 minutes, then restores the stored state | `BASE-HWT-33` |
| Kernel command line in the FIT | no `console=ttyAMA0` / `console=serial0` in the production image | `BASE-HWT-31`, `BASE-HWT-34` |

---

## 6. Interfaces to Other Modules

### Provides

- Persistent serial device names – used by applications and `BASE-AUDIT` (watch rules on serial interfaces).
- Persistent CAN interface name – used by `BASE-NETD` (CAN `.network` file) and `BASE-MAC` (AppArmor profiles).
- Access groups for serial and SPI nodes – used by `BASE-MAC` and the application layer.
- Service port on `ttyAMA0` – used by service technicians; its state tells the application whether COM1/COM4 is available.

### Consumes

- systemd-udevd and unit integration rules – owned by `BASE-INIT` (`BASE-INIT-20` … `BASE-INIT-22`).
- Device tree nodes for CAN, I2C, UART, SPI, user button (GPIO13) – owned by the hardware specification.
- Persistent data partition for the service port state – owned by `BASE-ROOTFS`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-HWT-01` | `manifest` | `can-utils` in image manifest | present |
| `BASE-HWT-02` | `manifest` | `i2c-tools` in image manifest | present |
| `BASE-HWT-03` | `manifest` | `picocom` in image manifest | present |
| `BASE-HWT-04` | `manifest` | `fuser` in image manifest | present |
| `BASE-HWT-04` | `device` | `fuser -v /dev/ttyAMA0` while `picocom` is open on it | `picocom` listed |
| `BASE-HWT-05`, `-06` | `manifest` | `usbutils`, `raspi-gpio` / `pciutils`, `spitools`, `rpi-gpio` in image manifest | present / absent |
| `BASE-HWT-10` | `rootfs` | `find <rootfs>/lib/modules -name 'mcp251x.ko*'` | found |
| `BASE-HWT-11` | `device` | `ip -details link show type can` | one CAN interface listed |
| `BASE-HWT-12` | `device` | `ls /dev/i2c-*` | all buses of hardware spec 3.1 present |
| `BASE-HWT-13` | `device` | `ls -l /dev/ttyAMA0 /dev/ttySC0` | both present |
| `BASE-HWT-14` | `device` | `ls /dev/spidev*` | no such file |
| `BASE-HWT-20` | `device` | Reboot twice, `ls -l /dev/serial-com14 /dev/serial-com23` | → `ttyAMA0`, `ttySC0` every time |
| `BASE-HWT-21` | `device` | `ip link show <can name>` | present after every boot |
| `BASE-HWT-22` | `device` | `stat -c '%U:%G %a' <nodes>` | defined owner/group, no world-write bit |
| `BASE-HWT-23` | `rootfs` | `ls <rootfs>/etc/udev/rules.d/` | layer rule files present |
| `BASE-HWT-24` | `device` | `getent group fieldbus` | group exists, `user` is member |
| `BASE-HWT-25` | `device` | Set RS-485 mode with `TIOCSRS485` (e.g. a small test tool), send a frame, observe RTS/DE with a scope or an RS-485 adapter; switch back to RS-232 | frame received in both modes; RTS active only while sending |
| `BASE-HWT-26` | `rootfs` | Search the layer and the image for `/dev/mem` / `/dev/gpiomem` access in RS-485 code | none |
| `BASE-HWT-30` | `device` | `modberry-serviceport on`; terminal on COM1 | journal and kernel messages visible; no login prompt |
| `BASE-HWT-31` | `device` | Service port on: open `/dev/serial-com14` as member of `fieldbus`; service port off: watch COM1 | permission denied; no output |
| `BASE-HWT-32` | `device` | `modberry-serviceport on`, reboot, `modberry-serviceport status` | `on` after reboot |
| `BASE-HWT-33` | `device` | Service port off, press the user button, wait 30 minutes | on for 30 minutes, then off |
| `BASE-HWT-34` | `device` | Fresh production image, `modberry-serviceport status` | `off` |
| `BASE-HWT-35` | `device` | Switch by command and by button, `journalctl -t modberry-serviceport` | one entry per change with the trigger |

---

## 8. Constraints & Risks

- `BASE-HWT-30`: the kernel command line is part of the signed FIT image (`BASE-VBOOT`, `BASE-MBOOT`) and cannot be changed at runtime. The service port therefore shows messages only from the start of journald; U-Boot and early kernel messages are not available on it in the production image.
- `BASE-HWT-31`: today, `cmdline.txt` contains `console=serial0,115200` and `console=tty1`. Both are removed in the production image (`BASE-INIT-40`).
- `BASE-HWT-25`: the RS-485 support of the PL011 driver (`amba-pl011`) was added to the mainline kernel only after 5.15 (around 5.18, to be verified). The kirkstone kernel (5.15) may not support `TIOCSRS485` on `ttyAMA0` (open point 9). `sc16is7xx` supports it.
- `BASE-HWT-26`: the approach of <https://sourceforge.net/p/arduino-icsc/wiki/Raspberry%20Pi/> (direction GPIO set through `/dev/mem`) needs root and `/dev/mem`, which `BASE-BUILD-11` disables. It is not used.
- `BASE-HWT-33`: the user button needs a GPIO input with debouncing; `gpiomon` comes from `libgpiod-tools`, which must be added to the components.
- A CAN interface is a network device. udev `GROUP`/`MODE` have no effect on it. Access to raw CAN sockets is controlled by `CAP_NET_RAW`, not by file permissions.
- `spi0-2cs.dtbo` creates `spidev0.0` and `spidev0.1` by default. Both chip selects are bound to kernel drivers (CAN, TPM), so both `spidev` nodes must be disabled in the device tree (`BASE-HWT-14`). The machine conf also autoloads `spidev` and installs `spitools`; both are removed.
- With `INIT_MANAGER = "systemd"`, udev is provided by systemd. The explicit `udev` entry in `IMAGE_INSTALL` of the machine conf must not pull in `eudev`.
- The machine conf installs packages that this specification does not list: `spitools`, `rpi-gpio`, `raspi-gpio`, `usbutils`, `pciutils`. `pciutils` has no use, because PCIe is not available on this hardware variant (hardware spec, section 6).

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Naming scheme for persistent serial names: `/dev/com1` … `/dev/com4`, or by function (e.g. `/dev/rs485-1`)? COM1/COM4 and COM2/COM3 share one UART each. | `BASE-HWT-20`, `BASE-HWT-24` | **Decided:** `/dev/serial-com14`, `/dev/serial-com23` (one name per UART). |
| 2 | Which groups get access to serial and SPI nodes (`dialout`, `bynacon`, a new group)? | `BASE-HWT-22` | **Decided:** new group `fieldbus` (`BASE-HWT-24`). |
| 3 | Which `spidev` nodes should exist at all? If none, the SPI udev rule is not needed. | `BASE-HWT-14`, `BASE-HWT-22` | **Decided:** none; the SPI udev rule is not needed. |
| 4 | CAN bitrate and automatic bring-up at boot: owned by `BASE-NETD` – confirm. | `BASE-HWT-11` | **Decided:** owned by `BASE-NETD` (`BASE-NETD-40`, 125 kbit/s). |
| 5 | Keep, remove or add to this spec: `spitools`, `rpi-gpio`, `raspi-gpio`, `usbutils`, `pciutils`? | Components | **Decided:** keep `usbutils`, `raspi-gpio`; remove `pciutils`, `spitools`, `rpi-gpio`. |
| 6 | How long does the service port stay on after pressing the user button? | `BASE-HWT-33` | **Decided:** 30 minutes. |
| 7 | How are the UARTs switched between RS-232 and RS-485 (jumper, GPIO, expander pin)? | `BASE-HWT-25` | **Decided:** by software (Linux RS-485 API, direction via RTS); no jumper. |
| 9 | Does the kirkstone kernel (5.15) support RS-485 mode (`TIOCSRS485`) on the PL011 UART (`ttyAMA0`)? If not: backport of the driver change, or kernel update. | `BASE-HWT-25` | **Deferred:** check on the device → verification task. |
| 8 | Function of the service port. | `BASE-HWT-30` … `BASE-HWT-36` | **Decided:** `ttyAMA0` is the service port; log output only, no login; switched by root command and temporarily by the user button; off by default; exclusive with field bus use. |
