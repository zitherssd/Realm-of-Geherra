-- Small priority evaluator. Activities own movement/combat; goals only request them.
local EcsWorld = require("src.ecs.world")
local PartySystem = require("src.systems.party_system")
local WorldActivitySystem = require("src.systems.world_activity_system")
local RaidActivity = require("src.systems.world_activities.raid_activity")
local Recovery = require("src.systems.recovery")
local Services = require("src.systems.service_system")
local Knowledge = require("src.systems.knowledge_system")
local Caravans = require("src.systems.caravan_system")
local LocationRules = require("src.systems.location_rules")

local GoalSystem = {
    evaluationIntervalSeconds = 1,
    retrySeconds = 10
}

local Definitions = require("src.systems.goal_definitions")
local newGoal = Definitions.create

-- Configuration is opt-in, even for an empty goal list. Replace only when idle.
function GoalSystem.configure(actor, definitions, capabilities)
    assert(not Services.hasObligation(actor, {world = actor.__world}), "Resolve accepted service before replacing goals")
    if actor.npc_goals then
        for _, goal in ipairs(actor.npc_goals.goals) do
            assert(not goal.activity, "Cannot replace goals while an activity is owned")
        end
    end
    local goals, methods = {}, {}
    for _, definition in ipairs(definitions or {}) do
        assert(definition.type ~= "fulfill_obligation", "Obligations are created by successful commissioning")
        goals[#goals + 1] = newGoal(definition)
    end
    for method, allowed in pairs(capabilities or {}) do
        assert(type(method) == "string" and method:match("^[%a][%w_]*$") and type(allowed) == "boolean",
            "Capabilities must be named boolean flags")
        methods[method] = allowed
    end
    actor:ensure("npc_goals")
    actor.npc_goals.selectedGoalIndex = nil
    actor.npc_goals.goals = goals
    actor.npc_goals.capabilities = methods
    actor.npc_goals.evaluationCooldownSeconds = 0
    return actor.npc_goals
end

function GoalSystem.addGoal(actor, definition)
    if definition.type == "fulfill_obligation" then
        local request = Services.getRequest(definition.serviceId, {world = actor.__world})
        assert(request and request.status == "assigned" and request.assignedActorId == actor.id,
            "FulfillObligation requires an accepted service")
        for _, existing in ipairs(actor.npc_goals and actor.npc_goals.goals or {}) do
            if existing.type == "fulfill_obligation" and existing.serviceId == definition.serviceId then return existing end
        end
    end
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
    if goal.type == "rest_and_recover" then
        return not Recovery.needsRest(actor, goal.recovering)
    end
    if goal.type == "provide_service" then
        if not actor.memory then return false, "important_actor_required" end
        return false
    elseif goal.type == "fulfill_obligation" then
        local request = Services.getRequest(goal.serviceId, {world = actor.__world})
        return not request or request.status ~= "assigned" or request.assignedActorId ~= actor.id
    end
    local destination
    if goal.type == "reach_location" then
        destination = destinationFor(goal, actor, map)
        if not destination then return false, "destination_missing" end
    end
    if goal.type == "acquire_gold" then
        return (party and PartySystem.getTreasury(party) or actor.treasury or 0) >= goal.amount
    end
    if not party then return false, "no_commanded_party" end
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
    if goal.type == "rest_and_recover" then
        activityType, params = "rest", {actorId = actor.id}
        local context = {world = actor.__world, map = map}
        local location = Services.getLocation(actor, context)
        local function settlement(place)
            return LocationRules.canRecover(place)
        end
        if not location or not settlement(location) then
            local nearest, distance
            for _, place in ipairs(map:getLocations() or {}) do
                if settlement(place) and EcsWorld.findLocationById(place.id, actor.__world) == place then
                    local d = (place.x - party.x)^2 + (place.y - party.y)^2
                    if not distance or d < distance then nearest, distance = place, d end
                end
            end
            if nearest then activityType, params = "travel", {destinationLocationId = nearest.id} end
        end
    elseif goal.type == "acquire_gold" then
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
        if goal.type == "rest_and_recover" then
            goal.recovering = nil
            goal.status = "pending"
        end
    end
    return true
end

-- Recovery is an opt-in safety interruption. Ordinary goals retain their data,
-- including future accepted assignments; only their current activity is cancelled.
local function updateRecovery(actor, party, map, playerParty, traveling)
    if not actor.memory then return false end
    local selected
    for _, goal in ipairs(actor.npc_goals.goals) do
        if goal.type == "rest_and_recover" then
            if Recovery.needsRest(actor, goal.recovering) then
                if not selected or goal.priority > selected.priority then selected = goal end
            else
                goal.recovering = nil
            end
        end
    end
    if not selected then return false end
    for index, goal in ipairs(actor.npc_goals.goals) do
        if goal == selected then actor.npc_goals.selectedGoalIndex = index end
    end
    selected.recovering = true
    selected.status, selected.reason = "pending", nil
    if actor.activeEncounterId or (party and party.activeEncounterId) then
        selected.status, selected.reason = "blocked", "party_in_encounter"
        return true
    end
    if party and party == playerParty then
        selected.status, selected.reason = "blocked", "player_party"
        return true
    end
    Services.tryRecoveryHealing(actor, selected, {world = actor.__world, map = map})
    if not party then
        if selected.activity then
            selected.status, selected.reason = "blocked", "releasing_previous_activity"
            return true
        end
        selected.status = "active"
        return true
    end
    local activity = party.world_activity
    if selected.activity then selected.status = "active"; return true end
    if activity and activity.status == "active" then
        for _, goal in ipairs(actor.npc_goals.goals) do
            if goal ~= selected and goal.activity and goal.activity.partyId == party.id
                and goal.activity.sequence == activity.sequence and activity.goalActorId == actor.id then
                WorldActivitySystem.cancel(party, "recovery_required")
                goal.status, goal.reason = "blocked", "recovery_required"
                return true
            end
        end
        selected.status, selected.reason = "blocked", "party_already_active"
        return true
    end
    if party == playerParty or (activity and activity.status ~= "idle")
        or (map.partyEncounterCooldowns and (map.partyEncounterCooldowns[party.id] or 0) > 0) then
        selected.status, selected.reason = "blocked", "party_unavailable"
        return true
    end
    if selected.retrySeconds > 0 then
        selected.status, selected.reason = "blocked", "recovery_retry"
        return true
    end
    local started, reason = requestActivity(selected, actor, party, map, playerParty, traveling)
    if not started then
        selected.status, selected.reason = "blocked", reason
        selected.retrySeconds = GoalSystem.retrySeconds
    end
    return true
end

local function provideService(goal, actor, party, map, playerParty, traveling)
    local context = {world = actor.__world, map = map}
    if Services.hasObligation(actor, context) then return false, "conflicting_obligation" end
    if actor.activeEncounterId or (party and party.activeEncounterId) then return false, "in_encounter" end
    goal.status = "active"
    local closed = {}
    for _, known in ipairs(Knowledge.getKnownEvents(actor)) do
        if known.serviceId and known.status and known.status ~= "open" then closed[known.serviceId] = true end
    end
    for _, offer in ipairs(Knowledge.getKnownEvents(actor, nil, "service_offered")) do
        if offer.serviceId and offer.locationId and offer.employerId and offer.requiredCapability
            and actor.npc_goals.capabilities[offer.requiredCapability] and not closed[offer.serviceId] then
            local here = Services.getLocation(actor, context)
            if here and here.id == offer.locationId then
                local ok, result = Services.assign(offer.serviceId, actor, context)
                goal.lastServiceResult = {serviceId = offer.serviceId, success = ok,
                    reason = not ok and result or nil}
                goal.retrySeconds = GoalSystem.retrySeconds
                return true
            end
            if not party then
                goal.reason = "independent_resident_cannot_travel"
                return true -- Still offers its local capabilities.
            end
            if party == playerParty or not actor.npc_goals.capabilities.travel then return false, "travel_not_allowed" end
            goal.destinationLocationId, goal.pursuedServiceId = offer.locationId, offer.serviceId
            return requestActivity(goal, actor, party, map, playerParty, traveling)
        end
    end
    return true -- Waiting for customers does not create a World Activity.
end

local function updateActor(actor, party, dt, map, playerParty, traveling)
    local state = actor.npc_goals
    state.evaluationCooldownSeconds = math.max(0, state.evaluationCooldownSeconds - dt)
    local outcomeChanged = false
    for _, goal in ipairs(state.goals) do
        goal.retrySeconds = math.max(0, goal.retrySeconds - dt)
        goal.healingRetrySeconds = math.max(0, (goal.healingRetrySeconds or 0) - dt)
        outcomeChanged = observeActivity(goal, actor, party) or outcomeChanged
    end
    if updateRecovery(actor, party, map, playerParty, traveling) then return end
    if state.evaluationCooldownSeconds > 0 and not outcomeChanged then return end
    state.evaluationCooldownSeconds = GoalSystem.evaluationIntervalSeconds
    state.selectedGoalIndex = nil

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
            state.selectedGoalIndex = index
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
            if goal.type == "provide_service" and goal.retrySeconds > 0 then
                candidates[#candidates + 1] = {goal = goal, index = index, waiting = true}
                goal.status = "active"
            elseif goal.retrySeconds > 0 then
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
    -- Ordinary priorities never preempt active work. Recovery above is the
    -- sole safety exception, and still cannot preempt explicit work or encounters.
    local activity = party and party.world_activity
    if ownsActivity or (party and party == playerParty) or actor.activeEncounterId or (party and party.activeEncounterId)
        or (map.partyEncounterCooldowns and (map.partyEncounterCooldowns[party and party.id] or 0) > 0)
        or (activity and (activity.status ~= "idle" or (activity.retryCooldownSeconds or 0) > 0)) then
        return
    end
    table.sort(candidates, function(left, right)
        if left.goal.priority == right.goal.priority then return left.index < right.index end
        return left.goal.priority > right.goal.priority
    end)
    for _, candidate in ipairs(candidates) do
        local goal = candidate.goal
        state.selectedGoalIndex = candidate.index
        local started, reason
        if goal.type == "provide_service" then
            if candidate.waiting then goal.status = "active"; return end
            started, reason = provideService(goal, actor, party, map, playerParty, traveling)
        elseif goal.type == "fulfill_obligation" then
            goal.status, goal.reason = "active", "awaiting_service_execution"
            local request = Services.getRequest(goal.serviceId, {world = actor.__world})
            if request and request.type == "lead_caravan" then
                Caravans.fulfill(actor, goal, {world = actor.__world, map = map})
            end
            return
        elseif goal.type == "acquire_gold" and state.capabilities.caravanFormation then
            started, reason = Caravans.begin(actor, {world = actor.__world, map = map})
            if started then goal.status = "active" end
            if not started and party and state.capabilities.raid then
                started, reason = requestActivity(goal, actor, party, map, playerParty, traveling)
            end
        elseif party then
            started, reason = requestActivity(goal, actor, party, map, playerParty, traveling)
        else
            reason = "no_commanded_party"
        end
        if started then return end
        goal.status, goal.reason = "blocked", reason
        goal.retrySeconds = GoalSystem.retrySeconds
        state.selectedGoalIndex = nil
    end
end

-- dt is elapsed world-simulation seconds, never render-frame time.
function GoalSystem.update(dt, map, playerParty)
    if not map or dt <= 0 or not EcsWorld.campaign then return end
    local world = EcsWorld.campaign
    -- Concord queries see committed entities; include freshly created actors too.
    world:__flush()
    Services.update({world = world, map = map})
    Caravans.update({world = world, map = map})
    local parties, traveling = mapParties(map)
    local commanded, membership, residents = {}, {}, {}
    -- Roster membership is authoritative even if a stale resident reference remains.
    for _, party in ipairs(world:query({"party"})) do
        for _, actor in ipairs(party.actors or {}) do membership[actor.id] = party end
    end
    for _, location in ipairs(map:getLocations() or {}) do
        if EcsWorld.findLocationById(location.id, world) == location then
            for _, actor in ipairs(location.npcs or {}) do residents[actor.id] = true end
        end
    end
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
        actor.npc_goals.evaluationMode = "inactive"
        local eligible = not actor.player and (actor.hp or 0) > 0
        if not eligible then actor.npc_goals.selectedGoalIndex = nil end
        if not actor.player and (actor.hp or 0) > 0
            and EcsWorld.findActorById(actor.id, world) == actor then
            local party = commanded[actor.id]
            local memberParty = membership[actor.id]
            local localFollower = actor.memory and memberParty
                and Services.getLocation(actor, {world = world, map = map}) ~= nil
            if party or localFollower or (actor.memory and residents[actor.id] and not memberParty) then
                actor.npc_goals.evaluationMode = party and "party leader" or (localFollower and "local party member" or "independent resident")
                updateActor(actor, party, dt, map, playerParty, traveling)
            else
                actor.npc_goals.selectedGoalIndex = nil
                -- Observe relinquished commands without running non-leader AI.
                for _, goal in ipairs(actor.npc_goals.goals) do observeActivity(goal, actor, nil) end
            end
        end
    end
end

return GoalSystem
