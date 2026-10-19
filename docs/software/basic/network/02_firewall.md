# Firewall Framework (nftables)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-FW` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-NETD` |
| **Hardware reference** | — |
| **Risk** | `high` |

---

## 1. Purpose

This module provides the packet filter framework of the device with nftables: one ruleset with the base chains `input`, `forward` and `output`, default policy `drop`, the ban sets, drop logging and the include directory for rules of other modules. Which services and flows are allowed is defined in `BASE-FWP`.

---

## 2. Scope

### In scope

- nftables as the only packet filter and its loading at boot.
- Base chains, default policies and generic rules (loopback, established, ICMP, invalid).
- Ban sets, drop logging, include directory.

### Out of scope

- Port, forward and output matrices, `service_nets`, NAT → `BASE-FWP`
- Decisions which addresses are banned → `BASE-IDS`
- Interface names and segments → `BASE-NETD`
- NAT64 chain → `THREAD-NAT64`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `nftables` | `poky` (openembedded-core) | `iptables` |
| `modberry-nftables-config` (new) | `meta-modberry` | — |

---

## 4. Requirements

### 4.1 Packet Filter

- `BASE-FW-01` **MUST** nftables is the only packet filter. `iptables` (legacy and `iptables-nft`) is not part of the image.
- `BASE-FW-02` **MUST** The ruleset is loaded by `nftables.service` before any network interface is configured (`Before=network-pre.target`).
- `BASE-FW-03` **MUST** If the ruleset cannot be loaded, no interface except loopback is brought up.
- `BASE-FW-04` **MUST** The ruleset uses the `inet` family, so that IPv4 and IPv6 are filtered by the same rules.
- `BASE-FW-05` **MUST** Rules refer to segments by interface name, using named sets for groups of interfaces (e.g. `uplinks`).

### 4.2 Base Chains

- `BASE-FW-10` **MUST** The `input` chain has the default policy `drop`.
- `BASE-FW-11` **MUST** The `input` chain allows established/related traffic, loopback, and the ICMP/ICMPv6 types required for IPv6 operation (neighbor discovery, router advertisement).
- `BASE-FW-13` **MUST** Packets with invalid connection state are dropped.
- `BASE-FW-20` **MUST** The `forward` chain has the default policy `drop`.
- `BASE-FW-30` **MUST** In the production image, the `output` chain has the default policy `drop`.
- `BASE-FW-32` **MAY** In the debug image, the `output` chain has the policy `accept` and logs packets that would be dropped in the production image.

### 4.3 Ban Sets

- `BASE-FW-40` **MUST** The ruleset defines named sets with timeout for banned IPv4 addresses, IPv6 addresses and MAC addresses.
- `BASE-FW-41` **MUST** Traffic from addresses in a ban set is dropped in `input` and `forward` before any accept rule.
- `BASE-FW-42` **MUST** Other modules add entries to the ban sets only; they do not create own tables or chains for bans.

### 4.4 Logging

- `BASE-FW-50` **MUST** Dropped packets in `input` and `forward` are logged with a fixed prefix per chain.
- `BASE-FW-51` **MUST** Drop logging is rate-limited.

### 4.5 Extension

- `BASE-FW-60` **MUST** The main ruleset `/etc/nftables.conf` includes all files of `/etc/nftables.d/*.nft`. Other modules add rules only through this directory.
- `BASE-FW-61` **MUST** Files in `/etc/nftables.d/` do not change the default policies of the base chains.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/nftables.conf` | `flush ruleset`, `table inet filter`, chains `input`/`forward`/`output` with `policy drop` | `BASE-FW-04`, `BASE-FW-10`, `BASE-FW-20`, `BASE-FW-30` |
| `/etc/nftables.conf` | `ct state established,related accept`, `iif lo accept`, `ct state invalid drop`, ICMPv6 ND/RA accept | `BASE-FW-11`, `BASE-FW-13` |
| `/etc/nftables.conf` | sets `ban_ipv4` (`type ipv4_addr; flags timeout`), `ban_ipv6`, `ban_mac` (`type ether_addr`) | `BASE-FW-40`, `BASE-FW-41` |
| `/etc/nftables.conf` | `log prefix "nft-drop-input: " limit rate 10/minute` (and `nft-drop-forward:`) | `BASE-FW-50`, `BASE-FW-51` |
| `/etc/nftables.conf` | `include "/etc/nftables.d/*.nft"` | `BASE-FW-60` |
| Debug image | `output` policy `accept` with `log prefix "nft-would-drop-output: "` | `BASE-FW-32` |
| `nftables.service.d/` | `Before=network-pre.target`, `Wants=network-pre.target` | `BASE-FW-02`, `BASE-FW-03` |

---

## 6. Interfaces to Other Modules

### Provides

- Table `inet filter` with chains `input`, `forward`, `output` – used by `BASE-FWP` and all modules that add rules.
- Ban sets `ban_ipv4`, `ban_ipv6`, `ban_mac` – used by `BASE-IDS`.
- Drop log prefixes – used by `BASE-IDS` (port scan jail).
- Include directory `/etc/nftables.d/` – used by `BASE-FWP`, `BASE-CONT`, `THREAD-NAT64` and `meta-ota`.

### Consumes

- Interface names and segments – owned by `BASE-NETD`.
- Image variant switch – owned by `BASE-INIT` (`BASE-INIT-42`).
- Service integration rules – owned by `BASE-INIT`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-FW-01` | `manifest` | `iptables` in image manifest | absent |
| `BASE-FW-02` | `device` | `systemctl show -p Before nftables.service` | contains `network-pre.target` |
| `BASE-FW-03` | `device` | Install a broken ruleset, reboot (console) | only `lo` is up |
| `BASE-FW-04` | `device` | `nft list tables` | `table inet filter` |
| `BASE-FW-10`, `-20`, `-30` | `device` | `nft list chain inet filter <chain>` (production image) | `policy drop` |
| `BASE-FW-11` | `device` | `ping6` to the device's link-local address from a connected segment | answered |
| `BASE-FW-13` | `device` | `nft list chain inet filter input` | `ct state invalid drop` |
| `BASE-FW-32` | `device` | `nft list chain inet filter output` (debug image) | `policy accept`, log rule present |
| `BASE-FW-40` | `device` | `nft list sets` | three ban sets with `flags timeout` |
| `BASE-FW-41` | `device` | `nft add element inet filter ban_ipv4 { <test-ip> timeout 1m }`, connect from test IP | dropped |
| `BASE-FW-50` | `device` | Connect to a closed port, `journalctl -k \| grep nft-drop` | entry logged |
| `BASE-FW-51` | `device` | Port scan, count log entries per minute | ≤ configured rate |
| `BASE-FW-60` | `rootfs` | `grep include <rootfs>/etc/nftables.conf` | includes `/etc/nftables.d/*.nft` |
| `BASE-FW-61` | `rootfs` | `grep -r policy <rootfs>/etc/nftables.d/` | no match |

---

## 8. Constraints & Risks

- `BASE-FW-01`: Docker uses `iptables` by default. `BASE-CONT` must run Docker without `iptables` and add its rules through `/etc/nftables.d/`.
- `BASE-FW-03`, `BASE-FW-30`: **human gate** – a wrong ruleset locks out remote access. Every change is tested with console access first.
- `BASE-FW-04`: the kernel needs the nftables options (`CONFIG_NF_TABLES`, `CONFIG_NF_TABLES_INET`, `CONFIG_NFT_CT`, `CONFIG_NFT_NAT`, `CONFIG_NFT_MASQ`, `CONFIG_NFT_LOG`, `CONFIG_NFT_LIMIT`, sets with timeout). Check the `linux-raspberrypi` defconfig.
- `BASE-FW-10` … `BASE-FW-30`: **there is no packet filter on the device today.** `iptables` is installed but has no rules.
- `BASE-FW-40`: MAC bans only work for traffic with an Ethernet header (LAN, WLAN). They have no effect on `wg0` or `wpan0`.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Output policy from the start or staged? | `BASE-FW-30`, `BASE-FW-32` | **Decided:** `drop` in production, `accept` with logging in debug. |
