# Firewall (nftables)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-FW` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-NETD` |
| **Hardware reference** | — |
| **Risk** | `high` |

---

## 1. Purpose

This module defines the packet filter of the device with nftables. It owns the base ruleset with the three chains `input`, `forward` and `output`, the NAT for the guest network, the named sets that other modules use to ban addresses, and the include directory through which other modules add their own rules. Everything that is not explicitly allowed is dropped.

---

## 2. Scope

### In scope

- nftables as the only packet filter.
- Base chains `input`, `forward`, `output` and their default policies.
- Port matrix: which service on the device is reachable from which segment.
- Forward matrix: which flows between segments are allowed.
- Masquerading of the guest segment on the uplinks.
- Named sets for temporary bans (IP and MAC).
- Logging of dropped packets.
- Include directory for rules of other modules.

### Out of scope

- Decisions which addresses are banned (Fail2Ban, PSAD, hostapd event scripts) → `BASE-IDS`
- NAT64 masquerading chain → `THREAD-NAT64`
- Interface names, segments and subnets → `BASE-NETD`
- Service configuration (SSH, nginx, WireGuard) → `BASE-RACC`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `nftables` | `poky` (openembedded-core) | `iptables` |
| `modberry-nftables-config` (new) | `meta-modberry` | networkd `IPMasquerade=` |

---

## 4. Requirements

### 4.1 Packet Filter

- `BASE-FW-01` **MUST** nftables is the only packet filter. `iptables` (legacy and `iptables-nft`) is not part of the image.
- `BASE-FW-02` **MUST** The ruleset is loaded by `nftables.service` before any network interface is configured (`Before=network-pre.target`).
- `BASE-FW-03` **MUST** If the ruleset cannot be loaded, no interface except loopback is brought up.
- `BASE-FW-04` **MUST** The ruleset uses the `inet` family, so that IPv4 and IPv6 are filtered by the same rules.
- `BASE-FW-05` **MUST** Rules refer to segments by interface name (`lan0`, `br-iot`, `wlan0_guest`, `wlan0_sta`, `wg0`), using named sets for the uplinks.

### 4.2 Input Chain

- `BASE-FW-10` **MUST** The `input` chain has the default policy `drop`.
- `BASE-FW-11` **MUST** The `input` chain allows established/related traffic, loopback, and the ICMP/ICMPv6 types required for IPv6 operation (neighbor discovery, router advertisement).
- `BASE-FW-12` **MUST** The `input` chain allows only the services of the port matrix (section 5.1), and each only from the segments listed there.
- `BASE-FW-13` **MUST** Packets with invalid connection state are dropped.
- `BASE-FW-14` **MUST** From LAN0, the management services (SSH, HTTPS, HTTP redirect, Border Router API) are reachable only from sources in the allow list `service_nets`.
- `BASE-FW-15` **MUST** In the image, `service_nets` contains only the factory subnet `10.99.0.0/24`. Site entries are added by factory provisioning (`BASE-PROV`) and are stored persistently outside the image.

### 4.3 Forward Chain & NAT

- `BASE-FW-20` **MUST** The `forward` chain has the default policy `drop`.
- `BASE-FW-21` **MUST** Forwarding between segments is allowed only for the flows of the forward matrix (section 5.2).
- `BASE-FW-22` **MUST** Traffic from the guest segment to the uplinks is masqueraded. No other segment is masqueraded, unless listed in section 5.2.
- `BASE-FW-23` **MUST** The guest segment has no access to the IoT segment, to LAN0, or to any service of the device except DHCP and DNS.
- `BASE-FW-24` **MUST** Forwarding from LAN0 to the IoT segment is allowed only from sources in `service_nets`.
- `BASE-FW-25` **MUST** The IoT segment has no internet access. ESP32 devices get their OTA updates from the device.

### 4.4 Output Chain

- `BASE-FW-30` **MUST** The `output` chain has the default policy `drop`.
- `BASE-FW-31` **MUST** The `output` chain allows only the protocols and destinations of the output matrix (section 5.3), plus established/related traffic.

### 4.5 Ban Sets

- `BASE-FW-40` **MUST** The ruleset defines named sets with timeout for banned IPv4 addresses, IPv6 addresses and MAC addresses.
- `BASE-FW-41` **MUST** Traffic from addresses in a ban set is dropped in `input` and `forward` before any accept rule.
- `BASE-FW-42` **MUST** Other modules add entries to the ban sets only; they do not create own tables or chains for bans.

### 4.6 Logging

- `BASE-FW-50` **MUST** Dropped packets in `input` and `forward` are logged with a fixed prefix per chain.
- `BASE-FW-51` **MUST** Drop logging is rate-limited.

### 4.7 Extension

- `BASE-FW-60` **MUST** The main ruleset `/etc/nftables.conf` includes all files of `/etc/nftables.d/*.nft`. Other modules add rules only through this directory.
- `BASE-FW-61` **MUST** Files in `/etc/nftables.d/` do not change the default policies of the base chains.

---

## 5. Configuration

### 5.1 Port Matrix (input)

Segments: **LAN0** = `lan0` (IPv4 from upstream DHCP), **IoT** = `br-iot` (`172.30.10.0/24`), **Guest** = `wlan0_guest` (`172.30.20.0/24`), **Uplink** = `lan0`, `wlan0_sta`, **VPN** = `wg0`. "SN" = only from sources in `service_nets`.

| Service | Port | LAN0 | IoT | Guest | VPN | Owner |
| :-- | :-- | :-: | :-: | :-: | :-: | :-- |
| SSH | 22/tcp | SN | — | — | ✅ | `BASE-RACC` |
| HTTPS – local web interface | 443/tcp | SN | — | — | ✅ | `BASE-RACC` |
| HTTP → HTTPS redirect | 80/tcp | SN | — | — | ✅ | `BASE-RACC` |
| MQTT-TLS | 8883/tcp | — | ✅ | — | — | application layer |
| ESP32 OTA (local server) | per application layer | — | ✅ | — | — | application layer |
| Border Router API | per `THREAD-OTBR` | SN | — | — | ✅ | `THREAD-OTBR` |
| DHCP server | 67/udp | — | ✅ | ✅ | — | `BASE-WAP` |
| DNS | 53/udp, 53/tcp | — | ✅ | ✅ | — | `BASE-WAP` |
| NTP server | 123/udp | — | ✅ | — | — | `BASE-TIME` |
| DHCP client replies | 68/udp | Uplink | — | — | — | `BASE-NETD` |

### 5.2 Forward Matrix

| From | To | Allowed | NAT | Reason |
| :-- | :-- | :-- | :-- | :-- |
| Guest | Uplink (internet) | ✅ all | masquerade | guest devices get internet access |
| Guest | IoT, LAN0, VPN | ❌ | — | guests have no access to sensors/actuators |
| LAN0 (`service_nets` only) | IoT | ✅ | — | service technician accesses sensors and actuators |
| VPN | IoT | ✅ | — | remote service access |
| IoT | Uplink (internet) | ❌ | — | ESP32 OTA comes from the device (`BASE-FW-25`) |
| IoT | LAN0, Guest | ❌ | — | sensors/actuators do not initiate connections into other segments |
| any other combination | | ❌ | — | `BASE-FW-20` |

### 5.3 Output Matrix

| Protocol | Destination | Owner |
| :-- | :-- | :-- |
| DNS 53/udp, 53/tcp | DNS servers from DHCP | `BASE-NETD` |
| NTP 123/udp, NTS-KE 4460/tcp | configured NTS servers | `BASE-TIME` |
| WireGuard `<port>`/udp | Bynacon VPN server (`VPN_ENDPOINT`) | `BASE-RACC` |
| DHCP 67/udp | Uplink | `BASE-NETD` |
| Answers to IoT and guest clients (DHCP, DNS, MQTT, OTA) | IoT, Guest | `BASE-WAP`, application layer |
| OTA system (device updates and ESP32 firmware) | defined by `meta-ota` in its own file in `/etc/nftables.d/` | `meta-ota` |
| Further destinations (cloud, package feeds) | open point 2 | — |

### 5.4 Files

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/nftables.conf` | `flush ruleset`, `table inet filter`, chains `input`/`forward`/`output` with `policy drop` | `BASE-FW-04` … `BASE-FW-30` |
| `/etc/nftables.conf` | `define`/set `uplinks = { "lan0", "wlan0_sta" }` | `BASE-FW-05` |
| `/etc/nftables.conf` | set `service_nets_v4` (`type ipv4_addr; flags interval; elements = { 10.99.0.0/24 }`), set `service_nets_v6` (empty) | `BASE-FW-14`, `BASE-FW-15` |
| `/data/provisioning/firewall/service_nets.nft` | site elements of `service_nets_v4` / `service_nets_v6`, loaded after the base ruleset | `BASE-FW-15` |
| `/etc/nftables.conf` | `table inet nat`, chain `postrouting`: `iifname "wlan0_guest" oifname @uplinks masquerade` | `BASE-FW-22` |
| `/etc/nftables.conf` | sets `ban_ipv4` (`type ipv4_addr; flags timeout`), `ban_ipv6`, `ban_mac` (`type ether_addr`) | `BASE-FW-40` |
| `/etc/nftables.conf` | `log prefix "nft-drop-input: " limit rate 10/minute` | `BASE-FW-50`, `BASE-FW-51` |
| `/etc/nftables.conf` | `include "/etc/nftables.d/*.nft"` | `BASE-FW-60` |
| `nftables.service.d/` | `Before=network-pre.target`, `Wants=network-pre.target` | `BASE-FW-02` |

---

## 6. Interfaces to Other Modules

### Provides

- Table `inet filter` with chains `input`, `forward`, `output` – used by all network services.
- Table `inet nat` with chain `postrouting` – used by `THREAD-NAT64` (own rules via include).
- Ban sets `ban_ipv4`, `ban_ipv6`, `ban_mac` – used by `BASE-IDS` (Fail2Ban, PSAD, hostapd event scripts).
- Drop log prefixes – used by `BASE-IDS` (PSAD).
- Include directory `/etc/nftables.d/` – used by `THREAD-NAT64` and by `meta-ota` (outbound rules of the OTA system).

### Consumes

- Interface names, segments and uplinks – owned by `BASE-NETD`.
- Port requirements of `BASE-WAP`, `BASE-TIME`, `BASE-RACC`, `THREAD-OTBR` and the application layer (section 5.1).
- Service integration rules – owned by `BASE-INIT`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-FW-01` | `manifest` | `iptables` in image manifest | absent |
| `BASE-FW-02` | `device` | `systemctl show -p Before nftables.service` | contains `network-pre.target` |
| `BASE-FW-03` | `device` | Install a broken ruleset, reboot (console) | only `lo` is up |
| `BASE-FW-04` | `device` | `nft list tables` | `table inet filter`, `table inet nat` |
| `BASE-FW-10`, `-20`, `-30` | `device` | `nft list chain inet filter <chain>` | `policy drop` |
| `BASE-FW-11` | `device` | `ping6` to the device's link-local address from LAN0 | answered |
| `BASE-FW-12` | `device` | `nmap -sT -sU -p- <device>` from each segment | only the ports of section 5.1 for that segment |
| `BASE-FW-13` | `device` | `nft list chain inet filter input` | `ct state invalid drop` |
| `BASE-FW-14` | `device` | SSH/HTTPS from a LAN0 host outside and inside `service_nets` | refused / accepted |
| `BASE-FW-15` | `rootfs` | `nft` set definitions in `<rootfs>/etc/nftables.conf` | `service_nets_v4` contains only `10.99.0.0/24`, `service_nets_v6` empty |
| `BASE-FW-15` | `device` | Add an element, reboot, `nft list set inet filter service_nets_v4` | element still present |
| `BASE-FW-21` | `device` | Connection attempts for each row of section 5.2 | only allowed flows succeed |
| `BASE-FW-22` | `device` | Guest client: `curl https://example.com` | works; source address on the uplink is the device |
| `BASE-FW-23` | `device` | Guest client: `nmap` the IoT subnet, LAN0, and the device | only DHCP/DNS on the device answer |
| `BASE-FW-24` | `device` | Ping an IoT device from a LAN0 host outside and inside `service_nets` | blocked / answered |
| `BASE-FW-25` | `device` | IoT client: `curl https://example.com` | blocked |
| `BASE-FW-31` | `device` | `curl https://example.com` from the device | blocked, unless listed in section 5.3 |
| `BASE-FW-40` | `device` | `nft list sets` | three ban sets with `flags timeout` |
| `BASE-FW-41` | `device` | `nft add element inet filter ban_ipv4 { <test-ip> timeout 1m }`, connect from test IP | dropped |
| `BASE-FW-50` | `device` | Connect to a closed port, `journalctl -k \| grep nft-drop` | entry logged |
| `BASE-FW-51` | `device` | Port scan, count log entries per minute | ≤ configured rate |
| `BASE-FW-60` | `rootfs` | `grep include <rootfs>/etc/nftables.conf` | includes `/etc/nftables.d/*.nft` |
| `BASE-FW-61` | `rootfs` | `grep -r policy <rootfs>/etc/nftables.d/` | no match |

---

## 8. Constraints & Risks

- **There is no packet filter on the device today.** `iptables` is installed but has no rules. Until this module is implemented, every service of the device is reachable from every segment.
- **Human gate:** a wrong ruleset locks out remote access. Every change is tested with console access first.
- `policy drop` on `output` breaks every outbound connection that is not listed in section 5.3. All modules must list their outbound needs before this policy is enabled (open point 3).
- Today, networkd does the masquerading (`IPMasquerade=both` on the AP). With this module, NAT is done only in nftables (`BASE-FW-22`); `IPMasquerade=` is not used.
- The kernel needs the nftables options (`CONFIG_NF_TABLES`, `CONFIG_NF_TABLES_INET`, `CONFIG_NFT_CT`, `CONFIG_NFT_NAT`, `CONFIG_NFT_MASQ`, `CONFIG_NFT_LOG`, `CONFIG_NFT_LIMIT`, sets with timeout). Check the `linux-raspberrypi` defconfig.
- Traffic between `lan1` and `wlan0_iot` is bridged inside `br-iot` and does not pass the `forward` chain of the `inet` family. Filtering inside the IoT segment needs the `bridge` family or `br_netfilter` (not planned).
- The factory subnet `10.99.0.0/24` is in `service_nets` of every device. If a customer network uses this subnet, its hosts reach SSH and the web interface login (authentication is still required). See open point 7.
- The device is a WireGuard client (`BASE-RACC-06`). There is no inbound WireGuard port; replies arrive as established traffic.
- MAC bans (`ban_mac`) only work for traffic that arrives with an Ethernet header (LAN, WLAN). They have no effect on `wg0` or `wpan0`.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | ESP32 OTA source. | `BASE-FW-12`, `BASE-FW-25` | **Decided:** the device caches the firmware and serves it locally; it downloads the firmware through the existing OTA system. Port of the local OTA server per application layer. |
| 2 | Which outbound destinations does the device need besides DNS, NTP, WireGuard and the OTA system (cloud, package feeds)? Value of `VPN_ENDPOINT`? | `BASE-FW-31` | **Partly decided:** OTA rules come from `meta-ota` (`BASE-FW-60`); Bynacon VPN server, host name follows. |
| 3 | Is `policy drop` on `output` wanted from the start, or first `accept` with logging, then `drop`? | `BASE-FW-30` | |
| 4 | May guest clients reach the local web interface (e.g. for a landing page)? Current assumption: no. | `BASE-FW-23` | |
| 5 | Allowed flows between segments. | `BASE-FW-21` … `BASE-FW-25` | **Decided:** guest → internet only; LAN0 → IoT and management services only from `service_nets`; IoT isolated from guest, LAN0 and internet. |
| 6 | Who fills `service_nets` at commissioning? | `BASE-FW-15` | **Decided:** factory provisioning (`BASE-PROV`); the image contains the factory subnet `10.99.0.0/24`. |
| 7 | Is the factory subnet removed at the end of provisioning (`BASE-PROV` open point 3)? | `BASE-FW-15` | |
