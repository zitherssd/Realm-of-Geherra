# ITEM Schema

This document defines the **authoritative data schema for Items**.

Items are **data-only definitions**. They do not contain logic, rendering, or battle resolution code. Systems interpret item data to apply effects.

This schema is designed to integrate cleanly with `UNIT_SCHEMA.md`.

---

## 1. Design Goals

* Items are fully data-driven
* Items declare **which equipment slots they occupy**
* Items may modify unit stats
* Items may grant battle actions
* Items must support one-handed, two-handed, and non-weapon equipment

---

## 2. Item Identity

```lua
item = {
  id = "iron_sword",
  name = "Iron Sword",
  description = "A simple iron blade",
}
```

* `id` must be unique and stable
* `name` is player-facing
* `description` is optional flavor text

---

## 3. Item Category

```lua
category = "weapon" -- weapon, armor, shield, accessory, etc.
```

Category is **informational**, not behavioral.
Systems should not hardcode logic based on category.

---

## 4. Equipment Slot Occupation

Items explicitly declare which slots they occupy when equipped.

```lua
slots = {
  "mainhand",
}
```

### Two-Handed Weapon Example

```lua
slots = {
  "mainhand",
  "offhand",
}
```

### Shield Example

```lua
slots = {
  "offhand",
}
```

### Cloak / Misc Example

```lua
slots = {
  "misc",
}
```

### Slot Rules

* All listed slots must exist on the unit
* All listed slots must be free to equip the item
* If any slot is unavailable, the item cannot be equipped

Slot compatibility is validated by systems.

---

## 5. Stat Modifiers

Items may modify unit stats additively or multiplicatively.

```lua
stat_modifiers = {
  attack = 2,
  defense = 1,
  strength = 1,
  protection = 0,
}
```

### Notes

* Omitted stats are unchanged
* Negative values are allowed
* All modifiers are applied dynamically while equipped

---

## 6. Granted Actions

Items may grant one or more battle actions.

```lua
actions = {
  "melee_slash",
}
```

Examples:

* Sword → `melee_slash`
* Bow → `arrow_shot`
* Magic staff → `fireball`

Actions are removed automatically when the item is unequipped.

---

## 7. Requirements & Restrictions (Optional)

Items may define requirements that units must satisfy.

```lua
requirements = {
  min_strength = 8,
}
```

Requirements are enforced by systems, not items.

---

## 8. Example Item Definitions

### One-Handed Sword

```lua
item = {
  id = "iron_sword",
  name = "Iron Sword",

  category = "weapon",

  slots = { "mainhand" },

  stat_modifiers = {
    attack = 2,
    strength = 1,
  },

  actions = {
    "melee_slash",
  },
}
```

### Two-Handed Axe

```lua
item = {
  id = "great_axe",
  name = "Great Axe",

  category = "weapon",

  slots = { "mainhand", "offhand" },

  stat_modifiers = {
    attack = 3,
    strength = 3,
  },

  actions = {
    "heavy_cleave",
  },
}
```

### Shield

```lua
item = {
  id = "wooden_shield",
  name = "Wooden Shield",

  category = "shield",

  slots = { "offhand" },

  stat_modifiers = {
    defense = 3,
    protection = 2,
  },

  actions = {},
}
```

### Cloak

```lua
item = {
  id = "travelers_cloak",
  name = "Traveler's Cloak",

  category = "accessory",

  slots = { "misc" },

  stat_modifiers = {
    defense = 1,
  },
}
```

---

## 9. Explicit Non-Responsibilities

Items:

* Do NOT resolve combat
* Do NOT validate slot availability
* Do NOT apply stat changes directly
* Do NOT know about scenes or rendering

Items only describe **what they affect**, not **how**.

---

## 10. Related Schemas

* `UNIT_SCHEMA.md`
* `ACTION_SCHEMA.md`

This schema is stable and should evolve cautiously.
