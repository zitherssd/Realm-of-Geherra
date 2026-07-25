# Faction Reputation System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: A Living, Persistent World, Meaningful Progression

## Overview

The Faction Reputation System tracks the player's standing with each of the game's factions. Reputation is a numeric value that changes based on the player's actions — completing quests, trading, attacking faction members, and making faction-affecting choices. Reputation tiers unlock or restrict access to services, NPCs, quests, and recruitment opportunities.

## Player Fantasy

Your reputation precedes you. Walk into a Pelasgian village as a friend and traders offer you their best goods, elders share quests, and hunters offer training. Walk in as an enemy and guards draw weapons. Every choice matters — helping one faction may harm your standing with another. The faction reputation system makes the world react to who you are and what you've done.

## Detailed Design

### Core Rules

1. **Reputation scale**: -100 to +100 per faction.
   - -100 to -51: **Hostile** — NPCs refuse service, guards attack on sight
   - -50 to -11: **Unfriendly** — higher prices (+20%), fewer quests offered
   - -10 to +10: **Neutral** — baseline interactions (starting point)
   - +11 to +50: **Friendly** — discounts (-10%), more quests, some NPCs recruitable
   - +51 to +100: **Allied** — best discounts (-20%), exclusive quests, special recruitment

2. **Starting reputation**: All factions start at 0 (Neutral). Exception: the hidden Atlantean faction starts at 0 but its reputation cannot change through normal gameplay.

3. **Reputation changes**:
   | Action | Change | Notes |
   |--------|--------|-------|
   | Complete a faction quest | +10 to +30 | Based on quest importance |
   | Complete a quest for a rival faction | -5 to -15 | Affects the opposing faction |
   | Kill a faction member | -20 | Per member killed |
   | Attack a faction town | -50 | Major offence |
   | Trade at a faction town | +1 | Per significant transaction |
   | Donate to a faction | +1 per 100 gold | Up to +10 per faction |
   | Return a faction item | +15 | Quest-item returns |

4. **Reputation decay**: Reputation does not decay over time for MVP. Once earned or lost, it stays until changed by another action.

5. **Cross-faction effects**: Some actions affect multiple factions. Completing a quest for the Pelasgians that harms Mycenaean interests may reduce Mycenaean reputation. These cross-effects are defined per quest in the quest template data.

6. **Reputation gates**: Certain content is locked behind reputation thresholds:
   - **-50 (Unfriendly)**: Can no longer accept new quests from this faction
   - **-100 (Hostile)**: Faction guards attack on sight. Cannot enter faction towns
   - **+30 (Friendly)**: Some NPCs become recruitable
   - **+60 (Allied)**: Exclusive quests and items become available

### States and Transitions

| Tier | Range | Effects |
|------|-------|---------|
| Hostile | -100 to -51 | Guards attack. Cannot trade. All NPCs hostile. |
| Unfriendly | -50 to -11 | Higher prices. Fewer quests. Some NPCs refuse dialogue. |
| Neutral | -10 to +10 | Baseline. Standard prices. Standard quests. |
| Friendly | +11 to +50 | Discounts. More quests. Some NPCs recruitable. |
| Allied | +51 to +100 | Best prices. Exclusive quests. Special NPCs recruitable. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S24 Faction Data | Consumes | Faction definitions with initial reputation |
| S26 NPC Faction Assignment | Consumes | Determines which NPCs are affected by reputation |
| S27 Economy/Trading | Provides | Reputation tier affects price multipliers |
| S30 Quest Instance | Consumed by | Quest availability gated by reputation thresholds |
| S28 NPC Recruitment | Consumed by | Some NPCs require reputation threshold to recruit |
| S31 Dialogue System | Consumed by | NPC dialogue options change with reputation tier |
| S16 Party Encounter | Consumed by | Faction patrols react based on reputation |

## Formulas

**Reputation tier determination:**

`tier = reputation_to_tier(current_reputation)`

**Price multiplier from reputation:**

`price_multiplier = 1.0 + (neutral_price - reputation_bonus)`

Where `reputation_bonus = clamp(rep / 100, -0.2, 0.2)`

At Allied (+100): `1.0 - 0.2 = 0.8` (20% discount)
At Hostile (-100): `1.0 + 0.2 = 1.2` (20% markup — and they may refuse service entirely)

## Edge Cases

- **If the player reaches Hostile with all factions**: The game becomes very difficult — no trading, no quests, constant combat. The player may need to find neutral NPCs or locations to recover.
- **If the player is Hostile with a faction and enters their town**: Guards attack immediately. The player must flee or fight.
- **If the player's reputation changes during an NPC conversation**: The current interaction is not interrupted. Reputation effects apply on the next interaction.
- **If a faction has no reputation-affecting actions available**: The player cannot change their reputation with that faction until they find a relevant quest or NPC.
- **If the player reaches Allied with a faction**: A special notification and possible invitation to the faction leader.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S24 Faction Data System | Hard | Faction IDs and initial reputation values |
| S26 NPC Faction Assignment | Hard | NPC faction affiliation for reputation checks |

**Depended on by:** S27 Economy/Trading, S30 Quest Instance, S28 NPC Recruitment, S31 Dialogue System, S16 Party Encounter.

## Tuning Knobs

- **Reputation range**: Integer -100 to +100.
- **Quest reputation gain**: Per-quest configurable. Default: +15 per quest.
- **Faction member kill penalty**: Integer. Default: -20.
- **Town attack penalty**: Integer. Default: -50.
- **Trade reputation gain**: Integer. Default: +1 per 100 gold spent.
- **Rival faction penalty**: Integer. Default: -10 per quest for rival.
- **Reputation tier thresholds**: Configurable integers for each tier boundary.

## Visual/Audio Requirements

- **Reputation notification**: A brief banner when reputation changes: "Reputation with Pelasgians: +15 (Friendly)" with a coloured flash (green for gain, red for loss).
- **Faction reputation screen**: Clay tablet with faction crests and reputation as gemstone-filled bars.

## UI Requirements

- **Reputation display**: Accessible from the main menu or pause screen. Shows all discovered factions with reputation bars and current tier label.
- **Reputation change indicator**: After any reputation change, a brief popup shows the change amount and current tier.
- **Warning when approaching hostile**: When about to take an action that would drop reputation below -50, a warning prompt appears: "This action will make the Pelasgians hostile. Continue?"

## Acceptance Criteria

- **GIVEN** the game starts, **WHEN** reputation is queried, **THEN** all factions are at 0 (Neutral).
- **GIVEN** the player completes a faction quest, **WHEN** the quest is turned in, **THEN** reputation increases by the configured amount.
- **GIVEN** the player kills a faction member, **WHEN** the kill is registered, **THEN** reputation decreases by 20.
- **GIVEN** the player has Friendly reputation with a faction, **WHEN** trading, **THEN** prices include the Friendly discount.
- **GIVEN** the player has Hostile reputation with a faction, **WHEN** entering their town, **THEN** guards attack.
- **GIVEN** the player has Friendly reputation, **WHEN** a recruitable NPC's conditions include that tier, **THEN** the NPC becomes available for recruitment.
- **GIVEN** the player takes an action that would drop reputation below -50, **WHEN** the action is confirmed, **THEN** a warning prompt is shown first.

## Open Questions

- **Reputation recovery**: Should there be quests or items that allow reputation recovery from Hostile? Proposed: yes — a "peace offering" quest or rare item that grants +50 reputation with a faction, allowing recovery from Hostile to Unfriendly.
- **Hidden faction discovery**: When the Atlantean faction is eventually discovered, what reputation should it start at? Proposed: 0 (Neutral), with unique ways to change it (god-touched items, ancient pacts).
