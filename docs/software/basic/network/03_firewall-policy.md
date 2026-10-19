# Firewall Policy (port, forward and output matrices)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-FWP` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
| **Depends on** | `BASE-FW`, `BASE-NETD`, `BASE-PROV` |
| **Hardware reference** | — |
| **Risk** | `high` |

---

## 1. Purpose

This module defines which services of the device are reachable from which segment, which flows between segments are allowed, and which outbound destinations the device may contact. It also defines the allow list `service_nets` for access from LAN0. The rules are installed into the framework of `BASE-FW`.

---

## 2. Scope

### In scope

- Port matrix (input), forward matrix, output matrix.
- Allow list `service_nets` and the factory subnet.
- NAT table for other modules.

### Out of scope

- Base chains, policies, ban sets, logging → `BASE-FW`
- Container network rules → `BASE-CONT`
- Outbound rules of the OTA system → `meta-ota`
- NAT64 → `THREAD-NAT64`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `modberry-nftables-policy` (new: files in `/etc/nftables.d/`) | `meta-modberry` | networkd `IPMasquerade=` |

---

## 4. Requirements

### 4.1 Input

- `BASE-FWP-01` **MUST** The `input` chain allows only the services of the port matrix (section 5.1), and each only from the segments listed there.
- `BASE-FWP-02` **MUST** From LAN0, the management services (SSH, HTTPS, HTTP redirect, Border Router API) are reachable only from sources in the allow list `service_nets`.
- `BASE-FWP-03` **MUST** In the image, `service_nets` contains only the factory subnet `10.99.0.0/24`, and only while the device is not provisioned (marker `BASE-PROV-23` absent). After provisioning, `service_nets` contains only the site entries of the provisioning store.

### 4.2 Forward & NAT

- `BASE-FWP-10` **MUST** Forwarding between segments is allowed only for the flows of the forward matrix (section 5.2).
- `BASE-FWP-11` **MUST** This module masquerades no segment. It provides an empty table `inet nat` with a `postrouting` chain, in which only `BASE-CONT` and `THREAD-NAT64` add rules.
- `BASE-FWP-13` **MUST** Forwarding from LAN0 to the IoT segment is allowed only from sources in `service_nets`.
- `BASE-FWP-14` **MUST** The IoT segment has no internet access. ESP32 devices get their OTA updates from the device.

### 4.3 Output

- `BASE-FWP-20` **MUST** The `output` chain allows only the protocols and destinations of the output matrix (section 5.3), plus established/related traffic.

---

## 5. Configuration

### 5.1 Port Matrix (input)

Segments: **LAN0** = `lan0`, **IoT** = `br-iot` (`172.30.10.0/24`), **SVC** = `wlan0_svc` (service AP, service mode only, `BASE-WAP-40`), **VPN** = `wg0`, **Uplink** = `lan0`, `wlan1_sta`. "SN" = only from sources in `service_nets`.

| Service | Port | LAN0 | IoT | SVC | VPN | Owner |
| :-- | :-- | :-: | :-: | :-: | :-: | :-- |
| SSH | 22/tcp | SN | — | ✅ | ✅ | `BASE-SSH` |
| HTTPS – local web interface | 443/tcp | SN | — | ✅ | ✅ | `BASE-WEB` |
| HTTP → HTTPS redirect | 80/tcp | SN | — | ✅ | ✅ | `BASE-WEB` |
| MQTT-TLS | 8883/tcp | — | ✅ | — | — | application layer |
| ESP32 OTA (local server) | per application layer | — | ✅ | — | — | application layer |
| Border Router API | per `THREAD-OTBR` | SN | — | ✅ | ✅ | `THREAD-OTBR` |
| DHCP server | 67/udp | — | ✅ | ✅ | — | `BASE-DNS` |
| DNS | 53/udp, 53/tcp | — | ✅ | — | — | `BASE-DNS` |
| NTP server | 123/udp | — | ✅ | — | — | `BASE-TIME` |
| DHCP client replies | 68/udp | Uplink | — | — | — | `BASE-NETD` |

### 5.2 Forward Matrix

| From | To | Allowed | Reason |
| :-- | :-- | :-- | :-- |
| LAN0 (`service_nets` only) | IoT | ✅ | service technician accesses sensors and actuators |
| VPN | IoT | ✅ | remote service access |
| SVC | IoT | ✅ | local service access via the service AP |
| IoT | Uplink, LAN0, SVC | ❌ | sensors/actuators are isolated; OTA comes from the device |
| Container networks | per `BASE-CONT` | per `BASE-CONT` | container rules in their own include file |
| any other combination | | ❌ | `BASE-FW-20` |

### 5.3 Output Matrix

| Protocol | Destination | Owner |
| :-- | :-- | :-- |
| DNS 53/udp, 53/tcp | DNS servers from DHCP | `BASE-NETD` |
| NTP 123/udp, NTS-KE 4460/tcp | configured NTS servers | `BASE-TIME` |
| WireGuard `<port>`/udp | Bynacon VPN server (`VPN_ENDPOINT`) | `BASE-VPN` |
| DHCP 67/udp | Uplink | `BASE-NETD` |
| Answers to IoT and SVC clients | IoT, SVC | `BASE-DNS`, application layer |
| OTA system | own file in `/etc/nftables.d/` | `meta-ota` |
| Further destinations (cloud, package feeds) | own files in `/etc/nftables.d/` | application layer |

### 5.4 Files

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/nftables.d/20-input.nft` | rules of section 5.1 per interface | `BASE-FWP-01` |
| `/etc/nftables.d/10-sets.nft` | sets `uplinks = { "lan0", "wlan1_sta" }`, `service_nets_v4` (`type ipv4_addr; flags interval`), `service_nets_v6`, empty | `BASE-FWP-02` |
| `/etc/nftables.d/05-factory.nft` | `add element inet filter service_nets_v4 { 10.99.0.0/24 }`; loaded only if `/data/provisioning/provisioned` is absent | `BASE-FWP-03` |
| `/data/provisioning/firewall/service_nets.nft` | site elements of `service_nets_v4` / `service_nets_v6`, loaded after the base ruleset | `BASE-FWP-03` |
| `/etc/nftables.d/30-forward.nft` | rules of section 5.2 | `BASE-FWP-10`, `BASE-FWP-13`, `BASE-FWP-14` |
| `/etc/nftables.d/40-nat.nft` | `table inet nat`, chain `postrouting` (`type nat hook postrouting`), no rules of this module | `BASE-FWP-11` |
| `/etc/nftables.d/50-output.nft` | rules of section 5.3 | `BASE-FWP-20` |

---

## 6. Interfaces to Other Modules

### Provides

- Port openings for `BASE-SSH`, `BASE-WEB`, `BASE-VPN`, `BASE-DNS`, `BASE-TIME`, `BASE-WAP` (service AP), `THREAD-OTBR` and the application layer.
- Allow list `service_nets` – used by `BASE-WEB` (nginx `allow`) and `BASE-IDS` (never banned).
- Table `inet nat` – used by `BASE-CONT` and `THREAD-NAT64` (own rules via include).

### Consumes

- Framework, include directory – owned by `BASE-FW`.
- Interface names, segments and uplinks – owned by `BASE-NETD`.
- Provisioning marker and site entries – owned by `BASE-PROV`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-FWP-01` | `device` | `nmap -sT -sU -p- <device>` from each segment | only the ports of section 5.1 for that segment |
| `BASE-FWP-02` | `device` | SSH/HTTPS from a LAN0 host outside and inside `service_nets` | refused / accepted |
| `BASE-FWP-03` | `device` | `nft list set inet filter service_nets_v4` before and after provisioning | `10.99.0.0/24` / only site entries |
| `BASE-FWP-03` | `device` | Reboot after provisioning, list the set again | site entries still present |
| `BASE-FWP-10` | `device` | Connection attempts for each row of section 5.2 | only allowed flows succeed |
| `BASE-FWP-11` | `device` | `nft list table inet nat` (without containers and Thread) | chain `postrouting` without rules |
| `BASE-FWP-13` | `device` | Ping an IoT device from a LAN0 host outside and inside `service_nets` | blocked / answered |
| `BASE-FWP-14` | `device` | IoT client: `curl https://example.com` | blocked |
| `BASE-FWP-20` | `device` | `curl https://example.com` from the device (production image) | blocked, unless listed in section 5.3 |

---

## 8. Constraints & Risks

- `BASE-FWP-01` … `BASE-FWP-20`: **human gate** – test every change with console access first.
- `BASE-FWP-03`: if a customer network uses `10.99.0.0/24`, its hosts reach the login of SSH and the web interface while the device is unprovisioned.
- `BASE-FWP-10`: traffic between `lan1` and `wlan0_iot` is bridged inside `br-iot` and does not pass the `forward` chain of the `inet` family. Filtering inside the IoT segment needs the `bridge` family (not planned).
- `BASE-FWP-11`: today, networkd masquerades on the AP (`IPMasquerade=both`). With this module, the IoT segment has no NAT and no internet access.
- `BASE-FWP-20`: `policy drop` on `output` breaks every outbound connection that is not listed in section 5.3. All modules must list their outbound needs before the production image is built.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Further outbound destinations of the device (cloud, package feeds)? | `BASE-FWP-20` | **Decided:** the destinations of section 5.3 are implemented now; further destinations are added by the application layer or `meta-ota` in own files in `/etc/nftables.d/` (`BASE-FW-60`). |
| 2 | ESP32 OTA source. | `BASE-FWP-01`, `BASE-FWP-14` | **Decided:** the device caches the firmware (via the OTA system) and serves it locally. |
| 3 | Allowed flows between segments. | `BASE-FWP-10` … `BASE-FWP-14` | **Decided:** LAN0 → IoT and management only from `service_nets`; VPN and service AP → IoT; IoT isolated. |
| 4 | Factory subnet after provisioning. | `BASE-FWP-03` | **Decided:** active only while unprovisioned. |
| 5 | Guest WLAN. | `BASE-FWP-11` | **Decided:** no guest WLAN (`BASE-WAP` open point 4); no NAT of this module. |
