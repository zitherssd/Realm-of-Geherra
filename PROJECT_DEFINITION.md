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
├─ ecs/
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

`ecs/` holds the Concord ECS layer (components/assemblages/systems/world) that
represents actors, parties, locations, quests, and battle units as entities.
See the `ecs/` section below.

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
│  └─ battle_context.lua     -- Battle-specific blackboard (units/casualties/
│                                camera/vfx/projectiles; battle units
│                                themselves are Concord entities, see ecs/)
│
├─ game_context.lua          -- Shared blackboard
└─ game_initializer.lua      -- New game setup and initialization
```

### game_context.lua

Acts as a **shared blackboard** containing session-level bookkeeping (not
game entities themselves, which live in the Concord campaign world):

* Reference to the player entity / player party entity
* Current world / map
* NPC relations, dialogue flags, global flags
* Instance-id counters (quest instances/offers)
* Difficulty, playtime

Actors, parties, locations, and quests are **not** stored here — they are
Concord entities in `EcsWorld.campaign` (see `ecs/`). This is the *only*
globally shared mutable session state in the game.

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
│  ├─ battle_unit_system.lua -- Plain helpers on battle-unit entities (canAct, snapToWorld)
│  └─ render_system.lua      -- Battle visualization
│  (decision_system.lua/execution_system.lua moved to ecs/systems/, see below)
│
├─ movement_system.lua
├─ party_system.lua
├─ player_system.lua      -- Player-only resources (e.g. favor)
├─ location_system.lua    -- Plain helpers on location entities
├─ quest_objective_system.lua -- Plain advance()/isCompleted() on objective data
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
├─ quest_availability_system.lua -- NPC-owned procedural offer lifecycle and gating
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
    * Created by `systems/quest_system.lua` when accepted, as Concord entities
      (tag `"quest"`) in `EcsWorld.campaign` via `ecs/assemblages/quest.lua`
    * Assigned unique instance IDs (for example `hunt_dogs#12`)
    * Active and completed quests are the **same** entity pool, distinguished
      only by the flat `quest.state` field ("active"/"completed"/"failed") --
      looked up via `QuestSystem.findQuestByInstanceId`/`getActiveQuests`/
      `getCompletedQuests` (an ad hoc `EcsWorld.campaign:query({"quest"})`)
    * Keep giver identity (`giverId`, `giverName`) and runtime bindings (for example spawned party IDs)

#### End-to-End Runtime Sequence

1.  **Dialogue asks QuestSystem for quest context**
    * `dialogue_state.lua` queries quest status using quest template + speaker reference
    * The returned context includes state and matching active/completed instance IDs for that giver

2.  **Player accepts a quest**
    * Static flow: `accept_quest` can activate a template directly
    * Procedural flow: `accept_procedural_quest` requests an offer from a template pool, then accepts that offer

3.  **Quest instance is created**
    * QuestSystem clones template data into a new quest entity (`quest.state = "active"`)
    * A unique instance ID is generated and stored on the entity
    * Objectives are copied as plain runtime objective tables
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
    * Completed instance's `quest.state` is set to `"completed"` (the entity
      stays in the same Concord pool; nothing physically "moves")
    * Rewards are granted by QuestSystem
    * `quest_completed` event is emitted with instance and template identifiers

#### Why This Model Is Required

* Supports multiple simultaneous quests from the same template
* Supports procedural map/NPC generation where giver identity is dynamic
* Preserves strict data/logic/UI separation:
  * Data defines template content
  * Systems own runtime state transitions
  * UI/dialogue only emits intent and reads state

### NPC Quest Offer Availability (Location Entry Lifecycle)

Procedural quest offers are owned by NPC runtime state, not UI state:

1.  **Offer Profile Data (`data/npc_quest_pools.lua`)**
    * Defines per-role quest generation rules (`rollChance`, `offerDurationDays`, `cooldownDays`, `questPool`)
    * Role key is typically `npc.troopType` (for example `elder`, `trader`)

2.  **Offer Runtime State (stored on NPC)**
    * Each NPC may contain `npc.questOfferState`
    * Tracks status and timing (`none`, `available`, `accepted`, `cooldown`)
    * Stores active linkage (`questInstanceId`) while accepted

3.  **Availability System (`systems/quest_availability_system.lua`)**
    * Rolls offers on location entry
    * Expires stale offers by day
    * Locks NPC while an accepted quest is active
    * Applies post-completion cooldown before NPC can roll again

4.  **Location Entry Trigger (`game/states/location_state.lua`)**
    * Calls availability refresh when entering a location
    * Does not re-roll offers on state resume from dialogue

5.  **Dialogue Gating (`game/states/dialogue_state.lua`)**
    * Dialogue filters quest options based on NPC quest context
    * Quest options are hidden unless pool/offer/turn-in requirements are satisfied
    * Dialogue sends intent (`accept_available_quest`, `turn_in_available_quest`) to availability/quest systems

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

## 🧩 ecs/ — Concord ECS Layer

**Purpose:** Represent actors, parties, locations, quests, and battle units as
Concord entities. This is the primary "what exists" layer for the game (it
supersedes most of the old `entities/` OOP classes).

```
ecs/
├─ world.lua               -- EcsWorld.campaign (persistent) + EcsWorld.battle
│                             (ephemeral, created/destroyed per battle)
├─ components/
│  ├─ init.lua             -- requires every component file below
│  ├─ unit.lua, player.lua, npc.lua   -- actor tag components
│  ├─ party.lua, location.lua, quest.lua, battle_unit.lua
│
├─ assemblages/            -- entity-creation factories (Concord "assemble" fns)
│  ├─ unit.lua             -- Unit.create(world, troopType) -- player/NPC/troop
│  ├─ party.lua, location.lua, quest.lua, battle_unit.lua
│
└─ systems/                -- genuine Concord.system({pool=...}) pool-iterating
   │                          systems only (battle world, per-frame)
   ├─ decision_system.lua  -- AI & player intent processing
   └─ execution_system.lua -- Action resolution & state updates
```

### Design Conventions

* Component data is kept **flat** on the entity (e.g. `entity.stats.health`,
  `entity.hp`, `entity.x`) rather than nested per-component, matching the
  data shape of the old Actor/Party classes. Concord components named
  `"player"`, `"npc"`, `"unit"`, `"party"`, `"location"`, `"quest"`,
  `"battleUnit"` are used mainly as **tag/marker** components for identity and
  pool queries (`world:query({"quest"})`).
* Genuine `Concord.system()` classes belong in `ecs/systems/` and are reserved
  for real per-frame pool-iterating logic — currently only the battle world's
  `decision_system.lua`/`execution_system.lua`.
* Call/event-driven logic that reads or mutates entities (quest advancement,
  location population, dialogue, recruitment, etc.) stays in `systems/*.lua`
  as **plain function modules** (e.g. `PartySystem.getTreasury(party)`), not
  Concord systems — this matches the pre-existing repo convention of systems
  as plain logic modules and avoids forcing every interaction through a pool.
* Items stay plain data (catalog id + instance overrides), embedded in
  inventory/equipment fields — not entities, since nothing queries loose
  items independently today.
* Two Concord worlds: the persistent `EcsWorld.campaign` (parties, actors,
  locations, quests) and an ephemeral `EcsWorld.battle` created by
  `EcsWorld.startBattle()` and torn down by `EcsWorld.endBattle()` per fight.
  Battle-world unit entities hold a direct reference to their campaign actor
  entity, so HP/death changes are visible without an explicit sync step.

---

## 🧍 entities/ — Legacy Non-ECS Objects

**Purpose:** A small set of plain-data classes that predate the Concord ECS
rewrite and were kept as-is because nothing about them needed to change.

```
entities/
├─ entity.lua          -- Base class for item.lua/mount.lua below
├─ item.lua            -- Loose item instances (loot, quest rewards)
└─ mount.lua           -- Actor-attached entity
```

Actors (player/NPC/troop), parties, locations, and quests are **not** here —
they are Concord entities defined in `ecs/` (see below). The old
`actor.lua`/`player.lua`/`npc.lua`/`troop.lua`/`party.lua` OOP classes were
deleted once their Concord replacements were wired in.

### Actor Specialization

An **actor** (Concord entity tagged `"unit"`, plus `"player"` or `"npc"`)
represents any living being capable of action. Player characters, NPCs, and
troops are all actors differentiated by **data, tags, control source, and
non-combat attributes (e.g., Oratory, Tracking)**, not by unique logic.
See `ecs/assemblages/{unit,player,npc}.lua`.

### Party Structure

A **party** (Concord entity tagged `"party"`, see `ecs/assemblages/party.lua`
+ `systems/party_system.lua`) represents a **persistent group of actors**
traveling and acting together on the world map.

Parties are entities because they:

* Have identity and long-term persistence
* Are referenced by quests, encounters, factions, and the world
* Maintain shared state over time

A party typically contains:

* A list of member actor entities
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
└─ scene_loader.lua
```

Locations are Concord entities (`ecs/assemblages/location.lua` +
`systems/location_system.lua`), created at runtime by
`systems/location_population_system.lua` and also registered on `map.locations`
for spatial lookup. `world/node.lua` and `world/encounter.lua` were deleted as
confirmed dead code (never required anywhere).

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

### Locations

Locations are **persistent world-scoped objects**, not actors.

They:

* Have identity and long-term state (Concord entity, tag `"location"`)
* Are referenced by quests, factions, and systems
* Define context rather than moment-to-moment action

They do **not**:

* Act independently
* Participate directly in combat or AI systems

Locations belong to the **ecs/ + world layer**, not the legacy entity layer.
(`world/settlement.lua` was a near-duplicate, confirmed dead code, and was
deleted alongside `node.lua`/`encounter.lua`.)

---

## 📜 quests/ — Narrative Structure & Objectives

**Purpose:** Define quest objective data without embedding gameplay logic.

```
quests/
└─ objective.lua       -- Plain objective-table factory (id, type, current/required)
```

Quest instances themselves are Concord entities (tag `"quest"`), assembled by
`ecs/assemblages/quest.lua` and managed by `systems/quest_system.lua` +
`systems/quest_objective_system.lua` — see `ecs/` and the Quest Runtime Flow
section above. `quest.lua`, `condition.lua`, `reward.lua`, and
`quest_registry.lua` (the old OOP quest/condition/reward classes) were deleted
once quests became Concord entities.

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
├─ npc_quest_pools.lua
├─ location_npc_spawn_rules.lua
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
ecs
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
