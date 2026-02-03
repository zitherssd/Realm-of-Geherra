# PARTY_SCHEMA.md

This document defines the **authoritative data schema for Parties**.

Parties are world-map entities that hold units, inventory, gold, and commanders.

---

## 1. Design Goals

* Parties are data-driven containers
* Parties hold a shared inventory for all commanders
* Parties exist on the world map and participate in encounters
* Parties remain renderer-agnostic

---

## 2. Party Identity

```lua
party = {
  id = "player_party",
  name = "Free Company",
  faction = "neutral",
}
```

* `id` is unique and stable
* `name` is player-facing
* `faction` may be null/neutral

---

## 3. World Map Fields

```lua
position = { x = 512, y = 1024 }
speed = 180
```

* Parties are positioned in continuous world space
* Speed determines travel rate

---

## 4. Roster and Commanders

```lua
commanders = {
  "human_commander",
}

units = {
  "human_infantry",
  "human_infantry",
  "human_swordsman",
}
```

* Commanders are a subset of units, flagged as commanders
* Commanders can equip items
* Regular units are locked to `starting_equipment`

---

## 5. Inventory and Currency

```lua
inventory = {
  "iron_spear",
  "iron_sword",
}

gold = 120
```

* Inventory is shared across all commanders
* Items are referenced by item ids

---

## 6. Party State (Optional)

```lua
morale = 75
supplies = 40
```

State fields are optional and may be expanded later.

---

## 7. Example Party

```lua
party = {
  id = "player_party",
  name = "Free Company",
  faction = "neutral",
  position = { x = 512, y = 1024 },
  speed = 180,
  commanders = { "human_commander" },
  units = { "human_infantry", "human_infantry", "human_swordsman" },
  inventory = { "iron_spear", "iron_sword", "wooden_shield" },
  gold = 120,
}
```

---

## 8. Related Schemas

* `UNIT_SCHEMA.md`
* `ITEM_SCHEMA.md`
* `COMMANDER_SQUADS.md`

---

## 9. Data File Location

Canonical data lives in:

* /data/parties.lua

Core schema validation lives in:

* /core/party.lua
