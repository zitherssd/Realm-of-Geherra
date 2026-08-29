-- quests/objective.lua
-- Quest objective data (nested inside a quest entity's `objectives` list).
-- Types in use: kill_party, deliver, talk, travel, collect, reach, protect,
-- escort, report_to_giver. Behavior lives in systems/quest_objective_system.lua.

local Objective = {}

function Objective.new(id, objectiveType)
    return {
        id = id,
        type = objectiveType or "talk",
        target = nil,
        required = 1,
        current = 0,
        description = ""
    }
end

return Objective
