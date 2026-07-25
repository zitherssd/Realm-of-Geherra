-- data/dialogue.lua
-- Dialogue tree registry composed from role-based dialogue files.

local dialogueRegistry = {}

local function mergeDialogueSet(target, source)
    for dialogueId, dialogueTree in pairs(source) do
        if target[dialogueId] then
            error("Duplicate dialogue id in registry: " .. tostring(dialogueId))
        end
        target[dialogueId] = dialogueTree
    end
end

mergeDialogueSet(dialogueRegistry, require("data.dialogues.common"))
mergeDialogueSet(dialogueRegistry, require("data.dialogues.elder"))
mergeDialogueSet(dialogueRegistry, require("data.dialogues.tavern_keeper"))
mergeDialogueSet(dialogueRegistry, require("data.dialogues.trader"))
mergeDialogueSet(dialogueRegistry, require("data.dialogues.soldier"))

return dialogueRegistry