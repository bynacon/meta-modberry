# USB Service Port (USB gadget)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-USBG` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-NETD`, `BASE-FWP`, `BASE-DNS` |
| **Hardware reference** | [M40804W_MAX.md](../../../hardware/M40804W_MAX.md) – section 5 (USB) |
| **Risk** | `high` |

---

## 1. Purpose

This module gives a service technician local access to the device over a USB cable. The device acts as USB network adapter (USB gadget). The technician's laptop gets an address in a small service segment and can reach SSH and the web interface. Login still requires the normal authentication (SSH key, web login).

---

## 2. Scope

### In scope

- USB device mode of the CM4 USB controller.
- USB network gadget (`usb0`) and its service segment.
- Allowed gadget functions.

### Out of scope

- Firewall openings for the service segment → `BASE-FWP`
- DHCP for the laptop → `BASE-DNS`
- USB host policy (USBGuard) → `BASE-USB`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| Kernel: `dwc2`, `libcomposite`, `usb_f_ncm` | `linux-raspberrypi` | — |
| `modberry-usb-gadget` (new: configfs setup as systemd unit) | `meta-modberry` | — |

---

## 4. Requirements

### 4.1 Gadget

- `BASE-USBG-01` **MUST** The gadget is set up through configfs by a systemd unit of this layer.
- `BASE-USBG-02` **MUST** The gadget offers exactly one function: a CDC-NCM network interface. No mass storage, serial (ACM) console, HID or other function is offered.
- `BASE-USBG-03` **MUST** The gadget uses fixed, per-device MAC addresses (derived from the serial number, `BASE-PROV-33`), so that the laptop sees a stable interface.
- `BASE-USBG-04` **MUST** Enabling device mode does not disable the internal USB devices (LAN9514, `lan1`) – see section 8.

### 4.2 Service Segment

- `BASE-USBG-10` **MUST** `usb0` is its own segment with the subnet `172.30.30.0/29`; the device has `172.30.30.1`.
- `BASE-USBG-11` **MUST** The laptop gets its address by DHCP from `BASE-DNS`; no default route and no DNS server are announced.
- `BASE-USBG-12` **MUST** From `usb0`, only the services of the port matrix (`BASE-FWP-01`, column SVC) are reachable; forwarding only to the IoT segment.

### 4.3 Activation

- `BASE-USBG-20` **SHOULD** The service port is active only for a limited time after a physical action (e.g. pressing the user button, GPIO13) – see open point 1.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `config.txt` / device tree | `dtoverlay=dwc2,dr_mode=<mode>` per hardware (see section 8) | `BASE-USBG-04` |
| `modberry-usb-gadget.service` | configfs: `idVendor`, `idProduct`, one config with `ncm.usb0`, `host_addr`/`dev_addr` from the serial number | `BASE-USBG-01` … `BASE-USBG-03` |
| `/etc/systemd/network/70-usb0.network` | `Address=172.30.30.1/29`, no `DHCPServer=` | `BASE-USBG-10` |
| `/etc/dnsmasq.d/70-usb0.conf` | `dhcp-range=usb0,172.30.30.2,172.30.30.6,1h`, `dhcp-option=usb0,3`, `dhcp-option=usb0,6` (empty router and DNS) | `BASE-USBG-11` |

---

## 6. Interfaces to Other Modules

### Provides

- Interface `usb0` and the service segment `172.30.30.0/29` – used by `BASE-FWP` (column SVC), `BASE-DNS`, `BASE-WEB` (`allow`).

### Consumes

- Port matrix and forward rules – owned by `BASE-FWP`.
- DHCP – owned by `BASE-DNS`.
- Serial number – owned by `BASE-PROV`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-USBG-01` | `device` | `systemctl status modberry-usb-gadget`; `ls /sys/kernel/config/usb_gadget/` | active; one gadget |
| `BASE-USBG-02` | `device` | Connect a laptop, `lsusb -v` on the laptop | one NCM interface only |
| `BASE-USBG-03` | `device` | Reconnect the laptop twice | same MAC addresses |
| `BASE-USBG-04` | `device` | Gadget active, `networkctl status lan1`; `usbguard list-devices` | `lan1` up, LAN9514 present |
| `BASE-USBG-10`, `-11` | `device` | Laptop: `ip addr`, `ip route` | address in `172.30.30.0/29`, no default route via the device |
| `BASE-USBG-12` | `device` | Laptop: `nmap 172.30.30.1`; ping an IoT device; ping the internet | only SVC ports; IoT reachable; no internet |
| `BASE-USBG-20` | `device` | Without button press, connect the laptop | no `usb0` (if open point 1 is decided for the button) |

---

## 8. Constraints & Risks

- `BASE-USBG-01`: the current machine conf sets `ENABLE_DWC2_HOST = "1"` and `ENABLE_DWC2_PERIPHERAL = "1"`; the resulting `dr_mode` must be checked.
- `BASE-USBG-02`: an ACM serial function would offer a console without network authentication; it is excluded on purpose.
- `BASE-USBG-04`: **hardware conflict to clarify.** The CM4 has one USB 2.0 controller (`dwc2`). On this board it is connected to the LAN9514 hub (USB host port and `lan1`, hardware specification section 5). If this controller runs in device mode, the LAN9514 is disconnected. Device mode is only possible if the board routes the CM4 USB to a separate service connector (e.g. through a USB switch or OTG ID pin). This module is blocked until the hardware is confirmed (open point 2).
- `BASE-USBG-12`: anyone with physical access and a cable reaches the login of SSH and the web interface. Authentication is still required; `BASE-USBG-20` limits the exposure.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Is the service port always active, or only for a limited time after pressing the user button (GPIO13)? Duration? | `BASE-USBG-20` | |
| 2 | Does the board have a USB connector for device mode that does not disconnect the LAN9514? | `BASE-USBG-04` | **Deferred:** needs the schematic → verification task. |
| 3 | USB service access needed. | Scope | **Decided:** yes. |
