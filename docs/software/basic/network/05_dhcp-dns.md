# DHCP & DNS for Local Segments (dnsmasq)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-DNS` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-NETD`, `BASE-FW` |
| **Hardware reference** | — |
| **Risk** | `low` |

---

## 1. Purpose

This module assigns addresses to the clients of the local segments – IoT (LAN1 and IoT WLAN) and the USB service port – and provides DNS in the IoT segment. dnsmasq forwards DNS queries to the resolver of the device and resolves local names, such as the device itself and its local OTA server.

---

## 2. Scope

### In scope

- dnsmasq as DHCP server on `br-iot` and `usb0`, and DNS forwarder on `br-iot`.
- Local domain and DHCP reservations.
- dnsmasq include directory for other modules.

### Out of scope

- DNS resolver of the device itself (`systemd-resolved`) → `BASE-NETD`
- Firewall openings for DHCP and DNS → `BASE-FWP`
- DNS64 extension → `THREAD-NAT64`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `dnsmasq` | `meta-openembedded` (meta-networking) | networkd `DHCPServer=`, `dhcpcd` server role |

---

## 4. Requirements

- `BASE-DNS-01` **MUST** dnsmasq is the only DHCP server in the IoT and USB service segments.
- `BASE-DNS-02` **MUST** dnsmasq serves DHCP and DNS only on `br-iot`, and DHCP only on `usb0`. It does not listen on any other interface.
- `BASE-DNS-03` **MUST** dnsmasq forwards DNS queries of IoT clients to the resolver of the device (`systemd-resolved`, `BASE-NETD-25`).
- `BASE-DNS-04` **MUST** dnsmasq includes `/etc/dnsmasq.d/*.conf`, so that other modules extend it without changing the main configuration.
- `BASE-DNS-05` **MUST** dnsmasq resolves the name of the device and of its local OTA server for IoT clients under the local domain `internal`, which is not forwarded upstream.
- `BASE-DNS-06` **MUST** Wired devices on LAN1 get their addresses by DHCP like IoT WLAN clients; fixed addresses are DHCP reservations.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/dnsmasq.conf` | `interface=br-iot`, `interface=usb0`, `bind-dynamic` | `BASE-DNS-02` |
| `/etc/dnsmasq.conf` | `dhcp-range=172.30.10.100,172.30.10.250,12h`; `usb0` range per `BASE-USBG` | `BASE-DNS-01` |
| `/etc/dnsmasq.conf` | `no-resolv`, `server=127.0.0.53` | `BASE-DNS-03` |
| `/etc/dnsmasq.conf` | `conf-dir=/etc/dnsmasq.d/,*.conf` | `BASE-DNS-04` |
| `/etc/dnsmasq.conf` | `local=/internal/`, `domain=internal`, `address=/modberry.internal/172.30.10.1` | `BASE-DNS-05` |
| `/etc/dnsmasq.d/` | `dhcp-host=` reservations (from provisioning or application layer) | `BASE-DNS-06` |
| `/var/lib/misc/dnsmasq.leases` | on `/data` (`BASE-ROOTFS`) | `BASE-DNS-01` |

---

## 6. Interfaces to Other Modules

### Provides

- DHCP and DNS in the IoT segment, DHCP in the USB service segment – used by sensors, actuators and technicians.
- Include directory `/etc/dnsmasq.d/` – used by `BASE-USBG`, `THREAD-NAT64` (DNS64) and the application layer (reservations).

### Consumes

- Interfaces `br-iot` (`BASE-NETD`) and `usb0` (`BASE-USBG`).
- Stub resolver `127.0.0.53` – owned by `BASE-NETD`.
- Firewall openings – owned by `BASE-FWP`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-DNS-01` | `rootfs` | `grep -E 'DHCPServer\|IPMasquerade' <rootfs>/etc/systemd/network/*` | no match |
| `BASE-DNS-02` | `device` | `ss -lunp \| grep dnsmasq` | bound only to `br-iot` and (DHCP) `usb0` |
| `BASE-DNS-03` | `device` | IoT client: `nslookup example.com <device>` | resolved |
| `BASE-DNS-04` | `rootfs` | `grep conf-dir <rootfs>/etc/dnsmasq.conf` | `/etc/dnsmasq.d/` |
| `BASE-DNS-05` | `device` | IoT client: `nslookup modberry.internal`; upstream query for `internal` | resolved locally; not forwarded |
| `BASE-DNS-06` | `device` | Wired test device on LAN1 | address from `172.30.10.0/24` |

---

## 8. Constraints & Risks

- `BASE-DNS-01`: today, networkd (`DHCPServer=yes`) and dnsmasq both run on the AP.
- `BASE-DNS-02`: `usb0` exists only in service mode (`BASE-USBG-20`). `bind-dynamic` lets dnsmasq bind when the interface appears.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Local names. | `BASE-DNS-05` | **Decided:** yes, domain `internal`. |
| 2 | DHCP on LAN1. | `BASE-DNS-06` | **Decided:** yes, with reservations. |
