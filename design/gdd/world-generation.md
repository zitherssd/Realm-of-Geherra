# Procedural World Generation

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Discovery-Driven Exploration, A Living, Persistent World

## Overview

The Procedural World Generation system creates the game's world map at the start of each new game. The world map is a **continuous 2D space** (not tile-based) over which terrain features, biomes, rivers, and sites are defined. It uses a **hybrid approach**: the computer procedurally generates the terrain geography, biome layout (noise-sampled, not gridded), river paths, road networks, and site placement (which town goes where), while all location *content* — town layouts, POI interiors, encounter zones, and landmarks — is **hand-crafted by the designer**. This ensures every place a player visits is intentionally designed, while the overall world layout varies between playthroughs. The system is seeded with a random integer seed, allowing the same world to be regenerated from a known seed.

## Player Fantasy

The world feels ancient and real because it was *designed* — every town has character, every ruin tells a story. But the *journey* between them changes each playthrough: different rivers to cross, different biomes to traverse, different roads to follow. The player's fantasy is exploring a living, hand-crafted world where the path is never quite the same twice.

## Detailed Design

### Core Rules

1. **Continuous coordinate space**: The world map uses logical float coordinates. Map bounds are defined as `(0, 0)` to `(map_width, map_height)` where both default to 1024.0 for MVP. Positions, distances, and paths use floats, not integers.

2. **Seeded generation**: A random integer seed (`love.math.random(1, 2^31)`) is generated at New Game. All noise functions use this seed for deterministic output. The seed is stored in the save file.

3. **Multi-stage pipeline**: Generation runs in ordered stages:

   ```
   Seed → Stage 1: Terrain Heightmap → Stage 2: Biome Voronoi + Rivers → Stage 3: Site Placement → Stage 4: Road Network
   ```

4. **Stage 1 — Terrain Heightmap**: Defines the terrain as a function of noise, not a grid. `lovemath.noise(x / scale, y / seed)` sampled at any (x, y) returns a height value. Thresholds determine walkability:
   - `height < -0.3`: Deep water (impassable)
   - `-0.3 ≤ height < -0.1`: Shallow water / marsh (slow travel, passable)
   - `-0.1 ≤ height < 0.6`: Walkable terrain
   - `height ≥ 0.6`: Mountain (impassable)
   
   At least 45% of the map area must be walkable. If not, the noise scale is adjusted and re-sampled (up to 3 retries).

5. **Stage 2 — Biome Voronoi + Rivers**: Places 10–20 biome seed points using Poisson disk sampling (minimum distance `map_width / 8`). Each seed point is assigned a biome type. Voronoi cells define biome regions in continuous space. Biome is determined by querying the nearest seed point to any (x, y) coordinate.

   **Biomes:**
   - Plains — open grassland, fast travel
   - Forest — slower travel, reduced visibility, more encounters
   - Hills — moderate speed, good vantage points
   - Wasteland — slow travel, hazardous, few resources
   - Desert — moderate speed, low visibility during sand events
   - Snow Forest — slow travel, cold visual palette, sparse
   - Snow Plains — open but cold, moderate speed
   - Beach — thin strip along water bodies, moderate speed

   **Rivers**: Generated as splines (polylines with smooth curves) originating from mountain/blocked areas and terminating at the map edge or a large water body. 3–7 rivers per map. River width varies from `2.0–8.0` units. Rivers are **impassable** except at bridges or natural fords. Bridges are placed procedurally where roads cross rivers. Natural fords may exist at narrow river points (width < 3.0 units) — these are marked on the map once discovered.

6. **Stage 3 — Site Placement**: Places hand-crafted location templates at continuous coordinates:
   - **Towns**: 2 towns per faction (4 total for MVP). Placed on walkable terrain with minimum spacing of `map_width / 4`. Each town is assigned a faction. At least one town must be reachable from the player start within `map_width / 5` travel distance.
   - **POIs**: 8–12 neutral POIs (shrines, ruins, springs, geysers, wizard towers, ancient trees, battlefields). Placed on walkable terrain with minimum spacing of `map_width / 10` from towns and `map_width / 20` from each other.
   - **Player start**: Placed near a Pelasgian town within `map_width / 30`.

7. **Stage 4 — Road Network**: Faction-specific road generation. Roads are polylines (arrays of `{x, y}` points) between towns:

   - **Proto-Mycenaean roads**: Narrow, stone-paved. Straight-line segments where possible, stepped on slopes. Most formal road style. Connects their towns directly. Visual: grey-brown cobbled strips.
   - **Proto-Egyptian roads**: Ceremonial causeways between towns and the Nile/rivers. Otherwise travel was river-based. Boundary markers (small standing stones) at intervals along desert routes rather than continuous paving. Visual: packed sand with stone markers every ~20 units.
   - **Pelasgian roads**: Worn dirt tracks following the terrain. Sacred paths marked by standing stones or carved waymarkers through forest areas. Less direct, more winding. Visual: beaten earth, mossy stones at intervals.
   
   **Road discovery**: Roads only appear on the player's map once discovered by travelling along them or being told about them by an NPC. Main routes between faction towns are known from the start.

8. **Hand-crafted location templates**: Each town and POI type has a template definition in `data/location_templates/`. Templates specify:
   - The layout (building positions, walkable paths, terrain features)
   - NPCs present (by NPC data IDs)
   - Available services (vendor, quest giver, recruitment, healing)
   - Faction ownership
   - Encounter tables (what enemies patrol nearby)
   - Visual style (faction-specific building sprites)

9. **World data output**: After generation, the system produces a structured table:
   ```lua
   {
       seed = 12345,
       width = 1024.0, height = 1024.0,
       noise_scale = 0.03,  -- terrain noise parameter
       biomes = {
           seeds = { {x, y, type}, ... },  -- Voronoi seed points
       },
       rivers = {
           { points = {{x, y}, ...}, width = 4.0 }, ...
       },
       roads = {
           { type = "paved"|"causeway"|"dirt", faction = "mycenaean"|"egyptian"|"pelasgian",
             points = {{x, y}, ...} }, ...
       },
       sites = {
           towns = { {id, name, faction, template, x, y}, ... },
           pois = { {id, type, template, x, y}, ... },
           player_start = {x, y}
       }
   }
   ```

### States and Transitions

| State | Description | Entry | Exit |
|-------|-------------|-------|------|
| **Not Generated** | No world data exists. | New Game starts | Generation begins |
| **Generating** | Multi-stage pipeline running. | Generation triggered | All stages complete |
| **Ready** | World data is available for systems to read. | Generation complete | Save/Load, World Map Navigation |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Save/Load System | Provides data | World data (seed, site placements) is persisted in saves. |
| World Map Navigation | Consumes | Queries terrain height at (x, y) for walkability. Reads river and road polylines. |
| Biome System | Consumes | Queries biome at (x, y) via Voronoi seed lookup. Provides traversal modifiers. |
| Location/Town System | Provides | Town and POI placements with template references. |
| Party Encounter System | Consumes | Uses terrain + biome to determine encounter tables per region. |
| POI System | Provides | POI positions and types for discovery tracking. |
| Map/Minimap System | Consumes | Reads terrain, biome, road, river, and site data for rendering. |

## Formulas

The terrain height at any point (x, y) is defined as:

`height(x, y) = love.math.noise(x * noise_scale + seed_offset, y * noise_scale + seed_offset)`

This returns a value in roughly `[-1.0, 1.0]`. Thresholds determine terrain type (see Stage 1 above).

**Voronoi biome query**: For any point (x, y), the biome is that of the nearest seed point:

`biome(x, y) = biome_of( argmin_i distance((x, y), seed_i) )`

**Minimum site spacing** (Poisson disk):

`minimum_spacing = map_width / sqrt(num_towns * 2 + num_pois)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Map width | `map_width` | float | 1024.0 | World map coordinate width |
| Number of towns | `num_towns` | int | 4 | MVP (2 factions × 2 towns) |
| Number of POIs | `num_pois` | int | 8–12 | Neutral sites |
| Noise scale | `noise_scale` | float | 0.01–0.10 | Terrain feature size |
| Seed offset | `seed_offset` | float | `seed / 2^31` | Deterministic noise offset |

**Output Range:** Minimum site spacing ~`1024 / sqrt(4*2 + 10) = 1024 / sqrt(18) ≈ 241` units apart on a 1024-wide map.

## Edge Cases

- **If generation produces <45% walkable terrain**: Re-sample with adjusted noise scale (lower = broader features, more walkable). Retry up to 3 times. If still failing, use a fallback hand-crafted layout.
- **If a town cannot be placed (no valid position meeting spacing)**: Reduce minimum spacing by 10% and retry. If still failing after 3 attempts, place at the first walkable position regardless of spacing.
- **If a river origin cannot find a path to the map edge**: The river terminates at the nearest water body or walkable low point. Short rivers (<50 units) are discarded.
- **If a road crosses a river with no bridge point**: A bridge is procedurally placed at the crossing point. Bridge visual matches the road's faction style.
- **If the player enters a seed producing an unsatisfactory map**: The player can restart with a new seed. No in-game regeneration.
- **At 800×600 resolution**: World map generation is resolution-independent. The continuous coordinate space scales to fit any viewport.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| LÖVE love.math | Hard (engine) | `love.math.noise(x, y)` for continuous terrain height sampling |
| LÖVE love.math RandomGenerator | Hard (engine) | Seeded RNG for deterministic generation |
| Biome System | Hard | Biome type definitions with traversal modifiers |
| Location/Town System | Hard | Hand-crafted location template loading |
| Save/Load System | Hard | World seed and site placements persisted in saves |

**Depended on by:** World Map Navigation, Party Encounter System, POI System, Biome System, Map/Minimap System.

## Tuning Knobs

- **Map size**: Float. Default: 1024. Range: 512–2048. MVP starts at 1024, can expand later.
- **Noise scale**: Float 0.01–0.10. Default: 0.03. Higher = more granular terrain. Lower = broader features.
- **Walkable threshold**: Float 0.0–1.0. Default: 0.45. Higher = more walkable terrain. Lower = more mountains/water.
- **Number of POIs**: Integer. Default: 10. Range: 5–20.
- **Number of rivers**: Integer. Default: 5. Range: 3–7.
- **Minimum town spacing**: Float. Default: `map_width / 4` (~256). Range: `map_width / 6` to `map_width / 3`.
- **Road generation enabled**: Boolean. Default: true.

## Visual/Audio Requirements

- **No direct visual/audio output.** The system produces data. Rendering is handled by World Map Navigation and Map/Minimap systems.
- **Debug overlay**: During development, a visualisation mode showing terrain height, biome regions, river paths, and road networks is recommended.

## UI Requirements

- **No direct UI.** A future "New Game" screen may offer a seed input field.
- **Generation screen**: During generation (<1 second), a brief "Generating world..." message with a compass or map-unfolding animation.

## Acceptance Criteria

- **GIVEN** a new game starts, **WHEN** world generation completes, **THEN** ≥45% of the map area is walkable terrain.
- **GIVEN** a seed value, **WHEN** `height(x, y)` is sampled twice with the same seed and coordinates, **THEN** both samples return the same value.
- **GIVEN** generation is complete, **WHEN** the site table is inspected, **THEN** it contains 4 towns (2 per faction), 8–12 POIs, and a player start position.
- **GIVEN** a different seed, **WHEN** generation runs, **THEN** the terrain, biome layout, and site positions differ from the first seed.
- **GIVEN** any (x, y) on the map, **WHEN** biome is queried, **THEN** it returns one of the defined biome types.
- **GIVEN** a road was generated between two towns, **WHEN** queried, **THEN** the road's polylines and faction style are consistent.
- **GIVEN** a river segment, **WHEN** queried, **THEN** its points form a continuous polyline from source toward the map edge or water body.
- **GIVEN** generation fails after 3 retries, **THEN** a fallback hand-crafted map layout is used.

## Open Questions

- **Faction territory assignment**: Should faction towns influence which biome they're placed in (e.g., Pelasgians prefer forest biomes, Egyptians prefer desert)? Proposed: yes. If unavailable, fall back to any walkable terrain.
- **Map expansion**: MVP map is 1024×1024 units. The system should support generating larger maps (2048+) without architecture changes — just tuning knob adjustments. Confirm when scaling.
- **River gameplay**: Should rivers be purely visual/a barrier, or have gameplay effects (fishing, water travel, crossing penalties)? Deferred — define when World Map Navigation is designed.
