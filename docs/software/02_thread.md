# Software Stack: Thread Network

This document defines the software components for the Thread mesh network layer. The Thread radio stack runs on a dedicated co-processor connected to the main CPU via UART. The main CPU operates as the Thread Border Router. Device-specific interface assignments (UART path, GPIO pins, baud rate) are defined in the hardware specification for the respective device.

---

## 1. Co-Processor (RCP) – UART Connection

The Thread Radio Co-Processor (RCP) runs on a dedicated microcontroller. The connection to the main CPU is exclusively via UART.

| Parameter | Value |
| :-- | :-- |
| Protocol | Spinel over HDLC-Lite framing |
| Firmware | OpenThread RCP (vendor SDK) |

The RCP handles only the IEEE 802.15.4 radio layer (PHY/MAC). The full Thread protocol stack runs on the main CPU.

---

## 2. OpenThread Daemon

- **ot-daemon:** OpenThread daemon process on the main CPU. Implements the complete Thread stack (network layer through application layer). Communicates with the RCP via Spinel frames over the UART interface.
  - Unix domain socket: `/run/openthread/wpan0`
  - Configuration: `/etc/openthread/wpan0.conf`
  - systemd unit: `ot-daemon@wpan0.service`
  - Virtual network interface: `wpan0`

- **ot-ctl:** CLI for runtime management of the Thread network. Connects to the ot-daemon Unix socket.

```bash
# Initialize and start the network
ot-ctl dataset init new
ot-ctl dataset commit active
ot-ctl ifconfig up
ot-ctl thread start

# Query status
ot-ctl state          # Leader / Router / End Device / Detached
ot-ctl ipaddr         # Assigned IPv6 addresses
ot-ctl networkkey     # Active Network Key
ot-ctl extpanid       # Extended PAN ID
```

---

## 3. Thread Border Router

- **otbr-agent:** OpenThread Border Router agent. Manages routing between the Thread interface (`wpan0`) and the IP backbone (Ethernet / WLAN). Publishes Thread on-mesh prefixes to the backbone via Router Advertisements.
  - Web API: port 8080
  - systemd unit: `otbr-agent.service`

- **otbr-web:** Web interface for network configuration. Sets the Active Operational Dataset (Network Key, PAN ID, Channel, Extended PAN ID).

### 3.1 Service Discovery

- **Avahi:** mDNS/DNS-SD daemon. Publishes the Border Router as `_meshcop._udp` and `_thread-meshcop-e._udp` on the local backbone network. Enables automatic discovery by Thread Commissioner applications.

---

## 4. NAT64 / DNS64

Thread devices communicate exclusively over IPv6. Access to IPv4 resources in the upstream network is handled via NAT64/DNS64 on the Border Router.

- **tayga:** Stateless NAT64 daemon. Maps outbound IPv6 packets from Thread devices to an IPv4 address on the Border Router.
  - NAT64 prefix: `64:ff9b::/96`
  - TUN interface: `nat64`
  - Configuration: `/etc/tayga.conf`

- **dnsmasq (DNS64):** DNS64 extension. Returns synthesized AAAA records with the NAT64 prefix in response to A-record queries from Thread devices.
  - DNS64 prefix: `64:ff9b::/96`

- **nftables (NAT64 masquerading):** Masquerading chain for the `nat64` interface. Packets from the Thread network are mapped to the external IPv4 address of the Border Router.

```text
Thread device (IPv6) → wpan0 → tayga (nat64) → nftables NAT → upstream (IPv4)
```

---

## 5. Thread Commissioning

New Thread devices join the network via the Joiner procedure. The Border Router assumes the Commissioner role.

- Commissioning runs over DTLS (port 49191).
- Joiner credentials are set per device: `ot-ctl commissioner joiner add <eui64> <pskd>`.
- External Commissioner applications discover the Border Router via the `_meshcop._udp` mDNS service record.

---

## 6. Monitoring & Security

- **Spinel/UART watchdog:** systemd service monitors `ot-daemon`. On connection loss, HDLC framing errors, or unexpected RCP reset, the UART interface is reset and `ot-daemon` is restarted.

```ini
# /etc/systemd/system/ot-daemon@wpan0.service (excerpt)
[Service]
Restart=on-failure
RestartSec=5
OnFailure=reset-uart.service
```

- **auditd:** Monitors all kernel-level access to the Thread UART interface. Logs any process opening the device node outside of ot-daemon.

- **nftables Thread zones:** Forwarding chains for `wpan0`:
  - Outbound from Thread network → backbone: Allows MQTT-TLS (8883), CoAP (5683/5684), DNS (53), HTTPS (443).
  - Inbound from backbone → Thread: Only established connections (`ct state established,related`). No unsolicited access from LAN/WLAN clients to Thread devices.
