# <Module Title>

<!--
  MODULE SPECIFICATION TEMPLATE
  - One file = one module that can be implemented and verified on its own.
  - This file is the source of truth (WHAT). It contains no implementation steps (HOW).
  - Copy this file, replace all <placeholders>, delete all guidance comments.
  - Requirement IDs are stable: never renumber or reuse a removed ID.
-->

| Field | Value |
| :-- | :-- |
| **Module ID** | `<STACK>-<MODULE>` <!-- e.g. BASE-FW, BASE-VBOOT, THREAD-OTBR --> |
| **Stack** | `basic` \| `thread` \| … |
| **Spec status** | `draft` \| `review` \| `approved` |
| **Depends on** | `<MODULE-ID>`, `<MODULE-ID>` <!-- modules that must be implemented first --> |
| **Hardware reference** | `docs/hardware/M40804W_MAX.md` (as relative link from the module file) – section <n> <!-- only if device-specific values are needed --> |
| **Risk** | `low` \| `medium` \| `high` <!-- high = can brick the device or lock out access → human gate --> |

---

## 1. Purpose

<!-- 2–3 sentences: what this module provides and why the system needs it. -->

<Describe the responsibility of this module.>

---

## 2. Scope

### In scope

- <What this module defines and owns.>

### Out of scope

- <What is explicitly NOT part of this module, with a reference to the owning module.> → `<MODULE-ID>`

---

## 3. Components

<!--
  Every package that this module adds or removes from the image.
  "Replaces" lists packages/configs that MUST be removed (conflicts with the current state).
-->

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `<package>` | `<meta-layer>` | `<package>` or `—` |

---

## 4. Requirements

<!--
  - One requirement = one testable statement.
  - Format: `<MODULE-ID>-<NN>` **MUST|SHOULD|MAY** <statement>.
  - MUST = mandatory for Definition of Done. SHOULD = implement unless there is a documented reason.
  - No device-specific values (paths like /dev/ttyAMA0, GPIO numbers) → reference the hardware spec.
  - Group by topic with ### subsections if there are more than ~8 requirements.
-->

### 4.1 <Topic>

- `<MODULE-ID>-01` **MUST** <requirement>.
- `<MODULE-ID>-02` **MUST** <requirement>.
- `<MODULE-ID>-03` **SHOULD** <requirement>.

### 4.2 <Topic>

- `<MODULE-ID>-10` **MUST** <requirement>.

<!-- Leave gaps between groups (01.., 10.., 20..) so new requirements can be added without renumbering. -->

---

## 5. Configuration

<!--
  Configuration files this module owns on the target, and the values that are fixed by the spec.
  Only list values that are requirements; leave everything else to the implementation.
-->

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/<file>` | `<key>=<value>` | `<MODULE-ID>-01` |

---

## 6. Interfaces to Other Modules

<!--
  Shared resources need exactly one owner. Consumers reference the owner and never redefine it.
-->

### Provides

- <Resource, e.g. nftables set `@banned_ips`, socket, user/group, partition> – used by `<MODULE-ID>`

### Consumes

- <Resource> – owned by `<MODULE-ID>` (`<REQ-ID>`)

---

## 7. Verification

<!--
  Every MUST requirement needs at least one check.
  Level:
    build    – bitbake completes without error
    manifest – package present/absent in the image manifest
    rootfs   – file/content present in the built rootfs (no hardware needed)
    device   – runtime check on real hardware
-->

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `<MODULE-ID>-01` | `manifest` | `<package>` in image manifest | present |
| `<MODULE-ID>-02` | `rootfs` | `grep '<key>' <rootfs>/etc/<file>` | `<key>=<value>` |
| `<MODULE-ID>-10` | `device` | `<command>` | <expected output> |

---

## 8. Constraints & Risks

<!-- Kirkstone/version constraints, known pitfalls, conditions that require a human gate. -->

- <Constraint or risk and its consequence.>

---

## 9. Open Points

<!--
  Unresolved questions or contradictions. A requirement affected by an open point is blocked
  for implementation until the point is resolved.
-->

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | <Open question> | `<MODULE-ID>-02` | <empty until decided> |
