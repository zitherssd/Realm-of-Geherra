# World Map Navigation

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Preparation Over Reflexes, Discovery-Driven Exploration, A Living, Persistent World

## Overview

The World Map Navigation system handles the player's movement across the continuous 2D world map. It reads the terrain (walkable vs. blocked), biome traversal modifiers, road speed bonuses, and party base speed to produce a final movement speed. It also manages collision with terrain boundaries (mountains, deep water) and detects proximity to POIs and other parties for encounter triggering. Movement is real-time and continuous — the player holds a direction and moves freely, like Mount & Blade's world map. Movement speed varies by biome, road presence, time period, and party composition.

## Player Fantasy

The world map is where *journey* happens. Sprinting across open plains at Highsun feels fast and free. Pushing through a wasteland at Gloamhour feels slow and dangerous. Spotting a party on the horizon, choosing whether to intercept or avoid, finding a road that speeds your travel — these are moment-to-moment tactical decisions. The player learns to read the terrain: "Take the road through the hills — it's longer but faster than the forest."

## Detailed Design

### Core Rules

1. **Continuous movement**: The player moves in continuous 2D space with float coordinates. Input is directional (WASD or gamepad stick). Movement is frame-rate independent: `position += direction * speed * dt`.

2. **Party base speed**: The party has a base movement speed determined by party composition (more members = slightly slower, certain skills like Navigation can increase speed). Base speed units: units/second on the world map coordinate system. Default base speed: 100 units/sec.

3. **Speed calculation**:
   `final_speed = base_speed * biome_modifier * (on_road ? road_multiplier : 1.0) * (is_night ? 0.8 : 1.0)`

4. **Terrain collision**: The system queries the terrain heightmap at the player's position each frame. If the position is blocked (mountain, deep water), movement is stopped at the boundary. Rivers are impassable except at bridge/ford points.

5. **Road detection**: Each frame, the system checks if the player's current position is on a road segment. Roads provide the road_multiplier speed bonus. Roads are faction-specific visually but provide the same speed bonus regardless of faction.

6. **Party encounter detection**: Proximity detection runs each frame. If another party comes within a detection range (modified by time period and biome visibility), the player can see them. If the player's party comes within engagement range, a prompt appears to engage or pass.

7. **POI discovery**: Undiscovered POIs (non-town locations) are hidden on the map. Moving near them accumulates **discovery progress** — the closer the player is, the faster progress accumulates. Each POI has a `discovery_difficulty` value representing total progress needed. When progress reaches 100%, the POI is discovered and appears on the map. Discovery range, rate, and difficulty vary by POI type (a tower is easier to spot than a hidden grove). NPCs giving quests related to a POI may auto-discover it or grant bonus discovery progress.

8. **Edge of map**: The world map has boundaries. The player cannot move beyond them. A visual cue (dark edge, wind effect) indicates the boundary.

### Movement Speed Reference

| Condition | Modifier | Example Result |
|-----------|----------|---------------|
| Plains, day | 1.0 | 100 units/sec |
| Forest, day | 0.7 | 70 units/sec |
| Wasteland, day | 0.5 | 50 units/sec |
| Any biome on road | 1.5 × biome | 150 units/sec (plains road) |
| Night (any biome, no road) | 0.8 × biome | 80 units/sec (plains night) |
| Snow Forest, night | 0.5 × 0.8 | 40 units/sec |

### States and Transitions

| State | Description |
|-------|-------------|
| **Travelling** | Player is moving on the world map. Time advances. Encounters and POI detection active. |
| **Idle** | Player is stationary on the world map. Time does not advance. |
| **Encountering** | Player has triggered a party encounter. Transition to encounter prompt or combat scene. |
| **Entering Location** | Player has reached a town or POI. Transition to location scene. |
| **Blocked** | Player is against a terrain boundary. Movement is zero in that direction. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S05 World Generation | Consumes | Terrain height queries, road network, river polylines |
| S06 Biome System | Consumes | `get_traversal_modifier(x, y)` → speed multiplier |
| S07 Time System | Consumes | `get_day_phase()` → night modifier for visibility and speed |
| S16 Party Encounter | Provides | Current position for proximity detection against other parties |
| S17 POI System | Provides | Current position for POI discovery range checks |
| S15 World Map Rendering | Provides | Camera position follows party position |
| S01 Input System | Consumes | Directional input for movement |
| S10 Character Stats | Consumes | Party base speed (modified by Navigation skill, party size) |

## Formulas

**Final movement speed:**

`final_speed = base_speed * biome_traversal * (on_road ? road_bonus : 1.0) * (is_night ? night_penalty : 1.0)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base party speed | `base_speed` | float | 50–200 | Party's base units/sec |
| Biome traversal | `biome_traversal` | float | 0.3–1.5 | Per-biome modifier from S06 |
| Road bonus | `road_bonus` | float | 1.5 | Speed multiplier when on a road |
| Night penalty | `night_penalty` | float | 0.8 | Speed reduction at night |
| Is on road | `on_road` | bool | true/false | Whether player position is on a road |

**Example:** Party with base speed 100 on a road through a forest (0.7): `100 * 0.7 * 1.5 = 105` units/sec. Faster than plains without road (100).

## Edge Cases

- **If the player is exactly on a biome boundary**: Sample the biome at the player's position each frame. Speed may fluctuate. A smoothing lerp (~0.5s) prevents jarring speed changes.
- **If the player moves diagonally**: Normalize the direction vector so diagonal movement isn't faster than cardinal movement.
- **If a road and river cross at the player's position**: The bridge takes priority — the player can cross. If no bridge, the river is impassable.
- **If the player's party speed is zero (all members incapacitated)**: The party cannot move. Player must wait for recovery or reload a save.
- **If the player walks into a map boundary**: Movement is clamped. Visual feedback (camera shake? dark edge pulse?) indicates the boundary.
- **At 800×600 resolution**: World map rendering scales. Movement speed in world coordinates is unchanged.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S05 World Generation | Hard | Terrain height function, road network data, river polylines |
| S06 Biome System | Hard | Traversal speed modifier per biome |
| S07 Time System | Hard | Night modifier for speed and visibility |
| S01 Input System | Hard | Directional movement input |
| S10 Character Stats | Soft | Party base speed affected by Navigation skill and party size |

**Depended on by:** S16 Party Encounter, S17 POI System, World Map Camera/Rendering.

## Tuning Knobs

- **Base party speed**: Float. Default: 100. Range: 50–200. Units/sec on the world map.
- **Road speed bonus**: Float. Default: 1.5. Range: 1.0–3.0.
- **Night speed penalty**: Float. Default: 0.8. Range: 0.3–1.0.
- **Speed smoothing duration**: Float seconds. Default: 0.5. How long speed changes take to lerp at biome boundaries.
- **Map boundary detection range**: Float. Default: 5.0. Distance from edge where visual cue appears.

## Visual/Audio Requirements

- **Party sprite**: A small party icon (heraldic sigil + unit sprites) shown on the world map at the player's position. Moves continuously with input.
- **Terrain rendering**: The world map is rendered from terrain + biome data. Colour-coded by biome with terrain features drawn.
- **Road rendering**: Paved roads (Mycenaean) shown as grey strips. Dirt tracks (Pelasgian) as brown paths. Markers (Egyptian) as dot-dash lines.
- **Movement particles**: Dust kicked up while moving, varying by terrain type (dusty in plains, leaves in forest, sand in desert).
- **Footstep/hoof audio**: Ambient movement sounds varying by terrain type. Handled by Audio/Music System triggered by movement state.

## UI Requirements

- **Minimap**: A small circular minimap in the HUD corner showing the surrounding terrain, known roads, discovered POIs, and nearby parties.
- **Speed indicator**: Subtle visual feedback showing current speed (e.g., party sprite animation speed, wind lines, or a speed bar).
- **Location name popup**: When entering a biome or approaching a POI, a brief name banner appears ("Forest of Echoes", "Shrine of the Lost").
- **Encounter prompt**: When encountering another party, a brief prompt or overlay appears: "Bandit Warband spotted. [F] Engage | [R] Pass"

## Acceptance Criteria

- **GIVEN** the player holds the W key, **WHEN** on the world map, **THEN** the party moves continuously in the upward direction.
- **GIVEN** the player is in a forest biome, **WHEN** moving, **THEN** speed is multiplied by the forest's traversal modifier.
- **GIVEN** the player walks onto a road, **WHEN** moving, **THEN** speed is further multiplied by the road bonus.
- **GIVEN** the player walks into a mountain tile, **WHEN** attempting to move, **THEN** movement is stopped at the boundary.
- **GIVEN** the player approaches a river without a bridge, **WHEN** attempting to cross, **THEN** movement is blocked.
- **GIVEN** the player walks within discovery range of a POI, **WHEN** the range is crossed, **THEN** the POI is marked discovered.
- **GIVEN** the player walks within encounter range of another party, **WHEN** the range is crossed, **THEN** the encounter prompt appears.
- **GIVEN** it is Stilldark, **WHEN** moving, **THEN** speed includes the night penalty.
- **GIVEN** the player releases all movement keys, **WHEN** on the world map, **THEN** the party stops and time stops advancing.

## Open Questions

- **Navigation skill effect**: The concept mentions Navigation as a skill that affects world map travel. Should it increase speed, reduce night penalty, or reveal more of the map? Proposed: Navigation increases base speed by a percentage per skill point. Deferred to Skill System design.
- **Party size speed penalty**: Should larger parties move slower? Proposed: minor penalty (1–2% per additional member beyond the first 3). Deferred to Party Management System design.
