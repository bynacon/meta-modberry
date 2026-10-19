<p align="center">
  <a href="https://www.techbase.eu/modberry">
    <img src="https://www.techbase.eu/wp-content/uploads/2022/03/logo_techbase_blue.svg" alt="Logo" width="200">
  </a>
</p>

<h1 align="center">meta-modberry</h1>

<p align="center">
  Yocto-Layer für den Techbase Modberry Industriecomputer, basierend auf dem Raspberry Pi Compute Module 4.
  <br />
  <a href="#9-release-notes-modberry"><strong>Release Notes anzeigen</strong></a>
</p>

<!-- PROJECT SHIELDS -->
<p align="center">
  <img src="https://img.shields.io/badge/Yocto-Kirkstone-blue.svg?style=for-the-badge" alt="Yocto Kirkstone">
  <img src="https://img.shields.io/badge/Raspberry%20Pi-CM4-C51A4A.svg?style=for-the-badge&logo=raspberry-pi" alt="Raspberry Pi CM4">
</p>

Dieses README beschreibt den Inhalt des Layers `meta-modberry`, seine Spezifikationen und wie die Spezifikationen mit dem Agent-System umgesetzt werden.

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Inhaltsverzeichnis</summary>
  <ol>
    <li><a href="#1-überblick">Überblick</a></li>
    <li><a href="#2-abhängigkeiten-dependencies">Abhängigkeiten (Dependencies)</a></li>
    <li><a href="#3-layer-zum-build-hinzufügen">Layer zum Build hinzufügen</a></li>
    <li><a href="#4-repository-struktur">Repository-Struktur</a></li>
    <li><a href="#5-hardware-dokumentation">Hardware-Dokumentation</a></li>
    <li><a href="#6-software-spezifikation">Software-Spezifikation</a></li>
    <li><a href="#7-umsetzung-mit-dem-agent-system">Umsetzung mit dem Agent-System</a></li>
    <li><a href="#8-patches">Patches</a></li>
    <li><a href="#9-release-notes-modberry">Release Notes Modberry</a>
      <ul>
        <li><a href="#release-note-nummerierung">Release Note Nummerierung</a></li>
      </ul>
    </li>
  </ol>
</details>

---

## 1. Überblick

Der Layer stellt das Basis-Image für den **Techbase Modberry M40804W MAX** (CM4) bereit: Maschinenkonfiguration, Board-Support (Device Tree, Overlays, Treiber), Basissystem und Sicherheitsfunktionen.

| Begriff | Wert |
| :-- | :-- |
| Yocto-Release | `kirkstone` (die Migration auf ein aktuelles LTS-Release ist offen, siehe `BASE-BUILD`) |
| Machine (Basis-Image) | `modberry-m40804w-max-basic` |
| Gemeinsame Machine-Konfiguration | `modberry-m40804w-max` (wird von der Basis-Machine eingebunden) |
| Image | `rpi-cm4` ([recipes-core/images/rpi-cm4.bb](recipes-core/images/rpi-cm4.bb)) |
| Bootloader | U-Boot (`RPI_USE_U_BOOT = "1"`) |

**Ist- und Soll-Stand:** Das Soll ist in den Modul-Spezifikationen unter [docs/software/basic/](docs/software/basic/README.md) festgelegt. Der heutige Stand der Rezepte (z. B. `dhcpcd`, `init-ifupdown`, `iptables`, `wpa-supplicant`) wird Task für Task durch die spezifizierten Module ersetzt (z. B. systemd-networkd, nftables). Der Fortschritt steht in [STATUS.md](docs/software/basic/STATUS.md).

---

## 2. Abhängigkeiten (Dependencies)

Dieser Layer hat die folgenden Abhängigkeiten:

| Layer | URI | Branch | Notwendigkeit |
| :--- | :--- | :--- | :--- |
| `poky` | `<https://github.com/yoctoproject/poky.git>` | `kirkstone` | **Erforderlich** |
| `meta-raspberrypi` | `git://git.yoctoproject.org/meta-raspberrypi` | `kirkstone` | **Erforderlich** |
| `meta-openembedded` | `<https://github.com/openembedded/meta-openembedded.git>` | `kirkstone` | **Erforderlich** |
| `meta-security` | `git://git.yoctoproject.org/meta-security.git` | `kirkstone` | **Erforderlich** |
| `meta-virtualization` | `git://git.yoctoproject.org/meta-virtualization` | `kirkstone` | **Erforderlich** |
| `meta-edgecon` | `git@github.com:bynacon/meta-edgecon.git` | `kirkstone` | Optional (nur für OTA, privat) |
| `meta-ota` | `<https://github.com/bynacon/meta-ota.git>` | `kirkstone` | Optional (nur für OTA, privat) |

**Hinweis:** Die Layer `meta-edgecon` und `meta-ota` sind nur für Builds mit OTA-Update-Funktionalität erforderlich. Die OTA-Machine-Konfigurationen und alle OTA-spezifischen Einstellungen liegen in `meta-ota`; `meta-modberry` enthält keine OTA-Konfiguration. `meta-ota` erweitert diesen Layer nur über die Erweiterungspunkte der Module (z. B. `/etc/nftables.d/`, `/etc/dnsmasq.d/`, Image-bbappend). Für ein Basis-Image (Machine: `modberry-m40804w-max-basic.conf`) werden sie nicht benötigt.

---

## 3. Layer zum Build hinzufügen

Führen Sie `bitbake-layers add-layer meta-modberry` aus und fügen Sie alle weiteren, oben aufgelisteten Abhängigkeiten zu Ihrer `bblayers.conf`-Datei hinzu.

Basis-Image bauen:

```bash
source poky/oe-init-build-env <build-verzeichnis>
MACHINE=modberry-m40804w-max-basic bitbake rpi-cm4
```

Zugangsdaten und Schlüssel (WLAN, Accounts, Zertifikate) gehören nicht in das Repository und nicht in die `local.conf`. Sie werden bei der Provisionierung auf dem Gerät gesetzt (`BASE-PROV`, `/data/provisioning/`).

---

## 4. Repository-Struktur

| Pfad | Inhalt | Geändert von |
| :-- | :-- | :-- |
| [conf/](conf/) | `layer.conf`, Machine-Konfigurationen | Entwickler, Agenten |
| `recipes-bsp/` | Boot-Dateien (`config.txt`, cmdline), U-Boot, udev | Entwickler, Agenten |
| `recipes-connectivity/` | Netzwerk-Dienste (hostapd, dnsmasq, OpenSSH, …) | Entwickler, Agenten |
| `recipes-core/` | Image `rpi-cm4`, systemd, Sprache/Locale | Entwickler, Agenten |
| `recipes-extended/` | libmbus, sudo | Entwickler, Agenten |
| `recipes-kernel/` | Kernel-bbappend, Device-Tree-Patch und Overlays (RTC, CAN, TPM, MCP23008, SC16IS740) | Entwickler, Agenten |
| `recipes-security/` | tpm2-tss | Entwickler, Agenten |
| [docs/hardware/](docs/hardware/README.md) | Hardware-Spezifikation und Datenblätter | nur Menschen |
| [docs/software/](docs/software/basic/README.md) | Modul-Spezifikationen des Basis-Stacks, Vorlage `_TEMPLATE.md` | nur Menschen |
| [agent/](agent/playbook.md) | Playbook, Tasks (`tasks/basic.json`), Task-Packs, Generator | Generator und Runner, nie Agenten direkt |

---

## 5. Hardware-Dokumentation

Dieser Layer stellt die Maschinenkonfiguration für den **Techbase Modberry M40804W MAX** bereit, einschliesslich grundlegender GPIO-Zuweisungen und Hardware-Einstellungen.

Für detaillierte Hardware-Spezifikationen, Pinouts und Implementierungshinweise ist ausschliesslich die zentrale Hardware-Dokumentation massgebend:
➡️ **[Hardware-Spezifikation (M40804W_MAX.md)](docs/hardware/M40804W_MAX.md)**

Datenblätter liegen unter [docs/hardware/datasheets/](docs/hardware/datasheets/). Gerätespezifische Werte (UART-Pfade, GPIO-Nummern, I2C-Adressen) stehen nur in der Hardware-Spezifikation; die Software-Spezifikationen verweisen darauf.

---

## 6. Software-Spezifikation

Die Spezifikation des Basis-Stacks liegt unter [docs/software/basic/](docs/software/basic/README.md). Sie legt fest, **was** das Image leisten muss, nicht wie es umgesetzt wird.

- **Module:** 28 Module mit der ID `BASE-<MODUL>`, gruppiert in Basissystem, Netzwerk (`network/`), Boot-Kette (`boot-chain/`) und Härtung (`hardening/`). Die Übersicht mit Abhängigkeiten und Risiko steht im [README der Spezifikation](docs/software/basic/README.md).
- **Anforderungen:** IDs `BASE-<MODUL>-<NN>` mit den Stufen `MUST`, `SHOULD`, `MAY`; Prüfstufen `build`, `manifest`, `rootfs`, `device`.
- **Spec-Status:** `planned` → `draft` → `review` → `approved`. Nur Module im Status `approved` werden umgesetzt.
- **Offene Punkte:** enden als *Decided* oder *Deferred*. Ein offener Punkt, der eine Messung am Gerät oder eine Prüfung im Schema braucht, wird zu einer Verifikations-Task (`V-…`).
- **Neue Module:** nach der Vorlage [_TEMPLATE.md](docs/software/_TEMPLATE.md).

---

## 7. Umsetzung mit dem Agent-System

Die Spezifikationen werden vom separaten Repository `agent-system` (CrewAI mit lokalen LLMs auf dem ASUS GX10) umgesetzt. Ein Agent bearbeitet pro Lauf genau eine Task.

```mermaid
flowchart LR
    S[docs/software/basic<br/>Spezifikationen] --> G[agent/tools/gen_tasks.py]
    G --> T[agent/tasks/basic.json<br/>Tasks + Status]
    G --> P[agent/packs/*.md<br/>Task-Packs]
    G --> ST[STATUS.md]
    T --> R[agent-system Runner]
    P --> R
    R --> L[Rezepte und conf/<br/>Commit pro Task]
```

| Datei | Zweck |
| :-- | :-- |
| [agent/playbook.md](agent/playbook.md) | Regeln für die Agenten: Schreibbereich, kirkstone-Syntax, keine Secrets, Definition of Done |
| [agent/tools/gen_tasks.py](agent/tools/gen_tasks.py) | erzeugt aus den Spezifikationen eine Task pro Abschnitt `4.x`, die Task-Packs und `STATUS.md`; behält den Status bestehender Tasks |
| `agent/tasks/basic.json` | Tasks mit Phase, Abhängigkeiten, Anforderungen und Status (`status`, `verified`, `evidence`, `notes`) |
| `agent/packs/` | ein kleines Kontext-Paket pro Task (nur die Anforderungen und Repo-Hinweise dieser Task) |
| [docs/software/basic/STATUS.md](docs/software/basic/STATUS.md) | generierter Umsetzungsstand pro Modul – nicht von Hand bearbeiten |

Regeln:

- Agenten schreiben nur in `conf/`, `recipes-*/`, `classes/`, `wic/`, `files/`. `docs/` und `agent/` sind für sie gesperrt.
- Den Task-Status schreibt nur der Runner. Jede Task endet in einem eigenen Commit `<Task-ID>: <Zusammenfassung>` mit den Anforderungs-IDs. Gepusht wird von Hand.
- Tasks mit *Human Gate* enden bei `implemented`; der Gerätetest wird von Hand gemacht.
- Nach einer Änderung an den Spezifikationen den Generator neu laufen lassen:

```bash
python3 agent/tools/gen_tasks.py
```

---

## 8. Patches

Bitte senden Sie alle Patches für den `meta-modberry`-Layer an den Bynacon-Maintainer:  
**Ben Roethlisberger** - `ben.roethlisberger@bynacon.ch`

---

## 9. Release Notes Modberry

### Release Note Nummerierung

Informationen zur Nummerierung der Release Notes (z.B. `5.04.12.023`):

- **Erste Zahl (5):** Geräteversion (5 = Modberry)
- **Zweite Zahl (04):** Haupt-Release-Nummer
- **Dritte Zahl (12):** Sub-Versionierungsnummer
- **Vierte Zahl (023):** Patch-Nummer

### Release 5.00.00.001

- **Erster Commit:** Standardkonfiguration für Modberry M40804W MAX.
- Grundlegende GPIO-Zuweisungen definiert.
