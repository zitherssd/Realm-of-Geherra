-- data/dialogue.lua
-- Dialogue tree registry composed from role-based dialogue files.

local Registry = require("src.data.definition_registry")
local dialogueRegistry = {}

local function mergeDialogueSet(target, source)
    for dialogueId, dialogueTree in pairs(source) do
        Registry.checkId("dialogue", dialogueId, dialogueTree)
        if target[dialogueId] then
            error("Duplicate dialogue id in registry: " .. tostring(dialogueId))
        end
        target[dialogueId] = dialogueTree
    end
end

mergeDialogueSet(dialogueRegistry, require("src.data.dialogues.common"))
mergeDialogueSet(dialogueRegistry, require("src.data.dialogues.elder"))
mergeDialogueSet(dialogueRegistry, require("src.data.dialogues.tavern_keeper"))
mergeDialogueSet(dialogueRegistry, require("src.data.dialogues.trader"))
mergeDialogueSet(dialogueRegistry, require("src.data.dialogues.debug_trader"))
mergeDialogueSet(dialogueRegistry, require("src.data.dialogues.soldier"))

return dialogueRegistry
