# Remote Access (WireGuard, OpenSSH, nginx)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-RACC` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-NETD`, `BASE-FW`, `BASE-TPM`, `BASE-TIME`, `BASE-PROV` |
| **Hardware reference** | — |
| **Risk** | `high` |

---

## 1. Purpose

This module provides secured remote access to the device. The device connects as WireGuard client to the Bynacon VPN server, so that it is reachable for remote service behind any NAT. OpenSSH provides an encrypted shell with key-based authentication only. nginx is the reverse proxy for the local web interface: it terminates TLS with a certificate of the Bynacon CA, redirects HTTP to HTTPS and restricts access by source address.

---

## 2. Scope

### In scope

- WireGuard client interface and its `.netdev` / `.network` files.
- OpenSSH server configuration and the Bynacon service key.
- nginx as TLS-terminating reverse proxy.
- Requirements on keys and certificates of these services.

### Out of scope

- Firewall openings for SSH, HTTP(S) and WireGuard → `BASE-FW`
- Generation and storage of per-device keys and certificates → `BASE-PROV`
- User accounts of the image → `BASE-INIT` (`BASE-INIT-45`)
- The local web application behind nginx → application layer
- TPM key storage → `BASE-TPM`
- Brute-force protection (Fail2Ban) → `BASE-IDS`
- The Bynacon VPN server and CA → infrastructure (outside this layer)

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `wireguard-tools` | `meta-openembedded` (meta-networking) | — |
| Kernel: `wireguard` | `linux-raspberrypi` (in-tree since 5.6) | — |
| `openssh-sshd`, `openssh-ssh`, `openssh-keygen` | `poky` (openembedded-core) | `dropbear` (`ssh-server-dropbear`) |
| `nginx` | `meta-openembedded` (meta-webserver) | — |
| `modberry-service-key` (new: Bynacon service public key) | `meta-modberry` | — |

---

## 4. Requirements

### 4.1 WireGuard

- `BASE-RACC-01` **MUST** The WireGuard interface `wg0` is defined as a systemd-networkd `.netdev` (`Kind=wireguard`) and `.network` file.
- `BASE-RACC-02` **MUST** The WireGuard private key is generated on the device during provisioning and is not stored in the image or the repository.
- `BASE-RACC-03` **MUST** The private key file is readable only by root and `systemd-network` (mode `0640`).
- `BASE-RACC-04` **MUST** The only peer is the Bynacon VPN server. Its `AllowedIPs` contain only the VPN subnet.
- `BASE-RACC-05` **MUST** Remote access to SSH and HTTPS from outside the local segments is possible only through `wg0`.
- `BASE-RACC-06` **MUST** The device is the WireGuard client: it initiates the tunnel to `VPN_ENDPOINT` and keeps it open with `PersistentKeepalive`. It does not listen on an inbound WireGuard port.

### 4.2 OpenSSH

- `BASE-RACC-10` **MUST** OpenSSH is the only SSH server. `dropbear` is not part of the image.
- `BASE-RACC-11` **MUST** Authentication is key-based only: `PasswordAuthentication no`, `KbdInteractiveAuthentication no`.
- `BASE-RACC-12` **MUST** Login as root is not possible (`PermitRootLogin no`).
- `BASE-RACC-13` **MUST** SSH host keys are generated on the device at first boot and stored persistently. They are not part of the image.
- `BASE-RACC-14` **MUST** The image contains exactly one authorized key: the Bynacon service public key for `user`. Further keys are added by provisioning (`BASE-PROV`).
- `BASE-RACC-15` **MUST** The Bynacon service key can be replaced by an image update, without reprovisioning the device.

### 4.3 nginx

- `BASE-RACC-20` **MUST** nginx forwards HTTPS requests to the local web application.
- `BASE-RACC-21` **MUST** nginx terminates TLS with TLS 1.2 or higher only.
- `BASE-RACC-22` **MUST** HTTP requests on port 80 are answered only with a redirect to HTTPS.
- `BASE-RACC-23` **MUST** nginx restricts access by source address to `service_nets` and the VPN subnet.
- `BASE-RACC-24` **MUST** The local web application listens only on loopback or a Unix socket, so that it is reachable only through nginx.
- `BASE-RACC-25` **SHOULD** The TLS private key of nginx is TPM-resident (see `BASE-TPM` open point 4).
- `BASE-RACC-26` **MUST** The TLS certificate of nginx is signed by the Bynacon CA and is issued per device during provisioning.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/systemd/network/60-wg0.netdev` | `Kind=wireguard`, `PrivateKeyFile=/data/provisioning/wireguard/wg0.key`, no `ListenPort` | `BASE-RACC-01`, `BASE-RACC-06` |
| `/etc/systemd/network/60-wg0.netdev` | `[WireGuardPeer] PublicKey=`, `Endpoint=${VPN_ENDPOINT}`, `AllowedIPs=<VPN subnet>`, `PersistentKeepalive=25` (from `wireguard/peer.conf`) | `BASE-RACC-04`, `BASE-RACC-06` |
| `/etc/systemd/network/60-wg0.network` | tunnel `Address=` from provisioning | `BASE-RACC-01` |
| `/etc/ssh/sshd_config` (layer file) | `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin no`, `AuthorizedKeysFile .ssh/authorized_keys /data/provisioning/ssh/authorized_keys` | `BASE-RACC-11`, `BASE-RACC-12`, `BASE-RACC-14` |
| `/home/user/.ssh/authorized_keys` | Bynacon service public key, mode `0600` | `BASE-RACC-14`, `BASE-RACC-15` |
| `/etc/ssh/ssh_host_*_key` | generated by `sshdgenkeys.service`, persistent location | `BASE-RACC-13` |
| `/etc/nginx/sites-enabled/webapp.conf` | `listen 443 ssl`, `ssl_protocols TLSv1.2 TLSv1.3`, `ssl_certificate /data/provisioning/tls/server.crt`, `proxy_pass http://127.0.0.1:<port>` or `unix:` | `BASE-RACC-20`, `BASE-RACC-21`, `BASE-RACC-24`, `BASE-RACC-26` |
| `/etc/nginx/sites-enabled/webapp.conf` | `listen 80; return 301 https://$host$request_uri;` | `BASE-RACC-22` |
| `/etc/nginx/sites-enabled/webapp.conf` | `allow <service_nets>; allow <VPN subnet>; deny all;` | `BASE-RACC-23` |

---

## 6. Interfaces to Other Modules

### Provides

- Interface `wg0` – used by `BASE-FW` (port matrix) and `BASE-NETD` (address plan).
- SSH on 22/tcp, HTTPS on 443/tcp, HTTP redirect on 80/tcp – opened by `BASE-FW`.
- SSH access with the Bynacon service key – used by `BASE-PROV` (factory provisioning).
- sshd authentication log – used by `BASE-IDS` (Fail2Ban).
- Reverse proxy for the web application – used by the application layer.

### Consumes

- `.netdev` / `.network` convention and address plan – owned by `BASE-NETD`.
- Firewall openings and `service_nets` – owned by `BASE-FW`.
- Per-device keys, peer configuration and certificate – owned by `BASE-PROV`.
- Account `user` – owned by `BASE-INIT`.
- OpenSSL and TPM keys – owned by `BASE-TPM`.
- Correct time for certificate validation – owned by `BASE-TIME` (`time-sync.target`).

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-RACC-01` | `device` | `networkctl status wg0`, `wg show` | interface up, one peer |
| `BASE-RACC-02` | `rootfs` | Search the rootfs for WireGuard private keys | none |
| `BASE-RACC-03` | `device` | `stat -c '%U:%G %a' /data/provisioning/wireguard/wg0.key` | `root:systemd-network 640` |
| `BASE-RACC-04` | `device` | `wg show wg0 allowed-ips` | only the VPN subnet |
| `BASE-RACC-05` | `device` | SSH from the uplink network from a host outside `service_nets` | blocked |
| `BASE-RACC-06` | `device` | `wg show wg0 listen-port`; device behind NAT, connect from VPN server | random port, no firewall opening; tunnel up |
| `BASE-RACC-10` | `manifest` | `dropbear` in image manifest; `openssh-sshd` present | absent / present |
| `BASE-RACC-11` | `device` | `ssh -o PubkeyAuthentication=no user@<device>` | `Permission denied (publickey)` |
| `BASE-RACC-12` | `device` | `sshd -T \| grep permitrootlogin` | `no` |
| `BASE-RACC-13` | `rootfs` | `ls <rootfs>/etc/ssh/ssh_host_*` | absent in the image |
| `BASE-RACC-13` | `device` | Fingerprint before and after reboot | unchanged |
| `BASE-RACC-14` | `rootfs` | `cat <rootfs>/home/user/.ssh/authorized_keys` | exactly the Bynacon service key |
| `BASE-RACC-15` | `rootfs` | Service key installed by its own recipe, not from provisioning | yes |
| `BASE-RACC-20` | `device` | `curl --cacert <Bynacon CA> https://<device>/` | answer of the web application |
| `BASE-RACC-21` | `device` | `openssl s_client -tls1_1 -connect <device>:443` | handshake fails |
| `BASE-RACC-22` | `device` | `curl -I http://<device>/` | `301` to `https://` |
| `BASE-RACC-23` | `device` | Request from a host outside `service_nets` and VPN (firewall rule temporarily open) | `403` |
| `BASE-RACC-24` | `device` | `ss -ltnp` | web application bound to `127.0.0.1` or a Unix socket |
| `BASE-RACC-26` | `device` | `openssl s_client -connect <device>:443 -CAfile <Bynacon CA>` | `Verify return code: 0 (ok)` |

---

## 8. Constraints & Risks

- **Human gate:** password login is disabled only after login with the Bynacon service key has been verified on the device. Otherwise the device is locked out.
- **One service key for all devices:** if the private part of the Bynacon service key is compromised, every device is affected. The private key must be protected (hardware token, restricted access). `BASE-RACC-15` allows rotation via image update. SSH is reachable only from `service_nets` and the VPN (`BASE-FW-14`).
- The current image uses `dropbear` (`ssh-server-dropbear` in `local_kirkstone.conf`). `openssh_%.bbappend` adds `file://sshd_config`, which does not exist in the layer. Because the `openssh` recipe of poky ships its own `sshd_config`, the bbappend has no effect: the upstream default configuration is used. A layer `sshd_config` with the settings of section 5 is needed.
- `recipes-connectivity/openssh/files/ssh_config` is a client configuration that no recipe installs. It contains `AllowRootLogin Yes`, which is not a valid option, and `PasswordAuthentication Yes`. It should be removed.
- `debug-tweaks` (enabled for every build today) allows root login with an empty password. This contradicts `BASE-RACC-11` and `BASE-RACC-12` (see `BASE-INIT-43`).
- Host keys must survive reboots. With a read-only root filesystem (`BASE-ROOTFS`), they must be on the data partition.
- WireGuard cannot use TPM-resident keys. The private key is a file.
- Technician laptops must trust the Bynacon CA, otherwise browsers show a warning.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | WireGuard role. | `BASE-RACC-01` … `BASE-RACC-06` | **Decided:** device is client of the Bynacon VPN server. Values of `VPN_ENDPOINT`, port and VPN subnet follow. |
| 2 | `PermitRootLogin`. | `BASE-RACC-12` | **Decided:** `no`; root is locked (`BASE-INIT-45`). |
| 3 | Provisioning of authorized SSH keys. | `BASE-RACC-14` | **Decided:** Bynacon service key in the image for `user`; further keys via provisioning. |
| 4 | Which web application runs behind nginx, and on which port or socket? (e.g. SmartHomeWebApp) | `BASE-RACC-20`, `BASE-RACC-24` | |
| 5 | TLS certificate source. | `BASE-RACC-21`, `BASE-RACC-26` | **Decided:** Bynacon CA, issued per device at factory provisioning. |
| 6 | Source networks for nginx. | `BASE-RACC-23` | **Decided:** `service_nets` and the VPN subnet. |
