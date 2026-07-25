# Health & Status System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Preparation Over Reflexes, Meaningful Progression

## Overview

The Health & Status System tracks each unit's HP, manages damage application, and handles status effects (burn, poison, stun, etc.). When HP reaches 0, the unit is incapacitated. Status effects apply over-time effects that can change the course of a battle.

## Detailed Design

### Core Rules

1. **HP tracking**: Each unit has a `current_hp` value. When damage is applied: `current_hp -= damage`. When `current_hp <= 0`, the unit is incapacitated.

2. **Incapacitation**: An incapacitated unit cannot act. For the player's party, the unit is wounded (not dead) — they recover after the battle with 1 HP. For enemies, incapacitation means death (removed from the battlefield).

3. **Wound recovery**: After battle, all wounded party members recover to 1 HP. Healing at locations (thermal geysers, villages) can restore more HP.

4. **Wound penalties**: An incapacitated companion suffers a temporary stat penalty (-2 Offence, -2 Defence) for the next battle. This stacks if they're incapacitated multiple times without rest.

5. **Status effects**: Effects applied by attacks or abilities:
   - **Burn**: 2 damage per tick for 10 ticks. Removed by water or time.
   - **Poison**: 1 damage per tick for 20 ticks. Stackable.
   - **Stun**: Unit skips its next action. Removed after acting once.
   - **Slow**: Speed halved for 15 ticks.

6. **Status effect application**: Each effect has a source, duration (in ticks), and tick interval. Effects are tracked per unit.

7. **Status effect resistance**: Some tags grant immunity or resistance:
   - `Fire Resistance`: Immunity to Burn
   - `Ethereal`: Immunity to Poison
   - `Armoured`: Halved duration of Stun

### States and Transitions

| State | Description |
|-------|-------------|
| **Healthy** | HP > 50%. No status effects. |
| **Injured** | HP 25–50%. No gameplay change. |
| **Wounded** | HP < 25%. Visual feedback (slower walking animation, blood drip). |
| **Incapacitated** | HP = 0. Cannot act. |
| **Dead** | Incapacitated + enemy = dead. Removed. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S20 Damage Calculation | Consumes | Damage values applied to HP |
| S18 Tactical Combat | Consumed by | Incapacitated units removed from action queue |
| S12 Inventory System | Consumed by | Healing items can restore HP |
| S08 Location System | Consumed by | Resting at locations restores HP |

## Formulas

No complex formulas. HP is tracked as an integer. Damage is subtracted. Status effects tick at their interval.

## Edge Cases

- **If damage exceeds remaining HP**: HP is set to 0. Overkill damage is discarded.
- **If a unit is hit while incapacitated**: Overkill has no effect (corpse can't be re-killed).
- **If a status effect expires**: It is removed from the unit's effect list.
- **If the same status effect is applied twice**: Durations stack (not intensity). Two 10-tick burns = 20 ticks total.
- **If a unit is immune to a status effect** (e.g., Fire Resistance ignores Burn): The effect is not applied.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S20 Damage Calculation | Hard | Receives final damage values |
| S18 Tactical Combat | Hard | Tick timing for status effect progression |
