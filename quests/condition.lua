-- quests/condition.lua
-- Reusable quest conditions

local Condition = {}
Condition.__index = Condition

function Condition.new(id, conditionType)
    local self = {
        id = id,
        type = conditionType or "time",
        parameters = {}
    }
    setmetatable(self, Condition)
    return self
end

function Condition:evaluate(gameContext)
    -- Evaluate condition based on game context
    -- Return true/false
    return true
end

function Condition:setParameter(key, value)
    self.parameters[key] = value
end

function Condition:getParameter(key)
    return self.parameters[key]
end

return Condition
