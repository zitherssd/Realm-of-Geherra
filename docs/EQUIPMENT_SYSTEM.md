# EQUIPMENT_SYSTEM.md

This document defines the **Equipment System** and **Camp Menu** flow for *Realms of Geherra*.

The equipment system is **data-driven** and uses `ITEM_SCHEMA.md` and `UNIT_SCHEMA.md`.

---

## 1. Design Goals

* Commander-only equipment changes
* Shared party inventory
* Immediate stat + action updates
* Simple grid inventory + slot UI
* Deterministic, inspectable rules

---

## 2. Core Rules

### 2.1 Commanders vs Regular Units

* **Commanders** can equip and swap items.
* **Regular units** are locked to `starting_equipment`.
* Commanders are structurally similar to units but carry a **commander flag**.

### 2.2 Shared Inventory

* One party inventory shared by all commanders.
* No direct commander-to-commander trade.
* Equipping moves an item from inventory into a commander slot.
* Unequipping returns the item to shared inventory.

### 2.3 Slot Validation

* Items list `slots` they occupy.
* Commanders must have matching slot types (`equipment_slots`).
* All required slots must be free to equip the item.

### 2.4 Stat + Action Effects

* Item `stat_modifiers` apply immediately to commander stats.
* Item `actions` are added to commander actions list while equipped.
* Removing an item removes its stat and action contributions.

---

## 3. Equipment UI (Grid + Slots)

### Layout

* **Left pane**: Inventory grid (icons, stack counts)
* **Right pane**: Commander slots (head, body, weapon, etc.)
* **Bottom pane**: Item details (name, stats, actions, sprite)

### Interaction

* Select item from grid → highlight compatible slots
* Select slot → equip/unequip
* Regular units are read-only display of `starting_equipment`

### Item Sprites

* Items define `sprite` in item data
* UI uses item sprite for inventory grid and slot display

---

## 4. Squad Notes (Future)

* Regular units are assigned to squads led by commanders.
* Squads affect battle deployment and formation ordering.
* Squad rules will be defined in a separate document.

---

## 5. Implementation Targets

* Inventory/Equipment logic: (future) systems/equipment_system.lua
* Camp menu UI: see `CAMP_MENU.md`
* Inventory view UI: see `INVENTORY_VIEW.md`
* Commander flags and leadership limits: (future) core/commander.lua

---

## 6. Related Schemas

* `UNIT_SCHEMA.md`
* `ITEM_SCHEMA.md`
* `ACTION_SCHEMA.md`
* `CAMP_MENU.md`
* `INVENTORY_VIEW.md`
