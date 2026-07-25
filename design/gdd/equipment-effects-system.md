# Equipment Effects System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Preparation Over Reflexes, Meaningful Progression

## Overview

The Equipment Effects System handles how different weapon and armour types interact with different enemy types and damage types. A mace is more effective against skeletons than a sword. A spear has reach advantage. These interactions make equipment choices meaningful tactical decisions.

## Detailed Design

### Core Rules

1. **Weapon-vs-armour interactions**: Based on damage type vs target protections:
   - Sharp weapons (swords, axes): Effective against unarmoured targets. Reduced by heavy armour.
   - Blunt weapons (maces, clubs): Effective against armoured targets and skeletons. Less effective against agile targets.
   - Pierce weapons (spears, arrows): Effective from range. Reduced by shields and thick hide.

2. **Weapon tags**:
   - `reach`: +1 attack range over standard melee
   - `fast`: -5 ticks to cooldown
   - `heavy`: +3 damage but +5 ticks to cooldown
   - `versatile`: Can be used one-handed or two-handed (changes damage/cooldown)

3. **Creature-specific effectiveness** (data-driven):
   ```lua
   creature_weaknesses = {
       skeleton = { blunt = 1.5 },  -- 50% more blunt damage
       troll = { fire = 2.0 },       -- 100% more fire damage
       ghost = { magic = 1.0 },      -- only magic damage affects ghosts
   }
   ```

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S20 Damage Calculation | Provides | Damage type modifiers based on target |
| S13 Equipment System | Consumes | Weapon tags and damage types |

## Edge Cases

- **If a weapon has multiple damage types**: The primary type is used for damage. Secondary types are for interaction checks.
- **If a creature has no specific weakness**: Standard damage formula applies.
