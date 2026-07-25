# Save/Load System

> **Status**: Complete
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Foundation — enables all pillars

## Overview

The Save/Load System manages all game state persistence: saving progress to disk, loading saved games, and creating new game sessions. It uses LÖVE's `love.filesystem` module to read and write save files as serialized Lua tables. Saves are stored as individual files per slot using LÖVE's save directory. The system provides a simple API consumed by the Main Menu (save selection, load, new game) and by gameplay systems (auto-save, manual save). Each save contains the complete game state: world generation seed, party data, faction reputation, quest instances, inventory, and game progress markers.

## Player Fantasy

The Save/Load System is invisible infrastructure. Players interact with it only through the Main Menu's load/save interface and whatever save prompts the game provides. The fantasy it protects is *investment* — the knowledge that progress is safe and can be returned to. Losing a save file is one of the most frustrating experiences in gaming; this system is designed to prevent that.

## Detailed Design

### Core Rules

1. **Save format**: Each save is a Lua file containing a single table with all game state. Files are written to LÖVE's `getSaveDirectory()` using `love.filesystem.write()`.

2. **Save slots**: MVP supports 3 save slots. Each slot has a numeric ID (1–3). Slot metadata (character name, level, play time, timestamp) is stored in a separate index file for fast listing without loading full saves.

3. **Save contents**: Each save contains:
   - `save_version` — integer for format migration
   - `timestamp` — ISO 8601 date string
   - `player_name` — string
   - `player_stats` — table of character attributes and skills
   - `party` — table of party members
   - `inventory` — table of items
   - `equipment` — equipped gear slots
   - `world_seed` — world generation seed (integer)
   - `biome_data` — explored regions
   - `faction_reputation` — table of faction IDs → reputation values
   - `quest_instances` — table of active/completed quests
   - `time_data` — game time (day, hour)
   - `location_data` — current position, current location ID
   - `discovered_pois` — table of discovered POI IDs

4. **Saving process**: Read current game state from all systems → serialize to Lua table → write to file as formatted Lua. Uses `string.dump()` or manual table serialization.

5. **Loading process**: Read file → verify integrity → deserialize → distribute state to all systems → trigger scene load.

6. **Save index**: A lightweight file `saves/index.lua` stores slot metadata only. Updated on every save. Read quickly for the save selection screen without loading full saves.

7. **Save migration**: The `save_version` field enables format migration. On load, if `save_version < current_version`, the system applies migration functions sequentially.

8. **New game**: Generates a fresh world seed (`love.math.random()`) and initialises all game state to defaults.

### States and Transitions

| State | Description | Entry | Exit |
|-------|-------------|-------|------|
| **Idle** | No save operation in progress. | Game running normally. | Save or Load requested |
| **Saving** | Writing save data to disk. | Save triggered (auto or manual). | Write complete → Idle |
| **Loading** | Reading save data and distributing to systems. | Load triggered from menu or auto-load. | State distributed → scene changes |
| **New Game** | Initialising fresh game state. | New Game selected from menu. | State ready → scene transitions |
| **Corrupt** | Save file failed integrity check. | Loading a corrupted file. | Display error → return to Idle |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Main Menu System | Called by | `SaveLoad.list_saves()` → `{slot_id, name, level, time, timestamp}` table. `SaveLoad.load_game(slot_id)` → loads save. `SaveLoad.new_game()` → fresh state. |
| All gameplay systems | Provide state | Each system implements `get_save_data()` and `load_save_data(data)` callbacks. The Save/Load System iterates all registered systems during save/load. |
| Scene Manager | Uses | After loading, `Game:change_scene(target_scene)` to enter the game world. |

## Formulas

No complex formulas. The save version migration uses a simple step function:

`current_save_version = 1`

When loading:
```
if loaded_version < current_save_version:
    for v = loaded_version to current_save_version - 1:
        apply_migration(v → v+1)
```

## Edge Cases

- **If the save directory is missing**: `love.filesystem.createDirectory("saves")` is called on first save. If creation fails, the system reports an error and does not overwrite in-memory state.
- **If a save file is corrupted**: The integrity check (attempt to load the Lua table, validate required fields) catches corruption. The save is marked as corrupt in the index. Loading a corrupt save shows an error message and returns to the menu.
- **If the player quits during a save**: The save file may be incomplete. On next load, the system detects a partially written file (missing `save_version` field) and treats it as corrupt. The previous save (written before the current save began) remains intact — saves write to a temp file first, then rename.
- **If two systems provide conflicting state**: Each system's save data is namespaced under its system ID. No conflicts possible.
- **If `love.filesystem` quota is exceeded**: LÖVE has a platform-dependent storage limit. The system checks available space before writing. If insufficient, it reports an error.
- **At 800×600 resolution**: No changes needed. File I/O is resolution-independent.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| LÖVE love.filesystem | Hard (engine) | `love.filesystem.write(path, data)`, `love.filesystem.read(path)`, `love.filesystem.getDirectoryItems(path)`, `love.filesystem.createDirectory(path)` |
| Scene Manager (ADR-0001) | Hard | `Game:change_scene(scene)` after loading completes |
| All gameplay systems | Soft (register) | `system.get_save_data()` → table. `system.load_save_data(table)` → void. Systems register themselves with Save/Load on init. |

**Depended on by:** S04 Main Menu System, all gameplay systems with persistent state.

## Tuning Knobs

- **Save slots**: Integer. Default: 3. Range: 1–9. Maximum number of save slots.
- **Save version**: Integer. Default: 1. Increment when save format changes. Used for migration.
- **Auto-save interval**: Float minutes. Default: 5.0. Range: 1.0–30.0. How often auto-save triggers on the world map. 0 = disabled.
- **Max save file size**: Integer KB. Default: 512. If a save exceeds this, warn the player.

## Visual/Audio Requirements

- **Save/Load icon**: A small spinning clay tablet or papyrus scroll icon displayed during save/load operations (32×32px, centred on screen).
- **No audio requirements.** Save/load operations are silent.

## UI Requirements

- **No direct UI owned by this system.** The save selection screen is part of the Main Menu System. This system provides the data. See S04 Main Menu GDD for UI details.
- **Save indicator**: A brief visual flash or icon (1–2 seconds) when auto-save triggers, to reassure the player.

## Acceptance Criteria

- **GIVEN** the player selects New Game, **WHEN** `SaveLoad.new_game()` is called, **THEN** a new world seed is generated and default state is initialised.
- **GIVEN** the player saves the game, **WHEN** the save completes, **THEN** a file exists at `saves/slot_1.lua` with valid game state.
- **GIVEN** the game starts and saves exist, **WHEN** `SaveLoad.list_saves()` is called, **THEN** it returns metadata for all populated slots.
- **GIVEN** the player selects a save to load, **WHEN** `SaveLoad.load_game(slot_id)` is called, **THEN** all systems receive their saved state.
- **GIVEN** a save file is corrupted, **WHEN** the player attempts to load it, **THEN** an error message is shown and no game state is modified.
- **GIVEN** the player plays for the auto-save interval, **WHEN** the interval elapses on the world map, **THEN** the game auto-saves to the most recent save slot.
- **GIVEN** the save format changes (version incremented), **WHEN** an old save is loaded, **THEN** migration functions are applied to update it to the current version.

## Open Questions

- **Auto-save triggers**: Should auto-save also trigger on significant events (quest completion, level up, entering town) in addition to the interval? Proposed: yes — both interval and event-based.
- **Cloud save support**: Not planned for MVP. LÖVE's save directory is local only. Steam Cloud integration would be a post-MVP addition via Steamworks.
