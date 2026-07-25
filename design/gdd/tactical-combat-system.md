# Tactical Combat System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Preparation Over Reflexes, Meaningful Progression

## Overview

The Tactical Combat System manages real-time battles on a continuous 2D battlefield. Combat uses a **tick-based action system** (20 ticks per second) where every unit on the battlefield follows the same pattern: act → cooldown → ready → act. When the player's captain is ready to act, ticks **pause** — there is no time pressure on the player's decisions. Movement is continuous and smooth, but actions (attacks, abilities) resolve on ticks. The battlefield is continuous space (no grid), and units have collision radii for positioning.

## Player Fantasy

Combat is deliberate, not frantic. You see the battlefield, assess the situation, and choose your captain's next move without rush. Your units fight autonomously while you decide where to position your captain and when to strike. Victory comes from preparation and good choices, not fast reflexes.

## Detailed Design

### Core Rules

1. **Tick system**: The battle runs at 20 ticks per second. Each tick, all ready units perform their action. Actions put units on cooldown for a fixed number of ticks.

2. **Action → Cooldown → Ready cycle**:
   - **Ready**: Unit can act (move, attack, use ability)
   - **Acting**: Unit performs its action (takes 0 ticks — instant)
   - **Cooldown**: Unit cannot act for N ticks. Cooldown varies by action type:
     - Basic attack: 20 ticks (1 second)
     - Move: 5 ticks per tile (re-evaluated each tick for continuous movement)
     - Special ability: 40–60 ticks (2–3 seconds)

3. **Player pause**: When the captain is ready to act, ticks pause. The player can issue a command (move, attack, use item, use ability) at their leisure. After the command, the captain acts and goes on cooldown, and ticks resume.

4. **Enemy/follower AI**: Other units act independently during tick advancement. They have simple behaviour:
   - Hostile units: move toward nearest enemy → attack when in range
   - Friendly followers: follow captain → attack nearest enemy in range
   - AI units always act immediately when ready (no delay)

5. **Continuous movement**: Units move smoothly between positions each tick. Movement speed is determined by the Speed stat. Units have a collision radius — they cannot overlap, and they push past each other when necessary.

6. **Attack range**: Determined by weapon type:
   - Melee (swords, axes, maces): range = unit collision radius + weapon reach
   - Polearms (spears): slightly longer range
   - Ranged (bows, javelins, slings): range = 10–20 units depending on weapon
   - Natural attacks (claws, bites): range = unit collision radius

7. **Battlefield**: A bounded 2D space. Boundaries are defined by the terrain where the battle takes place (clearing, pass, village outskirts, etc.).

### States and Transitions

| State | Description |
|-------|-------------|
| **Loading** | Battlefield being initialised from encounter data. |
| **Active** | Battle is running. Ticks advancing. Captain may be ready or on cooldown. |
| **Paused** | Captain is ready. Ticks paused. Player choosing action. |
| **Victory** | All hostile units defeated. Battle ends. |
| **Defeat** | Captain incapacitated or all friendly units defeated. Battle ends. |
| **Retreat** | Player chooses to retreat (future feature). |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S20 Damage Calculation | Consumes | Hit chance and damage resolution |
| S21 Health & Status | Consumes | HP tracking, status effects |
| S19 Unit AI | Consumes | Follower and enemy decision-making |
| S23 VFX Pipeline | Consumes | Visual feedback (hit effects, projectiles) |
| S10 Character Stats | Consumes | Unit stats for combat calculations |

## Formulas

**Action cooldown in ticks:**

`cooldown = base_cooldown * (3.0 / unit.speed)` — faster units recover more quickly

**Example:** A unit with Speed 3 performs a basic attack (base cooldown 20): `20 * 3/3 = 20` ticks. A unit with Speed 5: `20 * 3/5 = 12` ticks.

## Edge Cases

- **If the captain is on cooldown and all enemies are on cooldown**: Ticks continue advancing until someone is ready. No deadlocks.
- **If the captain is ready but the player takes no action**: The game remains paused indefinitely. No timeout.
- **If a unit's target dies mid-action**: The unit selects the nearest valid target.
- **If units collide (overlap)**: They push apart gently. No hard blocking — units can pass through each other but it slows them.
- **If a ranged unit has no line of sight**: The unit moves to find a clear shot or switches to melee (if capable).

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S10 Character Stats | Hard | Unit stats for speed, offence, defence |
| S20 Damage Calculation | Hard | Hit and damage resolution |
| S21 Health & Status | Hard | HP tracking and status effects |
| S19 Unit AI | Hard | AI behaviour for non-player units |
| S23 VFX Pipeline | Soft | Visual feedback |

**Depended on by:** S19 Unit AI, S23 VFX Pipeline.
