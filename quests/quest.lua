-- quests/quest.lua
-- Quest data schema

local Quest = {}
Quest.__index = Quest

function Quest.new(instanceId, title, templateId)
    local self = {
        id = instanceId,
        instanceId = instanceId,
        templateId = templateId,
        title = title or "Quest",
        description = "",
        giver = nil,
        giverId = nil,
        giverName = nil,
        state = "inactive", -- inactive, active, completed, failed
        objectives = {},    -- This will hold Objective objects
        rewards = {gold = 0, items = {}, reputation = {}, unlocks = {}},
        spawnedPartyIds = {}
    }
    setmetatable(self, Quest)
    return self
end

function Quest:addObjective(objective)
    table.insert(self.objectives, objective)
end

function Quest:setState(newState)
    self.state = newState
end

function Quest:getState()
    return self.state
end

function Quest:isCompleted()
    for _, obj in ipairs(self.objectives) do
        if not obj:isCompleted() then
            return false
        end
    end
    return true
end

return Quest
