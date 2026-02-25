-- quests/objective.lua
-- Quest objective definitions

local Objective = {}
Objective.__index = Objective

local objectiveTypes = {
    "kill",      -- Kill X enemies
    "deliver",   -- Deliver item to NPC
    "talk",      -- Talk to NPC
    "travel",    -- Travel to location
    "collect",   -- Collect items
    "reach",     -- Reach condition/trigger
    "protect",   -- Protect NPC/location
    "escort"     -- Escort NPC
}

function Objective.new(id, objectiveType)
    local self = {
        id = id,
        type = objectiveType or "talk",
        target = nil,
        required = 1,
        current = 0,
        description = ""
    }
    setmetatable(self, Objective)
    return self
end

function Objective:advance(amount)
    self.current = self.current + (amount or 1)
end

function Objective:isCompleted()
    return self.current >= self.required
end

return Objective
