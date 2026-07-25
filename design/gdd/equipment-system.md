# Equipment System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Meaningful Progression, Preparation Over Reflexes

## Overview

The Equipment System manages which items each party member has equipped. Equipment is drawn from the shared party inventory into character-specific slots. Each character has equipment slots that modify their combat stats, skills, and appearance. The system handles equipping, unequipping, and calculating the stat bonuses provided by equipped items.

## Player Fantasy

Gear is how your character grows tangibly. A new helmet isn't just a number going up — it's a bronze-crested helm that makes your captain look like a leader. Finding a better weapon changes how you approach combat. Equipping your tracker with lightweight boots makes them faster in the forest. Every equipment decision is a meaningful choice about how you want to play.

## Detailed Design

### Core Rules

1. **Equipment slots** (per character): Each character has the following slots:
   - `head` — helmets, circlets, crowns
   - `chest` — body armour, tunics, robes
   - `main_hand` — primary weapon (sword, axe, mace, spear, staff)
   - `off_hand` — shield, torch, secondary weapon, or empty
   - `boots` — footwear, greaves
   - `ranged` — bow, javelins, sling (optional — not all characters use ranged)
   - `accessory_1` — ring, amulet, torc, brooch
   - `accessory_2` — second accessory slot

2. **Equipping**: An item from inventory is assigned to a slot. The item's `slot` field must match the target slot (e.g., a `main_hand` weapon goes in the main_hand slot). The item is removed from inventory weight.

3. **Unequipping**: The item returns to the party inventory. The slot becomes empty.

4. **Stat calculation**: Each character's effective stats are:
   `effective_stat = base_stat + sum(equipped_items[slot].effects[stat])`
   When an item is equipped or unequipped, the character's stats are recalculated.

5. **Two-handed weapons**: Weapons with `two_handed = true` (greatswords, staves, great axes, long spears) occupy both the main_hand and off_hand slots simultaneously. Equipping a two-handed weapon automatically empties and locks the off_hand slot. Unequipping it unlocks the slot.

6. **Weapon types**: Weapons have a `damage_type` — `sharp` (swords, axes), `blunt` (maces, staves), or `pierce` (spears, arrows). These interact with enemy armour types in the Damage Calculation System (S20).

6. **Equipment tiers**: Items have tiers affecting their base stats:
   - Tier 0 (Crude): bone, wood, sharpened stone
   - Tier 1 (Standard): bronze
   - Tier 2 (Gem-Infused): bronze + gem inlay
   - Tier 3 (Enchanted): bronze + multiple gems
   - Tier 4 (Relic): meteorite bronze, god-touched

### Equipment Slots Summary

| Slot | Typical Items | Common Effects |
|------|--------------|----------------|
| Head | Helmet, circlet, hood | Defence, Divination bonus |
| Chest | Cuirass, robe, leather tunic | Defence, carrying capacity |
| Main Hand | Sword, axe, mace, spear, staff | Damage, skill bonuses |
| Off Hand | Shield, torch, dagger | Defence (shield), utility |
| Boots | Greaves, sandals, leather boots | Speed, Tracking bonus |
| Ranged | Bow, javelins | Ranged damage |
| Accessory 1 | Ring, amulet, torc | Variety of bonuses |
| Accessory 2 | Ring, amulet, brooch | Variety of bonuses |

### States and Transitions

| State | Description |
|-------|-------------|
| **Empty** | No item in this slot. No bonuses from this slot. |
| **Equipped** | Item is assigned to the slot. Bonuses are active. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S12 Inventory System | Consumes | Items are drawn from and returned to inventory |
| S18 Tactical Combat | Provides | Weapon damage, armour defence values for combat calculations |
| S11 Skill System | Provides | Some equipment may grant skill bonuses |
| S10 Character Stats | Provides | Equipment modifies character attributes |
| S20 Damage Calculation | Provides | Weapon damage type and armour values |
| S32 Visual (character sprite) | Provides | Equipment changes character appearance |

## Formulas

**Effective stat calculation:**

`effective_stat = character.base_stat + Σ_item_bonuses + Σ_skill_bonuses`

Where `Σ_item_bonuses` sums all `effects[stat]` values from equipped items.

## Edge Cases

- **If the player equips a two-handed weapon (staff, spear)**: The off_hand slot is automatically locked/emptied. A two-handed flag on the item handles this.
- **If the player unequips the last item in a slot**: The slot returns to Empty state. No bonuses. No errors.
- **If an equipped item is dropped from inventory**: The item is unequipped first, then removed. Character stats recalculated.
- **If the player tries to equip an item to the wrong slot**: The system rejects it. "This item does not fit in this slot."
- **If a character has no equipment at all**: Base stats only. The character fights with fists (minimum damage).

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S12 Inventory System | Hard | Items must exist in inventory before equipping |
| S10 Character Stats | Hard | Base stats that equipment modifies |

**Depended on by:** S18 Tactical Combat, S20 Damage Calculation, S11 Skill System.

## Tuning Knobs

- **Equipment slot count**: Array of slot names. Configurable if more slots are added later.
- **Two-handed weapon flag**: Boolean on items. When true, off_hand is locked.
- **Equipment tier stat multipliers**: Per-tier configurable in data.

## Visual/Audio Requirements

- **Equipment appearance**: Character sprites change based on equipped items (helmet visible on head, weapon visible in hand). This is a significant art asset — for MVP, only major slot changes (weapon, helmet) may be reflected visually.
- **Equip sound**: A short metallic clink or leather creak when equipping/unequipping.

## UI Requirements

- **Equipment screen**: A character silhouette with slots displayed as labelled regions. Click a slot to see available items from inventory. Shows current stats with equipment bonuses highlighted.
- **Comparison tooltip**: When selecting an item to equip, show a comparison: current item stats vs. new item stats with changes highlighted in green (improved) or red (reduced).
- **Slot locking**: Two-handed weapons visually lock/hide the off-hand slot.

## Acceptance Criteria

- **GIVEN** a character with an empty head slot, **WHEN** a helmet from inventory is equipped, **THEN** the helmet appears in the head slot and its defence value is added to the character's stats.
- **GIVEN** an equipped helmet, **WHEN** it is unequipped, **THEN** it returns to inventory and its defence is removed from the character's stats.
- **GIVEN** a two-handed weapon, **WHEN** equipped to main_hand, **THEN** the off_hand slot is locked/emptied.
- **GIVEN** an item with the wrong slot type, **WHEN** the player tries to equip it, **THEN** the system rejects the action.
- **GIVEN** a character with no equipment, **WHEN** stats are calculated, **THEN** only base stats apply.

## Open Questions

- **Shield types**: Round shields (Pelasgian), figure-eight shields (Mycenaean), rectangular shields (Egyptian). These are cosmetic variations of the same off-hand slot type or mechanically different? Proposed: cosmetic for MVP, faction-specific visuals only.
- **Equipment degradation**: Should equipment degrade with use and need repair? Proposed: deferred from MVP. When added, the blacksmith's repair service becomes meaningful.
