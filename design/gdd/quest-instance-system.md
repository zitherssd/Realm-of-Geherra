# Quest Instance System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Discovery-Driven Exploration, Meaningful Progression

## Overview

The Quest Instance System manages active quests in the player's journal. When a player accepts a quest from an NPC, an **instance** is created from the quest template. This instance tracks its own state — which objectives are completed, what rewards have been earned, and whether the quest is active, completed, or failed. This allows multiple distinct quests of the same template type to exist simultaneously (e.g., two "hunt wolves" quests from different villages).

## Player Fantasy

Your journal fills with purpose. Each quest is a promise of gold, reputation, and adventure. You track your progress, see which objectives remain, and feel the satisfaction of checking them off. Failed quests remind you of opportunities lost — but the world moves on, and new quests appear.

## Detailed Design

### Core Rules

1. **Quest instance structure**:
   ```lua
   {
       instance_id = "quest_instance_001",
       template_id = "quest_hunt_troll",
       status = "active",          -- active, completed, failed, expired
       accepted_from = "npc_elder_01",
       accepted_at = 3.5,          -- game day when accepted
       expires_at = nil,           -- game day when it expires (nil = never)
       
       objectives = {
           {
               template_index = 1,
               type = "kill",
               target = "troll",
               current = 0,        -- how many killed so far
               required = 1,
               complete = false,
           }
       },
       
       rewards_claimed = false,
   }
   ```

2. **Instance creation**: When the player accepts a quest from an NPC:
   - A new instance is created from the template
   - Objectives are initialised from the template (current = 0)
   - `accepted_from` records the NPC who gave it
   - `accepted_at` records the current game day
   - If the template has `expires_after_days`, `expires_at = accepted_at + expires_after_days`

3. **Progress tracking**: Each frame or event, the system checks if any action the player takes progresses an active quest:
   - Killing a troll → checks for active quests with `objective.type = "kill"` and `target = "troll"`
   - Entering a location → checks for discover/clear objectives
   - Picking up an item → checks for bring_item objectives
   - When progress is made, the objective's `current` is updated
   - When `current >= required`, the objective is marked `complete`

4. **Completion**: When all objectives are complete:
   - The quest status changes to `ready_to_turn_in`
   - The player must return to the quest giver NPC to claim rewards
   - When rewards are claimed, status changes to `completed`, `rewards_claimed = true`

5. **Failure and expiry**: 
   - If `expires_at` is reached before completion: status → `expired`
   - If the quest giver NPC dies before turn-in: status → `failed`
   - Expired/failed quests remain in the journal as a record

6. **Simultaneous instances**: Multiple instances of the same template can exist. If two villages both ask the player to hunt trolls, killing one troll progresses both quests.

### States and Transitions

| State | Description |
|-------|-------------|
| **Active** | Quest accepted. Objectives being tracked. |
| **Ready to Turn In** | All objectives complete. Waiting for player to return to quest giver. |
| **Completed** | Rewards claimed. Quest is done. |
| **Expired** | Quest expired (time ran out). |
| **Failed** | Quest cannot be completed (NPC died, location destroyed). |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S29 Quest Templates | Consumes | Templates provide objective definitions and rewards |
| S09 NPC Data System | Consumed by | NPCs know which quests they've given and can receive turn-ins |
| S16 Party Encounter | Consumed by | Kill objectives check party kills |
| S08 Location System | Consumed by | Visit/clear objectives check location visits |
| S12 Inventory System | Consumed by | Bring-item objectives check inventory |
| S25 Faction Reputation | Consumed by | Reputation rewards applied on completion |
| S11 Aptitudes System | Consumed by | Aptitude rewards applied on completion |
| S31 Dialogue System | Consumed by | Dialogue shows quest status and turn-in options |
| S02 Save/Load System | Consumed by | Quest instances are saved as part of game state |

## Formulas

No complex formulas. Quest state is tracked with counters and boolean flags.

**Objective progress:**
```
if action_matches(objective) and not objective.complete:
    objective.current += 1
    if objective.current >= objective.required:
        objective.complete = true
        if all_objectives_complete():
            quest.status = "ready_to_turn_in"
```

## Edge Cases

- **If the player kills a quest target before accepting the quest**: The kill is not retroactively counted. Progress starts at 0. The terrain may have the target's corpse as evidence (cosmetic).
- **If the quest target location is destroyed (troll lair cleared by another quest)**: The quest becomes impossible to complete. Status → failed after a notification.
- **If the player completes objectives but the quest giver is dead**: The quest fails. No rewards. The player keeps any items they acquired.
- **If the player has two quests with the same objective (kill troll)**: Progress counts for both simultaneously.
- **If the player saves and loads mid-quest**: Quest instances are saved as part of game state. Progress is preserved.
- **If a quest expires while the player is in a location scene**: Expiry is checked on world map time advance. It never expires during a scene.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S29 Quest Templates | Hard | Template data for instance creation |
| S02 Save/Load System | Hard | Quest instances persisted in saves |
| S25 Faction Reputation | Hard | Reputation rewards |
| S12 Inventory System | Soft | Item rewards and bring-item tracking |
| S11 Aptitudes System | Soft | Aptitude point rewards |
| S08 Location System | Soft | Location-based objective tracking |

**Depended on by:** S31 Dialogue System (quest turn-in status).

## Tuning Knobs

- **Expiry grace period**: Float days. Default: 1.0. Extra time after expiry before the quest is marked as failed (allows the player to turn in just past the deadline).
- **Max active quests**: Integer. Default: 20. Maximum concurrent quest instances.
- **Quest log limit**: Integer. Default: 50. Maximum completed/failed quests kept in the log.

## Visual/Audio Requirements

- **Quest progress notification**: Subtle popup when an objective progresses: "Trolls slain: 1/1 ✓"
- **Quest complete notification**: Banner: "Quest Complete — Return to [NPC name] for your reward" with a chime.
- **Quest expired notification**: Banner: "Quest Expired: [Quest Name]" with a soft negative tone.

## UI Requirements

- **Quest log**: A scroll or tablet-style interface listing active quests. Each shows objectives, progress, and the quest giver's location. Completed/failed quests are in a separate tab.
- **Turn-in prompt**: When speaking to a quest giver with a completed quest, the dialogue option is highlighted: "I've completed your task." Selecting it triggers reward distribution and dialogue.
- **Quest marker on map**: Active quests with location targets show markers on the map. Exact marker if discovered, search area if not.

## Acceptance Criteria

- **GIVEN** the player accepts a quest, **WHEN** the instance is created, **THEN** it appears in the quest log with status "active".
- **GIVEN** the player kills a troll with an active hunt-troll quest, **WHEN** the kill is registered, **THEN** the objective progresses by 1.
- **GIVEN** all objectives are complete, **WHEN** checked, **THEN** the quest status changes to "ready_to_turn_in".
- **GIVEN** the player turns in a completed quest, **WHEN** rewards are claimed, **THEN** gold, reputation, and items are awarded and the quest is marked "completed".
- **GIVEN** a quest expires, **WHEN** the expiry time passes, **THEN** the quest is marked "expired".
- **GIVEN** the quest giver dies before turn-in, **WHEN** the death is registered, **THEN** the quest is marked "failed".
- **GIVEN** two active quests share the same kill target, **WHEN** the target is killed, **THEN** both quests progress.

## Open Questions

- **Quest turn-in NPC death**: If the quest giver dies, should the player be able to turn in to another NPC of the same role in the same settlement? Proposed: yes — "The elder of Oak-Wall was killed. Take his quest reward to his successor."
- **Quest sharing between playthroughs**: Quest instances are saved and loaded. They are not shared between different saves.
