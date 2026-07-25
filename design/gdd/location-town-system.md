# Location System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: A Living, Persistent World, Discovery-Driven Exploration

## Overview

The Location System manages every named place on the world map — villages, towns, crypts, shrines, spires, geysers, groves, forges, tombs, lairs, and ancient trees. Conceptually, all locations share a common base: they have a position, a hand-crafted scene template, optional NPCs, optional Actions, and a discovery state. The system unifies them under one model. A town is simply a location where `settlement = true` and `always_visible = true`. A hidden shrine is a location where `discoverable = true` with progressive discovery. An NPC giving directions to a location simply boosts or maxes its discovery progress.

## Player Fantasy

Every place in the world has a purpose. A village is where you rest and trade. A shrine is where you pray for blessings. A crypt is where you risk danger for reward. A grove is hidden deep in the forest and must be *found* — the search itself is gameplay. The player learns that some locations are known from the start (towns) and others are secrets waiting to be uncovered.

## Detailed Design

### Core Rules

1. **Unified location model**: Every location, regardless of type, uses the same base structure:
   ```lua
   {
       id = "town_pelasgian_1",
       name = "Forest-Hold",
       position = {x = 250.0, y = 400.0},
       faction = "pelasgian",
       template = "town_forest_01",       -- hand-crafted scene
        
       -- Type flags
       settlement = true,                   -- true for towns/villages
       always_visible = true,               -- true for settlements, false for POIs
       
       -- Optional: NPCs and Actions
       npcs = {"npc_elder_01", "npc_trader_01"},
       actions = {},                        -- towns have actions through their NPCs
       
       -- Settlement-only properties
       population = 200,
       prosperity = 50,
       
       -- Discovery (only for non-settlement POIs)
       discoverable = true,                 -- false for always_visible locations
       discovery_difficulty = 100,          -- total progress needed
       discovery_radius = 80.0,             -- max range for progress
       discovery_progress = 0,              -- current progress
   }
   ```

2. **Settlement vs. POI**: The only structural differences are:
   - `settlement = true`: has population/prosperity, NPCs always present, services available
   - `settlement = false` (POI): may have NPCs (optional), may have Actions, uses progressive discovery
   - `always_visible = true`: appears on the map from game start
   - `discoverable = true`: hidden until discovery progress reaches 100

3. **Progressive discovery** (for discoverable locations): When the player moves within a location's `discovery_radius`:
   - `progress_rate = base_rate * (1.0 - distance / radius) * biome_visibility * (is_night ? 0.5 : 1.0)`
   - Each location type has a `discovery_difficulty` determining total progress needed:
     - Tower / Wind Spire: 40 (easy, far radius 120)
     - Thermal Geysers: 60 (moderate, radius 80)
     - Shrine / Altar: 80 (moderate, radius 60)
     - Crypt: 80 (moderate, radius 50)
     - Ancient Forge: 80 (moderate, radius 60)
     - Broken Tower: 60 (moderate, radius 80)
     - Healing Spring: 100 (hard, radius 50)
     - Ancient Tomb: 100 (hard, radius 40)
     - Grove of Spirits: 120 (hard, radius 40)
     - Troll Lair: 100 (hard, radius 30)
   - When progress reaches 100, the location is discovered and appears on the map.

4. **Discovery boosts from NPCs/quests**: When an NPC gives directions to a location:
   - `auto_discover = true` → progress forced to 100 (immediate discovery)
   - `discovery_progress += 50` → partial progress, final search faster

5. **NPCs at locations**: Each location has an `npcs` list referencing NPC data IDs. These NPCs become available when the player enters the location. NPCs can provide services (trade, quests, healing, recruitment) or simply dialogue.

6. **Location Actions**: Some locations offer things the player can do beyond talking to NPCs. Each action has:
   - Name/label (e.g., "Pray", "Explore", "Rest")
   - Requirements (optional): minimum skill level, item in inventory, gold cost
   - Effects: heal party, trigger encounter, grant buff, etc.
   - Cooldown (optional): how long until reusable

### Location Catalog (MVP)

**Always visible (settlements, 4 total):**
| ID | Name | Faction | NPCs | Notes |
|----|------|---------|------|-------|
| town_pelasgian_1 | Forest-Hold | Pelasgian | elder, trader, blacksmith | Trade, quests, repairs |
| town_pelasgian_2 | Oak-Wall | Pelasgian | elder, trader, hunter | Trade, quests, guidance |
| town_mycenaean_1 | Sea-Gate | Mycenaean | lord, trader, taverner | Trade, quests, recruitment |
| town_mycenaean_2 | Bronze-Hill | Mycenaean | lord, trader, blacksmith | Trade, quests, upgrades |

**Discoverable (non-settlement, ~10 total):**
| ID | Difficulty | NPC? | Actions |
|----|-----------|------|---------|
| Crypt | 80 | No | Explore → encounter (skeletons/ghosts) |
| Shrine/Altar | 80 | No | Pray (Divination → buff), Sacrifice (item → blessing) |
| Thermal Geysers | 60 | No | Rest → accelerated healing |
| Wind Spire | 40 | No | Trade gems → magic power |
| Healing Spring | 100 | No | Rest → heal wounds |
| Grove of Spirits | 120 | Druid | Converse, trade herbs |
| Ancient Tomb | 100 | Necromancer | Explore, converse, raise skeletons |
| Broken Tower | 60 | No | Explore → find loot |
| Troll Lair | 100 | No | Explore → encounter troll |
| Ancient Forge | 80 | No | Forge/upgrade equipment |

### States and Transitions

| State | Description |
|-------|-------------|
| **Hidden** | Exists in data, not on map. Progress accumulates when player is near. |
| **Seeking** | Player is within discovery radius. Progress accumulating. Not yet on map. |
| **Discovered** | Progress ≥ 100. Visible on map. Navigable. |
| **Active** | Player has entered the location scene. NPCs and Actions available. |
| **Depleted** | Action completed (loot taken, troll killed). May have cooldown. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S05 World Generation | Consumes | Site placement data (all locations) |
| S09 NPC Data System | Consumes | NPC references for location population |
| S15 World Map Navigation | Provides | Player position for discovery proximity |
| S06 Biome System | Consumes | Biome visibility modifier affects discovery |
| S07 Time System | Consumes | Night halves discovery rate |
| S30 Quest Instance | Consumed by | Quests can auto-discover or boost progress |
| S31 Dialogue System | Provides | NPCs at locations offer conversations |
| S32 Map/Minimap | Consumes | Discovered locations appear on map |

## Formulas

**Discovery progress rate:**

`rate = base_rate * (1.0 - distance / discovery_radius) * biome_visibility * (is_night ? 0.5 : 1.0)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base rate | `base_rate` | float | 10–20 | Progress/sec at zero distance |
| Distance to location | `distance` | float | 0–radius | Current distance from player to location |
| Discovery radius | `discovery_radius` | float | 30–120 | Max range for progress (per location type) |
| Biome visibility | `biome_visibility` | float | 0.4–1.3 | From S06 |
| Night multiplier | `night_multiplier` | float | 0.5 | Night halves discovery rate |

**Rest healing multiplier at Thermal Geysers:** `healing_rate = base_healing * 3.0`

**Pray success at Shrine:** `success = player.divination_skill >= shrine_difficulty` — binary check. On success, gain a temporary buff.

## Edge Cases

- **If two locations overlap in discovery radius**: Both accumulate progress independently. Player may discover both without knowing which is which.
- **If a location's NPC is killed or recruited**: The NPC is removed from the location's NPC list. The location may become empty (no NPCs, only actions).
- **If a location action has a cooldown and the player returns during it**: The action is greyed out with remaining time displayed.
- **If a settlement's population reaches 0 (all NPCs gone)**: Marked as abandoned. No services available (future feature: repopulation).
- **If the player enters a location with no NPCs and no actions**: Show a brief description with an "Exit" option. Guards against data errors.
- **If a quest auto-discovers a location but the player was already seeking it**: Quest progress is added to existing progress. Auto-discover forces to 100.
- **If a location is depleted (troll killed, loot taken)**: Remains on the map as "Depleted" with a grey icon. Cannot be re-entered.
- **At 800×600 resolution**: Location scenes and discovery ranges are resolution-independent.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S05 World Generation | Hard | Site placement data — all locations |
| S09 NPC Data System | Hard | NPC definitions referenced by locations |
| S01 Input System | Hard | Player input for menu navigation at locations |
| S15 World Map Navigation | Hard | Player position for proximity discovery |
| S06 Biome System | Hard | Biome visibility modifier for discovery rate |
| S07 Time System | Hard | Night modifier for discovery rate |
| S30 Quest Instance System | Soft | Quests can auto-discover or boost location progress |

**Depended on by:** S15 World Map Navigation, S31 Dialogue System, S32 Map/Minimap System.

## Tuning Knobs

- **Base discovery rate**: Float. Default: 15. Range: 5–30. Progress units/sec at zero distance.
- **Discovery difficulty per type**: Per-location-type configurable (40–120 range).
- **Discovery radius per type**: Per-location-type configurable (30–120 range).
- **Night discovery penalty**: Float. Default: 0.5.
- **Quest auto-discovery progress**: Float 0–100. Default: 50 (partial), 100 (auto-discover).
- **Rest healing multiplier**: Float. Default: 3.0 at geysers.
- **Action cooldown durations**: Float hours of game time. Per-action configurable.

## Visual/Audio Requirements

- **Location scenes**: Each location type has a hand-crafted pixel-art scene template. Templates define background, NPC positions, and interactive elements.
- **Discovery cue**: When discovery progress is accumulating near a hidden location, a subtle compass glow or particle drift hints at something nearby.
- **Discovery notification**: Banner: "Discovered: Shrine of the Forgotten" with a soft chime.
- **Audio**: Each location type has ambient audio (crypt = echoing wind, shrine = chime, town = crowd). Crossfade on entry/exit.

## UI Requirements

- **Location screen**: When entering a location, the view transitions to a scene. Available NPCs and Actions displayed as interactive options.
- **Discovery progress indicator**: Subtle compass edge glow when near a hidden location, growing stronger closer to it.
- **Quest-related search area**: If a quest points to a hidden location, the map shows a search circle rather than an exact marker. After discovery, the exact marker appears.
- **Location HUD overlay**: Location name, faction crest, action cooldown timers.
- **Transition effect**: Brief fade-to-black (0.3s) when entering/exiting a location.

## Acceptance Criteria

- **GIVEN** a settlement (always_visible=true), **WHEN** the game starts, **THEN** it appears on the map immediately.
- **GIVEN** a hidden location, **WHEN** the player moves within its discovery radius, **THEN** discovery progress begins accumulating.
- **GIVEN** the player is closer to a hidden location, **WHEN** compared to farther away, **THEN** progress accumulates faster.
- **GIVEN** a location reaches 100 discovery progress, **WHEN** discovered, **THEN** its name and icon appear on the map.
- **GIVEN** a quest auto-discovers a location, **WHEN** accepted, **THEN** the location is immediately discovered.
- **GIVEN** an NPC gives a rumour, **WHEN** shared, **THEN** the player receives 50 discovery progress.
- **GIVEN** a settlement with NPCs, **WHEN** the player enters, **THEN** all defined NPCs are available.
- **GIVEN** a shrine with a Pray action, **WHEN** selected, **THEN** a Divination check is performed.

## Open Questions

- **Location scene rendering**: Full-screen hand-crafted pixel art for POIs vs. zoomed-in tile view for settlements? Affects the art pipeline.
- **Settlement population changes**: Deferred from MVP.

