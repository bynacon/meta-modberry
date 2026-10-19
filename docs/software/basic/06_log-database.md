# Log Database Destination

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-LOGDB` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
| **Depends on** | `BASE-LOG`, `BASE-ROOTFS`, `BASE-LUKS`, PostgreSQL (not yet specified) |
| **Hardware reference** | — |
| **Risk** | `low` |

---

## 1. Purpose

This module transfers the log entries collected by `BASE-LOG` into the local PostgreSQL database, where they are stored next to the sensor data. syslog-ng writes structured entries through its `sql()` destination. The module makes sure that no entries are lost while the database is not available.

---

## 2. Scope

### In scope

- syslog-ng `sql()` destination into PostgreSQL.
- Format of the log entries in the database.
- Buffering of entries while the database is not available.
- Protection of the database credentials of syslog-ng.

### Out of scope

- journald and syslog-ng base configuration → `BASE-LOG`
- PostgreSQL installation, database, user, schema and retention → not yet specified (application layer)
- Encrypted data partition on which the database and the disk buffer are stored → `BASE-ROOTFS`, `BASE-LUKS`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| `syslog-ng` with libdbi support | `meta-openembedded` (meta-oe) | — |
| `libdbi`, `libdbi-drivers` (pgsql) | `meta-openembedded` | — |

---

## 4. Requirements

- `BASE-LOGDB-01` **MUST** syslog-ng writes the entries into the local PostgreSQL instance via the `sql()` destination.
- `BASE-LOGDB-02` **MUST** Each database entry contains the fields timestamp, facility, severity, program and message.
- `BASE-LOGDB-03` **MUST** Timestamps are stored with time zone information.
- `BASE-LOGDB-04` **MUST** The database credentials of syslog-ng are readable only by the syslog-ng service.
- `BASE-LOGDB-05` **MUST** No entries are lost while PostgreSQL is not available (boot, restart).
- `BASE-LOGDB-06` **MUST** The disk buffer is stored on the encrypted data partition.

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `/etc/syslog-ng/conf.d/50-pgsql.conf` | destination `sql(type(pgsql) …)` with columns `timestamp`, `facility`, `severity`, `program`, `message`; log path from `s_journal` | `BASE-LOGDB-01`, `BASE-LOGDB-02` |
| `/etc/syslog-ng/conf.d/50-pgsql.conf` | `disk-buffer(reliable(yes) dir(<data partition>))` on the `sql()` destination | `BASE-LOGDB-05`, `BASE-LOGDB-06` |
| `/etc/syslog-ng/` credentials file | mode `0600`, owner of the service | `BASE-LOGDB-04` |

---

## 6. Interfaces to Other Modules

### Provides

- Structured log table in PostgreSQL – used by the application layer.

### Consumes

- Source `s_journal`, filters and include directory `/etc/syslog-ng/conf.d/` – owned by `BASE-LOG` (`BASE-LOG-11`, `BASE-LOG-12`, `BASE-LOG-14`).
- Encrypted, persistent data partition – owned by `BASE-ROOTFS` and `BASE-LUKS`.
- PostgreSQL instance, database, user and table – owner not yet specified.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-LOGDB-01` | `device` | `SELECT count(*) FROM <log table>` | increases over time |
| `BASE-LOGDB-02` | `device` | `\d <log table>` | the five required columns exist |
| `BASE-LOGDB-03` | `device` | Column type of `timestamp` | `timestamptz` |
| `BASE-LOGDB-04` | `device` | `stat -c '%U %a' <credentials file>` | service user, `600` |
| `BASE-LOGDB-05` | `device` | Stop PostgreSQL, `logger -t dbtest test`, start PostgreSQL | test entry arrives in the DB |
| `BASE-LOGDB-06` | `device` | `findmnt -T <disk-buffer dir>` | encrypted data partition |

---

## 8. Constraints & Risks

- **PostgreSQL is not defined in any specification.** This module is blocked until a specification for the database exists.
- The `sql()` destination requires syslog-ng built with libdbi support and the PostgreSQL libdbi driver. Check that both are available for kirkstone.
- syslog-ng starts early in the boot, PostgreSQL later. Without `disk-buffer()`, entries from the early boot are lost (`BASE-LOGDB-05`).
- The disk buffer contains log messages in plain text. It must not be on the unencrypted root filesystem or on tmpfs (`BASE-LOGDB-06`).

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Which module owns PostgreSQL (database, user, log table, retention)? | all | **Deferred:** depends on the PostgreSQL / application layer specification. |
| 2 | Retention of log entries in the database (time, row count)? | `BASE-LOGDB-01` | **Deferred:** depends on the PostgreSQL / application layer specification. |
| 3 | Are all severities written into the database, or only from a minimum level (e.g. `info`)? | `BASE-LOGDB-01` | **Deferred:** depends on the PostgreSQL / application layer specification. |
| 4 | Maximum size of the disk buffer? | `BASE-LOGDB-05` | **Deferred:** depends on the PostgreSQL / application layer specification. |
