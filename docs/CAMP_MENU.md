# CAMP_MENU.md

This document defines the **Camp Menu** available from the World Map.

The camp menu pauses world time and provides management options for the party.

---

## 1. Design Goals

* Quick access to commander equipment
* Squad composition management
* Safe resting/waiting on the world map
* Minimal branching UI

---

## 2. Availability

* Accessible from the World Map at any time via **C**
* Can also be opened from location interactions (Camp option)
* World time is paused while the menu is open

---

## 3. Menu Options

* **Equipment** → open inventory + slots view for commanders
* **Squads** → assign units to commander-led squads (future)
* **Rest / Wait** → advance time on world map
* **Close** → return to world map

---

## 4. Interaction Rules

* Equipment changes are commander-only
* Regular units remain locked to `starting_equipment`
* Resting advances world time according to the time system
* Resting continues until the player moves or cancels

---

## 5. Related Docs

* `EQUIPMENT_SYSTEM.md`
* `COMMANDER_SQUADS.md`
* `TIME_SYSTEM.md`
* `UNIT_SCHEMA.md`
* `INTERACTION_SYSTEM.md`
