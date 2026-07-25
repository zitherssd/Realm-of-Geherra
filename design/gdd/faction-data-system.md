# Faction Data System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: A Living, Persistent World, Meaningful Progression, Discovery-Driven Exploration

## Overview

The Faction Data System defines the game's factions — their identities, relationships, visual motifs, and initial state. Factions are the political backbone of the world: they own towns, assign NPC allegiance, determine quest availability, and track the player's reputation. For MVP, there are **3 active factions** (Pelasgians, Proto-Mycenaeans, Proto-Egyptians) with neutral starting relationships. A **4th hidden faction** (Hyperborean/Atlantean) exists in data but is not part of MVP gameplay — it serves as a discovery goal for post-MVP content. Factions do not have defined territory borders — towns are assigned to factions, and the wilderness between them is unaligned.

## Player Fantasy

The player navigates a world of three distinct cultures, each with its own visual identity, values, and agenda. Your reputation with each faction opens or closes doors — better prices from friendly traders, quests from allied elders, hostility from wronged lords. The hidden Atlantean faction whispers at the edges of the world: ancient, god-touched, unreachable for now.

## Detailed Design

### Core Rules

1. **Faction definition structure**: Each faction is defined as a record:
   ```lua
   {
       id = "pelasgian",
       name = "Pelasgians",
       epithet = "The Forest-Bronze People",
       description = "Descendants of Indo-European wanderers who settled the deep forests...",
       preferred_biome = "forest",
       color_primary = {100, 80, 30},     -- Deep Bronze
       color_secondary = {40, 95, 70},    -- Forest Shade
       color_accent = {175, 95, 45},      -- Living Copper
       glyph = "oak_leaf",
       name_pool_male = "pelasgian_male",
       name_pool_female = "pelasgian_female",
       initial_reputation = 0,             -- -100 to +100
       towns = {"town_pelasgian_1", "town_pelasgian_2"},
       hidden = false,
   }
   ```

2. **Faction relationships**: Stored as a matrix of relationship values (-100 to +100) between factions. For MVP, all factions start at 0 (neutral). Relationships can change based on quest outcomes and player actions, though this is primarily a player-to-faction system — faction-to-faction relationship changes are post-MVP.

3. **Reputation scale**:
   - `-100 to -51`: Hostile — NPCs refuse service, guards attack on sight
   - `-50 to -11`: Unfriendly — higher prices, fewer quests
   - `-10 to +10`: Neutral — baseline interactions
   - `+11 to +50`: Friendly — discounts, more quests, some NPCs recruitable
   - `+51 to +100`: Allied — best prices, exclusive quests, special recruitment

4. **Player reputation**: Tracked per faction. Modified by:
   - Completing quests for the faction (+10 to +30)
   - Killing faction members or attacking faction towns (-20 to -50)
   - Completing quests for rival factions (-5 to -15 for affected factions)
   - Trading at faction towns (+1 per significant transaction)

5. **Hidden faction**: The 4th faction (Atlanteans/Hyperboreans) exists in data but has:
   - No towns assigned
   - `hidden = true` flag
   - Reputation starts at 0 but cannot be changed through normal gameplay
   - No NPCs visible in MVP
   - Exclusive to post-MVP content (discovery, special quests, god-touched rewards)

### Faction Catalog (MVP)

| Attribute | Pelasgians | Proto-Mycenaeans | Proto-Egyptians | Atlanteans (hidden) |
|-----------|------------|-------------------|-----------------|---------------------|
| Epithet | The Forest-Bronze People | The Sea-Kings | The River People | The God-Touched |
| Preferred Biome | Forest | Hills / Coast | Desert | — (any or unique) |
| Primary Colour | Deep Bronze | Aegean Blue | Desert Gold | — |
| Glyph | Oak leaf / Spiral | Wave spiral / Octopus | Sun disc / Lotus | — |
| Towns (MVP) | Forest-Hold, Oak-Wall | Sea-Gate, Bronze-Hill | — (post-MVP) | None |
| Hidden | No | No | No | Yes |

*Note: Only Pelasgian and Mycenaean towns are active for MVP. Egyptian towns are post-MVP content. The faction data exists for all three main factions from the start to enable quest/reputation infrastructure.*

### States and Transitions

| State | Description |
|-------|-------------|
| **Defined** | Faction exists in data. Towns and NPCs are assigned. |
| **Active** | Faction is available for interaction. All main factions start Active. |
| **Hidden** | Faction exists but is not discoverable through normal gameplay (Atlanteans). |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S25 Faction Reputation | Consumed by | `faction.initial_reputation` sets starting standing |
| S08 Location/Town System | Consumed by | Locations have `faction` field referencing faction ID |
| S09 NPC Data System | Consumed by | NPCs have `faction` field for allegiance and name pool |
| S27 Economy/Trading | Consumed by | Faction reputation affects prices |
| S26 NPC Faction Assignment | Consumed by | Determines which NPCs belong to which faction |
| S30 Quest Instance System | Consumed by | Faction alignment affects quest availability |

## Formulas

No mathematical formulas. Faction data is declarative.

Reputation threshold checks use simple comparison:
```
if reputation >= threshold then
    -- unlock faction tier
end
```

## Edge Cases

- **If a faction has 0 towns**: The faction still exists (NPCs can be encountered as wanderers). Trade and quests are unavailable until a town is established or discovered.
- **If the player reaches -100 reputation with a faction**: All faction towns are hostile. Guards attack on sight. The player cannot trade or accept quests from that faction. Recovery requires a costly quest or item.
- **If the player reaches +100 reputation with a faction**: Maximum benefits unlocked. The faction lord may offer special rewards.
- **If the player somehow discovers the hidden faction before post-MVP**: The faction exists in data but has no NPCs or locations. Discovery attempts return "nothing found."
- **If faction data is missing a required field**: Log a warning and use defaults. The system should never crash from a missing faction field.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S08 Location/Town System | Hard | Factions reference town IDs for their settlements |
| S09 NPC Data System | Hard | NPCs reference faction IDs for allegiance |

**Depended on by:** S25 Faction Reputation, S08 Location/Town System, S09 NPC Data System, S26 NPC Faction Assignment, S27 Economy/Trading, S30 Quest Instance System.

## Tuning Knobs

- **Initial reputation per faction**: Integer -100 to +100. Default: 0 for all.
- **Reputation gain per quest**: Integer. Default: +15. Range: +5 to +50.
- **Reputation loss per faction member killed**: Integer. Default: -20. Range: -5 to -50.
- **Reputation tiers** (Hostile/Unfriendly/Neutral/Friendly/Allied): Integer threshold values. Configurable in data.
- **Hidden faction flag**: Boolean. Toggle to reveal the Atlanteans when post-MVP content is ready.

## Visual/Audio Requirements

- **Faction crests**: 64×64px pixel-art crests for each faction (oak leaf, wave spiral, sun disc). Used in UI, banners, and loading screens.
- **Faction colours**: Art bible §4.6 defines the colour palettes. Used for UI accents, town banners, and NPC clothing.
- **Faction glyphs**: 16×16px simplified glyphs for minimap and compact UI.
- **Audio**: No faction-specific audio for MVP. Future: faction-specific music themes.

## UI Requirements

- **Faction reputation display**: A screen showing all factions with reputation bars. Style: clay tablet with faction crests and reputation as gemstone-filled bars (empty = hostile, full = allied).
- **Faction notification**: When reputation changes, a brief notification appears: "Reputation with Pelasgians: +15 (Friendly)".
- **Hidden faction UI**: The Atlanteans do not appear in the reputation screen until discovered (post-MVP).

## Acceptance Criteria

- **GIVEN** the game starts, **WHEN** faction data is loaded, **THEN** 3 main factions (Pelasgians, Mycenaeans, Egyptians) and 1 hidden faction (Atlanteans) exist in data.
- **GIVEN** the game starts, **WHEN** faction reputation is queried, **THEN** each faction starts at the configured initial reputation (default: 0).
- **GIVEN** the player completes a quest for a faction, **WHEN** reputation is recalculated, **THEN** it increases by the configured amount.
- **GIVEN** the player attacks a faction member, **WHEN** reputation is recalculated, **THEN** it decreases by the configured amount.
- **GIVEN** the hidden Atlantean faction, **WHEN** queried during normal gameplay, **THEN** it has no accessible towns or NPCs.
- **GIVEN** a faction with -100 reputation, **WHEN** the player attempts to trade at their town, **THEN** trade is refused.

## Open Questions

- **Egyptian towns for MVP**: The concept mentions 2 factions for MVP (which I assumed are Pelasgians and Mycenaeans). Egyptian towns are post-MVP. Confirm this is correct, or should Egyptians have MVP towns too?
- **Faction-to-faction relationships**: For MVP, factions don't have dynamic relationships with each other (only player-to-faction). Should factions ever go to war with each other based on player actions, or is that post-MVP?
- **Atlantean discovery trigger**: When post-MVP content is ready, how should the player discover the hidden faction? Through a quest chain? Finding a unique POI? Random event?
