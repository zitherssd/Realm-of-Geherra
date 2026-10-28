-- systems/quests/quest_objective_system.lua
-- Plain functions for objective progress. Objectives are nested data inside
-- a quest entity's `objectives` list, not independently-queried entities.

local QuestObjectiveSystem = {}

function QuestObjectiveSystem.advance(objective, amount)
    objective.current = objective.current + (amount or 1)
end

function QuestObjectiveSystem.isCompleted(objective)
    return objective.current >= objective.required
end

return QuestObjectiveSystem
