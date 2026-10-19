# Modberry Hardware Documentation

This directory contains the overarching hardware specifications and documentation for the Modberry device family used in the project. It serves as the single source of truth for driver and kernel development.

## 1. General Modberry Architecture

The Modberry devices are based primarily on the Raspberry Pi Compute Module (e.g. CM4). The carrier board extends them with dedicated industrial interfaces (CAN, RS485, TPM, DIO).

## 2. Specific Hardware Models

The exact pinouts, interfaces and configurations differ per model.

The detailed specifications, code examples and implementation notes are in the model-specific Markdown files in this directory:

- [M40804W_MAX.md](M40804W_MAX.md) (detailed pinout and implementation notes)
- [datasheets/CM4.pdf](datasheets/CM4.pdf) (official CM4 datasheet) and [datasheets/CM4.md](datasheets/CM4.md) (Markdown version)

## 3. General Electrical Characteristics

- **Power supply:** 9–30 V DC
