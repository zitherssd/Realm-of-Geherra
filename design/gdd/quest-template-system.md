# Quest Template System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Discovery-Driven Exploration, A Living, Persistent World, Meaningful Progression

## Overview

The Quest Template System defines reusable quest structures. Each quest template specifies objectives, rewards, conditions, and NPC roles that can offer it. The system is designed to be **extensible** — it supports many quest types (hunt, delivery, clear location, destroy party, kill creature, find hideout, discover ruins, bring item) even if only a subset are implemented for MVP. Quest templates are data-driven: adding a new quest type means adding a new template definition, not writing new code.

## Player Fantasy

Quests give purpose to travel. A hunter asks you to track a dangerous beast. An elder needs a message delivered to a neighbouring town. A lord wants the bandit camp near his lands cleared. Each quest is a story that takes you somewhere new, rewards you with gold and reputation, and occasionally grants an aptitude point for a job well done.

## Detailed Design

### Core Rules

1. **Quest template structure**:
   ```lua
   {
       id = "quest_hunt_troll",
       name = "Hunt the Troll",
       type = "hunt",               -- hunt, delivery, clear, destroy_party, kill_creature,
                                    -- find_hideout, discover_ruins, bring_item
       description = "A troll has been terrorising the village...",
       giver_roles = {"elder", "hunter", "lord"},
       faction = "pelasgian",       -- which faction offers this (nil for neutral)
       
       -- Objectives
       objectives = {
           { type = "kill", target = "troll", count = 1, location = "poi_troll_lair" },
       },
       
       -- Rewards
       rewards = {
           gold = { min = 200, max = 400 },
           reputation = { faction = "pelasgian", amount = 15 },
           aptitude = { aptitude = "command", chance = 0.3 },  -- 30% chance
           items = {"troll_hide"},  -- guaranteed item rewards
       },
       
       -- Requirements
       min_level = 0,
       min_reputation = { faction = "pelasgian", value = 0 },  -- Neutral+
       prerequisite_quest = nil,     -- quest chain
       expires_after_days = nil,     -- nil = never expires
   }
   ```

2. **Quest types** (framework supports all; MVP implements hunt, delivery, clear_location):
   - `hunt` — Kill a specific creature or creature type
   - `delivery` — Deliver an item to a target NPC or location
   - `clear_location` — Clear all enemies from a specific POI
   - `destroy_party` — Destroy a specific party on the world map
   - `kill_creature` — Kill a named unique creature
   - `find_hideout` — Locate and report a hidden location (doesn't require attack)
   - `discover_ruins` — Discover a specific POI (progressive discovery)
   - `bring_item` — Bring a specific item to the quest giver

3. **Objectives**: Each quest has one or more objectives. Each objective has:
   - `type`: The action required (kill, deliver, discover, clear, etc.)
   - `target`: What to interact with (creature ID, item ID, location ID, party type)
   - `count`: How many (for kill/collect objectives)
   - `location`: Where (optional — for location-specific objectives)
   - `dialogue`: Text shown when the objective updates ("You killed the troll!")

4. **Rewards**: Each quest defines:
   - `gold`: Range of gold rewarded
   - `reputation`: Array of faction reputation changes
   - `aptitude`: Optional aptitude point reward (with chance)
   - `items`: Array of guaranteed item rewards
   - `choice`: Optional — player chooses one reward from a set

5. **Availability conditions**: A quest template is available if:
   - The NPC's role matches `giver_roles`
   - The player's faction reputation meets `min_reputation`
   - The player's level meets `min_level` (if S10 is implemented)
   - No prerequisite quest is incomplete or unmet
   - The quest hasn't expired (if `expires_after_days` is set)

6. **Quest pools per NPC role**: Each NPC role has a pool of quest templates they can offer:
   ```lua
   -- data/npc_quest_pools.lua
   return {
       elder = {"quest_hunt_troll", "quest_delivery_urgent", "quest_find_hideout"},
       hunter = {"quest_hunt_troll", "quest_kill_beast"},
       lord = {"quest_clear_bandits", "quest_destroy_party"},
       trader = {"quest_delivery_urgent", "quest_bring_item"},
   }
   ```

### Built-in Quest Types

| Type | MVP? | Objective | Example |
|------|------|-----------|---------|
| hunt | ✅ | Kill X of creature Y | "Hunt 3 wolves" |
| delivery | ✅ | Deliver item to target | "Bring this scroll to Sea-Gate" |
| clear_location | ✅ | Clear all enemies at POI | "Clear the bandits from Broken Tower" |
| destroy_party | ❌ | Destroy a world map party | "Destroy the orc warband" |
| kill_creature | ❌ | Kill a named unique creature | "Slay the Ancient Wyrm" |
| find_hideout | ❌ | Locate a hidden location | "Find the bandit hideout in the forest" |
| discover_ruins | ❌ | Discover a POI | "Find the lost Temple of Ages" |
| bring_item | ❌ | Bring a specific item to NPC | "Bring me a troll hide" |

### States and Transitions

| State | Description |
|-------|-------------|
| **Available** | The quest can be offered by eligible NPCs. |
| **Offered** | An NPC has offered the quest. Player hasn't accepted or declined. |
| **Completed** | The quest has been completed by the player. Can be offered again? (No — once completed, it's locked.) |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S30 Quest Instance | Consumed by | Templates are instantiated into active quests |
| S31 Dialogue System | Consumed by | NPCs check available templates for quest offers |
| S25 Faction Reputation | Consumed by | Min reputation requirements for quest availability |
| S09 NPC Data System | Consumed by | NPC roles map to quest pools |
| S08 Location System | Consumed by | Location-based objectives reference POIs |
| S11 Aptitudes System | Consumed by | Optional aptitude point rewards |
| S12 Inventory System | Consumed by | Item rewards and bring_item objectives |

## Formulas

No mathematical formulas. Quest data is declarative.

Gold reward is randomised within range:
`gold_reward = math.random(quest.rewards.gold.min, quest.rewards.gold.max)`

Aptitude chance check:
`grants_aptitude = math.random() < quest.rewards.aptitude.chance`

## Edge Cases

- **If a quest's target location doesn't exist (removed from world gen)**: The quest is marked as unavailable. Logged for designer review.
- **If a quest expires while active**: The quest instance (S30) marks it as failed. The player receives a notification.
- **If a quest has no valid giver (all matching NPCs are dead/recruited)**: The quest becomes unavailable until a new matching NPC appears.
- **If a quest requires an item that doesn't exist in data**: The quest fails to load. Logged as a data error.
- **If multiple quests share the same objective (e.g., two quests to kill the same troll)**: Both quests progress simultaneously when the troll is killed.
- **If the player completes a quest objective before accepting it**: The objective progress is tracked. If already complete when accepted, the objective is marked as done immediately.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S09 NPC Data System | Hard | NPC roles for quest pool assignment |
| S25 Faction Reputation | Hard | Min reputation requirements |
| S08 Location System | Soft | Location references in objectives |
| S12 Inventory System | Soft | Item rewards and bring_item objectives |
| S11 Aptitudes System | Soft | Aptitude point rewards |

**Depended on by:** S30 Quest Instance System, S31 Dialogue System.

## Tuning Knobs

- **Gold reward range**: Per-quest configurable (min/max).
- **Reputation reward amount**: Per-quest configurable.
- **Aptitude chance**: Per-quest configurable (0.0–1.0). Default: 0.3 for special quests.
- **Expiry time**: Per-quest configurable in game days. Nil = never expires.
- **Quest pool per NPC role**: Data-driven in `data/npc_quest_pools.lua`.

## Visual/Audio Requirements

- **Quest offer notification**: When an NPC has a quest available, a small quest icon (!) appears next to their name in the interaction menu.
- **Quest accepted notification**: Brief banner: "Quest Accepted: Hunt the Troll" with a scroll-unfurl sound.
- **Quest update notification**: When an objective progresses or completes: "Troll slain! Return to the elder for your reward."

## UI Requirements

- **Quest offer screen**: When selecting a quest from an NPC, shows: quest name, description, objectives, and rewards. Accept/Decline buttons.
- **Quest log screen**: List of active quests with progress bars per objective. Completed quests are marked. Filter by active/completed.
- **Quest marker**: When a quest objective has a location, a search area or marker appears on the map. Not a hard marker — a vague area if the location is undiscovered, an exact marker if discovered.

## Acceptance Criteria

- **GIVEN** a quest template with `giver_roles = {"elder"}`, **WHEN** an elder NPC's quest pool is queried, **THEN** the quest appears in available offers.
- **GIVEN** a quest with `min_reputation = {faction="pelasgian", value=10}`, **WHEN** the player has reputation below 10, **THEN** the quest is not offered.
- **GIVEN** a quest with a gold reward range, **WHEN** the quest is completed, **THEN** gold within the range is awarded.
- **GIVEN** a hunt quest targeting "troll", **WHEN** a troll is killed, **THEN** objective progress is tracked.
- **GIVEN** a quest with an aptitude chance of 0.3, **WHEN** completed, **THEN** there is a 30% chance the aptitude point is granted.
- **GIVEN** a quest with a prerequisite quest that is incomplete, **WHEN** availability is checked, **THEN** the quest is not available.
- **GIVEN** a new quest type is added to the data, **WHEN** the system loads, **THEN** it is usable without code changes.

## Open Questions

- **Quest chains**: Should quests be chainable (completing quest A unlocks quest B from the same NPC)? Proposed: yes — the `prerequisite_quest` field supports this. A chain of 2–3 quests from the same NPC creates a mini-story arc.
- **Repeatable quests**: Should some quests be repeatable (e.g., "Hunt 3 wolves" can be done multiple times)? Proposed: not for MVP. Every quest is one-time.
