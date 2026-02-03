# INTERACTION_SYSTEM.md

This document defines the **Interaction System**, which governs how the player (and AI parties) interact with **locations** and **other parties** on the world map.

Interactions are the primary bridge between **world simulation** and **gameplay outcomes** such as battles, trading, recruitment, resting, and quests.

---

## Design Goals

* Encounters do not imply combat by default
* Interactions are **data-driven and contextual**
* Locations and parties act as **interaction providers**
* Quests, trade, recruitment, and combat all use the same interaction pipeline
* Easy to express rules like:

  * “Towns of type X recruit units A, B, C”
  * “Coastal villages sell fish”

---

## High-Level Flow

1. **Encounter Triggered**

   * Party enters interaction radius of a location or another party
2. **Context Built**

   * Information about both sides and the world state is gathered
3. **Interactions Generated**

   * Providers contribute possible interactions
4. **Menu Presented**

   * Available interactions shown to the player
5. **Interaction Resolved**

   * Effects applied or scene transitions occur
6. **Return to World Scene** (unless transitioning to battle)

---

## Core Concepts

### Encounter

An encounter represents a temporary paused state of the world where interactions are resolved.

An encounter contains:

* Initiating party
* Target (party or location)
* World context (time, region, biome)

Encounters do not contain logic — they only aggregate context.

---

### Interaction

An interaction is a **single selectable option** presented to the player.

Examples:

* Fight
* Trade
* Recruit
* Rest
* Accept Quest

An interaction defines:

* When it is available
* What it costs
* What it produces

---

## Interaction Structure (Conceptual)

```yaml
id: string
label: string
description: string

conditions:
  - condition_id

costs:
  - cost_id

effects:
  - effect_id

transition:
  scene: optional
```

Interactions are pure data. Resolution is handled by systems.

---

## Interaction Providers

Interaction Providers are systems or data objects that **contribute interactions** during an encounter.

Providers include:

* Location definitions
* Party definitions
* Quest system
* Global rules

Each provider may:

* Add interactions
* Modify existing interactions
* Disable interactions

---

## Location-Based Interactions

Locations define which interaction modules they expose.

Examples:

* Town → trade, recruit, quests
* Village → trade, rest
* Ruins → explore, fight

Locations do not implement logic; they declare **capabilities**.

---

## Party-Based Interactions

Parties contribute interactions based on:

* Faction
* Relationship
* Inventory
* Current goals

Examples:

* Caravan → trade
* Bandits → fight, bribe
* Patrol → inspect, fight

---

## Conditions

Conditions determine whether an interaction is available.

Examples:

* Player reputation ≥ threshold
* Location allows resting
* Party has required item
* Quest is active

Conditions are evaluated at menu generation time.

---

## Costs

Costs are applied when an interaction is selected.

Examples:

* Gold
* Time
* Items
* Morale

Costs may block interaction if unmet.

---

## Effects

Effects are applied when an interaction resolves.

Examples:

* Start battle
* Add/remove items
* Recruit units
* Advance time
* Start or update quest

Effects may:

* Modify world state
* Transition scenes

---

## Scene Transitions

Some interactions cause a scene change.

Examples:

* Fight → Battle Scene
* Enter dungeon → Exploration Scene (future)

Transitions are declared, not executed by interactions.

---

## Quest Integration

Quests integrate naturally as interaction providers.

* Quests add interactions like:

  * Accept quest
  * Turn in quest
* Quest progress updates are effects
* No quest-specific UI flow is required

---

## AI Usage

AI-controlled parties use the same interaction system.

* AI evaluates available interactions
* Chooses based on goals and utility
* Ensures symmetry between player and AI

---

## System Responsibilities

### encounter_system.lua

* Detects encounters
* Freezes world time
* Builds encounter context

### interaction_system.lua

* Queries providers
* Evaluates conditions
* Builds interaction menu
* Resolves selections

---

## Canonical Implementation

* Encounter detection: /systems/encounter_system.lua
* Interaction assembly + resolution: /systems/interaction_system.lua
* World scene integration: /scenes/world_scene.lua

---

## Design Constraints

* No hard-coded interaction logic per location
* No branching UI logic per encounter type
* Interactions must be inspectable and serializable

---

## Next Documents

* LOCATION_SCHEMA.md
* QUEST_SCHEMA.md
* ENCOUNTER_SYSTEM.md
