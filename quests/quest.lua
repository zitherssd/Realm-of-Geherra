-- quests/quest.lua
-- Quest data schema

local Quest = {}

function Quest.new(id, title)
    local self = {
        id = id,
        title = title or "Quest",
        description = "",
        giver = nil,
        state = "inactive",  -- inactive, active, completed, failed
        objectives = {},
        conditions = {},
        rewards = {gold = 0, items = {}, reputation = {}, unlocks = {}},
        progress = {}
    }
    return self
end

function Quest:addObjective(objectiveId, objective)
    self.objectives[objectiveId] = objective
end

function Quest:addCondition(conditionId, condition)
    self.conditions[conditionId] = condition
end

function Quest:setState(newState)
    self.state = newState
end

function Quest:getState()
    return self.state
end

function Quest:getProgress(objectiveId)
    return self.progress[objectiveId]
end

function Quest:setProgress(objectiveId, progress)
    self.progress[objectiveId] = progress
end

return Quest
