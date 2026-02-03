# ACTION_SCHEMA.md

This document defines the **Action system** used during grid-based battles.
Actions are **data-driven capabilities** that units can perform when they are not on cooldown.
They are granted by items or intrinsically by units.

The battle system is **tick-based** and real-time.
There are no turns and no action queues.

---

## Core Combat Model (Summary)

* Battles advance in discrete **ticks**
* Each unit has a **unit-level cooldown**
* When `unit.cooldown == 0`, the unit may choose **one action**
* Starting an action:

  * Locks the unit
  * Applies cooldown to the unit
  * Schedules execution after windup

Action lifecycle:

```
READY → WINDUP → EXECUTE → COOLDOWN → READY
```

---

## Action Lifecycle

### READY

* Action is available
* Unit is not on cooldown
* Preconditions are checked

### WINDUP

* Action has been committed
* Unit is locked and cannot act
* Windup timer counts down

### EXECUTE

* Action effects are applied
* Damage, movement, or effects occur
* Happens on a single tick

### COOLDOWN

* Unit remains locked
* Cooldown timer counts down
* No new actions allowed

---

## Action Definition

Each action is a **pure data object**.
Actions do not execute logic directly — they describe intent.

### Required Fields

```yaml
action_id: string
name: string
description: string
tags: [string]

windup_ticks: number
cooldown_ticks: number

targeting:
  type: unit | cell | self | directional
  range: number

requirements:
  adjacency: optional
  line_of_sight: optional

execution:
  aoe: optional
  effects: [Effect]
```

---

## Targeting

### Target Types

| Type        | Description                   |
| ----------- | ----------------------------- |
| self        | Targets the acting unit       |
| unit        | Targets another unit          |
| cell        | Targets a grid cell           |
| directional | Uses unit facing as direction |

Target validation occurs:

* When the action starts
* Optionally revalidated at execution

---

## Area of Effect (AoE)

AoE is defined as a **pattern** that produces a set of affected grid cells.

Actions do not compute geometry — systems do.

### AoE Definition

```yaml
aoe:
  pattern: radius | cone | line | scatter
  params: object
  seed: deterministic
```

---

## AoE Patterns

### Radius

Affects all cells within a distance from the origin.

```yaml
pattern: radius
params:
  radius: number
```

---

### Cone

A fan-shaped area extending from the unit’s facing direction.

```yaml
pattern: cone
params:
  length: number
  angle_degrees: number
```

---

### Line

A straight line extending from the origin.

```yaml
pattern: line
params:
  length: number
  width: number
```

---

### Scatter (Randomized AoE)

Affects the target cell plus randomly selected nearby cells.

```yaml
pattern: scatter
params:
  radius: number
  extra_cells: number
```

Scatter patterns must use a **deterministic seed**:

```
seed = battle_id + tick + unit_id + action_id
```

---

## Effects

Effects are symbolic descriptions resolved by combat systems.

### Effect Structure

```yaml
type: damage | move | status
stat: attack | strength | magic
formula: string
```

Multiple effects may be applied per action.

---

## Movement Actions

Movement is treated as an action.

Example:

```yaml
action_id: move_step
name: Step
windup_ticks: 0
cooldown_ticks: 1
targeting:
  type: cell
  range: 1
execution:
  effects:
    - type: move
```

---

## Example Actions

### Melee Slash

```yaml
action_id: melee_slash
name: Melee Slash
tags: [melee]
windup_ticks: 2
cooldown_ticks: 3
targeting:
  type: unit
  range: 1
execution:
  effects:
    - type: damage
      stat: attack
      formula: "attack + strength"
```

---

### Arrow Shot

```yaml
action_id: arrow_shot
name: Arrow Shot
tags: [ranged]
windup_ticks: 3
cooldown_ticks: 4
targeting:
  type: unit
  range: 6
execution:
  effects:
    - type: damage
      stat: attack
      formula: "attack"
```

---

### Fireball

```yaml
action_id: fireball
name: Fireball
tags: [magic]
windup_ticks: 4
cooldown_ticks: 5
targeting:
  type: cell
  range: 6
execution:
  aoe:
    pattern: radius
    params:
      radius: 2
  effects:
    - type: damage
      stat: magic
      formula: "magic * 1.5"
```

---

## Design Principles

* No action queues
* Unit-level cooldowns
* Deterministic resolution
* Data-driven geometry
* Symmetric player and AI rules

---

## Next Documents

* DAMAGE_RESOLUTION.md
* BATTLE_TICK_SYSTEM.md
* AI_ACTION_SELECTION.md
