# WORLD_MAP_SCENE.md

This document describes the **World Map Scene** for *Realms of Geherra*, incorporating the interaction system and location schema.

The World Map Scene is the overworld layer where parties roam, locations exist, and encounters are resolved via the interaction system.

---

## Purpose

The World Map Scene allows the player to:

* Move their party freely across a large continuous world
* Observe AI-controlled parties roaming and pursuing goals
* Interact with locations and other parties via the **Interaction System**
* Trigger encounters that may lead to battles, trade, recruitment, or quests

It acts as the **primary hub** connecting battles, quests, and world simulation.

---

## World Map Characteristics

* Continuous 2D space (not tile-based)
* Large procedural size (e.g., 2048×2048 or larger)
* Procedurally generated terrain with regions (forest, plains, mountains, beach)

  * Regions affect movement speed, healing rates, and strategic planning
* Handcrafted towns coexist with procedural locations (ruins, bandit camps)
* Surrounded or bounded by water or impassable terrain

---

## Core Entities

### Parties

* Groups of units led by a commander
* Player-controlled or AI-controlled
* Attributes:

  * Position and movement speed
  * Unit roster
  * Inventory and gold
  * Faction or alignment
* Capabilities:

  * Move across the map
  * Enter locations
  * Engage in encounters with other parties or locations

### Locations

* Handcrafted or procedurally generated
* May be permanent (towns) or temporary/destructible (bandit camps, ruins)
* Attributes and schema defined in `LOCATION_SCHEMA.md`
* Provide **interaction modules** exposed to the player or AI

Possible interactions include:

* Trade
* Recruit units
* Rest
* Accept quests
* Fight or bribe (for hostile or neutral parties)
* Trigger battles

Interactions are **type-driven** (e.g., coastal village, town, ruin) and immediately update based on faction ownership.

---

## Encounters

Encounters occur when:

* A party approaches another party
* A party enters a location's interaction radius

Encounter flow:

1. World time pauses
2. Encounter context is built (initiating party, target, location, world state)
3. **Interaction System** generates available options based on providers (locations, parties, quests)
4. Player or AI selects an interaction
5. Effects are applied, including possible scene transitions (e.g., battle scene)
6. Return to World Scene unless transitioning to a new scene

Battle stage is determined by the location type and applied to the battle grid (forest, ruin, village, town).

---

## Scene Responsibilities

* Render terrain, parties, and locations
* Update party movement continuously
* Detect encounters and generate interaction menus
* Advance world time and apply region modifiers (movement speed, healing)
* Handle scene transitions based on interactions

Excludes:

* Combat resolution (handled in Battle Scene)
* Inventory management
* Quest logic beyond triggering interactions

---

## Camera

* Follows the player party smoothly
* Supports panning and zooming
* Clamps to world bounds to prevent viewing outside the map

---

## Interaction Integration

* Uses **Interaction System** to query providers and generate dynamic menus
* Location type + ownership immediately determines available interactions
* Supports trade, recruitment, quests, resting, combat, and one-off mercenary hiring
* Quests integrate as additional interaction providers

---

## Time Progression

* Advances continuously while moving on the world map
* Pauses during interaction menus or encounters
* Certain actions (resting, travel) advance time more rapidly

---

## Future Extensions

* Fog of war
* Roads or terrain features affecting speed
* AI patrol routes and world events
* Day/night cycle and weather effects
* Dynamic quest markers and events

---

## Design Goals

* Maintain **clear separation** between world exploration, combat, and interactions
* Fully **data-driven** locations and parties
* **AI-friendly** architecture for both player and AI actions
* Easily extensible system for future content additions
