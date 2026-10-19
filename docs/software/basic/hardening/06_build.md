# Build Hardening & Vulnerability Management

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-BUILD` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
| **Depends on** | `BASE-INIT` |
| **Hardware reference** | — |
| **Risk** | `medium` |

---

## 1. Purpose

This module hardens the image at build time and makes its content traceable. Binaries are built with hardening compiler flags, the kernel with hardening options, and the production image contains no debug or package management features. Every release has a CVE report and an SBOM, and the build uses fixed revisions of all layers.

---

## 2. Scope

### In scope

- Compiler and linker hardening flags.
- Kernel configuration hardening (beyond `sysctl`).
- Content restrictions of the production image.
- CVE check, SBOM, release rules for known vulnerabilities.
- Fixed layer revisions.

### Out of scope

- `sysctl` parameters and module signing → `BASE-KERN`
- Signing of boot artifacts → `BASE-VBOOT`
- Delivery of updates → OTA layer

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `security_flags.inc` | `poky` (openembedded-core) | — |
| `cve-check.bbclass`, `create-spdx.bbclass` | `poky` (openembedded-core) | — |
| Kernel hardening config fragment (new) | `meta-modberry` | — |

---

## 4. Requirements

### 4.1 Compiler Hardening

- `BASE-BUILD-01` **MUST** The distro conf includes `conf/distro/include/security_flags.inc` (stack protector, `_FORTIFY_SOURCE=2`, PIE, RELRO, `-z now`).
- `BASE-BUILD-02` **MUST** Recipes of this layer do not remove the hardening flags (`SECURITY_CFLAGS:pn-<recipe>` overrides only with documented reason).

### 4.2 Kernel Configuration

- `BASE-BUILD-10` **MUST** The kernel config fragment enables: `CONFIG_STRICT_DEVMEM`, `CONFIG_IO_STRICT_DEVMEM`, `CONFIG_HARDENED_USERCOPY`, `CONFIG_FORTIFY_SOURCE`, `CONFIG_STACKPROTECTOR_STRONG`, `CONFIG_RANDOMIZE_BASE`, `CONFIG_SECURITY_DMESG_RESTRICT`, `CONFIG_INIT_ON_ALLOC_DEFAULT_ON`.
- `BASE-BUILD-11` **MUST** The kernel config fragment disables: `CONFIG_DEVMEM` (if no user needs `/dev/mem`), `CONFIG_KEXEC`, `CONFIG_HIBERNATION`, `CONFIG_LEGACY_PTYS`, `CONFIG_BINFMT_MISC`, `CONFIG_PROC_KCORE`.

### 4.3 Image Content

- `BASE-BUILD-20` **MUST** The production image contains none of the image features `debug-tweaks`, `tools-debug`, `tools-profile`, `dbg-pkgs`, `dev-pkgs`, `package-management`, `ssh-server-dropbear`.
- `BASE-BUILD-21` **MUST** The production image contains no compilers, debuggers (`gdb`, `strace`) or network test tools (`nmap`, `tcpdump`) unless a module lists them under *Components*.
- `BASE-BUILD-22` **MUST** Core dumps are disabled in the production image.

### 4.4 Vulnerability Management

- `BASE-BUILD-30` **MUST** Every build runs the CVE check (`cve-check`) and produces a report per image.
- `BASE-BUILD-31` **MUST** Every release produces an SBOM in SPDX format (`create-spdx`) and stores it with the release artifacts.
- `BASE-BUILD-32` **MUST** A release is published only after the CVE report has been reviewed. Known critical vulnerabilities in packages of the image are fixed or documented with an assessment before the release.
- `BASE-BUILD-33` **MUST** The build uses fixed revisions (commit hashes) of all layers. Updates of layer revisions are explicit changes.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| Distro conf `modberry` | `require conf/distro/include/security_flags.inc` | `BASE-BUILD-01` |
| `recipes-kernel/linux/files/hardening.cfg` | options of `BASE-BUILD-10`, `BASE-BUILD-11` | `BASE-BUILD-10`, `BASE-BUILD-11` |
| Image recipe | production: `IMAGE_FEATURES:remove` / no `EXTRA_IMAGE_FEATURES` of `BASE-BUILD-20` | `BASE-BUILD-20`, `BASE-BUILD-21` |
| `/etc/systemd/coredump.conf.d/`, `/etc/security/limits.d/` | `Storage=none`, `ProcessSizeMax=0`; `* hard core 0`; `kernel.core_pattern=|/bin/false` | `BASE-BUILD-22` |
| Distro conf `modberry` | `INHERIT += "cve-check create-spdx"` | `BASE-BUILD-30`, `BASE-BUILD-31` |
| `scripts/Yocto/Build_kirkstone.sh` | `git clone` + `git checkout <commit>` per layer (revisions in one versioned file) | `BASE-BUILD-33` |

---

## 6. Interfaces to Other Modules

### Provides

- Hardened build defaults – baseline for all modules.
- CVE report and SBOM per release – used by the release process and the OTA layer.

### Consumes

- Distro conf and image variant switch – owned by `BASE-INIT`.
- Build script – owned by the `scripts` repository.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-BUILD-01` | `build` | `bitbake -e <image> \| grep ^SECURITY_CFLAGS=` | contains `-fstack-protector-strong`, `-D_FORTIFY_SOURCE=2` |
| `BASE-BUILD-01` | `rootfs` | `checksec --file=<rootfs>/usr/sbin/sshd` (or `readelf -d`) | PIE, full RELRO, canary |
| `BASE-BUILD-02` | `build` | `grep -r SECURITY_CFLAGS <layer>` | no overrides without comment |
| `BASE-BUILD-10`, `-11` | `build` | `grep` the options in the kernel `.config` | set / not set as specified |
| `BASE-BUILD-20` | `build` | `bitbake -e <image> \| grep ^IMAGE_FEATURES=` (production) | none of the listed features |
| `BASE-BUILD-21` | `manifest` | `gdb`, `strace`, `gcc`, `nmap`, `tcpdump` in the production manifest | absent |
| `BASE-BUILD-22` | `device` | `ulimit -c`; `sysctl kernel.core_pattern` | `0`; no dump target |
| `BASE-BUILD-30` | `build` | `ls tmp/deploy/images/*/*.json` (cve report) | report per image |
| `BASE-BUILD-31` | `build` | `ls tmp/deploy/spdx/` | SPDX documents for the image |
| `BASE-BUILD-33` | `build` | Build twice from the same revision file | identical layer revisions |

---

## 8. Constraints & Risks

- `BASE-BUILD-11`: disabling `CONFIG_DEVMEM` breaks tools that access `/dev/mem` (e.g. `raspi-gpio` older versions). Check with `BASE-HWT-05`.
- `BASE-BUILD-20`: today, `local_kirkstone.conf` enables `debug-tweaks` and `ssh-server-dropbear` for every build; the production variant must remove them (`BASE-INIT-42`).
- `BASE-BUILD-30`, `BASE-BUILD-32`: **kirkstone reached its end of life in April 2026** and receives no upstream security fixes any more. Until a migration to a supported LTS release, every CVE fix must be backported by Bynacon (open point 1).
- `BASE-BUILD-33`: today, `Build_kirkstone.sh` clones moving branches (`-b kirkstone`); two builds from the same script can produce different images.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Kirkstone is end of life since April 2026: migrate to scarthgap (LTS until April 2028) or the next LTS release, or stay on kirkstone with own backports? | `BASE-BUILD-30`, `BASE-BUILD-32`, all modules | |
| 2 | Where are CVE reports and SBOMs stored, and who reviews them per release? | `BASE-BUILD-31`, `BASE-BUILD-32` | |
