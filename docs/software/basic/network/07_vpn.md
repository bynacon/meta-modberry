# VPN (WireGuard client)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-VPN` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-NETD`, `BASE-FWP`, `BASE-PROV` |
| **Hardware reference** | — |
| **Risk** | `high` |

---

## 1. Purpose

This module connects the device as WireGuard client to the Bynacon VPN server, so that it is reachable for remote service behind any NAT. Remote access to SSH and the web interface from outside the local segments goes only through this tunnel.

---

## 2. Scope

### In scope

- WireGuard interface `wg0` and its `.netdev` / `.network` files.
- Key and peer requirements.

### Out of scope

- Generation and storage of the key and peer data → `BASE-PROV`
- Firewall openings → `BASE-FWP`
- The Bynacon VPN server → infrastructure

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `wireguard-tools` | `meta-openembedded` (meta-networking) | — |
| Kernel: `wireguard` | `linux-raspberrypi` (in-tree since 5.6) | — |

---

## 4. Requirements

- `BASE-VPN-01` **MUST** The WireGuard interface `wg0` is defined as a systemd-networkd `.netdev` (`Kind=wireguard`) and `.network` file.
- `BASE-VPN-02` **MUST** The WireGuard private key is generated on the device during provisioning and is not stored in the image or the repository.
- `BASE-VPN-03` **MUST** The private key file is readable only by root and `systemd-network` (mode `0640`).
- `BASE-VPN-04` **MUST** The only peer is the Bynacon VPN server. Its `AllowedIPs` contain only the VPN subnet.
- `BASE-VPN-05` **MUST** Remote access to SSH and HTTPS from outside the local segments is possible only through `wg0`.
- `BASE-VPN-06` **MUST** The device is the WireGuard client: it initiates the tunnel to `VPN_ENDPOINT` and keeps it open with `PersistentKeepalive`. It does not listen on an inbound WireGuard port.
- `BASE-VPN-07` **MUST** On an unprovisioned device, `wg0` is not configured and no unit fails (`BASE-PROV-30`).

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/systemd/network/60-wg0.netdev` | `Kind=wireguard`, `PrivateKeyFile=/data/provisioning/wireguard/wg0.key`, no `ListenPort` | `BASE-VPN-01`, `BASE-VPN-06` |
| `/etc/systemd/network/60-wg0.netdev` | `[WireGuardPeer] PublicKey=`, `Endpoint=${VPN_ENDPOINT}`, `AllowedIPs=<VPN subnet>`, `PersistentKeepalive=25` (from `wireguard/peer.conf`) | `BASE-VPN-04`, `BASE-VPN-06` |
| `/etc/systemd/network/60-wg0.network` | tunnel `Address=` from provisioning | `BASE-VPN-01` |
| `/data/provisioning/wireguard/wg0.key` | `root:systemd-network 0640` | `BASE-VPN-02`, `BASE-VPN-03` |

---

## 6. Interfaces to Other Modules

### Provides

- Interface `wg0` and the VPN subnet – used by `BASE-FWP` (port and forward matrix), `BASE-WEB` (`allow`), `BASE-IDS` (never banned).

### Consumes

- `.netdev` / `.network` convention – owned by `BASE-NETD`.
- Key, peer and tunnel address – owned by `BASE-PROV`.
- Outbound rule to `VPN_ENDPOINT` – owned by `BASE-FWP`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-VPN-01` | `device` | `networkctl status wg0`, `wg show` | interface up, one peer |
| `BASE-VPN-02` | `rootfs` | Search the rootfs for WireGuard private keys | none |
| `BASE-VPN-03` | `device` | `stat -c '%U:%G %a' /data/provisioning/wireguard/wg0.key` | `root:systemd-network 640` |
| `BASE-VPN-04` | `device` | `wg show wg0 allowed-ips` | only the VPN subnet |
| `BASE-VPN-05` | `device` | SSH from the uplink network from a host outside `service_nets` | blocked |
| `BASE-VPN-06` | `device` | `wg show wg0 listen-port`; device behind NAT, connect from VPN server | random port, no firewall opening; tunnel up |
| `BASE-VPN-07` | `device` | Boot an unprovisioned device, `systemctl --failed` | empty |

---

## 8. Constraints & Risks

- `BASE-VPN-02`: WireGuard cannot use TPM-resident keys. The private key is a file on the encrypted data partition.
- `BASE-VPN-06`: the device needs outbound UDP to `VPN_ENDPOINT` (`BASE-FWP-20`).

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | WireGuard role. | `BASE-VPN-06` | **Decided:** device is client of the Bynacon VPN server. |
| 2 | Values of `VPN_ENDPOINT`, port and VPN subnet. | `BASE-VPN-04`, `BASE-VPN-06` | **Deferred:** infrastructure information. |
