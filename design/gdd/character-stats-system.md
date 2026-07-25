# Character Stats System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Meaningful Progression, Preparation Over Reflexes

## Overview

The Character Stats System defines the core attributes for every entity in the game — the player character, companion NPCs, generic troops, and all creatures (bandits, wolves, trolls, dragons, ghosts, etc.). Every entity uses the same stat model, ensuring consistency across combat, world map movement, and equipment. Stats are modified by equipment, level, and innate creature traits.

## Detailed Design

### Core Stats

| Stat | Range | Default (Human) | Description |
|------|-------|-----------------|-------------|
| **HP** | 1–500 | 30 | Health pool. When HP reaches 0, the entity is incapacitated or dead. |
| **Offence** | 1–50 | 10 | Determines hit chance and contributes to damage. Covers both melee and ranged. |
| **Defence** | 1–50 | 10 | Determines dodge/parry chance and flat damage reduction. |
| **Speed** | 1–10 | 3 | Movement units per tick on the battlefield. |
| **Size** | 1–10 | 3 | Affects ranged hit chance and other interactions. Baseline: human = 3. |

### Protections

Each entity has protection values for damage types. Protection is flat subtraction from incoming damage:

```lua
protections = {
    slashing = 0,
    piercing = 0,
    blunt = 0,
    fire = 0,
    ice = 0,
    shock = 0,
}
```

Protection comes from armour pieces (slot-stacked — helmet, chest, etc. each contribute) and innate creature traits. Negative values indicate weakness (takes extra damage of that type).

### Derived Stats

- **Max HP**: Defined per entity. Not derived from other stats. A dragon simply has 100 HP because it's a dragon.
- **Movement Speed**: Determined by the Speed stat (units per combat tick).
- **Effective Offence**: `base_offence + equipment_offence_bonus`
- **Effective Defence**: `base_defence + equipment_defence_bonus`

### Creature Stat Examples

| Creature | HP | Offence | Defence | Speed | Size | Notable Protections |
|----------|----|---------|---------|-------|------|---------------------|
| Peasant | 12 | 4 | 4 | 3 | 3 | — |
| Bandit | 20 | 8 | 7 | 3 | 3 | — |
| Wolf | 15 | 10 | 6 | 5 | 2 | — |
| Skeleton | 18 | 8 | 6 | 3 | 3 | Piercing +5, Blunt -3 |
| Troll | 60 | 14 | 10 | 2 | 4 | Piercing +5, Blunt +5 |
| Soldier | 40 | 14 | 16 | 3 | 3 | Slashing +2 (bronze armour) |
| Ghost | 25 | 18 | 8 | 5 | 2 | Ethereal tag |
| Minotaur | 80 | 24 | 22 | 2 | 5 | Armoured tag |
| Dragon | 100 | 30 | 25 | 2 | 6 | Fire Resistance tag |

### States and Transitions

| State | Description |
|-------|-------------|
| **Alive** | HP > 0. Entity can act. |
| **Incapacitated** | HP ≤ 0. Entity cannot act. May recover (wounded) or be dead. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S14 Progression | Consumed by | Level-ups grant stat increases |
| S13 Equipment System | Consumed by | Equipment modifies effective stats |
| S20 Damage Calculation | Consumes | Offence, Defence, Protections for combat math |
| S21 Health & Status | Consumes | HP for damage tracking |
| S18 Tactical Combat | Consumes | Speed for tick-based movement |

## Formulas

**Effective Offence:** `effective_offence = base_offence + equipment_offence_bonus`

**Effective Defence:** `effective_defence = base_defence + equipment_defence_bonus`

**Hit chance:** `hit_chance = attacker.offence / (attacker.offence + defender.defence)`

**Ranged hit chance (Size modifier):** `ranged_hit_chance = hit_chance * (1.0 + (target.size - 3) * 0.1)`
Larger targets are easier to hit at range. Size 6 dragon: +30% ranged hit chance. Size 1 pixie: -20%.

## Edge Cases

- **If a creature has 0 Offence**: Hit chance is 0%. Cannot deal damage through normal attacks.
- **If a creature has 0 Defence**: Hit chance against it is effectively 100% (approaches but never reaches 100%).
- **If protection exceeds incoming damage**: Damage is clamped to minimum 1. Every hit deals at least 1 damage.
- **If a creature has negative protection**: That damage type deals extra damage. Blunt -3 means +3 damage from blunt attacks.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S13 Equipment System | Soft | Equipment modifies effective stats |
| S14 Progression | Soft | Level-ups grant stat increases |

**Depended on by:** S20 Damage Calculation, S21 Health & Status, S18 Tactical Combat.
