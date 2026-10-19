# Init System & Service Management

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-INIT` |
| **Stack** | `basic` |
| **Status** | `draft` |
| **Depends on** | — |
| **Hardware reference** | — |
| **Risk** | `medium` |

---

## 1. Purpose

This module defines systemd as the init system and service manager of the base image. systemd handles the boot sequence, the lifecycle of all daemons, and socket activation. All other modules rely on it to install and start their services.

---

## 2. Scope

### In scope

- Selection of systemd as the only init system (PID 1), set in the distro configuration of this layer.
- Removal of SysV init components from the image.
- Rules for how other modules integrate their services (unit files, enablement, restart policy, socket activation).
- Image variants (production, debug) and the debug switch.
- Serial console login per image variant.

### Out of scope

- Network configuration via `systemd-networkd` and `.network` files → `BASE-NETD`
- Time synchronization (replaces `systemd-timesyncd`) → `BASE-TIME`
- Journal configuration (`systemd-journald`) → `BASE-LOG`
- Hardware watchdog integration → `BASE-KERN`
- SSH access and authentication → `BASE-SSH`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `systemd` | `poky` (openembedded-core) | `sysvinit`, `initscripts` |
| `systemd-serialgetty` | `poky` (openembedded-core) | `sysvinit` getty entries – **debug image only** |
| — | — | `init-ifupdown` (SysV networking, see `BASE-NETD`) |

---

## 4. Requirements

### 4.1 Init System

- `BASE-INIT-01` **MUST** systemd is the init system and runs as PID 1.
- `BASE-INIT-02` **MUST** The distro configuration of this layer (`conf/distro/modberry.conf`) sets `INIT_MANAGER = "systemd"`. `local.conf` does not set init or distro features.
- `BASE-INIT-03` **MUST** The image contains no SysV init system (`sysvinit`, `initscripts`).

### 4.2 Boot Sequence

- `BASE-INIT-10` **MUST** The boot sequence is controlled exclusively by systemd units and targets.
- `BASE-INIT-11` **MUST** The system reaches its default target without failed units.
- `BASE-INIT-12` **SHOULD** The default target is `multi-user.target` (headless device, no graphical target).

### 4.3 Service Lifecycle

- `BASE-INIT-20` **MUST** Every system service is started by a systemd unit. SysV init scripts are not used.
- `BASE-INIT-21` **MUST** Services are enabled at build time via the `systemd` bbclass (`SYSTEMD_SERVICE`, `SYSTEMD_AUTO_ENABLE`), not via manually created symlinks in `do_install`.
- `BASE-INIT-22` **MUST** Unit files of the layer are installed to `${systemd_system_unitdir}`.
- `BASE-INIT-23` **MUST** Every long-running service (`Type=simple`, `exec`, `notify`, `forking`) has `Restart=on-failure`. For upstream units without this setting, the layer adds a drop-in.
- `BASE-INIT-24` **MUST** `Restart=always` is not used. One-shot tasks use `Type=oneshot` without a restart policy.
- `BASE-INIT-25` **MUST** The start limit (`StartLimitIntervalSec`, `StartLimitBurst`) is not disabled, so that a service that keeps failing ends in the `failed` state.

### 4.4 Socket Activation

- `BASE-INIT-30` **MUST** Socket activation is available for system services.
- `BASE-INIT-31` **MUST** Own services (software developed by Bynacon, in this layer or the application layer) that accept connections on a socket are socket-activated.
- `BASE-INIT-32` **SHOULD** Third-party daemons that support socket activation use it.

### 4.5 Image Variants & Serial Console

- `BASE-INIT-40` **MUST** The production image has no login prompt on any console: serial interfaces, HDMI/`tty1` and virtual terminals.
- `BASE-INIT-41` **MAY** The debug image provides a login on the service serial port via `systemd-serialgetty`.
- `BASE-INIT-42` **MUST** One image recipe builds both variants. The variable `MODBERRY_DEBUG = "1"` in `local.conf` selects the debug variant; without it, the production variant is built.
- `BASE-INIT-43` **MUST** The production variant contains no `debug-tweaks` and no account with an empty password.
- `BASE-INIT-44` **MUST** A debug image can be identified on the device and by its file name (e.g. `VARIANT_ID=debug` in `/etc/os-release`, image name suffix `-debug`).
- `BASE-INIT-45` **MUST** The production variant of this layer has the account `user` with a locked password; it logs in only via SSH key. `root` is locked.
- `BASE-INIT-46` **MUST** Accounts that other layers add (e.g. the OTA layer) also meet `BASE-INIT-43` and `BASE-INIT-45`.
- `BASE-INIT-47` **MUST** `user` has password-less `sudo` (its password is locked, so `sudo` cannot ask for one).
- `BASE-INIT-48` **MUST** No human account is member of a group that grants root-equivalent access other than through `sudo` (in particular `docker`, `disk`).

### 4.6 Service Sandboxing

- `BASE-INIT-50` **MUST** Every long-running service of this layer runs as its own system user unless it needs root; the reason for root is documented in the module.
- `BASE-INIT-51` **MUST** Every long-running service of this layer sets at least `NoNewPrivileges=yes`, `PrivateTmp=yes`, `ProtectSystem=strict` (with explicit `ReadWritePaths=`), `ProtectHome=yes`, `ProtectKernelTunables=yes`, `ProtectKernelModules=yes`, `ProtectControlGroups=yes`, `RestrictSUIDSGID=yes`, unless the module documents an exception.
- `BASE-INIT-52` **MUST** Services limit their capabilities with `CapabilityBoundingSet=` to the capabilities they need.
- `BASE-INIT-53` **SHOULD** Upstream services get the same settings through drop-ins, and `systemd-analyze security` rates every long-running service at most `MEDIUM`.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/sbin/init` | Symlink to `systemd` | `BASE-INIT-01` |
| Build: `conf/distro/modberry.conf` | `require conf/distro/poky.conf`, `INIT_MANAGER = "systemd"` | `BASE-INIT-02` |
| Build: `local.conf` | `DISTRO = "modberry"` | `BASE-INIT-02` |
| `/etc/systemd/system/default.target` | → `multi-user.target` | `BASE-INIT-12` |
| `/etc/systemd/system/<unit>.d/10-restart.conf` | `[Service] Restart=on-failure` for upstream units | `BASE-INIT-23` |
| Build: production image | `SERIAL_CONSOLES = ""` or `systemd-serialgetty` not installed | `BASE-INIT-40` |
| Build: `local.conf` | `MODBERRY_DEBUG = "1"` only for debug builds | `BASE-INIT-42` |
| Build: image recipe `rpi-cm4.bb` | `debug-tweaks`, `systemd-serialgetty`, debug users only if `MODBERRY_DEBUG` is `1` (e.g. via `bb.utils.contains`/`oe.utils.conditional`) | `BASE-INIT-41`, `BASE-INIT-43` |
| Build: image recipe `rpi-cm4.bb` | `IMAGE_NAME_SUFFIX`/`IMAGE_BASENAME` and `os-release` `VARIANT_ID` per variant | `BASE-INIT-44` |
| Build: image recipe `rpi-cm4.bb` | production: `useradd -p '!'` for `user`; `usermod -L root` (instead of `-p ''`) | `BASE-INIT-45` |
| `/etc/sudoers.d/10-user` | `user ALL=(ALL) NOPASSWD: ALL`, mode `0440` | `BASE-INIT-47` |
| `cmdline.txt` / kernel command line | no `console=tty1` in production; `getty@tty1.service` masked | `BASE-INIT-40` |
| `<service>.service.d/50-sandbox.conf` | settings of `BASE-INIT-51`, `CapabilityBoundingSet=`, `User=` | `BASE-INIT-50` … `BASE-INIT-53` |

---

## 6. Interfaces to Other Modules

### Provides

- systemd as PID 1 and service manager – used by all modules.
- Distro configuration `modberry` – used by all modules that need `DISTRO_FEATURES`.
- `multi-user.target` as the target to which modules attach their services.
- Integration rules `BASE-INIT-20` to `BASE-INIT-25` and `BASE-INIT-31` – binding for all modules that install services.

### Consumes

- —

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-INIT-01` | `rootfs` | `readlink <rootfs>/sbin/init` | path to `systemd` |
| `BASE-INIT-01` | `device` | `ps -p 1 -o comm=` | `systemd` |
| `BASE-INIT-02` | `build` | `bitbake -e <image> \| grep -E '^(DISTRO\|DISTRO_FEATURES\|VIRTUAL-RUNTIME_init_manager)='` | `DISTRO="modberry"`, contains `systemd` |
| `BASE-INIT-02` | `build` | `grep -E 'INIT_MANAGER\|DISTRO_FEATURES' conf/local.conf` | no match |
| `BASE-INIT-03` | `manifest` | `sysvinit`, `initscripts` in image manifest | absent |
| `BASE-INIT-10` | `rootfs` | `ls <rootfs>/etc/init.d/` | empty or missing |
| `BASE-INIT-11` | `device` | `systemctl is-system-running` | `running` |
| `BASE-INIT-11` | `device` | `systemctl --failed --no-legend` | empty |
| `BASE-INIT-12` | `device` | `systemctl get-default` | `multi-user.target` |
| `BASE-INIT-20` | `rootfs` | `ls <rootfs>/etc/rc*.d/` | empty or missing |
| `BASE-INIT-21` | `rootfs` | Review: no `ln -s` into `*.target.wants` in layer recipes | none found |
| `BASE-INIT-22` | `rootfs` | Layer unit files under `<rootfs>/lib/systemd/system/` | present |
| `BASE-INIT-23` | `device` | `systemctl show -p Restart <service>` for every long-running service | `Restart=on-failure` |
| `BASE-INIT-24` | `rootfs` | `grep -r 'Restart=always' <rootfs>/lib/systemd/system <rootfs>/etc/systemd/system` | no match in layer units |
| `BASE-INIT-25` | `rootfs` | `grep -r 'StartLimitIntervalSec=0' <rootfs>/lib/systemd/system <rootfs>/etc/systemd/system` | no match in layer units |
| `BASE-INIT-30` | `device` | `systemctl list-sockets` | command works, lists sockets |
| `BASE-INIT-31` | `device` | `systemctl list-sockets` | one `.socket` unit per own listening service |
| `BASE-INIT-40` | `manifest` | `systemd-serialgetty` in production image manifest | absent |
| `BASE-INIT-40` | `device` | Connect to every serial interface and to HDMI with a keyboard (production image) | no login prompt |
| `BASE-INIT-42` | `build` | `bitbake -e rpi-cm4 \| grep -E '^(IMAGE_FEATURES\|EXTRA_IMAGE_FEATURES)='` with and without `MODBERRY_DEBUG` | `debug-tweaks` only with `MODBERRY_DEBUG = "1"` |
| `BASE-INIT-43` | `rootfs` | `awk -F: '$2==""' <rootfs>/etc/shadow` of the production image | no output |
| `BASE-INIT-44` | `rootfs` | `grep VARIANT_ID <rootfs>/etc/os-release`; image file name | `debug` / `-debug` only for the debug variant |
| `BASE-INIT-45` | `rootfs` | `cut -d: -f1,2 <rootfs>/etc/shadow` of the production image | `root`, `user` start with `!` or `*` |
| `BASE-INIT-46` | `rootfs` | `awk -F: '$2==""' <rootfs>/etc/shadow` of the production image with all layers | no output |
| `BASE-INIT-47` | `device` | `sudo -n true` as `user` | exit code 0 |
| `BASE-INIT-48` | `device` | `getent group docker disk` | no human member |
| `BASE-INIT-50` … `-52` | `device` | `systemctl show -p User,NoNewPrivileges,ProtectSystem,CapabilityBoundingSet <service>` | values of `BASE-INIT-51`, `-52` |
| `BASE-INIT-53` | `device` | `systemd-analyze security` | every long-running service `MEDIUM` or better |

---

## 8. Constraints & Risks

- If the init manager is misconfigured, the device does not boot. Recovery requires reflashing the eMMC.
- `INIT_MANAGER` is currently set in `scripts/Yocto/local_kirkstone.conf` (other repository). With `BASE-INIT-02` it moves into the layer. `local_kirkstone.conf` must then set `DISTRO = "modberry"` and drop `INIT_MANAGER`.
- `recipes-core/systemd/systemd_%.bbappend` currently installs `.network` files and `timesyncd.conf`. This content belongs to `BASE-NETD` and `BASE-TIME`. One bbappend should not hold configuration for several modules.
- `BASE-INIT-24` covers the error that the former `slb9670-rpi.service` had: `Restart=always` on a command that exits at once. The recipe has been removed (see `BASE-TPM`).
- Several recipes use `${systemd_unitdir}/system` instead of `${systemd_system_unitdir}` (`BASE-INIT-22`). The target path is the same, so this is a consistency issue only.
- `local_kirkstone.conf` currently enables `debug-tweaks` for every build (`EXTRA_IMAGE_FEATURES`), and `rpi-cm4.bb` sets empty passwords for `root` and `user` (`EXTRA_USERS_PARAMS`). Every image built today is a debug image in the sense of `BASE-INIT-43`.
- **Human gate:** a production image without empty passwords and without serial login is only accessible via SSH keys (`BASE-SSH`). Key provisioning must work before the first production image is flashed.
- Both variants have the same recipe and, without `BASE-INIT-44`, the same file name. The suffix is required so that a debug image is not shipped by mistake.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Is `INIT_MANAGER` set in `local.conf` or in a new distro conf of this layer? | `BASE-INIT-02` | **Decided:** distro conf `conf/distro/modberry.conf` in this layer. |
| 2 | The source spec says socket activation applies to "all system services". Many daemons do not support it. | `BASE-INIT-30` … `BASE-INIT-32` | **Decided:** MUST for own services that accept connections, SHOULD for third-party daemons. |
| 3 | Should the spec define restart policies as a general rule? | `BASE-INIT-23` … `BASE-INIT-25` | **Decided:** yes, `Restart=on-failure` for all long-running services. |
| 4 | Serial console getty on the production image? | `BASE-INIT-40`, `BASE-INIT-41` | **Decided:** debug image only. |
| 5 | How are the production and debug image variants defined: two image recipes, or a switch? Which module owns the definition? | `BASE-INIT-40` … `BASE-INIT-44` | **Decided:** one image recipe with the switch `MODBERRY_DEBUG`; owned by `BASE-INIT`. |
| 6 | Which accounts does the production image have, and how do they log in? | `BASE-INIT-43`, `BASE-INIT-45` | **Decided:** this layer provides `user` (SSH key only), root locked. Accounts of the OTA stack are defined in `meta-ota`. |
| 7 | `sudo` rules: today `user` is in `sudo` (and `docker`). Password-less `sudo` for `user`? | `BASE-INIT-45` | **Decided:** password-less `sudo` for `user` (`BASE-INIT-47`). |
