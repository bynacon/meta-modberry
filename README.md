<p align="center">
  <a href="https://www.techbase.eu/modberry">
    <img src="https://www.techbase.eu/wp-content/uploads/2022/03/logo_techbase_blue.svg" alt="Logo" width="200">
  </a>
</p>

<h1 align="center">meta-modberry</h1>

<p align="center">
  Yocto-Layer für den Techbase Modberry Industriecomputer, basierend auf dem Raspberry Pi Compute Module 4.
  <br />
  <a href="#5-release-notes-modberry"><strong>Release Notes anzeigen</strong></a>
</p>

<!-- PROJECT SHIELDS -->
<p align="center">
  <img src="https://img.shields.io/badge/Yocto-Kirkstone-blue.svg?style=for-the-badge" alt="Yocto Kirkstone">
  <img src="https://img.shields.io/badge/Raspberry%20Pi-CM4-C51A4A.svg?style=for-the-badge&logo=raspberry-pi" alt="Raspberry Pi CM4">
</p>

This README file contains information on the contents of the meta-modberry layer.

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Inhaltsverzeichnis</summary>
  <ol>
    <li><a href="#1-dependencies">Abhängigkeiten (Dependencies)</a></li>
    <li><a href="#2-patches">Patches</a></li>
    <li><a href="#3-layer-zum-build-hinzufügen">Layer zum Build hinzufügen</a></li>
    <li><a href="#4-hardware-dokumentation">Hardware-Dokumentation</a></li>
    <li><a href="#5-release-notes-modberry">Release Notes Modberry</a>
      <ul>
        <li><a href="#release-note-nummerierung">Release Note Nummerierung</a></li>
      </ul>
    </li>
  </ol>
</details>

---

## 1. Abhängigkeiten (Dependencies)
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

**Hinweis:** Die Layer `meta-edgecon` und `meta-ota` sind nur für Builds mit OTA-Update-Funktionalität erforderlich. Die OTA-Machine-Konfigurationen und alle OTA-spezifischen Einstellungen liegen in `meta-ota`; `meta-modberry` enthält keine OTA-Konfiguration. Für ein Basis-Image (Machine: `modberry-m40804w-max-basic.conf`) werden sie nicht benötigt.

---

## 2. Patches
Bitte senden Sie alle Patches für den `meta-modberry`-Layer an den Bynacon-Maintainer:  
**Ben Roethlisberger** - `ben.roethlisberger@bynacon.ch`

---

## 3. Layer zum Build hinzufügen
Führen Sie `bitbake-layers add-layer meta-modberry` aus und fügen Sie alle weiteren, oben aufgelisteten Abhängigkeiten zu Ihrer `bblayers.conf`-Datei hinzu.

---

## 4. Hardware-Dokumentation

Dieser Layer stellt die Maschinenkonfiguration für den **Techbase Modberry M40804W MAX** bereit, einschliesslich grundlegender GPIO-Zuweisungen und Hardware-Einstellungen.

Für detaillierte Hardware-Spezifikationen, Pinouts und Implementierungshinweise ist ausschliesslich die zentrale Hardware-Dokumentation massgebend:
➡️ **Hardware-Spezifikation (M40804W_MAX.md)**

---

## 5. Release Notes Modberry

### Release Note Nummerierung
Informationen zur Nummerierung der Release Notes (z.B. `5.04.12.023`):

*   **Erste Zahl (5):** Geräteversion (5 = Modberry)
*   **Zweite Zahl (04):** Haupt-Release-Nummer
*   **Dritte Zahl (12):** Sub-Versionierungsnummer
*   **Vierte Zahl (023):** Patch-Nummer

### Release 5.00.00.001
*   **Erster Commit:** Standardkonfiguration für Modberry M40804W MAX.
*   Grundlegende GPIO-Zuweisungen definiert.
