# Combat Skills System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Preparation Over Reflexes, Discovery-Driven Exploration

## Overview

Combat Skills are special actions that units can perform in battle, distinct from basic attacks. These include dragon fire breath, druid oakskin, fireballs, javelin throws, water elemental invocations, and more. Each creature or character has a set of skills they can use, defined in their data. Skills have cooldowns (in ticks), target requirements, and unique effects. Skills are what make each creature type feel distinct in combat.

## Player Fantasy

A dragon doesn't just claw — it *breathes fire*. A druid doesn't just hit — she *bestows oakskin* on an ally. A fire mage doesn't just throw sparks — he *launches a fireball*. Combat skills are the identity of each unit. The player learns what each enemy can do and prepares accordingly — that's the Preparation Over Reflexes pillar in action.

## Detailed Design

### Core Rules

1. **Skill definition**:
   ```lua
   {
       id = "fire_breath",
       name = "Fire Breath",
       owner_types = {"dragon"},          -- which creatures can use it
       target = "area",                   -- single, self, ally, area
       range = 6,                         -- max distance to target
       cooldown = 40,                     -- ticks before reusable
       damage_type = "fire",
       base_damage = 20,
       description = "The dragon unleashes a cone of flame.",
       vfx = "vfx_fire_breath",
   }
   ```

2. **Skill sources**: Skills come from three sources:
   - **Innate skills**: Hard-coded on the creature/character definition. A dragon always has Fire Breath. A wizard always knows Fireball. These cannot be removed or unlearned.
   - **Equipment-granted skills**: Items (weapons, armour, accessories) can grant skills when equipped. Equipping a javelin grants the "Throw Javelin" skill. Unequipping it removes the skill. This is the primary way player characters and companions gain combat skills.
   - **Training**: Certain NPCs can teach combat skills for gold or quests. These are permanent once learned.
   
   All three sources stack. A captain with a javelin equipped and innate Battle Cry has both skills available.

3. **Skill execution**: When a unit uses a skill:
   - The skill's cooldown timer starts
   - If single-target: damage/effect is applied to the target
   - If area: damage/effect is applied to all units within the area
   - If self/ally: buff effect is applied

4. **Skill types**:

   | Type | Target | Example |
   |------|--------|---------|
   | Melee Attack | Single enemy | Dragon claw, sword strike |
   | Ranged Attack | Single enemy | Javelin throw, sling shot |
   | Area Attack | Area of enemies | Fire Breath, Fireball |
   | Self Buff | Self | Oakskin (self), Battle Cry |
   | Ally Buff | Single ally | Oakskin (ally), Healing Word |
   | Summon | Self | Invoke Water Elemental |
   | Debuff | Single enemy | Web, Stun Strike |

5. **Sample skills (MVP)**:

   | Skill | Source | Owner | Type | Damage | Cooldown | Special |
   |-------|--------|-------|------|--------|----------|---------|
   | Fire Breath | Innate | Dragon | Area (cone) | 20 fire | 40 ticks | Ignites targets (Burn) |
   | Oakskin | Innate | Druid | Ally Buff | — | 60 ticks | +5 Defence for 30 ticks |
   | Fireball | Innate | Fire Mage | Area (radius) | 15 fire | 40 ticks | Area of effect 3 units |
   | Throw Javelin | Item (Javelin) | Any | Ranged | 12 pierce | 30 ticks | Consumes javelin |
   | Heal | Innate | Priest | Ally | — | 50 ticks | Restores 15 HP |
   | Invoke Elemental | Innate | Water Mage | Summon | — | 80 ticks | Summons water elemental |
   | Battle Cry | Training | Captain | Self Buff | — | 50 ticks | +3 Offence for 20 ticks |
   | Web | Innate | Giant Spider | Debuff | — | 40 ticks | Slows target for 15 ticks |
   | Power Strike | Item (Greatsword) | Any | Melee | 18 blunt | 35 ticks | Two-handed only |

6. **Skill usage by AI**: Non-player units use skills when:
   - The skill is off cooldown
   - A valid target is in range
   - The skill's condition is met (e.g., Heal only when an ally is below 50% HP)

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S18 Tactical Combat | Consumed by | Skills are actions units can take on their turn |
| S20 Damage Calculation | Consumes | Skill damage goes through normal damage formula |
| S21 Health & Status | Consumes | Skills may apply status effects or heal |
| S19 Unit AI | Consumed by | AI uses skill definitions for decision-making |
| S23 VFX Pipeline | Consumes | Each skill references a VFX ID |
| S11 Aptitudes | Consumed by | Some skills require Aptitude thresholds |

## Edge Cases

- **If a skill's target dies before the skill executes (e.g., during the same tick)**: Skill fails. Cooldown is not triggered.
- **If a skill has no valid target when the unit is ready**: Unit falls back to basic attack or movement.
- **If multiple skills are available**: AI picks the highest-damage or most-appropriate skill.
- **If a summoned elemental dies**: The summoner does not re-summon until the summon cooldown expires.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S18 Tactical Combat | Hard | Tick timing for cooldowns and execution |
| S20 Damage Calculation | Hard | Skill damage resolved through standard formula |
| S21 Health & Status | Hard | Healing and status effects |
| S23 VFX Pipeline | Soft | Visual feedback for skill use |

## Open Questions

- **Mana/energy system**: Should skills consume a resource (mana, gem charges) or only have cooldowns? Proposed: cooldowns only for MVP. Resource systems can be added later.
- **Skill learning for player**: How does the player acquire new skills? Through trainers? Equipment? Aptitude thresholds? Proposed: a mix — basic skills from equipment, advanced skills from trainers, signature skills from Aptitudes.
