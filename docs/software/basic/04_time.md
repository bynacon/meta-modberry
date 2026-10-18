# Time Synchronization

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-TIME` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-NETD` |
| **Hardware reference** | [M40804W_MAX.md](../../hardware/M40804W_MAX.md) – section 3.1 (RTC MCP79412) |
| **Risk** | `low` |

---

## 1. Purpose

This module keeps the system time correct. A correct time is required for TLS certificate validation, for log correlation and for TPM-based operations. chrony synchronizes the time from authenticated NTP sources (NTS), serves time to local networks, and uses the hardware RTC when no network is available.

---

## 2. Scope

### In scope

- chrony as NTP client and NTP server.
- Authenticated time sources via NTS.
- Use of the hardware RTC at boot and on network loss.
- Removal of `systemd-timesyncd`.
- Ordering of services that need a valid time.

### Out of scope

- RTC device tree overlay and driver → hardware specification, section 8
- Network interfaces on which time is served → `BASE-NETD`
- Firewall rules for NTP and NTS-KE → `BASE-FW`
- Time zone and locale → not yet specified

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `chrony` (with NTS support) | `meta-openembedded` | `systemd-timesyncd` |
| — | — | `recipes-core/systemd/files/timesyncd.conf` |

---

## 4. Requirements

### 4.1 Time Service

- `BASE-TIME-01` **MUST** chrony is installed and `chronyd` starts at boot.
- `BASE-TIME-02` **MUST** `systemd-timesyncd` is not part of the image.
- `BASE-TIME-03` **MUST** Exactly one service sets the system clock.

### 4.2 Authenticated Sources

- `BASE-TIME-10` **MUST** All configured time sources use NTS.
- `BASE-TIME-11` **MUST** chrony does not use unauthenticated sources, including pool or DHCP-provided servers.
- `BASE-TIME-12` **SHOULD** At least three independent NTS sources are configured.

### 4.3 Hardware RTC

- `BASE-TIME-20` **MUST** At boot, the system time is set from the hardware RTC before network time is available.
- `BASE-TIME-21` **MUST** chrony keeps the hardware RTC synchronized with the system time while sources are reachable.
- `BASE-TIME-22` **MUST** On network loss, the system keeps running on the last synchronized time without a time jump.
- `BASE-TIME-23` **MUST** If the RTC time is invalid at boot, chrony may make exactly one clock update without checking the time validity of the NTS-KE certificates (`nocerttimecheck 1`). Certificate chain and signature are still checked.

### 4.4 NTP Server

- `BASE-TIME-30` **MUST** chronyd serves time via NTP to the IoT segment (`br-iot`) only.
- `BASE-TIME-31` **MUST** chronyd denies NTP clients from all other networks.
- `BASE-TIME-32` **MUST** chronyd does not serve time to clients while it is not synchronized.

### 4.5 Service Ordering

- `BASE-TIME-40` **SHOULD** `time-sync.target` is reached only after chrony is synchronized, so that services which validate certificates can order themselves after it.

### 4.6 Time Zone

- `BASE-TIME-50` **MUST** The system time zone is UTC. Conversion to local time is done by the applications.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/chrony.conf` | `server <host> iburst nts` for `time.cloudflare.com`, `nts.netnod.se`, `ptbtime1.ptb.de`, `ntppool1.time.nl`; no `pool` | `BASE-TIME-10`, `BASE-TIME-11`, `BASE-TIME-12` |
| `/etc/chrony.conf` | `nocerttimecheck 1` | `BASE-TIME-23` |
| Build: distro conf `modberry` | `DEFAULT_TIMEZONE = "UTC"` (replaces `CET` in `local_kirkstone.conf`) | `BASE-TIME-50` |
| `/etc/chrony.conf` | `rtcsync` or `rtcfile` + `rtcdevice /dev/rtc0` | `BASE-TIME-21` |
| `/etc/chrony.conf` | `allow 172.30.10.0/24`, no `allow all` | `BASE-TIME-30`, `BASE-TIME-31` |
| `/etc/chrony.conf` | no `local` directive | `BASE-TIME-32` |
| `/etc/chrony.conf` | `ntsdumpdir /var/lib/chrony` | `BASE-TIME-10` |
| systemd | `chrony-wait.service` enabled | `BASE-TIME-40` |

---

## 6. Interfaces to Other Modules

### Provides

- Correct system time and `time-sync.target` – used by `BASE-RACC` (TLS), `BASE-LOG` (timestamps), `BASE-TPM` consumers.
- NTP service on UDP 123 for the local networks – used by devices on the sensor/actuator network.

### Consumes

- `/dev/rtc0` (MCP79412) – owned by the hardware specification.
- Network interfaces and network names – owned by `BASE-NETD`.
- Firewall rules – owned by `BASE-FW`: outbound UDP 123 and TCP 4460 (NTS-KE) to the sources, inbound UDP 123 from the served networks.
- Service integration rules – owned by `BASE-INIT`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-TIME-01` | `manifest` | `chrony` in image manifest | present |
| `BASE-TIME-01` | `device` | `systemctl is-active chronyd` | `active` |
| `BASE-TIME-02` | `manifest` | `systemd-timesyncd` in image manifest | absent |
| `BASE-TIME-03` | `device` | `timedatectl show -p NTP` | `NTP=no` (timesyncd not active) |
| `BASE-TIME-10` | `device` | `chronyc -N authdata` | every source has mode `NTS` and a valid key |
| `BASE-TIME-11` | `rootfs` | `grep -E '^(pool\|server)' <rootfs>/etc/chrony.conf` | every line contains `nts` |
| `BASE-TIME-12` | `device` | `chronyc sources` | ≥ 3 sources |
| `BASE-TIME-20` | `device` | Boot without network, `date` | time from RTC, not 1970 or build time |
| `BASE-TIME-21` | `device` | `hwclock -r` vs. `date` after sync | difference < 1 s |
| `BASE-TIME-22` | `device` | Unplug network for 1 h, then reconnect, `chronyc tracking` | no step correction |
| `BASE-TIME-23` | `device` | Clear the RTC, boot (lab) | one clock step, then normal NTS operation |
| `BASE-TIME-30` | `device` | `chronyd -Q 'server <device> iburst'` from a host in a served network | offset reported |
| `BASE-TIME-31` | `device` | Same query from another network | no answer |
| `BASE-TIME-40` | `device` | `systemctl show -p After <TLS service>` | contains `time-sync.target` |
| `BASE-TIME-50` | `device` | `timedatectl show -p Timezone` | `UTC` |

---

## 8. Constraints & Risks

- **NTS needs TLS, and TLS needs a correct time.** Without a working RTC, chrony cannot validate the NTS-KE certificates after a cold boot. `BASE-TIME-20` solves this. If the RTC fails, chrony's `nocerttimecheck` directive can allow a limited number of clock updates before certificate time checks. This weakens security and needs a decision.
- NTS requires chrony ≥ 4.0 built with GnuTLS. Check that the kirkstone recipe enables NTS (`chronyd -v` shows `+NTS`).
- The public `pool.ntp.org` servers configured today in `timesyncd.conf` do not support NTS.
- `systemd-timesyncd` is part of the `systemd` recipe and must be removed via `PACKAGECONFIG`, not only disabled.
- The machine conf refers to RTC settings in `local_kirkstone.conf`, which is not part of the layer.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Which NTS servers are used (public servers, or a company time server)? | `BASE-TIME-10`, `BASE-TIME-12` | **Decided:** public NTS servers of at least 3 operators (section 5). |
| 2 | To which networks does the device serve time: LAN0 (service), LAN1 (sensor/actuator), WLAN AP, Thread? | `BASE-TIME-30`, `BASE-TIME-31` | **Decided:** IoT segment only. |
| 3 | Is `nocerttimecheck` allowed as a fallback when the RTC is invalid? | `BASE-TIME-20` | **Decided:** yes, one update (`BASE-TIME-23`). |
| 4 | Is the MCP79412 battery-backed on this device? The hardware spec does not say. Without a battery, `BASE-TIME-20` cannot be met after power loss. | `BASE-TIME-20` | **Deferred:** needs hardware information → verification task. |
| 5 | The source spec mentions "TPM PCR timestamping". TPM PCRs have no timestamps. What is meant (e.g. timestamps in attestation quotes or in the event log)? | Purpose | **Decided:** removed; PCRs have no timestamps. |
| 6 | Time zone of the device (UTC, or `Europe/Zurich`)? Which module owns it? | Scope | **Decided:** UTC, owned by this module (`BASE-TIME-50`). |
