---
name: dialogue-authoring
summary: Add, modify, and wire dialogue trees plus dialogue-triggered gameplay effects while preserving project architecture.
---

# Dialogue Authoring Skill

Use this skill when you need to:
- Add a new NPC or encounter conversation.
- Modify existing dialogue branches.
- Add gameplay effects triggered by dialogue choices.

## Architecture Contract

Follow these rules from project architecture:
- Dialogue content belongs in data files.
- UI and dialogue screens collect intent only.
- Gameplay effects must be executed by systems, not UI code.
- Keep dependencies flowing downward.

In this codebase, dialogue choice actions are dispatched in game state logic and delegated into systems.

## Where Dialogue Lives

- Content: data/dialogue.lua
- Runtime state/controller: game/states/dialogue_state.lua
- Rendering and input: ui/screens/dialogue_screen.lua
- Quest context/gating:
  - systems/quest_system.lua
  - systems/quest_availability_system.lua
- Common entry points:
  - ui/screens/location_screen.lua (NPC buttons)
  - game/states/world_state.lua (party/world interactions)
  - systems/location_actions.lua (inline one-off dialogue trees)

## Dialogue Data Shape

Each dialogue entry in data/dialogue.lua follows this shape:

```lua
["some_dialogue_id"] = {
    id = "some_dialogue_id",
    speaker = "Speaker Name", -- optional, can be overridden by runtime target
    checkQuest = "optional_template_id", -- optional quest-aware redirect
    states = { -- optional map if checkQuest is set
        active = "dialogue_when_active",
        ready_to_turn_in = "dialogue_when_ready",
        completed = "dialogue_when_completed"
    },
    lines = {
        {
            text = "Line text",
            options = {
                { text = "Option text", next = "another_dialogue_id" },
                { text = "Exit", next = "end" }
            }
        }
    }
}
```

Option fields currently supported:
- text: option label.
- next: next dialogue id, or end.
- action: effect key handled in dialogue_state.lua.
- quest gating booleans:
  - requiresQuestPool
  - requiresQuestOffer
  - requiresAcceptedQuest
  - requiresReadyToTurnIn

If all options are filtered out by gating, the runtime injects Leave -> end automatically.

## Runtime Flow

1. Dialogue starts via StateManager.push("dialogue", { target, dialogueId or dialogueTree, ... }).
2. dialogue_state.lua resolves the tree from data/dialogue.lua (or uses inline dialogueTree).
3. If checkQuest exists, quest state is read and optionally redirected via states map.
4. Quest-offer gating filters options based on NPC offer context.
5. DialogueScreen renders current node and returns selected choice.
6. dialogue_state.lua runs choice.action side effects.
7. Navigation:
   - next == end: pop dialogue state.
   - next == <dialogueId>: swap to next node/dialogue id.

## Add Or Modify Dialogue

1. Add or edit nodes in data/dialogue.lua.
2. Ensure each new id is unique.
3. Ensure each next points to either:
   - an existing dialogue id, or
   - end.
4. Wire an entry point if needed:
   - NPC path: set npc.dialogueId or rely on troopType_greeting fallback.
   - World/party path: push dialogue from world_state.lua.
   - Location interaction path: push dialogue from location_actions.lua.
5. If quest-reactive, set checkQuest + states mapping.

## Add Gameplay Effects To Dialogue Choices

### Existing Actions You Can Reuse

Handled in game/states/dialogue_state.lua:
- battle
- recruit_volunteers
- accept_quest
- accept_procedural_quest
- accept_available_quest
- turn_in_quest
- turn_in_available_quest

Use these in data/dialogue.lua with action = "...".

### Add A New Action (Recommended Pattern)

When you need a new effect:

1. Add action key in dialogue data.

```lua
{ text = "Rest until dawn", action = "rest_until_dawn", next = "end" }
```

2. Implement action handling in game/states/dialogue_state.lua inside the choice callback.
3. Delegate gameplay logic to the appropriate system. Do not put gameplay math/state mutation in UI modules.
4. Keep dialogue_state as orchestration glue only.

Example:

```lua
elseif choice.action == "rest_until_dawn" then
    TimeSystem.advanceHours(8)
    PartySystem.restorePartyFatigue(GameContext.data.playerParty)
end
```

If no fitting system exists, create a focused system and call it from dialogue_state.

## Effect Design Guidance

- Prefer declarative data in dialogue nodes.
- Keep side effects idempotent when possible.
- For complex or reusable outcomes, route through a system API.
- Emit events for cross-system reactions when needed.
- Avoid embedding long inline dialogue trees in systems unless they are truly one-off utility popups.

## Quest-Aware Dialogue Checklist

For NPC-offer quests:
- Ensure NPC role is configured in data/npc_quest_pools.lua.
- Ensure location entry refresh runs (location_state.lua already does this).
- Gate options with requiresQuestOffer or requiresReadyToTurnIn as needed.
- Use accept_available_quest and turn_in_available_quest for offer lifecycle.

For template-bound static quest dialogue:
- Use checkQuest + states in the root node.
- Use turn_in_quest when turning in by template/instance id.

## Validation Checklist

After edits:
- Enter dialogue from intended entry point.
- Verify option visibility in all expected quest states.
- Verify action effects are applied exactly once.
- Verify next navigation and end behavior.
- Verify no UI module directly mutates unrelated game state.

## Common Pitfalls

- Typo in next id causing dead ends.
- Adding an action string in data but forgetting to implement it in dialogue_state.
- Putting gameplay logic in ui/screens/dialogue_screen.lua.
- Assuming speaker in data always displays; runtime target may override speaker.
- Forgetting quest gating flags, which can expose unavailable options.
