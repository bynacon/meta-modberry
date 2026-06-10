# Modberry Hardware Documentation

This directory contains the overarching hardware specifications and documentation for the Modberry device family used in the project. It serves as the single source of truth for driver and kernel development.

## 1. Allgemeine Modberry Architektur

Die Modberry-Geräte basieren primär auf dem Raspberry Pi Compute Module (z. B. CM4) und werden auf dem Carrier-Board durch dedizierte industrielle Schnittstellen erweitert (CAN, RS485, TPM, DIO).

## 2. Spezifische Hardware-Modelle

Die exakten Pinouts, Interfaces und Konfigurationen unterscheiden sich je nach Modell. 

Die detaillierten Spezifikationen, Code-Beispiele und Implementierungshinweise findest du in den jeweiligen Modellspezifischen Markdown-Dateien in diesem Verzeichnis:

- `M40804W_MAX.md` (Detailed pinout and implementation TODOs)
- `Raspberry_Pi_CM4-datasheet.pdf` (Official CM4 Datasheet)
- `SLB9670-datasheet.pdf` (TPM Datasheet)

## 3. Allgemeine Elektrische Charakteristika

- **Power Supply:** 9-30V DC
- ...