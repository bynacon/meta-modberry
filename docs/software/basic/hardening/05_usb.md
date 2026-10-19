# USB Device Control (USBGuard)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-USB` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
| **Depends on** | `BASE-INIT` |
| **Hardware reference** | [M40804W_MAX.md](../../../hardware/M40804W_MAX.md) – section 5 (LAN9514 USB hub and Ethernet) |
| **Risk** | `high` |

---

## 1. Purpose

This module blocks unauthorized USB devices. USBGuard allows only the USB devices of the hardware itself and explicitly listed devices. Every other device that is plugged in is blocked automatically, before a driver can bind to it.

---

## 2. Scope

### In scope

- USBGuard daemon and its policy.
- Allow list of internal and explicitly permitted external USB devices.
- Behavior for devices present at boot and for newly connected devices.
- Logging of blocked devices.

### Out of scope

- USB host hardware and the LAN9514 hub → hardware specification
- Network configuration of the LAN9514 Ethernet port (`lan1`) → `BASE-NETD`
- Possible second WLAN radio via USB → `BASE-WAP` (section 8)

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `usbguard` 1.1.1 | `meta-openembedded` (meta-oe) | — |
| `modberry-usbguard-policy` (new) | `meta-modberry` | — |

---

## 4. Requirements

### 4.1 Policy

- `BASE-USB-01` **MUST** USBGuard runs from early boot, before the USB devices are enumerated by user space.
- `BASE-USB-02` **MUST** The default policy is `block` for every device that matches no rule (`ImplicitPolicyTarget=block`).
- `BASE-USB-03` **MUST** Devices that are present at boot are checked against the rules too (`PresentDevicePolicy=apply-policy`).
- `BASE-USB-04` **MUST** The internal USB devices of the hardware are allowed: the LAN9514 hub and its Ethernet controller. They are matched by vendor/product ID **and** port (`via-port`), so that an external device with the same IDs is not allowed.
- `BASE-USB-05` **MUST** External devices are allowed only by explicit rules (section 5.1): one defined service USB stick, one defined USB WLAN adapter, one defined LTE modem. Each is matched by vendor/product ID and the external port; the service stick also by serial number.
- `BASE-USB-06` **MUST** The kernel authorizes no USB device by default (`usbcore.authorized_default=0`); only USBGuard authorizes devices.
- `BASE-USB-07` **MUST** The USB controller of the CM4 runs in host mode only. USB device (gadget) mode is disabled.

### 4.2 Operation

- `BASE-USB-10` **MUST** Every blocked device is logged to the journal with vendor/product ID, serial number and port.
- `BASE-USB-11` **MUST** The policy file is installed by the recipe of this module and is readable only by root (`0600`).
- `BASE-USB-12` **MUST** The USBGuard IPC interface is accessible only to root.
- `BASE-USB-13` **MAY** In the debug image, `ImplicitPolicyTarget=allow` with logging is used.

---

## 5. Configuration

### 5.1 Allow List

<!-- Vendor/product IDs and ports must be read on the device (open point 1). -->

| Device | Rule | Req. |
| :-- | :-- | :-- |
| LAN9514 USB hub | `allow id 0424:9514 via-port "<port>"` | `BASE-USB-04` |
| LAN9514 Ethernet (`smsc95xx`) | `allow id 0424:ec00 via-port "<port>"` | `BASE-USB-04` |
| Root hubs of the CM4 | `allow with-interface 09:00:*` on the internal bus only | `BASE-USB-04` |
| Service USB stick (defined model) | `allow id <vid:pid> serial "<serial>" via-port "<external port>"` | `BASE-USB-05` |
| USB WLAN adapter (defined model) | `allow id <vid:pid> via-port "<external port>"` | `BASE-USB-05` |
| LTE modem (defined model) | `allow id <vid:pid> via-port "<external port>"` | `BASE-USB-05` |

### 5.2 Files

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/usbguard/usbguard-daemon.conf` | `ImplicitPolicyTarget=block`, `PresentDevicePolicy=apply-policy`, `PresentControllerPolicy=keep`, `IPCAllowedUsers=root` | `BASE-USB-02`, `BASE-USB-03`, `BASE-USB-12` |
| `/etc/usbguard/rules.conf` | rules of section 5.1, mode `0600` | `BASE-USB-04`, `BASE-USB-05`, `BASE-USB-11` |
| `usbguard.service.d/` | `DefaultDependencies=no`, `Before=sysinit.target` (or as early as the unit allows) | `BASE-USB-01` |
| `cmdline.txt` / kernel command line in the FIT | `usbcore.authorized_default=0` | `BASE-USB-06` |
| Machine conf / `config.txt` | `ENABLE_DWC2_PERIPHERAL` removed; `dtoverlay=dwc2,dr_mode=host` (or no gadget support) | `BASE-USB-07` |

---

## 6. Interfaces to Other Modules

### Provides

- USB allow list – used by `BASE-NETD` (`lan1` depends on the LAN9514 being allowed) and by `BASE-WAP` (a possible second radio).
- Block events in the journal – used by `BASE-LOG` / `BASE-LOGDB` and `BASE-AUDIT`.

### Consumes

- Service integration rules – owned by `BASE-INIT`.
- USB topology of the board – owned by the hardware specification.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-USB-01` | `device` | `systemd-analyze critical-chain usbguard.service` | starts before network configuration |
| `BASE-USB-02` | `device` | Plug in an unknown USB stick | blocked; no block device appears |
| `BASE-USB-03` | `device` | Boot with an unknown USB stick plugged in | blocked |
| `BASE-USB-04` | `device` | `usbguard list-devices`; `networkctl status lan1` | hub and Ethernet `allow`; `lan1` works |
| `BASE-USB-04` | `device` | External device with spoofed LAN9514 IDs on the external port (lab) | blocked |
| `BASE-USB-07` | `device` | `cat /sys/kernel/config/usb_gadget/` / `ls /sys/class/udc/` | no UDC available |
| `BASE-USB-10` | `device` | `journalctl -u usbguard` after plugging in an unknown device | entry with IDs, serial, port |
| `BASE-USB-11` | `rootfs` | `stat -c '%a' <rootfs>/etc/usbguard/rules.conf` | `600` |
| `BASE-USB-12` | `device` | `usbguard list-devices` as `user` | access denied |

---

## 8. Constraints & Risks

- **The second Ethernet port (`lan1`) is a USB device** (LAN9514). A missing or wrong rule disables `lan1` and the USB host port. Every policy change is tested with console access (human gate).
- `via-port` values depend on the USB topology of the board. They must be read on the device (`usbguard generate-policy`) and are then fixed for this hardware variant.
- With `usbcore.authorized_default=0`, `lan1` and the USB port work only after USBGuard has started.
- An LTE modem is a further uplink. It is not yet specified in `BASE-NETD` and `BASE-FWP` (see `README.md`, open points).
- USBGuard blocks at the authorization level of the kernel. A device that is blocked is still powered and visible in `lsusb`, but no driver binds to it.
- If USBGuard fails to start, the kernel default (authorize all) applies. `BASE-INIT-23` (restart) and `BASE-KERN-21` (reboot after start limit) limit this window.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Read the vendor/product IDs and ports of the internal USB devices on the device (`usbguard generate-policy`). | `BASE-USB-04` | **Deferred:** read on the device → verification task. |
| 2 | Which external USB devices are allowed (service USB stick for provisioning/diagnostics, USB WLAN radio, USB modem)? | `BASE-USB-05` | **Decided:** service USB stick, USB WLAN adapter, LTE modem (one defined model each). Models and IDs follow. |
| 3 | Should USBGuard be the only mechanism, or should the kernel default be "deny" as well (`usbcore.authorized_default=0` on the kernel command line)? | `BASE-USB-01` | **Decided:** kernel default deny in addition (`BASE-USB-06`). |
