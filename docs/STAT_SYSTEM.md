# STAT_SYSTEM.md

This document defines the **Stat Aggregation System**.

The stat system produces a unit’s **effective stats** by combining base stats with item and status modifiers.

---

## 1. Inputs

* Base stats (from unit data)
* Equipped items (`stat_modifiers`)
* Status effects (`stat_modifiers`)
* Item-granted actions (optional aggregation)

---

## 2. Rules

* Modifiers are **additive** per stat
* Missing stats default to 0 during aggregation
* The output is a new table (base stats are not mutated)
* Action aggregation merges unit actions with item-granted actions

---

## 3. Canonical Implementation

* /systems/stat_system.lua

The stat system also provides:

* `get_max_hp(base_stats, items, effects)`

---

## 4. Example

```lua
local effective = StatSystem.aggregate(unit.stats, equipped_items, status_effects)
```

---

## 5. Related Docs

* `UNIT_SCHEMA.md`
* `ITEM_SCHEMA.md`
* `ACTION_SCHEMA.md`
