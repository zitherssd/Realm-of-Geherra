# Dialogue System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: A Living, Persistent World, Discovery-Driven Exploration

## Overview

The Dialogue System handles all NPC interactions — conversations in towns, with parties on the world map, and with recruitable characters. It uses a Mount & Blade-style context-sensitive menu: when speaking to an NPC, the player sees a set of options based on the NPC's role, the player's reputation, active quests, and the NPC's services. Options appear and disappear based on context — a trader shows "Show me your wares", a quest giver with an active quest shows "I've completed your task", a trainer shows "I'd like to train". No branching dialogue trees for MVP — the system is menu-based, not choice-based.

## Player Fantasy

Every NPC interaction feels natural and purposeful. You approach an elder and see: "Greetings, wanderer." Your options: [Talk] [Any quests?] [Train Oratory] [Leave]. The options change based on who you are and what you've done. A blacksmith you've never met offers [Trade] and [Leave]. A blacksmith you saved from bandits offers [Trade] [Repair] [Talk about the bandits] [Train Engineering] [Leave].

## Detailed Design

### Core Rules

1. **Dialogue screen structure**: When interacting with an NPC, the screen shows:
   - NPC portrait (left) with name and role
   - NPC greeting text (top) — contextual, changes with reputation
   - Player action options (bottom) — context-sensitive list of buttons

2. **Greeting text**: The NPC's first line depends on:
   - Reputation tier: Hostile → "Get out of my sight." Neutral → "Greetings, traveller." Friendly → "Well met, friend!" Allied → "An honour to see you!"
   - First meeting vs. returning: First → "You're new around here." Returning → "Good to see you again."
   - Quest status: Has active quest for player → "Any news on that task?"

3. **Interaction options** — dynamically generated based on NPC role and context:

   **Always available:**
   - [Leave] — Ends the conversation

   **Role-based (appear based on NPC role):**
   - [Trade] — For NPCs with `services = {"trade"}` (opens trade screen)
   - [Repair] — For blacksmiths (opens repair interface)
   - [Train [aptitude]] — For NPCs with training capability (opens training interface)
   - [Recruit] — For recruitable NPCs (shows conditions if not met)
   - [Show me your wares] — Same as Trade, flavour variant for traders

   **Quest-based (appear based on quest status):**
   - [I have a quest for you] — NPC has available quests to offer
   - [I've completed your task] — Player has a quest ready to turn in
   - [Any news on that job?] — Player has an active quest from this NPC

   **Context-based:**
   - [Talk] — Generic conversation, shows NPC lore/rumour text
   - [Tell me about [location/faction]] — Appears if NPC has relevant knowledge
   - [I need to rest] — At tavern keepers (opens rest/room interface)

4. **Option generation**: Each time dialogue opens, the system:
   - Checks NPC's `services` field → adds role-based options
   - Checks active quest instances for this NPC → adds quest options
   - Checks available quest templates for this NPC role → adds quest offer option
   - Checks NPC's training capabilities → adds training option
   - Checks reputation tier → adjusts greeting and available options

5. **Dialogue text pools**: NPCs reference a `dialogue_pool` (set in NPC Data) that determines their speaking style. Each pool has:
   - Array of greeting variations
   - Array of "talk" responses (lore, rumours, personal stories)
   - Array of role-specific phrases (traders talk about prices, hunters talk about beasts)
   - Pools: `elders`, `traders`, `blacksmiths`, `hunters`, `barbarians`, `necromancers`, etc.

6. **No branching dialogue trees**: For MVP, selecting an option triggers an immediate action (open trade, open training, show text, accept quest) rather than leading to further dialogue choices. The conversation ends after the action or the player can select another option.

### States and Transitions

| State | Description |
|-------|-------------|
| **Closed** | No dialogue active. Player on world map or in location. |
| **Greeting** | Dialogue opened. NPC greeting shown. Options displayed. |
| **Interaction** | Player selected an action. Sub-screen open (trade, training, quest offer). |
| **Reading** | Player selected [Talk]. Text displayed. "Continue" button returns to Greeting. |
| **Closed (action)** | After an action completes (trade closed, quest accepted), dialogue returns to Greeting. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S09 NPC Data System | Consumes | NPC dialogue_pool, services, role, name, portrait |
| S25 Faction Reputation | Consumes | Reputation tier → greeting text and available options |
| S30 Quest Instances | Consumes | Active/ready/available quests for this NPC |
| S29 Quest Templates | Consumes | Available quest templates for this NPC's role |
| S11 Aptitudes System | Consumes | Training availability per NPC |
| S27 Economy/Trading | Consumed by | [Trade] option opens trade screen |
| S13 Equipment System | Consumed by | [Repair] option opens repair interface |
| S28 NPC Recruitment | Consumed by | [Recruit] option shows recruitment conditions |

## Formulas

No mathematical formulas. Dialogue is conditional logic.

**Greeting selection:**
```
if reputation <= -51: greeting = "hostile_pool"
elif reputation <= -11: greeting = "unfriendly_pool"
elif reputation <= 10: greeting = "neutral_pool"
elif reputation <= 50: greeting = "friendly_pool"
else: greeting = "allied_pool"
```

## Edge Cases

- **If the player speaks to an NPC from a Hostile faction**: The NPC refuses dialogue. "We don't talk to your kind." Only [Leave] is available.
- **If an NPC has no available quests and no services**: Only [Talk] and [Leave] are shown. The NPC is purely flavour.
- **If the player has multiple completed quests for the same NPC**: All turn-in options appear. Each can be selected individually.
- **If the NPC's trainer capability requires gold and the player has none**: The training option still appears but shows the cost in red. Selecting it shows "Not enough gold."
- **If a recruitable NPC is already in the party**: The [Recruit] option is replaced with [Talk].
- **If the NPC was met as a world map party and then met again in a town**: Dialogue state is consistent between encounters.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S09 NPC Data System | Hard | NPC definitions with dialogue_pool, services, role |
| S25 Faction Reputation | Hard | Reputation tier for greeting and option availability |
| S30 Quest Instance System | Hard | Quest status for quest-related options |
| S29 Quest Template System | Hard | Available quest offers per NPC role |
| S11 Aptitudes System | Soft | Training option availability |
| S27 Economy/Trading | Soft | Trade option triggers trade screen |
| S28 NPC Recruitment | Soft | Recruit option triggers recruitment flow |

**Depended on by:** (consuming system — triggered by NPC interaction)

## Tuning Knobs

- **Greeting pools**: Per-reputation-tier configurable in data files.
- **Talk response pools**: Per-role configurable. Add or remove lines freely.
- **Options shown**: All context-sensitive options shown by default. Can be capped (max 6 options before scrolling).
- **First meeting flag**: Reset on new game. Tracks whether the player has spoken to each NPC before.

## Visual/Audio Requirements

- **NPC portrait**: 64×64px pixel-art portrait. Shows NPC's face with faction-coloured border.
- **Greeting text**: Displayed in a text box below the portrait. Uses the custom pixel font (6×8 body).
- **Option buttons**: Shield-shaped buttons (per art bible). Coloured based on option type (green for trade, gold for quest, blue for talk).
- **Audio**: Soft paper/scroll sound when dialogue opens. Click sound when selecting an option. Chime when a quest is accepted or turned in.

## UI Requirements

- **Dialogue screen layout**: Portrait (left 20% of screen), greeting text (right 60%), options list (bottom 40%, centred).
- **Option list**: Vertical list of shield-shaped buttons. Up to 6 visible; if more, a scroll indicator appears.
- **New quest indicator**: If the NPC has an unoffered quest, a small glow (!) pulses on the quest option.
- **Turn-in highlight**: If the player has a completed quest to turn in, the turn-in option is highlighted in gold.
- **Tooltip on options**: Hovering over an option shows a brief description. "Train Command (200 gold) — increases your Command aptitude."

## Acceptance Criteria

- **GIVEN** the player speaks to a neutral NPC, **WHEN** dialogue opens, **THEN** the neutral greeting is shown and appropriate options are displayed.
- **GIVEN** the player speaks to a Hostile faction NPC, **WHEN** dialogue opens, **THEN** only [Leave] is available.
- **GIVEN** an NPC has the trader service, **WHEN** dialogue opens, **THEN** [Trade] or [Show me your wares] is an available option.
- **GIVEN** an NPC has an available quest, **WHEN** dialogue opens, **THEN** a quest offer option is available.
- **GIVEN** the player has a completed quest for the NPC, **WHEN** dialogue opens, **THEN** the turn-in option is highlighted.
- **GIVEN** the player selects [Talk], **WHEN** the action is chosen, **THEN** appropriate dialogue text is displayed.
- **GIVEN** the player selects [Leave], **WHEN** the action is chosen, **THEN** dialogue closes and the player returns to the location or world map.
- **GIVEN** a recruitable NPC with unmet conditions, **WHEN** [Recruit] is selected, **THEN** the conditions are displayed but recruitment is not processed.

## Open Questions

- **Dialogue pools volume**: How many lines per pool for MVP? Proposed: 3–5 greetings per tier, 5–8 talk responses per role, 2–3 role-specific phrases. Enough for variety without excessive writing.
- **NPC-to-NPC dialogue references**: Should NPCs ever mention each other? ("Have you spoken to the hunter? He was asking about you.") Proposed: deferred — simple random rumours for MVP. Specific cross-references post-MVP.
