# Party Encounter System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: A Living, Persistent World, Preparation Over Reflexes, Discovery-Driven Exploration

## Overview

The Party Encounter System manages all mobile groups on the world map — bandits, traders, hunters, faction patrols, and wandering NPCs. Parties move in real-time alongside the player (like Mount & Blade) and are only visible when within spotting range. Not all parties are hostile: traders offer trade, hunters offer quests, and neutral parties may simply pass by. Encounters unfold on the world map — the player sees a party approaching or in the distance, decides whether to intercept or avoid, and if contact is made, the appropriate interaction screen or combat scene triggers. Chasing is a speed comparison on the world map.

## Player Fantasy

The world feels alive. A trader caravan crosses the plains ahead — do you intercept to trade, or let them pass? A bandit warband is visible on the horizon, moving parallel to your route — do you change course to avoid them, or speed up to catch them before nightfall? A band of hunters emerges from the forest — they might have work for you. Every dot on the horizon is a decision.

## Detailed Design

### Core Rules

1. **Party definition**: Each mobile party is a data-driven entity:
   ```lua
   {
       id = "party_bandit_01",
       type = "bandit",           -- bandit, trader, hunter, patrol, wandering_npc
       faction = nil,             -- or faction ID for faction-aligned parties
       name = "Bandit Warband",   -- display name
       position = {x, y},
       target_position = {x, y},  -- parties have patrol routes or destinations
       speed = 60.0,              -- world map movement speed
       spot_range = 100.0,        -- how far away they can be spotted
       
       -- Interaction
       hostility = "hostile",     -- hostile, neutral, friendly
       interaction = "combat",    -- combat, trade, dialogue, quest
       
       -- Composition
       units = {"bandit1", "bandit2", "bandit3"},
       leader_npc = nil,          -- if led by a named NPC
       inventory = {},            -- for trader parties
   }
   ```

2. **Party types and interactions**:
   | Type | Hostility | Interaction | Behaviour |
   |------|-----------|-------------|-----------|
   | Bandit | Hostile | Combat | Patrols roads, chases player on sight |
   | Faction patrol | Depends on rep | Combat or dialogue | Patrols faction territory, reacts to reputation |
   | Trader | Neutral | Trade | Moves between towns, can be intercepted |
   | Hunter | Friendly | Quest/Dialogue | Roams wilderness, offers beast hunt quests |
   | Wandering NPC | Neutral | Dialogue | Random encounters, rumours, information |

3. **Spotting range**: A party becomes visible when the player comes within `spot_range` distance. Spotting range is modified by:
   - Time period: night reduces spotting range (Stilldark = 0.4×, Gloamhour = 0.6×)
   - Biome visibility: forests reduce spotting range, hills increase it
   - Party size: larger parties are easier to spot
   - The player's Tracking skill (future): increases spotting range

4. **Real-time movement**: Parties move in real-time on the world map when the player is moving. Parties have:
   - A `target_position` or patrol route
   - A `speed` value (compared against the player's speed for chase/evade)
   - Parties move independently when within a certain radius of the player (simulated when far away)

5. **Chasing mechanics**: When the player moves toward a visible party:
   - If `player_speed > party_speed`: the player gains distance each frame
   - If `player_speed <= party_speed`: the player maintains distance or falls behind
   - Contact is made when distance < `engagement_range` (10.0 units)
   - Parties may also chase the player if hostile and the player is within their aggro range

6. **Engagement**: When a party is engaged:
   - Hostile party → transitions to Tactical Combat scene
   - Trader party → opens trade interface (same system as location vendors)
   - Hunter / Wandering NPC party → opens the **Dialogue System (S31)** — the exact same conversation screen used when talking to NPCs in towns and locations. An NPC encountered on the road uses the same dialogue pool, portrait, and interaction options as if you'd found them at a settlement.
   - The player can choose to pass (not engage) when within range of a neutral/friendly party

7. **Party spawning and despawning**: Parties are spawned from encounter tables per biome (see S06 Biome System). They are despawned when:
   - Engaged and resolved (combat ends, trade completes, etc.)
   - They reach their destination (traders)
   - They move too far from the player (beyond simulation range)

### States and Transitions

| State | Description |
|-------|-------------|
| **Inactive** | Party exists in encounter pool but is not on the map (too far from player). |
| **Active** | Party is on the map, moving. Not yet spotted by the player. |
| **Spotted** | Party is within the player's spotting range. Visible on screen. |
| **Engaging** | Player has chosen to intercept or party has aggroed. Distance decreasing. |
| **Engaged** | Contact made. Transition to combat, trade, or dialogue scene. |
| **Resolved** | Encounter complete. Party despawns or transitions to resolved state. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S15 World Map Navigation | Provides | Player position, speed, and movement direction |
| S06 Biome System | Consumes | Encounter tables per biome determine which parties spawn |
| S07 Time System | Consumes | Night modifier for spot range and encounter tables |
| S10 Character Stats | Consumes | Party speed affected by Navigation skill, party size, equipment |
| S18 Tactical Combat | Provides | Hostile engagements transition to combat scene |
| S27 Economy/Trading | Provides | Trader parties offer trade interface |
| S31 Dialogue System | Provides | Hunter and NPC parties offer dialogue |
| S30 Quest Instance | Consumes | Hunter parties may offer quests from quest templates |

## Formulas

**Spot range:**

`effective_spot_range = party.spot_range * time_visibility_modifier * biome_visibility_modifier * size_modifier`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Party spot range | `spot_range` | float | 50–200 | Base visibility of the party |
| Time modifier | `time_mod` | float | 0.4–1.0 | Night reduction (0.4 Stilldark, 0.6 Gloamhour, 1.0 day) |
| Biome modifier | `biome_mod` | float | 0.4–1.3 | From S06 Biome System |
| Size modifier | `size_mod` | float | 0.8–1.5 | Smaller parties harder to spot, larger easier |

**Chase distance change:**

`distance_change = (player_speed - party_speed) * dt`

If `distance_change > 0`: player is gaining. If `< 0`: party is pulling away.

**Engagement:** When `distance < 10.0`, engagement triggers.

## Edge Cases

- **If the player spots two parties simultaneously**: Both are shown. The player can choose which to engage or pass both.
- **If a hostile party and a friendly party are near each other**: They may fight each other (future feature). For MVP, they ignore each other.
- **If the player is chasing a party and a second party intercepts from the side**: Both parties are within engagement range. The player chooses which to engage.
- **If the player approaches a trader party but has no gold**: Trade can still be opened, but no purchases can be made. The trader still offers dialogue.
- **If a party's speed is zero (stationary)**: The party is camped or waiting. The player can always catch them.
- **If the player's speed changes during a chase (biome transition, road)**: The chase dynamic updates immediately. The player may gain or lose ground.
- **If a party moves off the edge of the map**: The party despawns. A new party of the same type may spawn later.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S15 World Map Navigation | Hard | Player position, speed, movement direction |
| S06 Biome System | Hard | Encounter tables, biome visibility modifiers |
| S07 Time System | Hard | Night modifiers for spot range and encounters |
| S10 Character Stats | Soft | Party speed affected by skills and composition |
| S18 Tactical Combat | Soft | Hostile engagement → combat scene |
| S27 Economy/Trading | Soft | Trader engagement → trade interface |
| S31 Dialogue System | Soft | NPC engagement → dialogue |
| S30 Quest Instance | Soft | Hunter engagement → quest offer |

**Depended on by:** (consuming system — parties are events that trigger other systems)

## Tuning Knobs

- **Party spot range per type**: Float. Configurable per party type (50–200).
- **Party speed per type**: Float. Configurable per party type (30–150).
- **Engagement range**: Float. Default: 10.0. Distance at which contact is made.
- **Party spawn frequency**: Float. Per-biome configurable via encounter tables.
- **Chase speed threshold**: Player must be faster than the party to catch them.
- **Party simulation range**: Float. Default: 500.0. How far parties exist from the player before despawning.

## Visual/Audio Requirements

- **Party sprites**: Each party type has a map sprite (16×16px icon showing composition — bandits = skull, traders = coin, hunters = spear, patrol = faction crest).
- **Party label**: Party name shown below the sprite when spotted (e.g., "Bandit Warband").
- **Engagement UI**: Brief flash or ripple effect when a party is engaged.
- **Audio**: Ambient party sounds when nearby (distant chatter, horse hooves, caravan creaks).

## UI Requirements

- **Party tooltip**: Hovering over a spotted party shows its name, size, and type.
- **Engagement prompt**: When close to a party, a contextual prompt appears: "[F] Engage [R] Pass". For hostile parties, only engage is offered.
- **Mini-map dots**: Spotted parties appear as coloured dots on the minimap (red = hostile, green = friendly, yellow = neutral).
- **Chase indicator**: When chasing or being chased, a distance indicator or closing-speed bar appears briefly.

## Acceptance Criteria

- **GIVEN** the player is on the world map, **WHEN** a party moves within spot range, **THEN** the party becomes visible on the screen and minimap.
- **GIVEN** it is Stilldark, **WHEN** a party's spot range is calculated, **THEN** it is 40% of the base range.
- **GIVEN** the player moves toward a spotted party that is slower, **WHEN** the distance decreases to engagement range, **THEN** the engagement prompt appears.
- **GIVEN** the player engages a bandit party, **WHEN** contact is made, **THEN** the scene transitions to Tactical Combat.
- **GIVEN** the player engages a trader party, **WHEN** contact is made, **THEN** the trade interface opens.
- **GIVEN** the player engages a hunter party, **WHEN** contact is made, **THEN** dialogue opens with a quest offer.
- **GIVEN** the player moves away from a hostile party, **WHEN** the distance exceeds their aggro range, **THEN** the party stops chasing.
- **GIVEN** the player passes a neutral party, **WHEN** within engagement range, **THEN** no encounter triggers and the party continues its route.

## Open Questions

- **Party persistence**: If the player saves and loads, should parties persist at their last position, or be respawned? Proposed: persist — saves include party state. Respawning only happens when a party reaches its destination or despawns.
- **Faction patrol behaviour**: Should faction patrols attack the player on sight if reputation is low enough (Hostile tier)? Proposed: yes — at Hostile reputation, faction patrols act like bandits. Deferred to S25 Faction Reputation design.
