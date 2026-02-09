-- systems/dialogue_system.lua
-- Handle dialogue trees and conversations

local DialogueSystem = {}

function DialogueSystem.startDialogue(actor, dialogueId)
    if not actor.dialogue then
        actor.dialogue = {}
    end
    actor.dialogue.current = dialogueId
    actor.dialogue.visited = {}
end

function DialogueSystem.selectDialogueOption(actor, optionId)
    if not actor.dialogue then return end
    actor.dialogue.visited[optionId] = true
end

function DialogueSystem.endDialogue(actor)
    if not actor.dialogue then return end
    actor.dialogue.current = nil
end

function DialogueSystem.getVisitedOptions(actor)
    if not actor.dialogue then return {} end
    return actor.dialogue.visited
end

return DialogueSystem
