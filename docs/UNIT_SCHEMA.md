# UNIT Schema

This document defines the **authoritative data schema for Units**.

Units are **data-only definitions**. They do not contain rendering logic, scene logic, or battle rules. Systems interpret unit data to produce behavior.

---

## 1. Design Goals

* Units are fully data-driven
* Units define their **own equipment slots**
* Units may grant **intrinsic actions**
* Stats are mutable via items, effects, and actions
* Schema must support humans, animals, monsters, and commanders

---

## 2. Unit Identity

```lua
unit = {
  id = "human_infantry",
  name = "Infantry",
  description = "Basic human foot soldier",
}
```

* `id` is unique and stable
* `name` is player-facing
* `description` is optional flavor text

---

## 3. Visual Representation

```lua
sprite = {
  image = "sprites/units/infantry.png",
  scale = 1.0,
  offset = { x = 0, y = 0 }
}
```

* `image` is a path relative to the assets directory
* Rendering systems decide how sprites are drawn

---

## 3.1 Unit Size

Units define a **size** value used for battle grid stacking.

```lua
size = 2
```

Rules:

* Size ranges from **1 to 10**
* A battle cell holds units whose total size ≤ 10

---

## 3.2 Combat Speed

Units define a **combat_speed** used to scale movement cooldown.

```lua
combat_speed = 13
```

Rules:

* Higher values reduce movement cooldown
* Default should be around **13**

---

## 4. Base Stats

Stats represent the **unit’s intrinsic combat capability** before equipment.

```lua
stats = {
  hp = 30,
  attack = 10,
  defense = 8,
  strength = 9,
  protection = 5,
}
```

### Stat Definitions

* **attack** – accuracy and offensive skill
* **defense** – evasion and defensive skill
* **strength** – damage scaling and physical power
* **protection** – damage reduction from armor
* **hp** – max hit points before modifiers

Stats may be modified by:

* Items
* Actions
* Status effects

---

## 5. Equipment Slots

Each unit defines **which slots it possesses**.

Slots are **named**, **typed**, and **exclusive**.

```lua
equipment_slots = {
  helmet = { type = "head" },
  armor  = { type = "body" },
  boots  = { type = "feet" },
  mainhand = { type = "weapon" },
  offhand  = { type = "weapon" },
}
```

### Slot Rules

* Units may define **any number of slots**
* Slots are authoritative (items must match slot type)
* Units without a slot **cannot equip** items of that type

### Example: Bird Unit

```lua
equipment_slots = {
  helmet = { type = "head" }
}
```

---

## 6. Intrinsic Actions

Units may define actions that are always available, regardless of equipment.

```lua
actions = {
  "claw_attack",
  "bite",
}
```

Use cases:

* Animals (claws, bites)
* Monsters (special attacks)
* Commanders (leadership abilities)

---

## 6.1 Starting Equipment (Optional)

Units may define a starting equipment loadout. This is **default gear** granted when the unit is created.

```lua
starting_equipment = {
  mainhand = "iron_spear",
  offhand = "wooden_shield",
}
```

Rules:

* Keys must be valid equipment slot names
* Values are item ids from `ITEM_SCHEMA.md`
* Systems validate slot compatibility and availability

---

## 7. Equipment-Derived Actions

* Items may define actions
* Equipped items **grant their actions to the unit**
* If an item is unequipped, its actions are removed

This logic is handled by systems, not units.

---

## 8. Example Complete Unit Definition

```lua
unit = {
  id = "human_swordsman",
  name = "Swordsman",

  size = 2,

  combat_speed = 13,

  sprite = {
    image = "sprites/units/swordsman.png",
  },

  stats = {
    hp = 34,
    attack = 11,
    defense = 9,
    strength = 10,
    protection = 6,
  },

  equipment_slots = {
    helmet   = { type = "head" },
    armor    = { type = "body" },
    boots    = { type = "feet" },
    mainhand = { type = "weapon" },
    offhand  = { type = "weapon" },
  },

  starting_equipment = {
    mainhand = "iron_sword",
  },

  actions = {},
}
```

---

## 9. Explicit Non-Responsibilities

Units:

* Do NOT resolve combat
* Do NOT apply damage
* Do NOT handle animation
* Do NOT know about scenes

Units are **static definitions** interpreted by systems.

---

## 10. Related Schemas

* `ITEM_SCHEMA.md`
* `ACTION_SCHEMA.md`
* `PARTY_SCHEMA.md`

This schema is a foundation and should remain stable.
