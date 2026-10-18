# Software Stack: Base System & Security

This document defines the software components of the base system layer. It covers the init system, hardware interface tooling, cryptography, network security, and system hardening. This is the source of truth for image composition and build configuration. Device-specific interface mappings (UART paths, GPIO numbers, I2C addresses) are defined in the hardware specification for the respective device.

---

## 1. Init System & Service Management

- **systemd:** Init system and service manager. Handles boot sequence, daemon lifecycle, and socket activation for all system services.
- **systemd-networkd:** Built-in network daemon. Configures Ethernet and WLAN interfaces via `.network` files in `/etc/systemd/network/`.

---

## 2. Hardware Interface Tooling

- **can-utils:** Userspace toolset for CAN bus access. Includes `candump`, `cansend`, `cangen`. Requires the corresponding kernel module for the CAN controller.
- **i2c-tools:** Diagnostic tools for I2C bus access (`i2cdetect`, `i2cget`, `i2cset`).
- **picocom:** Lightweight serial terminal for UART access and testing.
- **udev:** Kernel device manager. Rule files under `/etc/udev/rules.d/` enforce persistent interface names and access permissions for serial, CAN, and SPI device nodes.

---

## 3. Secure Boot & Filesystem Integrity

- **U-Boot Verified Boot:** Cryptographic signature verification of the kernel image and device tree at boot time. Signing keys are stored in the TPM. Prevents execution of unsigned or tampered boot artifacts.
- **TPM Measured Boot:** Each boot stage (bootloader, kernel, initramfs) extends TPM PCR registers. LUKS keys are sealed against specific PCR values and are only released if the measured boot state matches the expected configuration.
- **dm-verity:** Kernel-level integrity verification for the root filesystem. A cryptographic hash tree over the block device is verified on every read. The root hash is stored in the TPM and verified at mount time. The root filesystem is mounted read-only.
- **overlayfs:** Writable overlay on top of the read-only root filesystem. Ephemeral writes go to a tmpfs layer; persistent application data is stored on a separate encrypted data partition.

---

## 4. Cryptography & Data Encryption

- **tpm2-tss:** TCG TPM2 Software Stack. Abstraction layer for the hardware TPM. Provides `ESYS`, `FAPI`, and `TCTI` interfaces for TPM access.
- **tpm2-tools:** CLI for TPM2 operations: key generation, sealing, PCR read-out, remote attestation.
- **OpenSSL:** TLS/SSL library for all encrypted connections (HTTPS, MQTT-TLS, VPN handshake). Bound to the hardware TPM via `ENGINE_load_tpm2`.
- **dm-crypt / LUKS:** Kernel-level block device encryption for data partitions. Keys are sealed in the TPM and unsealed at boot via `tpm2-tools`.

---

## 4. Network & Remote Access

### 4.1 Firewall

- **nftables:** Netfilter ruleset in the Linux kernel. Replaces iptables. Three base chains:
  - **input:** Inbound packets to the device itself. Allows only authorized ports (SSH, MQTT-TLS, HTTPS, Border Router API).
  - **forward:** Forwarding between interfaces. Controls traffic between the LAN, and WLAN.
  - **output:** Outbound traffic from the device. Restricted to defined protocols and destinations.

### 4.2 WLAN Access Point

- **hostapd:** WLAN AP daemon. Configuration: WPA3-Personal (SAE) or WPA2/WPA3 mixed mode. `ap_isolate=1` enabled. WEP, WPA-TKIP, and WPS disabled.
- **iwd:** WLAN client daemon (Intel iNet wireless daemon). Manages client-side WLAN connections with native WPA3 support.
- **dnsmasq:** DHCP server and DNS forwarder in AP mode.
- **hostapd_cli event scripts:** React to hostapd events (deauth flooding, repeated authentication failures). Applies temporary MAC bans via nftables.

### 4.3 Remote Access & VPN

- **WireGuard (`wireguard-tools`):** Kernel-native VPN. Integrated as a `systemd-networkd` interface. Provides secured remote access to the device.
- **OpenSSH:** Encrypted remote shell access. Configuration: key-based authentication, `PasswordAuthentication no`.
- **nginx:** Reverse proxy for the local web application. TLS termination, HTTP→HTTPS redirect, source IP restriction.

### 4.4 VLAN & Bridge

- **iproute2 / bridge-utils:** VLAN and bridge management. Isolates the access point (WLAN AP), the service network (LAN0), and the sensore/actuator network (LAN1).

---

## 5. Time Synchronization

- **chrony:** NTP client and server daemon. Maintains accurate system time required for TLS certificate validation, TPM PCR timestamping, and log correlation. Configured with authenticated NTP sources (NTS — Network Time Security). Falls back to the hardware RTC on network loss.

---

## 6. System Monitoring & Hardening

- **AppArmor:** Mandatory Access Control (MAC). Per-service profiles restrict filesystem paths, network sockets, and device nodes to the required minimum.
- **auditd:** Linux Audit Subsystem. Logs kernel syscalls. Configured for continuous monitoring of access to serial interfaces and the SPI TPM interface.
- **AIDE (Advanced Intrusion Detection Environment):** File integrity monitoring. Builds a cryptographic baseline of critical system files at first boot. Detects unauthorized modifications on subsequent checks. Runs as a scheduled systemd timer.
- **USBGuard:** USB device whitelisting at kernel level. Unauthorized USB devices are blocked automatically on connect.
- **Fail2Ban:** Log-based IP blocklist. Bans source IPs after repeated failed logins (SSH, WLAN authentication) via nftables integration.
- **PSAD (Port Scan Attack Detector):** Detects port scans and attack patterns from nftables drop logs. Triggers automatic block rules for identified scanners.
- **watchdog:** Hardware watchdog daemon. Triggers a system reset if the main CPU hangs or critical services become unresponsive. Integrates with the kernel hardware watchdog driver (`/dev/watchdog`).
- **sysctl hardening:** Kernel parameter hardening via `/etc/sysctl.d/`. Key settings: `kernel.kptr_restrict=2`, `kernel.dmesg_restrict=1`, `net.ipv4.conf.all.rp_filter=1`, `net.ipv4.conf.all.accept_redirects=0`, `kernel.yama.ptrace_scope=2`.
- **fuser:** Diagnostic tool. Lists active processes holding a file or device node open.

---

## 6. Logging

- **systemd-journald:** Central log collection for all systemd services. Configuration: `Storage=persistent` in `/etc/systemd/journald.conf`.
- **syslog-ng:** Structured syslog daemon. Routes logs by facility and severity. Uses the `sql()` destination to write structured log entries (timestamp, facility, severity, program, message) into the local PostgreSQL instance alongside sensor data. Kernel messages from journald (`_TRANSPORT=kernel`) are included automatically.
