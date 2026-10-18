# Intrusion Detection & Prevention (Fail2Ban, port scan detection, hostapd events)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-IDS` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-FW`, `BASE-WAP`, `BASE-LOG` |
| **Hardware reference** | — |
| **Risk** | `medium` |

---

## 1. Purpose

This module detects attacks from the network and blocks the attackers for a limited time. Fail2Ban bans source addresses after repeated failed logins. A port scan detector bans addresses that scan the device. Event scripts on the WLAN access point react to deauthentication floods and repeated authentication failures with temporary MAC bans. All bans use the ban sets of the firewall.

---

## 2. Scope

### In scope

- Fail2Ban jails for SSH and WLAN authentication.
- Port scan detection based on the firewall drop log.
- hostapd event scripts for WLAN attacks.
- Ban durations, thresholds and allow lists.

### Out of scope

- Ban sets, drop logging and their placement in the ruleset → `BASE-FW` (`BASE-FW-40` … `BASE-FW-51`)
- hostapd and its control interface → `BASE-WAP` (`BASE-WAP-30`)
- Journal → `BASE-LOG`
- Notification of operators → application layer

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `python3-fail2ban` 0.11.2 | `meta-security` (recipes-security) | — |
| `python3-systemd` (journal backend) | `meta-openembedded` (meta-python) | — |
| Port scan detection (PSAD or alternative) | **not available for kirkstone** (see open point 1) | — |
| `hostapd-cli` (`hostapd_cli`) | `meta-openembedded` | — |
| `modberry-ids` (new: jails, nftables actions, event scripts) | `meta-modberry` | — |

---

## 4. Requirements

### 4.1 General

- `BASE-IDS-01` **MUST** All bans are entries with timeout in the ban sets of `BASE-FW` (`ban_ipv4`, `ban_ipv6`, `ban_mac`). This module creates no own tables, chains or sets (`BASE-FW-42`).
- `BASE-IDS-02` **MUST** Addresses in `service_nets` (`BASE-FW-14`) and the VPN subnet are never banned.
- `BASE-IDS-03` **MUST** Every ban and every unban is logged to the journal with address, reason and duration.
- `BASE-IDS-04` **MUST** Bans do not survive a reboot.

### 4.2 Fail2Ban

- `BASE-IDS-10` **MUST** Fail2Ban reads the journal (`backend = systemd`).
- `BASE-IDS-11` **MUST** A jail bans the source IP address after repeated failed SSH logins (`sshd`).
- `BASE-IDS-12` **MUST** A jail bans after repeated WLAN authentication failures. Because WLAN clients have no IP address before authentication, this ban uses the MAC address (`ban_mac`).
- `BASE-IDS-13` **MUST** Fail2Ban uses a custom nftables action that adds elements to the ban sets of `BASE-FW`, not the default `nftables` action (which creates its own table).

### 4.3 Port Scan Detection

- `BASE-IDS-20` **MUST** Port scans are detected from the firewall drop log (`BASE-FW-50`).
- `BASE-IDS-21` **MUST** A detected scanner is banned by its source IP address.

### 4.4 hostapd Events

- `BASE-IDS-30` **MUST** An event script reacts to hostapd events on both AP interfaces (`wlan0_iot`, `wlan0_guest`).
- `BASE-IDS-31` **MUST** A deauthentication flood or repeated authentication failures from one MAC address lead to a temporary MAC ban.
- `BASE-IDS-32` **MUST** The event script runs as a systemd service with `Restart=on-failure` (`BASE-INIT-23`) and connects to the hostapd control interface as member of the control interface group (`BASE-WAP-30`).

---

## 5. Configuration

### 5.1 Thresholds

<!-- Proposal, to be confirmed (open point 2). -->

| Detection | Threshold | Ban duration | Ban set |
| :-- | :-- | :-- | :-- |
| SSH failed logins | 5 in 10 min | 1 h | `ban_ipv4` / `ban_ipv6` |
| WLAN authentication failures | 10 in 5 min | 30 min | `ban_mac` |
| Port scan | 10 dropped ports in 1 min | 24 h | `ban_ipv4` / `ban_ipv6` |
| Deauthentication flood | 20 frames in 10 s | 30 min | `ban_mac` |

### 5.2 Files

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/fail2ban/jail.d/modberry.conf` | `backend = systemd`, jails `sshd`, `hostapd-auth`, `ignoreip = <service_nets> <VPN subnet>` | `BASE-IDS-02`, `BASE-IDS-10` … `BASE-IDS-12` |
| `/etc/fail2ban/action.d/nftables-modberry.conf` | `actionban = nft add element inet filter ban_<family> { <ip> timeout <bantime>s }` | `BASE-IDS-01`, `BASE-IDS-13` |
| `/etc/fail2ban/filter.d/hostapd-auth.conf` | regex on hostapd authentication failure messages | `BASE-IDS-12` |
| `/etc/fail2ban/fail2ban.conf` | `dbfile = :memory:` | `BASE-IDS-04` |
| `modberry-hostapd-events.service` | `hostapd_cli -i <if> -a /usr/libexec/modberry/hostapd-event` per AP interface | `BASE-IDS-30` … `BASE-IDS-32` |

---

## 6. Interfaces to Other Modules

### Provides

- Temporary bans in the ban sets – effective in the `input` and `forward` chains of `BASE-FW`.
- Ban and unban events in the journal – used by `BASE-LOG` / `BASE-LOGDB` and the application layer.

### Consumes

- Ban sets, drop log prefixes, `service_nets` – owned by `BASE-FW`.
- hostapd control interface and AP interfaces – owned by `BASE-WAP`.
- sshd authentication log – owned by `BASE-RACC`.
- Journal – owned by `BASE-LOG`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-IDS-01` | `device` | `nft list tables` while bans are active | no table besides those of `BASE-FW` and `THREAD-NAT64` |
| `BASE-IDS-02` | `device` | Failed SSH logins from a host in `service_nets` | no ban |
| `BASE-IDS-03` | `device` | `journalctl -u fail2ban` after a ban | ban with address, jail and duration |
| `BASE-IDS-04` | `device` | Ban, reboot, `nft list set inet filter ban_ipv4` | empty |
| `BASE-IDS-11` | `device` | 5 failed SSH logins from a test host | test host banned for 1 h |
| `BASE-IDS-12` | `device` | Repeated wrong passphrase from a test client | test client MAC in `ban_mac` |
| `BASE-IDS-13` | `rootfs` | `grep -r 'banaction' <rootfs>/etc/fail2ban/jail.d/` | `nftables-modberry` |
| `BASE-IDS-20`, `-21` | `device` | `nmap -sS <device>` from a test host | test host banned |
| `BASE-IDS-31` | `device` | Deauthentication flood from a test device (lab only) | test device MAC banned |
| `BASE-IDS-32` | `device` | `systemctl show -p Restart modberry-hostapd-events` | `on-failure` |

---

## 8. Constraints & Risks

- **PSAD is not available for kirkstone** (neither in `meta-security` nor in `meta-openembedded`). Options: own recipe for PSAD (Perl, expects iptables log format), a Fail2Ban jail on the nftables drop log (simple, no extra daemon), or `crowdsec` / `suricata` from `meta-security` (heavy for the CM4).
- The default `nftables` action of Fail2Ban creates its own table `f2b-table`. This violates `BASE-FW-42`; a custom action is required (`BASE-IDS-13`).
- Fail2Ban with `backend = systemd` needs `python3-systemd`. Without it, Fail2Ban falls back to file polling and finds no log files on a journald-only system.
- MAC addresses can be spoofed. MAC bans slow down an attacker, they do not stop a determined one.
- Detecting deauthentication floods requires that the driver reports these frames to hostapd. With `brcmfmac` (FullMAC), management frames are handled in the firmware, so deauthentication floods are probably not visible (open point 3).
- A ban on the address of a legitimate service technician locks them out. `BASE-IDS-02` excludes `service_nets` and the VPN for this reason.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Port scan detection: own PSAD recipe, Fail2Ban jail on the nftables drop log (recommended), or `crowdsec` / `suricata`? | `BASE-IDS-20`, `BASE-IDS-21`, Components | |
| 2 | Confirm thresholds and ban durations (section 5.1). | `BASE-IDS-11` … `BASE-IDS-31` | |
| 3 | Does `brcmfmac` report deauthentication and authentication failure events to hostapd? If not, `BASE-IDS-31` cannot be met with the on-board radio. | `BASE-IDS-30`, `BASE-IDS-31` | |
| 4 | Should repeated offenders get longer bans (`bantime.increment`)? | `BASE-IDS-11` | |
