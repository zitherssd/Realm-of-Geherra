-- Goal records live only on npc_goals; this module does not evaluate or select them.
local Definitions = require("src.systems.goals.goal_definitions")
local GoalState = {}

function GoalState.add(actor, definition)
    if definition.type == "fulfill_obligation" then
        local requests = actor.__world.serviceRequests or {}
        local request = requests[definition.serviceId]
        assert(request and request.status == "assigned" and request.assignedActorId == actor.id,
            "FulfillObligation requires an accepted service")
        for _, goal in ipairs(actor.npc_goals and actor.npc_goals.goals or {}) do
            if goal.type == "fulfill_obligation" and goal.serviceId == definition.serviceId then return goal end
        end
    end
    local goal = Definitions.create(definition)
    actor:ensure("npc_goals")
    table.insert(actor.npc_goals.goals, goal)
    actor.npc_goals.evaluationCooldownSeconds = 0
    return goal
end

function GoalState.closeObligation(actor, serviceId, status)
    local state = actor and actor.npc_goals
    for index, goal in ipairs(state and state.goals or {}) do
        if goal.type == "fulfill_obligation" and goal.serviceId == serviceId then
            goal.status, goal.resolvedStatus = "satisfied", status
            if state.selectedGoalIndex == index then state.selectedGoalIndex = nil end
        end
    end
end

return GoalState
