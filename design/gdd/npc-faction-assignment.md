# NPC Faction Assignment

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: A Living, Persistent World

## Overview

The NPC Faction Assignment system handles the relationship between NPCs and factions. Since each NPC already stores a `faction` field in its data definition, this system is primarily a validation and query layer: it ensures every NPC references a valid faction, provides lookup functions (all NPCs of faction X, all NPCs at location Y with faction Z), and handles neutral or unaffiliated NPCs. It also manages faction-wide NPC behaviour triggers (e.g., if the player's reputation with a faction drops to Hostile, guards of that faction become aggressive).

## Player Fantasy

Invisible infrastructure. The player experiences this system through faction consistency: Pelasgian NPCs look and sound Pelasgian, Egyptian NPCs look and sound Egyptian. Breaking the illusion (a Pelasgian NPC with an Egyptian name) would be immediately noticed.

## Detailed Design

### Core Rules

1. **Assignment source**: Each NPC's `faction` field is the single source of truth. No separate assignment table is needed — the NPC Data System owns the field, this system validates and queries it.

2. **Validation on load**: When the game starts, all NPCs are checked:
   - The NPC's `faction` field must reference a valid faction ID from S24 Faction Data.
   - If invalid: log a warning and default to neutral.
   - If missing: log a warning and default to neutral.

3. **Neutral NPCs**: NPCs with `faction = nil` or `faction = "neutral"` are unaffiliated. They are not affected by faction reputation. They may appear anywhere and offer basic services regardless of the player's faction standing.

4. **Faction-wide behaviour triggers**: When the player's reputation crosses thresholds, faction NPCs respond:
   - Hostile: All NPCs of that faction refuse dialogue. Guards attack on sight.
   - Friendly/Allied: NPCs may offer discounts or additional dialogue options.

5. **Query functions**:
   - `get_npcs_by_faction(faction_id)` → list of NPCs
   - `get_npcs_by_faction_and_location(faction_id, location_id)` → list
   - `get_faction_for_npc(npc_id)` → faction_id or nil
   - `get_npcs_by_role_and_faction(role, faction_id)` → list

### States and Transitions

| State | Description |
|-------|-------------|
| **Validated** | All NPC faction references verified at load time. |
| **Active** | Queries available. Behaviour triggers active. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S24 Faction Data System | Consumes | Validates that faction IDs exist in faction definitions |
| S09 NPC Data System | Consumes | Reads `npc.faction` field for assignment |
| S25 Faction Reputation | Consumes | Reputation thresholds trigger behaviour changes |
| S08 Location/Town System | Provides | `get_npcs_by_faction_and_location()` for populating town scenes |

## Formulas

No formulas. Pure data validation and query logic.

## Edge Cases

- **If an NPC's faction field references a deleted faction ID**: System defaults to neutral and logs a warning. The NPC functions as unaffiliated.
- **If all NPCs of a faction are killed or recruited**: The faction still exists (data level), but has no active NPCs. New NPCs may appear in the future (respawning).
- **If a neutral NPC is encountered**: No reputation checks apply. The NPC always offers default dialogue and services.
- **If the player's reputation changes mid-conversation**: The current interaction is not interrupted. Reputation effects apply on the next interaction.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S24 Faction Data System | Hard | Valid faction ID list |
| S09 NPC Data System | Hard | NPC definitions with `faction` field |

**Depended on by:** S25 Faction Reputation, S08 Location/Town System.

## Tuning Knobs

- **Default faction for missing field**: String. Default: "neutral".
- **Hostile behaviour trigger**: Integer. Default: -50. The reputation threshold at which faction NPCs become hostile.

## Visual/Audio Requirements

- None. This system is purely data validation and queries.

## UI Requirements

- None. Effects are visible through NPC behaviour changes (guards attacking, dialogue refusal).

## Acceptance Criteria

- **GIVEN** all NPCs are loaded, **WHEN** faction validation runs, **THEN** every NPC with a `faction` field references a valid faction ID.
- **GIVEN** an NPC with no `faction` field, **WHEN** faction lookup is queried, **THEN** it returns "neutral".
- **GIVEN** a faction with Hostile reputation, **WHEN** a player interacts with an NPC of that faction, **THEN** guards attack and traders refuse service.
- **GIVEN** a Pelasgian faction ID, **WHEN** `get_npcs_by_faction("pelasgian")` is called, **THEN** all Pelasgian NPCs are returned.
- **GIVEN** a neutral NPC, **WHEN** the player has any reputation level, **THEN** the NPC always offers default interactions.

## Open Questions

- **Faction-specific NPC spawns**: Should certain NPC roles only appear in certain factions? E.g., "lord" NPCs are Mycenaean only, "druid" NPCs are Pelasgian only. This is already handled by manually assigning NPCs to factions, but could be formalised. Proposed: handled by manual assignment — no additional system needed.
- **NPC respawning**: If a faction's NPCs are killed, should new ones appear after some time? Deferred from MVP.
