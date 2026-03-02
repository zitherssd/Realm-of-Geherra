# 🛡️ Love2D Mount & Blade–Style RPG Architecture

*A structural, system-oriented architecture for building a Mount & Blade–style RPG using **LÖVE (Love2D)**.*

---

## 📘 Purpose of This Document

This document defines the **project structure**, **architectural philosophy**, and **strict system boundaries** for the game.

It is intended to serve as:

* A **long-term technical reference**
* A **set of hard constraints** for implementation
* A **clear instruction set for an AI agent** (or human developer) to extend the project incrementally **without architectural drift**

No section of this document describes concrete gameplay implementations. It describes *where things belong* and *why*.

---

## 🎯 High-Level Goals

* Scale to **large battles, parties, and AI-driven NPCs**
* Support **data-driven content** and future modding
* Maintain a clean separation between **data, logic, and presentation**
* Remain flexible for long-term iteration, refactoring, and experimentation

---

## 🧠 Core Design Principles

1. **Systems operate on data, not objects with behavior**
2. **Entities are primarily data containers**
3. **UI never mutates game state directly**
4. **Quests, encounters, and progression are data-driven**
5. **Dependencies only flow downward**

These principles are non-negotiable.

---

## 📁 Root Project Structure

```
project/
│
├─ main.lua
├─ conf.lua
│
├─ core/
├─ game/
├─ systems/
├─ entities/
├─ world/
├─ quests/
├─ ui/
├─ data/
├─ assets/
├─ utils/
└─ debug/
```

---

## 🧠 core/ — Engine & Framework Glue

**Purpose:** Provide engine-agnostic foundations. No gameplay logic is permitted here.

```
core/
├─ game.lua            -- Main lifecycle coordination
├─ state_manager.lua   -- Push/pop/swap game states
├─ event_bus.lua       -- Decoupled event dispatch
├─ input.lua           -- Abstracted input layer
├─ time.lua            -- Time scaling & pausing
└─ save.lua            -- Save/load infrastructure
```

**Rules:**

* Must not reference gameplay concepts (combat, quests, items, factions)
* Must be reusable across entirely different games

---

## 🎲 game/ — High-Level Game Flow

**Purpose:** Define *what mode the game is currently in*.

```
game/
├─ states/
│  ├─ menu_state.lua
│  ├─ world_state.lua
│  ├─ battle_state.lua
│  ├─ dialogue_state.lua
│  └─ pause_state.lua
│  ├─ battle_end_state.lua
│  └─ location_state.lua
│
├─ battle/
│  ├─ battle_context.lua     -- Battle-specific blackboard
│  ├─ battle_grid.lua        -- Tactical grid data
│  └─ battle_unit.lua        -- Battle entity wrapper
│
├─ game_context.lua          -- Shared blackboard
└─ game_initializer.lua      -- New game setup and initialization
```

### game_context.lua

Acts as a **shared blackboard** containing:

* Player party
* Current world / map
* Active quests
* Global flags
* Difficulty or rulesets

This is the *only* globally shared mutable state in the game.

### game_initializer.lua

Handles initialization of a new game:

* Creates and configures the player character
* Initializes the world map
* Places initial settlements and NPCs
* Sets up starting quests and global state

Called when transitioning from the main menu to world state.

---

## ⚙️ systems/ — Game Logic Modules

**Purpose:** Implement game rules and mechanics. Systems never render UI.

```
systems/
├─ battle/
│  ├─ decision_system.lua    -- AI & Player intent processing
│  ├─ execution_system.lua   -- Action resolution & state updates
│  └─ render_system.lua      -- Battle visualization
│
├─ movement_system.lua
├─ party_system.lua
├─ combat_system.lua
├─ ai_system.lua
├─ animation_system.lua
├─ attribute_system.lua   -- Manages and checks character attributes
├─ skill_system.lua
├─ inventory_system.lua
├─ equipment_system.lua
├─ progression_system.lua
├─ faction_system.lua
├─ reputation_system.lua
├─ quest_system.lua
├─ dialogue_system.lua
├─ loot_system.lua       -- Handles loot generation and distribution
├─ trade_system.lua      -- Handles buying/selling logic
├─ loot_system.lua       -- Handles loot generation and distribution
├─ trade_system.lua      -- Handles buying/selling logic
├─ world_generation_system.lua   -- Seeded world mask, biome partitioning, road graph
├─ location_population_system.lua -- Spawns runtime locations from generated site data
├─ time_system.lua       -- Manages day/night cycle and time flow
```

### Procedural World Generation Flow

World map generation is split into two systems and one data config:

1.  **Config Layer (`data/world_generation.lua`)**
    * Declares tunable parameters (seed, site count, spacing, biome definitions, biome colors, road options)
    * Declares location population ranges (type weights, population/prosperity ranges, faction pool)

2.  **Generation Layer (`systems/world_generation_system.lua`)**
    * Builds walkable navigation cells from map art mask (black = blocked, non-black = walkable)
    * Places major sites with spacing constraints
    * Assigns biomes to sites and computes Voronoi ownership for walkable cells
    * Computes road paths between sites over the walkable grid
    * Writes generation payload into `Map.worldGen`

3.  **Population Layer (`systems/location_population_system.lua`)**
    * Consumes generated site payloads from `Map.worldGen`
    * Creates runtime `Location` instances (village/town/castle) using weighted data rules
    * Assigns faction, biome tags, population, and prosperity to each location

#### Extensibility Contract

* Adding a biome requires only data updates (`id`, `weight`, `color`, optional location bias)
* Changing settlement counts or spacing requires only config updates
* New location archetypes are added in data and interpreted by `location_population_system`
* Rendering systems may consume biome colors for overlays, but generation remains system-owned

### Battle System Flow

The tactical battle mode operates on a strict loop managed by `battle_state.lua`:

1.  **Input:** Player inputs are captured and stored as commands in `BattleContext`.
2.  **Decision System:**
    *   Converts Player commands into Unit Intents.
    *   Runs AI logic to generate Enemy Intents.
3.  **Execution System:** Resolves all Intents, updates grid positions, applies damage, and manages cooldowns.
4.  **Render System:** Visualizes the state, interpolating (lerping) unit positions for smooth movement.

### Battle VFX & Status Effect Pipeline (MANDATORY)

All combat effects (projectile trails, impact bursts, status glows) must follow a unified runtime pipeline.

1.  **Data Layer (`data/skills.lua`)**
    * Skills declare effect intent only (for example `projectile.style = "fireball"`, `aoe`, `targeted`)
    * No rendering code or imperative callbacks in data

2.  **Execution Layer (`systems/battle/execution_system.lua`)**
    * Spawns projectiles and transient VFX payloads into `BattleContext` (for example trail particles, explosion descriptors)
    * Applies/refreshes runtime statuses on `BattleUnit.statusEffects` (for example `burn` with `{remaining, duration}`)
    * Owns status ticking/expiration logic

3.  **Context Layer (`game/battle/battle_context.lua`)**
    * Stores transient render payloads in `BattleContext.data.vfx`
    * Stores live projectile payloads in `BattleContext.data.projectiles`
    * Contains no effect logic beyond storage helpers

4.  **Render Layer (`systems/battle/render_system.lua`)**
    * Sole owner of visual representation (particles, additive glow, shader passes)
    * Reads `BattleUnit.statusEffects` and context VFX payloads to draw effect state
    * Must not apply gameplay outcomes (damage, CC, stat changes)

#### Status Effect Contract

Runtime status effects on `BattleUnit` must use keyed entries in `statusEffects`:

* Example: `unit.statusEffects.burn = { remaining = 100, duration = 100, sourceSkillId = "fireball" }`
* Renderer computes visual intensity from `remaining / duration`
* Gameplay systems can later consume the same status key for mechanics (DoT, penalties) without changing UI/state boundaries

#### Authoring Rule for New Effects

When adding any future effect (ice, poison, holy, shock):

* Add declarative config in data
* Spawn/update runtime payloads in execution
* Render exclusively in render system (shader/particles/sprites)
* Never place effect gameplay logic in UI, entities, or context storage modules

### party_system.lua

**Responsibilities:**

* Manage party membership and leadership
* Handle party-level movement and travel
* Aggregate party stats (speed, visibility, strength)
* Interface with encounter, world, and combat systems

**Must not:**

* Control individual actor behavior
* Contain combat resolution logic

### quest_system.lua

**Responsibilities:**

* Track quest states (inactive, active, completed, failed)
* Manage unique quest instances derived from quest templates
* Evaluate objectives and conditions
* Generate procedural quest offers from data-defined templates
* Emit quest-related events
* Interface with dialogue and world systems

**Must not:**

* Render UI
* Contain hardcoded narrative or story logic

### Quest Runtime Flow (Template → Offer → Instance → Completion)

This project uses a two-layer quest model:

1.  **Quest Templates (Author-Time Data):**
    * Stored in `data/quests.lua`
    * Define reusable structure (title, objectives, rewards, optional onStart actions)
    * May be marked as procedural/repeatable for generator-based NPC quest handouts

2.  **Quest Instances (Runtime State):**
    * Created by `systems/quest_system.lua` when accepted
    * Assigned unique instance IDs (for example `hunt_dogs#12`)
    * Stored in `GameContext.data.activeQuests` keyed by instance ID
    * Keep giver identity (`giverId`, `giverName`) and runtime bindings (for example spawned party IDs)

#### End-to-End Runtime Sequence

1.  **Dialogue asks QuestSystem for quest context**
    * `dialogue_state.lua` queries quest status using quest template + speaker reference
    * The returned context includes state and matching active/completed instance IDs for that giver

2.  **Player accepts a quest**
    * Static flow: `accept_quest` can activate a template directly
    * Procedural flow: `accept_procedural_quest` requests an offer from a template pool, then accepts that offer

3.  **Quest instance is created**
    * QuestSystem clones template data into a runtime quest object
    * A unique instance ID is generated and stored in `activeQuests`
    * Objectives are copied as runtime objective objects
4.  **onStart actions bind runtime targets**
    * If the template has spawn actions (for example enemy party spawn), QuestSystem creates runtime entities with unique IDs
    * Objective targets are rebound from template target IDs to runtime IDs
    * This prevents one kill from completing multiple same-template quests

5.  **Gameplay events advance objectives**
    * Systems emit events (for example `party_killed`)
    * QuestSystem matches the event against objective runtime targets and increments only the correct instance

6.  **Turn-in objective gating**
    * If a quest includes `report_to_giver`, the quest enters a ready-to-turn-in dialogue state after non-report objectives are complete
    * Reward payout is deferred until player reports to the correct giver

7.  **Completion and archival**
    * Completed instance moves from `activeQuests` to `completedQuests`
    * Rewards are granted by QuestSystem
    * `quest_completed` event is emitted with instance and template identifiers

#### Why This Model Is Required

* Supports multiple simultaneous quests from the same template
* Supports procedural map/NPC generation where giver identity is dynamic
* Preserves strict data/logic/UI separation:
  * Data defines template content
  * Systems own runtime state transitions
  * UI/dialogue only emits intent and reads state

### time_system.lua

**Responsibilities:**

* Manage global game time (days, hours, minutes)
* Define time periods (e.g., "Highsun", "Stilldark")
* Calculate environmental effects like night tint
* Pause/Resume time flow

**Must not:**

* Render UI directly
* Store state locally (must use `GameContext`)

---

## 🧍 entities/ — Persistent Actors and Objects

**Purpose:** Define *what exists* independently of systems.

```
entities/
├─ entity.lua          -- Base entity schema
├─ actor.lua           -- Living, acting entities
├─ player.lua          -- Player-controlled actor
├─ npc.lua             -- AI- or dialogue-driven actor
├─ troop.lua           -- Mass-produced combat actor
├─ mount.lua           -- Actor-attached entity
├─ item.lua            -- Inventory and equipment entities
└─ party.lua           -- Persistent group of actors
```

### Entity Design Guidelines

* Entities have **identity and persistence**
* Entities store **data only** (stats, tags, references)
* Entities never contain gameplay logic
* Entities are manipulated exclusively by systems

### Actor Specialization

An **actor** represents any living being capable of action. Player characters, NPCs, and troops are all actors differentiated by **data, tags, control source, and non-combat attributes (e.g., Oratory, Tracking)**, not by unique logic.

### Party Structure

A **party** represents a **persistent group of actors** traveling and acting together on the world map.

Parties are entities because they:

* Have identity and long-term persistence
* Are referenced by quests, encounters, factions, and the world
* Maintain shared state over time

A party typically contains:

* A list of member actor IDs
* A leader (actor reference)
* Inventory and shared resources
* Movement speed modifiers
* Current world location
* Faction alignment
* Morale and supply tracking

Parties do **not**:

* Replace individual actors
* Contain combat or AI logic
* Act independently of systems

In battles, parties are **resolved into individual actors or formations** by combat and encounter systems.

---

## 🌍 world/ — Spatial Context & Locations

**Purpose:** Define spatial structure, travel, and world context.

```
world/
├─ world.lua
├─ map.lua
├─ camera.lua           -- Camera system for viewport management
├─ node.lua             -- Travel nodes / regions
├─ location.lua         -- Persistent world locations
├─ encounter.lua
└─ scene_loader.lua
```

### Camera System

Manages the viewport and player tracking:

* Follows the player with smooth lerp interpolation
* Constrains camera to map bounds
* Provides world-to-screen coordinate conversion
* Supports zoom and panning

### Map

Enhanced with visual rendering:

* Displays optional map background image loaded from config/options
* Renders settlements and their locations
* Displays parties and actors on the map
* Stores `worldGen` runtime payload (navigation grid, biome ownership, road paths)
* Provides walkability checks (`isWalkable`) and biome lookup (`getBiomeAt`)

### Settlements and Locations

Settlements are **persistent world-scoped objects**, not actors.

They:

* Have identity and long-term state
* Are referenced by quests, factions, and systems
* Define context rather than moment-to-moment action

They do **not**:

* Act independently
* Participate directly in combat or AI systems

Settlements belong to the **world layer**, not the entity layer.

---

## 📜 quests/ — Narrative Structure & Objectives

**Purpose:** Define quest structure without embedding gameplay logic.

```
quests/
├─ quest.lua           -- Quest data schema
├─ objective.lua       -- Objective definitions
├─ condition.lua       -- Reusable conditions
├─ reward.lua          -- Reward definitions
└─ quest_registry.lua
```

### Quest Design Rules

* Quests are **pure data plus conditions**
* No quest contains executable gameplay logic
* Systems interpret quest data and emit events

Quest data may include:

* Metadata (title, description, giver)
* Objectives (kill, deliver, talk, travel)
* Conditions (time, faction, reputation)
* Rewards (items, gold, reputation, unlocks)

---

## 🖥️ ui/ — Presentation Layer

**Purpose:** Display information and collect player intent.

```
ui/
├─ ui_manager.lua
├─ screens/
│  ├─ main_menu.lua
│  ├─ inventory_screen.lua
│  ├─ character_screen.lua
│  ├─ party_screen.lua
│  ├─ quest_log_screen.lua
│  └─ dialogue_screen.lua
│
└─ widgets/
   ├─ button.lua
   ├─ panel.lua
   ├─ list.lua
   └─ tooltip.lua
```

**Rules:**

* UI requests data from systems
* UI emits intent events
* UI never mutates game state directly

---

## 📦 data/ — Game Content Definitions

**Purpose:** Store all tunable and authorable content.

```
data/
├─ items.lua
├─ skills.lua
├─ troops.lua
├─ factions.lua
├─ encounters.lua
├─ equipment.lua
├─ quests.lua
├─ dialogue.lua
├─ progression.lua
└─ world_generation.lua
```

All content must be editable without modifying system logic.

---

## 🧰 utils/ — Shared Utilities

```
utils/
├─ math.lua
├─ table.lua
├─ string.lua
├─ timer.lua
└─ serializer.lua
```

---

## 🐞 debug/ — Development Tools

```
debug/
├─ console.lua
├─ inspector.lua
├─ profiler.lua
└─ draw.lua
```

Used only in development builds.

---

## 🔁 Dependency Direction (MANDATORY)

```
core
 ↓
game
 ↓
systems
 ↓
entities
 ↓
world / quests
 ↓
ui
```

Upward imports are strictly forbidden.

---

## 🤖 Instructions for AI Agents

When extending the project:

1. **Do not collapse or merge folders**
2. **Do not add gameplay logic to UI or entities**
3. **Prefer data definitions over code**
4. **Emit events instead of direct cross-system calls**
5. **Respect system and layer boundaries strictly**
6. **Update this document** whenever meaningful architectural changes, new systems, or data flows are introduced.

If a feature does not clearly belong to an existing system, **create a new system**.

---

## ✅ Outcome

This architecture is designed to support:

* Large-scale battles and parties
* Dynamic, data-driven quests
* Faction politics and reputation
* Emergent gameplay
* Long-term expansion and maintainability

This document is the **authoritative structural reference** for the project.
