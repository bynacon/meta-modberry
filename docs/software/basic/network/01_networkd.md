# Network Configuration (systemd-networkd)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-NETD` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
| **Depends on** | `BASE-INIT` |
| **Hardware reference** | [M40804W_MAX.md](../../../hardware/M40804W_MAX.md) – section 5 (Ethernet), section 3.2 (CAN) |
| **Risk** | `medium` |

---

## 1. Purpose

This module configures all network interfaces of the device with systemd-networkd. It defines the network segments of the device and keeps them isolated from each other: the service and uplink network (LAN0) and the IoT network for sensors and actuators (LAN1 and the IoT WLAN). It also defines the interface names, the address plan and the uplink that all other network modules use.

---

## 2. Scope

### In scope

- systemd-networkd as the only network configuration daemon.
- Network segments and the IoT bridge.
- Interface naming (`.link` files) and address plan for all segments.
- `.network` / `.netdev` files for both Ethernet ports, the IoT bridge, the WLAN client interface and the CAN interface.
- Uplink selection with fallback, and `systemd-networkd-wait-online`.

### Out of scope

- WLAN AP interface (`wlan0_iot`) and its `.netdev` / `.network` files → `BASE-WAP`
- WireGuard interface and its `.network` / `.netdev` files → `BASE-VPN`
- Service AP interface `wlan0_svc` → `BASE-WAP`
- WLAN client authentication (iwd) → `BASE-WCLI`
- Packet filtering → `BASE-FW`; forwarding and NAT rules → `BASE-FWP`
- DHCP server and DNS forwarder for the local segments → `BASE-DNS`
- Thread interface `wpan0` → `THREAD-OTD`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `systemd` (networkd) | `poky` (openembedded-core) | `dhcpcd`, `init-ifupdown`, `ifplugd` |
| `iproute2` (`ip`, `bridge`) | `poky` (openembedded-core) | busybox `ip` |
| `systemd` (resolved) | `poky` (openembedded-core) | static `/etc/resolv.conf` |
| `modberry-network-config` (new) | `meta-modberry` | `.network` files in `systemd_%.bbappend` |
| — | — | `bridge-utils` (networkd creates the bridge, `iproute2` provides `bridge`) |

---

## 4. Requirements

### 4.1 Network Daemon

- `BASE-NETD-01` **MUST** systemd-networkd is the only network configuration daemon. `dhcpcd`, `init-ifupdown`, `ifplugd`, `connman` and `NetworkManager` are not part of the image.
- `BASE-NETD-02` **MUST** `.link`, `.network` and `.netdev` files are installed under `/etc/systemd/network/`. Each file is installed by the module that owns the interface (see section 6).
- `BASE-NETD-03` **MUST** Interfaces are not configured by udev `RUN` scripts, `ifup`, or `iw` calls at boot.
- `BASE-NETD-04` **MUST** `iproute2` is installed for diagnostics (`ip`, `bridge`).

### 4.2 Network Segments

- `BASE-NETD-10` **MUST** The device provides the segments of the address plan (section 5.1): LAN0 (service and uplink), IoT (sensors and actuators), and the service segment of the service AP (`BASE-WAP-40`, service mode only).
- `BASE-NETD-11` **MUST** The IoT segment is one bridge `br-iot`. Its members are the LAN1 Ethernet port and the IoT WLAN interface (`wlan0_iot`, owned by `BASE-WAP`).
- `BASE-NETD-12` **MUST** No interface of one segment is a member of another segment. LAN0 is never bridged.
- `BASE-NETD-13` **MUST** Bridges are defined as systemd-networkd `.netdev` files.
- `BASE-NETD-14` **MUST** IP forwarding is enabled only on interfaces whose traffic is routed by the forward matrix of `BASE-FWP`.

### 4.3 Naming & Addressing

- `BASE-NETD-20` **MUST** Both Ethernet ports get persistent names (`lan0`, `lan1`) via `.link` files that match the driver or the device path, not the probe order.
- `BASE-NETD-21` **MUST** The device has a static address in the IoT segment (section 5.1).
- `BASE-NETD-22` **MUST** `lan0` gets its address via DHCP from the upstream network.
- `BASE-NETD-23` **MUST** IPv6 link-local addressing is enabled on all segments (required for Thread border routing).
- `BASE-NETD-24` **MUST** The WLAN client interface gets its address via DHCP from networkd, not from iwd.
- `BASE-NETD-25` **MUST** `systemd-resolved` is the DNS resolver of the device. It uses the DNS servers of the active uplink; `/etc/resolv.conf` points to its stub resolver.
- `BASE-NETD-26` **MUST** The mDNS and LLMNR functions of `systemd-resolved` are disabled (Avahi provides mDNS, see `THREAD-OTBR`).

### 4.4 Uplink

- `BASE-NETD-30` **MUST** `lan0` is the preferred uplink. The WLAN client `wlan1_sta` (USB WLAN adapter, if fitted) is the fallback uplink.
- `BASE-NETD-31` **MUST** The default route via `lan0` has a lower metric than the default route via `wlan1_sta`, so that traffic uses `wlan1_sta` only while `lan0` has no carrier or no lease.
- `BASE-NETD-32` **MUST** `systemd-networkd-wait-online` waits for any one of the uplinks, so that the boot does not block on a missing uplink or on unconnected segments.

### 4.5 CAN Interface

- `BASE-NETD-40` **MUST** The CAN interface is brought up at boot with a bitrate of 125 kbit/s.

---

## 5. Configuration

### 5.1 Address Plan

| Segment | Interface | Physical | IPv4 subnet | Device address | Status |
| :-- | :-- | :-- | :-- | :-- | :-- |
| LAN0 – service & uplink | `lan0` | CM4 Gigabit port (`bcmgenet`) | DHCP from upstream | DHCP | decided |
| IoT – sensors & actuators | `br-iot` (`lan1` + `wlan0_iot`) | LAN9514 port (`smsc95xx`) + IoT SSID | `172.30.10.0/24` | `172.30.10.1` | decided |
| Uplink fallback | `wlan1_sta` | WLAN client on the USB WLAN adapter (optional) | DHCP | DHCP | decided |
| VPN | `wg0` | WireGuard | per `BASE-VPN` | per `BASE-VPN` | open |
| Service (service mode only) | `wlan0_svc` | service AP (`BASE-WAP-40`) | `172.30.30.0/29` | `172.30.30.1` | decided |
| CAN | `can0` | MCP2515 | — | — | 125 kbit/s |

### 5.2 Files

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/systemd/network/10-lan0.link` | `[Match] Driver=bcmgenet`, `[Link] Name=lan0` | `BASE-NETD-20` |
| `/etc/systemd/network/10-lan1.link` | `[Match] Driver=smsc95xx`, `[Link] Name=lan1` | `BASE-NETD-20` |
| `/etc/systemd/network/20-lan0.network` | `DHCP=yes`, `[DHCPv4] RouteMetric=100` | `BASE-NETD-22`, `BASE-NETD-31` |
| `/etc/systemd/network/30-br-iot.netdev` | `Kind=bridge`, `Name=br-iot` | `BASE-NETD-11`, `BASE-NETD-13` |
| `/etc/systemd/network/30-br-iot.network` | `Address=172.30.10.1/24`, `IPForward=` per `BASE-FWP` | `BASE-NETD-21`, `BASE-NETD-14` |
| `/etc/systemd/network/30-lan1.network` | `Bridge=br-iot` | `BASE-NETD-11` |
| `/etc/systemd/network/40-wlan1_sta.network` | `DHCP=yes`, `[DHCPv4] RouteMetric=600` | `BASE-NETD-24`, `BASE-NETD-31` |
| `/etc/systemd/network/50-can0.network` | `[CAN] BitRate=125000` | `BASE-NETD-40` |
| `/etc/systemd/resolved.conf` | `MulticastDNS=no`, `LLMNR=no` | `BASE-NETD-26` |
| `/etc/resolv.conf` | symlink to `/run/systemd/resolve/stub-resolv.conf` | `BASE-NETD-25` |
| `*.network` | `LinkLocalAddressing=ipv6` (at least) | `BASE-NETD-23` |
| `systemd-networkd-wait-online.service.d/` | `--any --interface=lan0 --interface=wlan1_sta` | `BASE-NETD-32` |

---

## 6. Interfaces to Other Modules

### Provides

- Interface names, segments and address plan – used by `BASE-FW`, `BASE-FWP`, `BASE-WAP`, `BASE-DNS`, `BASE-TIME`, `BASE-VPN`, `THREAD-*`.
- Bridge `br-iot` – used by `BASE-WAP` (hostapd adds `wlan0_iot` with `bridge=br-iot`).
- Convention for `.link` / `.network` / `.netdev` files (`BASE-NETD-02`) – binding for `BASE-WAP` and `BASE-VPN`.
- Uplink interfaces `lan0`, `wlan1_sta` – used by `BASE-FWP` (output rules).
- DNS stub resolver `127.0.0.53` – used by `BASE-DNS` (dnsmasq upstream) and all services of the device.
- `can0` up at boot – used by the application layer.

### Consumes

- Service integration rules – owned by `BASE-INIT`.
- Persistent CAN interface name – owned by `BASE-HWT` (`BASE-HWT-21`).
- WLAN client connection – owned by `BASE-WCLI`.
- Ethernet ports – owned by the hardware specification (section 5).

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-NETD-01` | `manifest` | `dhcpcd`, `init-ifupdown`, `ifplugd`, `connman`, `networkmanager`, `bridge-utils` in image manifest | absent |
| `BASE-NETD-01` | `device` | `systemctl is-active systemd-networkd` | `active` |
| `BASE-NETD-02` | `rootfs` | `ls <rootfs>/etc/systemd/network/` | only files listed in the owning modules |
| `BASE-NETD-03` | `rootfs` | `grep -r 'RUN+=' <rootfs>/etc/udev/rules.d/` | no network setup commands |
| `BASE-NETD-04` | `manifest` | `iproute2` in image manifest | present |
| `BASE-NETD-10` | `device` | `networkctl list` | `lan0`, `br-iot` present and configured |
| `BASE-NETD-11` | `device` | `bridge link` | `lan1` and `wlan0_iot` are ports of `br-iot` |
| `BASE-NETD-12` | `device` | `bridge link` | `lan0`, `wlan1_sta` are not bridge ports |
| `BASE-NETD-14` | `device` | `sysctl net.ipv4.conf.<if>.forwarding` per interface | `1` only on routed interfaces |
| `BASE-NETD-20` | `device` | Reboot twice, `ip link` | `lan0`, `lan1` always on the same physical port |
| `BASE-NETD-21` | `device` | `ip -4 addr show br-iot` | `172.30.10.1/24` |
| `BASE-NETD-22` | `device` | `networkctl status lan0` | address from DHCP |
| `BASE-NETD-23` | `device` | `ip -6 addr show scope link` | link-local address on every segment |
| `BASE-NETD-24` | `device` | `networkctl status wlan1_sta` | address from DHCP via networkd |
| `BASE-NETD-25` | `device` | `resolvectl status`; `readlink /etc/resolv.conf` | DNS servers of the active uplink; stub resolver |
| `BASE-NETD-26` | `device` | `resolvectl status` | `-mDNS -LLMNR` |
| `BASE-NETD-30`, `-31` | `device` | `ip route show default` with `lan0` connected, then unplugged | via `lan0` (metric 100); after unplug via `wlan1_sta` |
| `BASE-NETD-32` | `device` | Boot with `lan0` unplugged and `wlan1_sta` connected | boot does not wait for `lan0` |
| `BASE-NETD-40` | `device` | `ip -details link show can0` | `state UP`, `bitrate 125000` |

---

## 8. Constraints & Risks

- **Two Ethernet ports:** 100 Mbit/s via LAN9514 (`smsc95xx`) and 1 Gbit/s via the CM4 PHY (`bcmgenet`). The second port must still be confirmed in the hardware specification. Kernel names (`eth0`, `eth1`) depend on probe order, so `.link` files are required (`BASE-NETD-20`).
- `BASE-NETD-30`: the on-board radio runs only the IoT AP (`BASE-WAP-06`). The WLAN client `wlan1_sta` exists only with a USB WLAN adapter; without it, `lan0` is the only uplink.
- When `lan0` is the uplink, every host in the upstream network is in "LAN0". Access from LAN0 to the IoT segment and to the management services is therefore restricted by `BASE-FW` to an allow list (`service_nets`), which is empty by default.
- There is no direct service access on `lan0` (no static service address). A service technician uses the upstream network (with an entry in `service_nets`) or the VPN.
- The `.link` files match by driver. If a USB Ethernet adapter with the `smsc95xx` driver is plugged in, it would also match `10-lan1.link`. If this is a risk, the match must use `Path=` instead (determined on the device with `udevadm info`).
- Today, the AP interface is created by a udev rule that calls `iw` and `ifup` (`70-net-sta-interface.rules`). This violates `BASE-NETD-03`. The AP interfaces move to `.netdev` files of `BASE-WAP`.
- `10-wlan0ap-config.network` contains `address 192.168.4.254/24`, which is not valid networkd syntax and is ignored. `dhcpcd.conf` sets `192.168.4.1`. Both disappear with this module.
- `systemd_%.bbappend` installs the `.network` files today. They move into a dedicated recipe (see `BASE-INIT`, section 8).
- Changing the network configuration can cut off remote access. Changes need a test with console access.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Which physical port is LAN0 and which is LAN1? | `BASE-NETD-20` | **Decided:** LAN0 = CM4 Gigabit port (`bcmgenet`), LAN1 = LAN9514 port (`smsc95xx`). |
| 2 | IPv4 subnets of the local segments? | `BASE-NETD-21` | **Decided:** IoT `172.30.10.0/24` (device `.1`); service AP `172.30.30.0/29` (device `.1`). No guest segment. |
| 3 | Direct service access on LAN0, and restriction of LAN0 → IoT. | `BASE-NETD-22`, `BASE-FWP-02`, `BASE-FWP-13` | **Decided:** no direct access (no static service address); access from LAN0 only from the allow list `service_nets` of `BASE-FW`. |
| 4 | CAN bitrate? | `BASE-NETD-40` | **Decided:** 125 kbit/s. |
| 5 | DNS resolver of the device. | `BASE-NETD-25`, `BASE-NETD-26` | **Decided:** `systemd-resolved`. |
| 6 | LAN0 and LAN1 as separate ports. | `BASE-NETD-10` | **Decided:** two physical ports (LAN9514 and CM4 Gigabit PHY). |
| 7 | Uplink. | `BASE-NETD-30` | **Decided:** LAN0 preferred, WLAN client as fallback. |
| 8 | Network segments. | `BASE-NETD-10`, `BASE-NETD-11` | **Decided:** LAN0 (service & uplink), IoT (LAN1 + IoT WLAN), service segment of the service AP; no guest WLAN. |
