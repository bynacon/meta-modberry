# Web Proxy (nginx)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-WEB` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-FWP`, `BASE-TPM`, `BASE-TIME`, `BASE-PROV` |
| **Hardware reference** | — |
| **Risk** | `medium` |

---

## 1. Purpose

nginx is the reverse proxy for the local web interface. It terminates TLS with a per-device certificate of the Bynacon CA and a TPM-resident key, redirects HTTP to HTTPS and restricts access by source address.

---

## 2. Scope

### In scope

- nginx as TLS-terminating reverse proxy.
- TLS settings, certificate and key handling.
- Source address restriction.

### Out of scope

- The web application behind nginx → application layer
- Issuing of the certificate → `BASE-PROV`
- TPM provider for OpenSSL → `BASE-TPM`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `nginx` | `meta-openembedded` (meta-webserver) | — |

---

## 4. Requirements

- `BASE-WEB-01` **MUST** nginx forwards HTTPS requests to the local web application.
- `BASE-WEB-02` **MUST** nginx terminates TLS with TLS 1.2 or higher only.
- `BASE-WEB-03` **MUST** HTTP requests on port 80 are answered only with a redirect to HTTPS.
- `BASE-WEB-04` **MUST** nginx restricts access by source address to `service_nets`, the VPN subnet and the USB service port.
- `BASE-WEB-05` **MUST** The local web application listens only on loopback or a Unix socket, so that it is reachable only through nginx.
- `BASE-WEB-06` **MUST** The TLS private key of nginx is a TPM key (`BASE-TPM-33`); nginx uses it through the OpenSSL TPM provider.
- `BASE-WEB-07` **MUST** The TLS certificate of nginx is signed by the Bynacon CA and is issued per device during provisioning.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/nginx/sites-enabled/webapp.conf` | `listen 443 ssl`, `ssl_protocols TLSv1.2 TLSv1.3`, `proxy_pass http://127.0.0.1:<port>` or `unix:` | `BASE-WEB-01`, `BASE-WEB-02`, `BASE-WEB-05` |
| `/etc/nginx/sites-enabled/webapp.conf` | `ssl_certificate /data/provisioning/tls/server.crt`, key via TPM provider | `BASE-WEB-06`, `BASE-WEB-07` |
| `/etc/nginx/sites-enabled/webapp.conf` | `listen 80; return 301 https://$host$request_uri;` | `BASE-WEB-03` |
| `/etc/nginx/sites-enabled/webapp.conf` | `allow <service_nets>; allow <VPN subnet>; allow <usb0 subnet>; deny all;` | `BASE-WEB-04` |

---

## 6. Interfaces to Other Modules

### Provides

- HTTPS on 443/tcp and HTTP redirect on 80/tcp – opened by `BASE-FWP`.
- Reverse proxy – used by the application layer.

### Consumes

- `service_nets` – owned by `BASE-FWP`; VPN subnet – owned by `BASE-VPN`; `usb0` subnet – owned by `BASE-USBG`.
- TPM key and OpenSSL provider – owned by `BASE-TPM`.
- Certificate – owned by `BASE-PROV`.
- Correct time – owned by `BASE-TIME` (`time-sync.target`).

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-WEB-01` | `device` | `curl --cacert <Bynacon CA> https://<device>/` | answer of the web application |
| `BASE-WEB-02` | `device` | `openssl s_client -tls1_1 -connect <device>:443` | handshake fails |
| `BASE-WEB-03` | `device` | `curl -I http://<device>/` | `301` to `https://` |
| `BASE-WEB-04` | `device` | Request from a host outside the allowed networks (firewall rule temporarily open) | `403` |
| `BASE-WEB-05` | `device` | `ss -ltnp` | web application bound to `127.0.0.1` or a Unix socket |
| `BASE-WEB-06` | `device` | `ls /data/provisioning/tls/`; nginx config | no PEM private key file; key reference to the TPM |
| `BASE-WEB-07` | `device` | `openssl s_client -connect <device>:443 -CAfile <Bynacon CA>` | `Verify return code: 0 (ok)` |

---

## 8. Constraints & Risks

- `BASE-WEB-06`: nginx must load the OpenSSL TPM provider; check that the kirkstone nginx works with OpenSSL 3 providers for the server key (`ssl_certificate_key "store:..."` or engine syntax).
- `BASE-WEB-07`: technician laptops must trust the Bynacon CA, otherwise browsers show a warning.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Which web application runs behind nginx, and on which port or socket? | `BASE-WEB-01`, `BASE-WEB-05` | **Deferred:** application layer. |
| 2 | Certificate source. | `BASE-WEB-07` | **Decided:** Bynacon CA, issued at factory provisioning. |
| 3 | Allowed source networks. | `BASE-WEB-04` | **Decided:** `service_nets`, VPN, USB service port. |
