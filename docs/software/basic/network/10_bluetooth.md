# Bluetooth Low Energy (BlueZ)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-BLE` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-INIT` |
| **Hardware reference** | [M40804W_MAX.md](../../../hardware/M40804W_MAX.md) – CM4 Bluetooth (BCM43455) |
| **Risk** | `medium` |

---

## 1. Purpose

This module provides Bluetooth Low Energy for reading BLE sensors. The device acts as BLE central: it scans for sensors and connects only to allowed devices. Classic Bluetooth (BR/EDR) is disabled, the device is not discoverable, and pairing uses LE Secure Connections only.

---

## 2. Scope

### In scope

- BlueZ in LE-only mode, controller attachment over UART.
- Roles, discoverability, pairing and allow list.
- Access control to the Bluetooth API.

### Out of scope

- Application that reads the sensors → application layer
- AppArmor profile of `bluetoothd` → `BASE-MAC`
- Assignment of the UARTs → hardware specification

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `bluez5` (`bluetoothd`, `btattach` via `bluez5-noinst-tools` only in debug) | `poky` (openembedded-core) | — |
| `linux-firmware-rpidistro-bcm43455` (BT patch file) | `meta-raspberrypi` | — |
| Overlay `miniuart-bt` | `meta-raspberrypi` | — |

---

## 4. Requirements

### 4.1 Controller

- `BASE-BLE-01` **MUST** The Bluetooth controller is attached on the mini UART (`miniuart-bt`), so that the PL011 UART stays available for `ttyAMA0` (COM1/COM4).
- `BASE-BLE-02` **MUST** BlueZ runs in LE-only mode. BR/EDR (Classic) is disabled.
- `BASE-BLE-03` **MUST** The distro feature `bluetooth` is set in the distro conf, not in the machine conf.

### 4.2 Roles & Pairing

- `BASE-BLE-10` **MUST** The device is not discoverable and does not advertise.
- `BASE-BLE-11` **MUST** Pairing and bonding use LE Secure Connections only. Legacy pairing is refused.
- `BASE-BLE-12` **MUST** The device connects only to sensors in an allow list (address or identity resolving key). The allow list is provisioned or managed by the application layer.
- `BASE-BLE-13` **MUST** No Bluetooth profile is offered that gives access to the system (no PAN/BNEP networking, no serial port profile, no OBEX).

### 4.3 Access Control

- `BASE-BLE-20` **MUST** Only root and members of the group `bluetooth` can use the BlueZ D-Bus API and raw HCI sockets.
- `BASE-BLE-21` **MUST** Pairing, bonding and connection events are logged to the journal.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| Machine conf | `RPI_KERNEL_DEVICETREE_OVERLAYS:append = " overlays/miniuart-bt.dtbo"` (kept) | `BASE-BLE-01` |
| Distro conf `modberry` | `DISTRO_FEATURES:append = " bluetooth"` (moved from machine conf) | `BASE-BLE-03` |
| `/etc/bluetooth/main.conf` | `[General] ControllerMode = le`, `Discoverable = false`, `DiscoverableTimeout = 0`, `Privacy = device`, `SecureConnections = only` | `BASE-BLE-02`, `BASE-BLE-10`, `BASE-BLE-11` |
| `bluetooth.service.d/` | `ExecStart=… --noplugin=sap,network,input,hog` (only the plugins needed for LE sensors) | `BASE-BLE-13` |
| `/etc/dbus-1/system.d/bluetooth.conf` | `allow` for group `bluetooth` only | `BASE-BLE-20` |
| Build: production image | no `bluez5-noinst-tools`, `bluez5-obex` | `BASE-BLE-13` |

---

## 6. Interfaces to Other Modules

### Provides

- BlueZ D-Bus API (LE central) – used by the application layer (group `bluetooth`).
- Bluetooth events in the journal – used by `BASE-LOG`.

### Consumes

- UART assignment – owned by the hardware specification.
- Distro conf – owned by `BASE-INIT`.
- AppArmor profile for `bluetoothd` – owned by `BASE-MAC`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-BLE-01` | `device` | `hciconfig -a` / `btmgmt info`; `ls -l /dev/ttyAMA0` | controller on the mini UART; `ttyAMA0` free for COM1/COM4 |
| `BASE-BLE-02` | `device` | `btmgmt info` | `le` enabled, `br/edr` disabled |
| `BASE-BLE-03` | `build` | `bitbake -e <image> \| grep ^DISTRO_FEATURES=` | contains `bluetooth`; not set in the machine conf |
| `BASE-BLE-10` | `device` | Scan from a phone (Classic and LE) | device not visible |
| `BASE-BLE-11` | `device` | Pair with a test device that supports only legacy pairing | refused |
| `BASE-BLE-12` | `device` | Connect to a sensor outside the allow list via the application | refused |
| `BASE-BLE-13` | `device` | `sdptool browse local` / `bluetoothctl show` | no PAN, SPP or OBEX service |
| `BASE-BLE-20` | `device` | `bluetoothctl list` as a user without group `bluetooth` | access denied |
| `BASE-BLE-21` | `device` | Pair a test sensor, `journalctl -u bluetooth` | event logged |

---

## 8. Constraints & Risks

- `BASE-BLE-01`: with `miniuart-bt`, Bluetooth uses the mini UART, whose baud rate depends on the VPU core clock. The core clock must be fixed (`core_freq` in `config.txt`), otherwise the BT link is unstable.
- `BASE-BLE-10`: BLE and WLAN share the BCM43455 radio (2.4 GHz coexistence). Heavy BLE scanning can reduce WLAN throughput.
- `BASE-BLE-12`: many BLE sensors only broadcast advertisements and need no connection. Reading advertisements does not require pairing; the allow list then applies to the evaluated addresses in the application.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Which BLE sensors are used: advertisements only, or GATT connections with pairing? | `BASE-BLE-11`, `BASE-BLE-12` | |
| 2 | Who manages the allow list (provisioning, web interface)? | `BASE-BLE-12` | |
| 3 | Bluetooth needed. | Scope | **Decided:** yes, BLE for sensors. |
