# PROJECT.md

## Project Title (Working)

**Realms of Geherra**
*Mount & Blade–Style Strategy RPG*

---

## 1. Project Vision

This project is a **single-player strategy RPG** built in **Lua using Love2D**.

The core fantasy:

* A living world where **parties roam freely** on a large procedural map
* The player directly controls a single party
* Encounters on the world map lead to **contextual interactions** or **grid-based tactical battles**

Primary inspirations:

* **Mount & Blade** – overworld simulation, roaming parties, factions, momentum
* **Dominions** – deterministic, systemic, grid-based battles

Design priorities:

* Systems depth over presentation
* Determinism and replayability
* Clear, inspectable rules
* AI-friendly, data-driven architecture

---

## 2. High-Level Game Loop

1. **Title Scene**
2. **World Scene**

   * Player moves their party freely on the world map
   * AI parties roam, trade, raid, patrol, and pursue goals
   * Player encounters parties and locations
3. **Interaction / Encounter Resolution**

   * Contextual menus (fight, trade, rest, recruit, quests, etc.)
   * May transition to Battle Scene or remain in World Scene
4. **Battle Scene** (when combat is chosen or forced)

   * Grid-based tactical combat between two parties
5. **Return to World Scene**

This loop repeats until campaign end conditions are met.

---

## 3. Core Design Principles (Hard Rules)

### 3.1 Separation of Concerns

* **Scenes** orchestrate flow and input, but contain no game logic
* **Systems** operate on data only
* **Core domain objects** (units, parties, items, actions) are renderer-agnostic

### 3.2 Data-Driven Design

* Units, items, actions, locations, and quests are defined as **data tables**
* Behavior emerges from systems acting on data
* Avoid deep inheritance trees and hard-coded branching

### 3.3 Determinism First

* World generation is seed-based
* Battles are reproducible from inputs
* Randomness is explicit, seeded, and controlled

### 3.4 AI-Assisted Development Compatibility

* Every major system is documented in Markdown
* Modules are small, explicit, and self-contained
* No hidden side effects or magic state

---

## 4. Core Domain Concepts

These concepts are stable and should not be redefined casually.

### Units

* Base combat entities
* Exist inside parties on the world map
* Deployed individually during battles

### Commanders

* Special units
* Provide leadership bonuses and abilities
* Strongly define party identity

### Parties

* Collections of units led by a commander
* Exist on the world map
* Have position, speed, morale, inventory, and gold

### Locations

* Fixed entities on the world map
* Examples: towns, villages, forts, ruins, camps
* Provide **interaction menus**, not battle maps by default

### Items

* Equipment, consumables, and trade goods

### Actions

* Battle-only operations
* Attacks, spells, skills, and abilities
* Granted by units or items

---

## 5. Scenes

### Title Scene

* New game
* Load game
* Exit

### World Scene

* Free movement of parties
* AI world simulation
* Encounter detection
* Entry point for interactions

### Battle Scene

* Grid-based tactical combat
* Deterministic, tick-based resolution

Scenes must never own or mutate core game data directly.

---

## 6. World Map Design

* Continuous coordinate space (not tile-locked)
* Large procedural size (e.g. 2048×2048 or larger)
* Surrounded or bounded by water or impassable terrain

World data layers:

* Elevation
* Biome / terrain type
* Movement cost

World systems sample these fields at arbitrary positions.

---

## 7. Interaction & Encounter System (Critical)

### 7.1 Encounters

Encounters occur when:

* A party approaches another party
* A party enters a location’s interaction radius

An encounter:

* Pauses world time
* Produces a **set of available interactions**
* Does not assume combat by default

Examples:

* Party vs party → fight, trade, intimidate, ignore
* Party vs town → rest, trade, recruit, quests

---

### 7.2 Interaction Model

Interactions are **data-defined options** generated from context.

An interaction:

* Has a label ("Trade", "Recruit", "Fight")
* Has availability conditions
* Has an effect or scene transition

The system determines:

* Which interactions are offered
* In what context
* At what cost

No interaction logic is hard-coded per location or party.

---

### 7.3 Locations as Interaction Providers

Locations define:

* Their **type** (town, village, fort, ruin, etc.)
* Which interaction modules they provide

Examples:

* A coastal village may provide:

  * Trade (fish, salt)
  * Rest
* A fortified town may provide:

  * Recruit (heavy infantry)
  * Trade (weapons, armor)
  * Quests

This allows statements like:

> “Towns of type X offer units A, B, C for recruitment.”

---

### 7.4 Parties as Interaction Providers

Parties may offer interactions based on:

* Faction
* Relationship
* Inventory

Examples:

* Caravan → trade
* Bandits → fight or bribe
* Patrol → inspection or conflict

---

## 8. Quest System Integration

Quests are **world-state modifiers**, not scripted scenes.

A quest:

* Is offered via an interaction
* Stores objectives and conditions
* Modifies the world when progressed or completed

Examples:

* Deliver item to location
* Defeat a roaming party
* Recruit units for a faction

Quests plug into the **same interaction system**:

* Offered by locations or parties
* Updated via encounters
* Resolved without special-case logic

---

## 9. Battle Design

* Battles occur on grid maps
* Grid generated from world context
* Terrain affects movement, combat, and visibility

Battle flow:

* Deployment
* Tick-based action resolution
* Victory or retreat

---

## 10. AI Behavior Scope

AI parties may:

* Roam
* Patrol
* Trade
* Raid
* Chase enemies

AI behavior is **goal-driven**, not scripted per scene.

---

## 11. Save / Load Philosophy

* Save minimal state
* Prefer regeneration from seed + deltas
* World seed is a first-class value

---

## 12. Folder Structure (Authoritative)

/game
main.lua

/scenes
title_scene.lua
world_scene.lua
battle_scene.lua

/core
unit.lua
commander.lua
party.lua
location.lua
item.lua
action.lua

/systems
world_generator.lua
world_simulation.lua
movement_system.lua
encounter_system.lua
interaction_system.lua
battle_system.lua
ai_system.lua

/battle
battle_map.lua
grid.lua
battle_rules.lua

/data
units.lua
items.lua
actions.lua
locations.lua
quests.lua

/util
noise.lua
math.lua
state_machine.lua

/docs
PROJECT.md

---

## 13. Non-Goals (Important)

* No multiplayer
* No real-time reflex combat
* No cinematic-heavy presentation

The focus is **systems interacting cleanly**.

---

## 14. How AI Agents Should Use This File

When generating code or documentation:

* Do not invent new core concepts
* Respect separation of concerns
* Generate one module at a time
* Always include a matching `.md` file

This file is the **source of truth** for the project.
