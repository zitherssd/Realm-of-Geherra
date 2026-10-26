-- Small priority evaluator. Activities own movement/combat; goals only request them.
local EcsWorld = require("src.ecs.world")
local PartySystem = require("src.systems.party_system")
local WorldActivitySystem = require("src.systems.world_activity_system")
local RaidActivity = require("src.systems.world_activities.raid_activity")

local GoalSystem = {
    evaluationIntervalSeconds = 1,
    retrySeconds = 10
}

local function finiteNumber(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function newGoal(definition)
    assert(type(definition) == "table", "Goal definition must be a table")
    local goal = {
        type = definition.type,
        priority = definition.priority or 0,
        status = "pending",
        attempts = 0,
        retrySeconds = 0
    }
    assert(finiteNumber(goal.priority), "Goal priority must be finite")
    if goal.type == "acquire_gold" then
        assert(finiteNumber(definition.amount) and definition.amount >= 0,
            "Gold goal requires a finite non-negative amount")
        goal.amount = definition.amount
        if definition.roam then
            local roam = definition.roam
            assert(type(roam) == "table" and finiteNumber(roam.radius) and roam.radius > 0,
                "Roaming requires a positive radius")
            assert((roam.originLocationId ~= nil and roam.originX == nil and roam.originY == nil
                and (type(roam.originLocationId) == "string" or finiteNumber(roam.originLocationId)))
                or (roam.originLocationId == nil and finiteNumber(roam.originX) and finiteNumber(roam.originY)),
                "Roaming requires coordinates or a location ID")
            assert(roam.durationSeconds == nil or (finiteNumber(roam.durationSeconds) and roam.durationSeconds > 0),
                "Roaming duration must be positive")
            goal.roam = {originX = roam.originX, originY = roam.originY,
                originLocationId = roam.originLocationId, radius = roam.radius, durationSeconds = roam.durationSeconds}
        end
    elseif goal.type == "reach_location" then
        local id = definition.destinationLocationId
        assert(type(id) == "string" or finiteNumber(id), "Location goal requires a stable ID")
        goal.destinationLocationId = id
    else
        error("Unknown goal type: " .. tostring(goal.type))
    end
    return goal
end

-- Configuration is opt-in, even for an empty goal list. Replace only when idle.
function GoalSystem.configure(actor, definitions, capabilities)
    if actor.npc_goals then
        for _, goal in ipairs(actor.npc_goals.goals) do
            assert(not goal.activity, "Cannot replace goals while an activity is owned")
        end
    end
    local goals, methods = {}, {}
    for _, definition in ipairs(definitions or {}) do
        goals[#goals + 1] = newGoal(definition)
    end
    for method, allowed in pairs(capabilities or {}) do
        assert((method == "raid" or method == "travel" or method == "roam") and type(allowed) == "boolean",
            "Capabilities must be raid/travel/roam boolean flags")
        methods[method] = allowed
    end
    actor:ensure("npc_goals")
    actor.npc_goals.goals = goals
    actor.npc_goals.capabilities = methods
    actor.npc_goals.evaluationCooldownSeconds = 0
    return actor.npc_goals
end

function GoalSystem.addGoal(actor, definition)
    local goal = newGoal(definition)
    actor:ensure("npc_goals")
    table.insert(actor.npc_goals.goals, goal)
    actor.npc_goals.evaluationCooldownSeconds = 0
    return goal
end

local function mapParties(map)
    local parties, traveling = {}, {}
    for _, party in ipairs(map:getParties() or {}) do
        parties[#parties + 1] = party
        traveling[party.id] = true
    end
    for _, location in ipairs(map:getLocations() or {}) do
        for _, party in ipairs(location.stationedParties or {}) do
            parties[#parties + 1] = party
        end
    end
    return parties, traveling
end

local function destinationFor(goal, actor, map)
    local destination = EcsWorld.findLocationById(goal.destinationLocationId, actor.__world)
    for _, location in ipairs(map:getLocations() or {}) do
        if location == destination then return destination end
    end
    return nil
end

local function condition(goal, actor, party, map)
    local destination
    if goal.type == "reach_location" then
        destination = destinationFor(goal, actor, map)
        if not destination then return false, "destination_missing" end
    end
    if not party then return false, "no_commanded_party" end
    if goal.type == "acquire_gold" then
        return PartySystem.getTreasury(party) >= goal.amount
    end
    for _, stationed in ipairs(destination.stationedParties or {}) do
        if stationed == party then return true end
    end
    return false
end

local function finishAttempt(goal, status, reason, activityType)
    goal.lastOutcome = {status = status, reason = reason, activityType = activityType}
    goal.activity = nil
    goal.retrySeconds = GoalSystem.retrySeconds
    if activityType == "roam" and reason == "opportunity_detected" and goal.detectedTargetId then
        goal.retrySeconds = 0
    else
        goal.detectedTargetId = nil
    end
end

local function observeActivity(goal, actor, party)
    local owned = goal.activity
    if not owned then return false end
    local originalParty = EcsWorld.findPartyById(owned.partyId, actor.__world)
    local activity = originalParty and originalParty.world_activity
    if activity and activity.sequence == owned.sequence and activity.status ~= "idle" then
        if activity.status == "active" then
            if originalParty ~= party and not originalParty.activeEncounterId then
                WorldActivitySystem.cancel(originalParty, "goal_lost_command")
            end
            return false
        end
        finishAttempt(goal, activity.status, activity.reason, activity.type)
    elseif activity and activity.lastActivity
        and activity.lastActivity.sequence == owned.sequence then
        local outcome = activity.lastActivity
        finishAttempt(goal, outcome.status, outcome.reason, outcome.type)
    else
        finishAttempt(goal, "cancelled", "activity_unavailable")
    end
    return true
end

local function requestActivity(goal, actor, party, map, playerParty, traveling)
    local capabilities = actor.npc_goals.capabilities
    local activityType, params
    if goal.type == "acquire_gold" then
        if not capabilities.raid then return false, "raid_not_allowed" end
        if not traveling[party.id] then return false, "raid_requires_traveling_party" end
        if not (party.hostile == true or party.faction == "bandits") then
            return false, "raider_not_hostile"
        end
        local target
        if goal.detectedTargetId then
            target = RaidActivity.visibleTarget(party, map, playerParty, goal.detectedTargetId)
            goal.detectedTargetId = nil
        else
            target = RaidActivity.selectTarget(party, map, playerParty)
        end
        if target then
            activityType, params = "raid", {targetPartyId = target.id}
        elseif capabilities.roam and goal.roam then
            activityType, params = "roam", goal.roam
        else
            return false, "no_eligible_target"
        end
    else
        if not capabilities.travel then return false, "travel_not_allowed" end
        activityType = "travel"
        params = {destinationLocationId = goal.destinationLocationId}
    end
    local started, reason = WorldActivitySystem.start(party, activityType, params, map)
    if not started then return false, reason end
    party.world_activity.goalActorId = actor.id
    goal.activity = {partyId = party.id, sequence = party.world_activity.sequence}
    goal.status, goal.reason = "active", nil
    goal.attempts = goal.attempts + 1
    return true
end

-- Explicit tools may stop owned work before reconfiguring. No clock advancement.
-- Preflight every attempt so a reserved encounter leaves all goals unchanged.
function GoalSystem.cancelActivities(actor, reason)
    local goals = actor.npc_goals and actor.npc_goals.goals or {}
    for _, goal in ipairs(goals) do
        local owned = goal.activity
        local party = owned and EcsWorld.findPartyById(owned.partyId, actor.__world)
        if party and party.activeEncounterId then return false, "party_in_encounter" end
    end
    for _, goal in ipairs(goals) do
        local owned = goal.activity
        local party = owned and EcsWorld.findPartyById(owned.partyId, actor.__world)
        if party and party.world_activity and party.world_activity.sequence == owned.sequence then
            WorldActivitySystem.cancel(party, reason or "goal_cancelled")
        end
        observeActivity(goal, actor, party)
    end
    return true
end

local function updateActor(actor, party, dt, map, playerParty, traveling)
    local state = actor.npc_goals
    state.evaluationCooldownSeconds = math.max(0, state.evaluationCooldownSeconds - dt)
    local outcomeChanged = false
    for _, goal in ipairs(state.goals) do
        goal.retrySeconds = math.max(0, goal.retrySeconds - dt)
        outcomeChanged = observeActivity(goal, actor, party) or outcomeChanged
    end
    if state.evaluationCooldownSeconds > 0 and not outcomeChanged then return end
    state.evaluationCooldownSeconds = GoalSystem.evaluationIntervalSeconds

    local candidates, ownsActivity = {}, false
    for index, goal in ipairs(state.goals) do
        local satisfied, reason = condition(goal, actor, party, map)
        if satisfied then
            goal.status, goal.reason = "satisfied", nil
            -- Let reserved encounters finish and apply their real outcomes first.
            if goal.activity then
                local owner = EcsWorld.findPartyById(goal.activity.partyId, actor.__world)
                if owner and not owner.activeEncounterId and owner.world_activity
                    and owner.world_activity.sequence == goal.activity.sequence then
                    WorldActivitySystem.cancel(owner, "goal_satisfied")
                end
            end
        elseif goal.activity then
            goal.status, goal.reason = "active", reason
            local activity = party and party.world_activity
            if goal.type == "acquire_gold" and state.capabilities.raid and state.capabilities.roam
                and party and not party.activeEncounterId and traveling[party.id]
                and (party.hostile == true or party.faction == "bandits")
                and goal.activity.partyId == party.id and activity
                and activity.sequence == goal.activity.sequence and activity.goalActorId == actor.id
                and activity.status == "active" and activity.type == "roam" then
                local target = RaidActivity.selectTarget(party, map, playerParty)
                if target and WorldActivitySystem.cancel(party, "opportunity_detected") then
                    goal.detectedTargetId = target.id
                end
            end
        elseif reason then
            goal.status, goal.reason = "blocked", reason
        else
            if goal.retrySeconds > 0 then
                goal.status = "blocked"
                goal.reason = goal.reason or (goal.lastOutcome and goal.lastOutcome.reason)
            else
                goal.status, goal.reason = "pending", nil
            end
            if goal.retrySeconds <= 0 then
                candidates[#candidates + 1] = {goal = goal, index = index}
            end
        end
        ownsActivity = ownsActivity or goal.activity ~= nil
    end
    -- Never preempt another goal, an explicit activity, or a reserved encounter.
    local activity = party and party.world_activity
    if ownsActivity or not party or party == playerParty or party.activeEncounterId
        or (map.partyEncounterCooldowns and (map.partyEncounterCooldowns[party.id] or 0) > 0)
        or (activity and (activity.status ~= "idle" or (activity.retryCooldownSeconds or 0) > 0)) then
        return
    end
    table.sort(candidates, function(left, right)
        if left.goal.priority == right.goal.priority then return left.index < right.index end
        return left.goal.priority > right.goal.priority
    end)
    for _, candidate in ipairs(candidates) do
        local goal = candidate.goal
        local started, reason = requestActivity(goal, actor, party, map, playerParty, traveling)
        if started then return end
        goal.status, goal.reason = "blocked", reason
        goal.retrySeconds = GoalSystem.retrySeconds
    end
end

-- dt is elapsed world-simulation seconds, never render-frame time.
function GoalSystem.update(dt, map, playerParty)
    if not map or dt <= 0 or not EcsWorld.campaign then return end
    local world = EcsWorld.campaign
    -- Concord queries see committed entities; include freshly created actors too.
    world:__flush()
    local parties, traveling = mapParties(map)
    local commanded = {}
    for _, party in ipairs(parties) do
        local leader = PartySystem.getLeader(party)
        local liveParty = EcsWorld.findPartyById(party.id, world) == party
        local activity = party.world_activity
        -- Removed/dead actors are absent from evaluation, but their previous commands
        -- must still be released. Store only the persistent owner ID on the activity.
        if activity and activity.status == "active" and activity.goalActorId
            and not party.activeEncounterId then
            local owner = EcsWorld.findActorById(activity.goalActorId, world)
            if not liveParty or not owner or (owner.hp or 0) <= 0 or owner ~= leader then
                WorldActivitySystem.cancel(party, "goal_lost_command")
            end
        end
        if leader and liveParty then
            commanded[leader.id] = party
        end
    end
    for _, actor in ipairs(world:query({"unit", "npc_goals"})) do
        if not actor.player and (actor.hp or 0) > 0
            and EcsWorld.findActorById(actor.id, world) == actor then
            updateActor(actor, commanded[actor.id], dt, map, playerParty, traveling)
        end
    end
end

return GoalSystem
