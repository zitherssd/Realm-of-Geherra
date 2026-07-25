# NPC Recruitment System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Meaningful Progression, A Living, Persistent World

## Overview

The Recruitment System handles two tiers of party members, inspired by Mount & Blade's companion + troop model:

**Tier 1 — Named NPCs (Companions)**: Unique characters with portraits, aptitudes, full equipment slots, and dialogue. Recruited through conditions (gold, reputation, quests, items). Each is one-of-a-kind — lose them and they're gone.

**Tier 2 — Generic Troops**: Unnamed soldiers recruited in bulk from villages, taverns, or captured after battles. They have basic stats, limited equipment (weapon + armour only), no aptitudes, no dialogue, and are interchangeable. Recruited for a fixed gold cost per unit.

Both tiers share the party's space (limited by Command aptitude) and fight alongside each other in combat, but companions are far more valuable and customisable.

## Player Fantasy

Building your warband is the heart of progression. Your core companions are characters with names and stories — the barbarian you paid to join, the tracker you helped, the assassin who respects your strength. Around them, you build a force of generic troops — recruits from villages, captured bandits pressed into service. The companions are your officers; the troops are your army.

## Detailed Design

### Core Rules

**Tier 1 — Named NPC Recruitment (existing design):**
Recruitment conditions are defined per-NPC in the NPC Data System — ranging from simple gold payments to complex requirements (reputation thresholds, specific items, completed quests). When an NPC joins, they leave their location and become a permanent party member with full equipment slots, aptitudes, and dialogue access. See recruitment condition types below.

**Tier 2 — Generic Troop Recruitment:**
Generic troops are simpler:
- Recruited from villages (pay gold per recruit) or captured after battle
- No aptitudes, no dialogue, no portrait
- Limited equipment: weapon and armour only (head + chest — no accessories)
- Interchangeable — if one dies, recruit another
- Troops have a "type" (recruit, warrior, archer, cavalry) that determines their base stats and equipment
- Cost per troop: 50–200 gold depending on type and settlement prosperity
- Troop types can be upgraded (recruit → warrior → veteran) through experience or training (post-MVP)

**Party composition**: The party has a single combined size limit based on Command aptitude:
- Command 0: 1 (captain only)
- Command 1: 5 (captain + 4)
- Command 2: 10 (captain + 9)
- Command 3: 20 (captain + 19)
- Command 4: 40 (captain + 39)
Companions and generic troops share this limit. A party of 3 companions + 7 troops = 10 total, at Command 2.

1. **Recruitment condition types**:
   ```lua
   -- Gold only: easy recruitment
   recruitment = { type = "gold", amount = 500 }
   
   -- Reputation + gold
   recruitment = { type = "reputation", faction = "pelasgian", min_standing = 30, gold = 200 }
   
   -- Item + reputation
   recruitment = { type = "item_and_reputation", item = "death_stone", faction = "neutral", min_standing = 20 }
   
   -- Quest-gated: complete a specific quest first
   recruitment = { type = "quest", quest_template = "free_the_tracker" }
   
   -- Multiple conditions
   recruitment = {
       type = "multi",
       conditions = {
           { type = "gold", amount = 1000 },
           { type = "reputation", faction = "mycenaean", min_standing = 50 },
           { type = "aptitude", aptitude = "command", min_level = 2 },
       }
   }
   ```

2. **Recruitment flow**:
   - Player speaks to a recruitable NPC (has `recruitable = true` in NPC data)
   - Dialogue shows [Recruit] option
   - Selecting it checks conditions:
     - If all met: confirmation prompt → NPC joins party → NPC removed from location → added to party roster
     - If conditions not met: NPC tells the player what's needed ("I'll only join you if you have 500 gold" or "Prove yourself to my people first — earn our trust, then we'll talk.")

3. **Party roster**: Recruited NPCs are added to the party. Each has:
   - Equipment slots (inherits their existing gear)
   - Aptitudes (as defined in their NPC data)
   - Combat capabilities (to be designed with S18 Combat)
   - Carry capacity contribution (to S12 Inventory)

4. **NPC state after recruitment**: The NPC is removed from their home location's NPC list. They cannot be interacted with at that location anymore. If the player dismisses them from the party (future feature), they return to their home location.

5. **NPC death in combat**: If a recruited NPC dies in combat, they are permanently lost. Their equipment can be recovered from their body.

6. **Party size limit**: The party (companions + troops combined) is limited by the captain's **Command aptitude**:
   - Command 0: 1 (captain only, no companions or troops)
   - Command 1: 5 (captain + 4)
   - Command 2: 10 (captain + 9)
   - Command 3: 20 (captain + 19)
   - Command 4: 40 (captain + 39)

7. **Companion vs. troop distinction in combat**: Both appear on the battlefield but:
   - Companions have full equipment, aptitudes, and can use combat Skills
   - Generic troops have basic AI, limited equipment, and no Skills
   - Troops are generated as a group (5 archers = one unit on the battlefield that breaks into individuals during combat)

### Recruitment Archetypes (MVP)

| Archetype | Recruitment | Role |
|-----------|------------|------|
| Barbarian | Gold (500) | Front-line melee |
| Tracker | Reputation (Friendly, 200 gold) | Scout, ranged |
| Assassin | Complex — item + reputation | Stealth, back-line |
| Warrior | Gold (800) | Heavy melee |
| Hunter | Quest (hunt a beast) | Ranged, wilderness |
| Initiate | Aptitude (Divination 1+) | Magic support |

### States and Transitions

| State | Description |
|-------|-------------|
| **Available** | NPC is at their location and recruitable. Conditions can be checked. |
| **Conditions Not Met** | Player has spoken to NPC but lacks requirements. NPC indicates what's needed. |
| **Recruited** | NPC has joined the party. Removed from location. |
| **Dead** | NPC died in combat. Permanently lost. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S09 NPC Data System | Consumes | NPC `recruitable` flag and `recruitment` conditions |
| S08 Location System | Consumed by | NPC removed from location on recruitment |
| S12 Inventory System | Consumed by | Gold checks, item checks for conditions |
| S25 Faction Reputation | Consumed by | Reputation threshold checks |
| S11 Aptitudes System | Consumed by | Aptitude threshold checks |
| S30 Quest Instance | Consumed by | Quest completion checks |
| S31 Dialogue System | Consumed by | [Recruit] option and condition display |

## Formulas

No mathematical formulas. Recruitment is conditional logic.

Condition check example:
```
if recruitment.type == "gold":
    can_recruit = party.gold >= recruitment.amount
    if not: npc_says = "Come back when you have " .. recruitment.amount .. " gold."

if recruitment.type == "reputation":
    can_recruit = faction_reputation(recruitment.faction) >= recruitment.min_standing
    if not: npc_says = "I don't trust you enough yet. Earn my people's respect."
```

## Edge Cases

- **If the player meets multiple recruitment conditions for the same NPC**: All conditions are checked. If all met, recruitment proceeds.
- **If the player recruits an NPC but the party is full (Command limit)**: Recruitment is refused. "Your company is already too large. Come back when you have room."
- **If a recruitable NPC is killed before recruitment**: Can't recruit a dead NPC. The slot is permanently lost.
- **If the player recruits an NPC and then their reputation drops below the threshold**: The NPC doesn't leave (recruitment is permanent). But they may comment on the reputation change.
- **If the player has the required item for item-based recruitment**: The item is consumed on recruitment.
- **If a quest-gated NPC's quest is failed**: The NPC becomes permanently unrecruitable. The player must reload or start a new game.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S09 NPC Data System | Hard | NPC `recruitable` flag and `recruitment` conditions |
| S12 Inventory System | Hard | Gold and item checks |
| S25 Faction Reputation | Hard | Reputation threshold checks |
| S08 Location System | Hard | NPC removal from location on recruitment |
| S11 Aptitudes System | Soft | Aptitude threshold checks |
| S30 Quest Instance | Soft | Quest completion checks |
| S31 Dialogue System | Consumed by | [Recruit] dialogue option |

**Depended on by:** (consuming system — recruitment is triggered via dialogue)

## Tuning Knobs

- **Command aptitude party size limits**: Per-level configurable. Default: 1, 5, 10, 20, 40.
- **Recruitment gold costs (companions)**: Per-NPC configurable. Range: 0–5000.
- **Recruitment reputation thresholds (companions)**: Per-NPC configurable. Range: 0–100.
- **Generic troop cost**: Per-type configurable. Range: 50–200 gold per troop.
- **Troop types**: Data-driven. Each type has base stats and equipment template.
- **Max recruitable NPCs per playthrough**: Not capped — limited by Command aptitude.

## Visual/Audio Requirements

- **Recruitment notification (companion)**: Banner: "[Name] has joined your party!" with a fanfare chime and companion portrait.
- **Recruitment notification (troops)**: Subtle: "10 Recruits joined your party." No portrait.
- **Recruitment confirmation**: Companion shows portrait and bio. Troops show type and count.
- **Party roster screen**: Shows companions (with portraits and names) and troop counts per type.

## UI Requirements

- **Recruit option for companions**: Shows primary condition (e.g., "Recruit (500 gold)" or "Recruit — requires Friendly reputation").
- **Troop recruitment**: When in a village, a "Recruit troops" option shows available types and costs. Select quantity and confirm.
- **Party management screen**: Lists companions individually, troops as grouped counts. Shows current total vs. Command limit.
- **Troop upgrade UI**: Future — shows troop type and upgrade path.

## Acceptance Criteria

- **GIVEN** a recruitable NPC with a gold cost, **WHEN** the player has sufficient gold, **THEN** recruitment succeeds and gold is deducted.
- **GIVEN** a recruitable NPC with a gold cost, **WHEN** the player has insufficient gold, **THEN** recruitment is refused with an explanation.
- **GIVEN** a recruitable NPC with a reputation threshold, **WHEN** the player meets the threshold, **THEN** recruitment is allowed.
- **GIVEN** the party is at the Command limit, **WHEN** the player attempts recruitment, **THEN** it is refused with a "party full" message.
- **GIVEN** the player recruits an NPC, **WHEN** recruitment completes, **THEN** the NPC is removed from their location and added to the party roster.
- **GIVEN** a recruited NPC dies in combat, **WHEN** their HP reaches 0, **THEN** they are permanently lost.

## Open Questions

- **NPC dismissal**: Should the player be able to dismiss a recruited NPC back to their home location? Proposed: deferred from MVP. For now, recruited NPCs stay until they die.
- **NPC party roles in combat**: Each recruitable NPC has a combat role (melee, ranged, support, magic). These feed into the Tactical Combat System (S18). To be defined when combat is designed.
