# VFX Pipeline

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: A Living, Persistent World

## Overview

The VFX Pipeline handles all visual effects in combat — projectile trails, impact sparks, gemstone glows, status effect auras, and ability animations. Effects are data-driven and separate from gameplay logic: the combat system fires events ("fire_breath_at_position"), and the VFX system plays the corresponding visual.

## Detailed Design

### Core Rules

1. **Event-driven**: Combat produces events. VFX consumes them. No gameplay logic in VFX code.
   ```
   Combat Event → VFX Pipeline → Visual Output
   ```

2. **Effect types**:
   - `projectile`: A moving visual (arrow, javelin, fireball) from source to target
   - `impact`: A burst at a position (sparks, blood spatter, gem shards)
   - `aura`: A persistent effect around a unit (oakskin green glow, burn flames)
   - `status`: Small icon or coloured ring indicating a status effect (poison green, burn red)
   - `screen_shake`: Camera shake on heavy impacts

3. **Gemstone colour mapping**: Magic effects use gemstone colours (from art bible §4.7):
   - Ruby → Fire (red-orange)
   - Sapphire → Water/Ice (blue)
   - Emerald → Nature (green)
   - Amethyst → Spirit/Arcane (purple)
   - Topaz → Light (gold)
   - Carnelian → Earth (orange-brown)

4. **Performance**: VFX use pre-loaded sprite sheets and particle configurations. No runtime spawning of large textures. Maximum 20 simultaneous particle systems.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S18 Tactical Combat | Consumes | Combat events trigger VFX |
| S22 Combat Skills | Consumes | Skill definitions reference VFX IDs |

## Edge Cases

- **If a VFX asset is missing**: The effect is silently skipped. No crash.
- **If the player is on a retro handheld with lower performance**: VFX intensity is reduced. Particle count halved.
