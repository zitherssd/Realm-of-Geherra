# Unit AI System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Preparation Over Reflexes

## Overview

The Unit AI System controls behaviour for all non-player units in combat — enemy creatures and friendly followers. AI is simple and predictable: units evaluate their situation when ready to act and choose the most appropriate action. The goal is competent but not sophisticated behaviour — enough that followers feel useful and enemies feel threatening, but the player's captain is always the deciding factor.

## Detailed Design

### Core Rules

1. **AI evaluation cycle**: When a non-player unit is ready to act, it evaluates:
   - Is there a valid target in attack range? → Attack the nearest enemy
   - Is there a valid target in move range? → Move toward the nearest enemy
   - Has a special ability that's off cooldown and applicable? → Use it
   - No targets? → Hold position

2. **Friendly follower AI**:
   - Follow the captain (stay within 5 units)
   - Attack the nearest enemy in range
   - If the captain moves, follow
   - If a enemy attacks the captain, prioritise that enemy

3. **Enemy AI**:
   - Attack the nearest or weakest target
   - If the target dies, select the next nearest
   - If no targets in range, move toward the nearest enemy
   - Use special abilities when available and appropriate

4. **Special ability usage**: Units with special abilities use them when:
   - The ability is off cooldown
   - The target condition is met (enemy in range for Fire Breath, ally below 50% HP for Heal)
   - Priority: healing abilities > damage abilities > buff abilities

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S18 Tactical Combat | Consumed by | AI decisions feed into unit actions each tick |
| S22 Combat Skills | Consumes | Unit skill definitions for special ability usage |

## Edge Cases

- **If all enemies are dead**: AI switches to idle. No further actions until next battle.
- **If the captain is incapacitated**: Followers continue fighting until all enemies are dead or the followers are defeated.
- **If an enemy has multiple valid targets**: Attack the closest one. Ties broken by lowest HP.
