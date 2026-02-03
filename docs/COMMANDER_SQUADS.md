# COMMANDER_SQUADS.md

This document defines **Commander leadership** and **Squad structure** (planning only).

Implementation will follow later when the battle scene is expanded.

---

## 1. Core Concepts

### Commander Flag

* Commanders are units with `is_commander = true`.
* Commanders can equip items and lead squads.

### Leadership Limits

Each commander defines:

* `max_units` – maximum number of regular units they can lead
* `max_squads` – maximum squads they can split their forces into

---

## 2. Squad Structure

* Squads are collections of regular units assigned to a commander.
* A commander may lead multiple squads, limited by `max_squads`.
* Squads are used for:

  * Battle deployment positions
  * Initial facing/orientation
  * Formation ordering (future)

---

## 3. World Map Integration

* Squads are managed from the **Camp Menu**.
* Reassigning squads is only allowed while camped/resting.

---

## 4. Battle Scene Integration (Future)

* Each squad spawns at a specific grid segment.
* Squad order determines initial deployment priority.
* Commander bonuses can apply to all units in their squads.

---

## 5. Data Fields (Draft)

```lua
commander = {
  is_commander = true,
  max_units = 20,
  max_squads = 3,
}
```

---

## 6. Related Docs

* `EQUIPMENT_SYSTEM.md`
* `UNIT_SCHEMA.md`
* `PROJECT.md`
