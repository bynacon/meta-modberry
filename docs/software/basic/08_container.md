# Container Runtime (Docker)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-CONT` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-FW`, `BASE-FWP`, `BASE-ROOTFS`, `BASE-MAC` |
| **Hardware reference** | — |
| **Risk** | `high` |

---

## 1. Purpose

This module provides the container runtime for the application layer. Docker runs without network exposure, without giving users root-equivalent access, with user namespace remapping and AppArmor, and with its data on the data partition. Container networking is integrated into the nftables ruleset instead of Docker's own `iptables` rules.

---

## 2. Scope

### In scope

- Docker engine and Compose, daemon configuration.
- Access control to the Docker API.
- Container isolation defaults.
- Integration with nftables and the read-only root filesystem.
- Origin and integrity of container images.

### Out of scope

- The containers of the application (web application, databases) → application layer
- Container-specific AppArmor profiles → application layer (`BASE-MAC` open point 3)
- Firewall framework → `BASE-FW`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `docker-ce` (or `docker-moby`), `containerd`, `runc` | `meta-virtualization` | — |
| Docker Compose v2 plugin (`docker compose`) | `meta-virtualization` (or own recipe, see section 8) | `python3-docker-compose` (Compose v1, unsupported) |
| `modberry-docker-config` (new) | `meta-modberry` | Docker `iptables` rules |

---

## 4. Requirements

### 4.1 Daemon

- `BASE-CONT-01` **MUST** The Docker API is available only on the local Unix socket. No TCP socket is configured.
- `BASE-CONT-02` **MUST** No human account is member of the group `docker` (`BASE-INIT-48`). Containers are started by systemd units, not interactively.
- `BASE-CONT-03` **MUST** The Docker data root is on the data partition (`/data/app/docker`).
- `BASE-CONT-04` **MUST** Container logs go to the journal (`log-driver: journald`).
- `BASE-CONT-05` **MUST** `live-restore` is enabled, so that a restart of the daemon does not stop the containers.

### 4.2 Isolation

- `BASE-CONT-10` **MUST** User namespace remapping is enabled (`userns-remap`), so that root in a container is not root on the device.
- `BASE-CONT-11` **MUST** `no-new-privileges` is the default for all containers.
- `BASE-CONT-12` **MUST** Containers run with the AppArmor profile `docker-default` or a stricter profile.
- `BASE-CONT-13` **MUST** Privileged containers, host network mode and mounts of `/var/run/docker.sock` are not used.
- `BASE-CONT-14` **SHOULD** Every container has memory and CPU limits.

### 4.3 Networking

- `BASE-CONT-20` **MUST** Docker does not manage packet filter rules (`iptables: false`, `ip6tables: false`).
- `BASE-CONT-21` **MUST** The forwarding and NAT rules for container networks are defined by this module in its own file in `/etc/nftables.d/` and follow the forward matrix of `BASE-FWP`.
- `BASE-CONT-22` **MUST** Ports of containers are published only on `127.0.0.1` (reached through nginx, `BASE-WEB-05`) or on the interfaces of the port matrix.

### 4.4 Images

- `BASE-CONT-30` **MUST** Container images come only from the Bynacon registry.
- `BASE-CONT-31` **MUST** Compose files reference every image by digest (`image: <registry>/<name>@sha256:…`), never by tag. The compose files themselves are delivered signed through the OTA system.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/docker/daemon.json` | `"hosts": ["unix:///run/docker.sock"]`, `"data-root": "/data/app/docker"`, `"log-driver": "journald"`, `"live-restore": true` | `BASE-CONT-01`, `BASE-CONT-03` … `BASE-CONT-05` |
| `/etc/docker/daemon.json` | `"userns-remap": "default"`, `"no-new-privileges": true` | `BASE-CONT-10`, `BASE-CONT-11` |
| `/etc/docker/daemon.json` | `"iptables": false`, `"ip6tables": false` | `BASE-CONT-20` |
| `/etc/nftables.d/60-container.nft` | forward and masquerade rules for the Docker bridge networks | `BASE-CONT-21` |
| Image recipe | no `usermod -a -G docker` for human accounts | `BASE-CONT-02` |
| systemd units of the application | `docker compose up` per application, `Restart=on-failure` | `BASE-CONT-02` |
| Compose files of the application | `image: <bynacon-registry>/<name>@sha256:<digest>` | `BASE-CONT-30`, `BASE-CONT-31` |

---

## 6. Interfaces to Other Modules

### Provides

- Container runtime – used by the application layer.
- Container network rules in `/etc/nftables.d/` – part of the ruleset of `BASE-FW`.

### Consumes

- Include directory – owned by `BASE-FW`; forward matrix – owned by `BASE-FWP`.
- `/data/app/` – owned by `BASE-ROOTFS`.
- AppArmor – owned by `BASE-MAC`.
- Account rules – owned by `BASE-INIT`.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-CONT-01` | `device` | `ss -ltnp \| grep dockerd` | no TCP listener |
| `BASE-CONT-02` | `device` | `getent group docker` | no human member |
| `BASE-CONT-03` | `device` | `docker info -f '{{.DockerRootDir}}'` | `/data/app/docker` |
| `BASE-CONT-04`, `-05` | `device` | `docker info` | `Logging Driver: journald`, `Live Restore Enabled: true` |
| `BASE-CONT-10` | `device` | `docker info` → Security Options | `userns` |
| `BASE-CONT-11`, `-12` | `device` | `docker inspect <container>` | `no-new-privileges`, `AppArmorProfile` set |
| `BASE-CONT-13` | `device` | `docker inspect` of all containers | not privileged, no host network, no socket mount |
| `BASE-CONT-20` | `device` | `iptables` command absent; `nft list ruleset` | no Docker-created tables |
| `BASE-CONT-21` | `device` | Container reaches only the destinations allowed by `BASE-FWP` | as specified |
| `BASE-CONT-22` | `device` | `ss -ltnp` | container ports only on `127.0.0.1` or matrix interfaces |
| `BASE-CONT-30`, `-31` | `rootfs` / `device` | `grep image: <compose files>`; start with a modified image of the same tag | only Bynacon registry, only `@sha256:` references; modified image not used |

---

## 8. Constraints & Risks

- `BASE-CONT-02`: today, `user` is in the group `docker` (`rpi-cm4.bb`). Membership in `docker` is equivalent to root access.
- `BASE-CONT-03`: Docker needs a writable, large `/data/app/docker`; with a read-only root filesystem this is mandatory.
- `BASE-CONT-10`: `userns-remap` changes file ownership of volumes; existing volumes of the application must be prepared for it.
- Components: kirkstone `meta-virtualization` ships Compose v1 (`python3-docker-compose`). Whether a Compose v2 recipe is available for kirkstone must be checked; otherwise the plugin binary is packaged by an own recipe.
- `BASE-CONT-12`: `docker-default` requires AppArmor to be enabled (`BASE-MAC-01`).
- `BASE-CONT-20`: with `iptables: false`, Docker sets up no NAT for container networks; `BASE-CONT-21` must provide it, otherwise containers have no network.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Which registry, and signed images (Notation/cosign) or pinned digests? | `BASE-CONT-30`, `BASE-CONT-31` | **Decided:** Bynacon registry; images pinned by digest; compose files signed via OTA. |
| 2 | Rootless Docker instead of `userns-remap`? | `BASE-CONT-10` | **Decided:** `userns-remap`. |
| 3 | Compose v1 (`python3-docker-compose`) or the Compose v2 plugin? | Components | **Decided:** Compose v2 plugin. |
| 4 | Docker in the base image. | Scope | **Decided:** own base module. |
