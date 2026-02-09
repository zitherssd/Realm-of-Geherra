-- entities/npc.lua
-- AI- or dialogue-driven character

local Actor = require("entities.actor")
local NPC = setmetatable({}, Actor)
NPC.__index = NPC

function NPC.new(id, name)
    local self = Actor.new(id, "npc")
    setmetatable(self, NPC)
    
    self.name = name or "NPC"
    self:addTag("npc")
    
    self.dialogue = nil
    self.quests = {}
    self.schedules = {}
    
    return self
end

function NPC:setDialogue(dialogueId)
    self.dialogue = dialogueId
end

function NPC:giveQuest(questId)
    table.insert(self.quests, questId)
end

return NPC
