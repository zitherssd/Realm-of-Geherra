# INVENTORY_VIEW.md

This document defines the **Inventory + Equipment View** for the camp menu.

The view is a primitive UI that lets the player equip items on their commander.

---

## 1. Layout

* Left pane: inventory list
* Right pane: commander equipment slots
* Bottom: selected item details

---

## 2. Controls

* Up/Down — move selection
* Tab — switch focus between inventory and slots
* Enter — auto-equip (from inventory) or unequip (from slots)
* Esc — close

---

## 3. Rules

* Items must match slot names (`item.slots`)
* Items occupying multiple slots require all slots to be free
* Equipping removes item from inventory
* Unequipping returns item to inventory

---

## 4. Canonical Implementation

* /ui/inventory_view.lua
* Integrated by /scenes/world_scene.lua

---

## 5. Related Docs

* `EQUIPMENT_SYSTEM.md`
* `CAMP_MENU.md`
