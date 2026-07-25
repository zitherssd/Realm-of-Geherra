# Inventory System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Meaningful Progression, Preparation Over Reflexes

## Overview

The Inventory System manages items carried by the player's party. Items are physical objects with weight, value, and purpose — weapons, armour, gems, quest items, crafting materials, and consumables. The party has a total carry capacity (sum of all party members' strength-based limits), and each item contributes weight toward that cap. Items are stored in a shared party inventory (not per-character), and equipment is drawn from this pool into individual equipment slots.

## Player Fantasy

Every item has weight — both literally and in terms of gameplay decisions. Do you carry that heavy set of bronze armour or leave it behind for more gemstones? Do you hold onto the troll hide you found, or sell it for supplies? The inventory is a resource management puzzle that rewards planning — you can't carry everything, so you must choose what matters for the journey ahead.

## Detailed Design

### Core Rules

1. **Shared party inventory**: The party has one unified inventory. All items are stored in a single list. Items are not owned by individual party members until equipped.

2. **Item definition**: Each item is defined as a record:
   ```lua
   {
       id = "bronze_sword",
       name = "Bronse Sword",
       type = "weapon",
       subtype = "sword",           -- sword, axe, mace, spear, bow, etc.
       slot = "main_hand",          -- which equipment slot it goes in
       weight = 3.0,                -- weight units
       value = 50,                  -- gold value for trading
       rarity = "common",           -- common, uncommon, rare, legendary
       description = "A simple bronze blade. Reliable.",
       effects = {                  -- what it does when equipped
           damage = {type = "sharp", min = 5, max = 10},
       },
       gem_sockets = 0,             -- how many gems can be socketed
       stackable = false,           -- true for consumables, materials
       quantity = 1,                -- stack count for stackable items
   }
   ```

3. **Item categories**:
   - `weapon` — swords, axes, maces, spears, bows, staves
   - `armour` — helmets, chest armour, boots, shields
   - `accessory` — rings, amulets, torcs, brooches
   - `consumable` — potions, food, scrolls (stackable)
   - `material` — ore, gems, herbs, hides (stackable, used for crafting/forging)
   - `quest` — unique items for quests (non-tradeable)
   - `key` — keys, seals, tokens

4. **Carry capacity**: `party_capacity = sum of all party members' carry capacity`
   - Base carry capacity per character: 20 weight units
   - Strength or Endurance attribute (when designed) increases this
   - Some equipment (bags, belts) may increase capacity

5. **Weight tracking**: If total inventory weight exceeds party capacity:
   - Movement speed is reduced by 10% per 10% over capacity
   - At >150% capacity, the party cannot move

6. **Item stacks**: Stackable items (consumables, materials) share a single inventory slot with a `quantity` field. Max stack size: 99.

7. **Item acquisition**: Items enter the inventory through:
   - Loot from combat
   - Purchase from traders
   - Quest rewards
   - Forging/crafting at locations (ancient forge)
   - Finding at discovered locations

### States and Transitions

| State | Description |
|-------|-------------|
| **In Inventory** | Item is in shared party storage. Not equipped. |
| **Equipped** | Item is assigned to a character's equipment slot. Removed from inventory weight. |
| **Dropped** | Item is removed from the game. Cannot be recovered. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S13 Equipment System | Provides | Items with `slot` field can be equipped |
| S27 Economy/Trading | Provides | Items for sale/purchase with `value` field |
| S18 Tactical Combat | Provides | Weapons and armour affect combat calculations |
| S08 Location System | Consumes | Location actions (forge, trade) interact with inventory |
| S21 Economy/Trading | Provides | Item data for buy/sell/list |
| S30 Quest Instance | Consumed by | Quest items are flagged and non-tradeable |

## Formulas

**Carry capacity:**

`party_capacity = Σ(character_base_capacity)`

Default base capacity: 20 per character. A party of 4 = 80 total weight capacity.

**Speed penalty when over capacity:**

`speed_multiplier = 1.0 - max(0, (current_weight - capacity) / capacity * 0.5)`

At 120% capacity: `1.0 - (0.2 * 0.5) = 0.9` (90% speed)
At 150% capacity: `1.0 - (0.5 * 0.5) = 0.75` (75% speed)
At >150% capacity: speed = 0 (cannot move)

## Edge Cases

- **If the player picks up an item that would exceed capacity**: The item is picked up but the party becomes over-encumbered. Speed penalty applies immediately.
- **If a stackable item exceeds max stack size**: A new stack is created.
- **If the player tries to drop a quest item**: "This item is required for an active quest. Drop it anyway?" Confirmation required.
- **If an equipped item is dropped**: The item is unequipped first, then dropped. The character's stats are recalculated.
- **If inventory is full and no capacity remains**: The player cannot pick up new items. A notification shows "Inventory full."
- **If the party size changes (member recruited or lost)**: Carry capacity is recalculated. If new capacity is below current weight, speed penalty applies.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S10 Character Stats | Soft | Carry capacity per character (depends on Strength/Endurance) |
| S13 Equipment System | Hard | Equipped items are drawn from and return to inventory |

**Depended on by:** S13 Equipment System, S27 Economy/Trading, S18 Tactical Combat, S08 Location System.

## Tuning Knobs

- **Base carry capacity**: Float. Default: 20 per character. Range: 10–50.
- **Speed penalty per 10% over capacity**: Float. Default: 0.1 (10% speed loss).
- **Max over-capacity threshold**: Float. Default: 1.5 (150%). Beyond this, speed = 0.
- **Max stack size**: Integer. Default: 99.
- **Max inventory slots**: Integer. Default: 64 (number of unique items before full).

## Visual/Audio Requirements

- **Item icons**: 24×24px pixel-art icons per item. Weapon icons show the weapon shape, armour icons show the item, gems show the gemstone with colour.
- **Inventory UI sound**: Soft rustle/paper sound when scrolling, metallic clink when equipping, coin sound when selling.

## UI Requirements

- **Inventory screen**: Grid layout showing all items with icons, names, weight, and quantity. Filterable by category (weapons, armour, consumables, etc.).
- **Item tooltip**: Hovering shows: name, type, weight, value, description, equipped effects, gem sockets.
- **Weight bar**: A visual bar at the top showing current weight / max capacity. Changes colour as the party approaches capacity (green → yellow → red).
- **Equipment preview**: Alongside the inventory grid, a character silhouette showing equipped items in their slots.

## Acceptance Criteria

- **GIVEN** an empty inventory, **WHEN** the player picks up an item, **THEN** it appears in the inventory list.
- **GIVEN** a stackable item (e.g., herbs), **WHEN** the player picks up more, **THEN** the quantity increases (up to max stack).
- **GIVEN** the inventory weight exceeds capacity, **WHEN** the player moves on the world map, **THEN** speed is reduced proportionally.
- **GIVEN** the inventory weight exceeds 150% capacity, **WHEN** the player tries to move, **THEN** movement is blocked.
- **GIVEN** a quest item, **WHEN** the player tries to drop it, **THEN** a confirmation prompt appears.
- **GIVEN** the player drops an equipped item, **WHEN** confirmed, **THEN** the item is unequipped and removed from inventory.
- **GIVEN** a full inventory, **WHEN** the player tries to pick up a new item, **THEN** a notification says "Inventory full."

## Open Questions

- **Item sorting**: Should the inventory auto-sort by category, or let the player drag-and-drop? Proposed: auto-sort by category, with sub-sort by type. Manual sorting is post-MVP.
- **Gem socketing**: Items with `gem_sockets > 0` can have gems inserted for bonuses. This needs a dedicated UI for socketing/unsocketing. Deferred to post-MVP or handled by the Ancient Forge location action.
