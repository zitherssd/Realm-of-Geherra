-- Dynamic importance evaluator. Activities own movement/combat; goals only request them.
local EcsWorld = require("src.ecs.world")
local PartySystem = require("src.systems.parties.party_system")
local WorldActivitySystem = require("src.systems.world_activities.world_activity_system")
local RaidActivity = require("src.systems.world_activities.raid_activity")
local Services = require("src.systems.services.service_system")
local Knowledge = require("src.systems.knowledge.knowledge_system")
local Caravans = require("src.systems.services.caravan_system")
local Investigations = require("src.systems.services.investigation_system")
local LocationRules = require("src.systems.locations.location_rules")

local GoalSystem = {
    evaluationIntervalSeconds = 1,
    retrySeconds = 10
}

local Definitions = require("src.systems.goals.goal_definitions")
local newGoal = Definitions.create
local Importance = require("src.systems.goals.goal_importance")
local Treatment = require("src.systems.actors.injury_treatment")

-- Shared pure read API, also used by F1. Custom definitions may supply their own rule.
function GoalSystem.getImportance(goal, actor, party)
    if type(goal) ~= "table" or not actor then return 0 end
    if goal.status == "cancelled" or goal.status == "completed" or goal.status == "invalid" then return 0 end
    if goal.type == "reach_location" then
        local destination = EcsWorld.findLocationById(goal.destinationLocationId, actor.__world)
        for _, stationed in ipairs(destination and destination.stationedParties or {}) do
            if stationed == party then return 0 end
        end
    end
    local spec = Definitions.goals[goal.type]
    local value = spec and spec.importance and spec.importance(goal, actor, party)
        or goal.accumulatedImportance or goal.priority or 0
    return Importance.clamp(value)
end

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
    if actor.memory then require("src.data.types.personality").normalize(actor) end
    actor:ensure("npc_goals")
    actor.npc_goals.selectedGoalIndex = nil
    actor.npc_goals.goals = goals
    actor.npc_goals.capabilities = methods
    actor.npc_goals.evaluationCooldownSeconds = 0
    return actor.npc_goals
end

GoalSystem.addGoal = require("src.systems.goals.goal_state").add

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

local function condition(goal, actor, party, map, traveling)
    if goal.type == "return_home" then
        local home, atHome = Importance.home(actor, map)
        if not home then return false, "home_missing" end
        if atHome then return false end
        if not party then return false, "no_commanded_party" end
        if not actor.npc_goals.capabilities.travel then return false, "travel_not_allowed" end
        return false
    end
    if goal.type == "acquire_knowledge" then
        local eventId = Knowledge.findKnownInformation(actor, goal)
        if eventId then goal.knownEventId = eventId; return true end
        return false, not goal.investigation and "awaiting_knowledge" or nil
    end
    if goal.type == "rest_and_recover" then
        if not actor.memory then return false, "important_actor_required" end
        if GoalSystem.getImportance(goal, actor, party) == 0 then return true end
        if Importance.recoveryHealth(goal, actor, party) == 0 then return false, Treatment.recoveryState(actor, party) end
        return false
    end
    if goal.type == "provide_service" then
        if not actor.memory then return false, "important_actor_required" end
        if Services.hasObligation(actor, {world = actor.__world}) then return false, "conflicting_obligation" end
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
        if not actor.npc_goals.capabilities.caravanFormation then
            if not party then return false, "no_commanded_party" end
            if not actor.npc_goals.capabilities.raid then return false, "raid_not_allowed" end
            if not traveling[party.id] then return false, "raid_requires_traveling_party" end
            if not (party.hostile == true or party.faction == "bandits") then return false, "raider_not_hostile" end
        end
        return GoalSystem.getImportance(goal, actor, party) == 0
    end
    if goal.type ~= "reach_location" then return false end
    if not party then return false, "no_commanded_party" end
    if not actor.npc_goals.capabilities.travel then return false, "travel_not_allowed" end
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
        params = {destinationLocationId = goal.type == "return_home" and actor.homeLocationId or goal.destinationLocationId}
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

local function provideService(goal, actor, party, map, playerParty, traveling, localOnly)
    local context = {world = actor.__world, map = map}
    if Services.hasObligation(actor, context) then return false, "conflicting_obligation" end
    if actor.activeEncounterId or (party and party.activeEncounterId) then return false, "in_encounter" end
    if not localOnly then goal.status = "active" end
    local closed = {}
    for _, known in ipairs(Knowledge.getKnownEvents(actor)) do
        if known.serviceId and known.status and known.status ~= "open" then closed[known.serviceId] = true end
    end
    for _, offer in ipairs(Knowledge.getKnownEvents(actor, nil, "service_offered")) do
        if offer.serviceId and offer.locationId and offer.employerId and offer.requiredCapability
            and actor.npc_goals.capabilities[offer.requiredCapability] and not closed[offer.serviceId]
            and (not localOnly or goal.pursuedServiceId == offer.serviceId) then
            local here = Services.getLocation(actor, context)
            if here and here.id == offer.locationId then
                local request = Services.getRequest(offer.serviceId, context)
                local assign = request and request.type == "lead_caravan" and Caravans.assign or Services.assign
                if request and request.type == "investigate" then assign = Investigations.assign end
                local ok, result = assign(offer.serviceId, actor, context)
                if ok and not localOnly then
                    local state = actor.npc_goals
                    local obligation = state.goals[#state.goals]
                    if GoalSystem.getImportance(obligation, actor, party) >= GoalSystem.getImportance(goal, actor, party) + 5 then
                        state.selectedGoalIndex = #state.goals
                        obligation.status = "active"
                    end
                end
                goal.lastServiceResult = {serviceId = offer.serviceId, success = ok,
                    reason = not ok and result or nil}
                goal.retrySeconds = GoalSystem.retrySeconds
                return true
            end
            if localOnly then return false end
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

-- Relinquish only the exact owned attempt. Assignment/capability state stays intact.
local function release(goal, actor, reason)
    if not goal then return true end
    local owned = goal.activity
    local owner = owned and EcsWorld.findPartyById(owned.partyId, actor.__world)
    if owner and owner.world_activity and owner.world_activity.sequence == owned.sequence
        and owner.world_activity.goalActorId == actor.id and owner.world_activity.status == "active" then
        if owner.activeEncounterId or actor.activeEncounterId then return false end
        local work = actor.investigation_work
        if work and work.serviceId == goal.serviceId and work.activitySequence == owned.sequence then
            if work.phase == "searching" then
                work.searchElapsed = (work.searchBase or 0) + (owner.world_activity.elapsedSeconds or 0)
                work.phase = "traveling"
            end
            work.activitySequence, work.activityType = nil, nil
        end
        if not WorldActivitySystem.cancel(owner, reason) then return false end
    end
    observeActivity(goal, actor, owner)
    if goal.type == "rest_and_recover" then goal.recovering = nil end
    return true
end

local function updateActor(actor, party, dt, map, playerParty, traveling)
    local state = actor.npc_goals
    local previous = state.goals[state.selectedGoalIndex]
    Investigations.recognize(actor, {world = actor.__world, map = map})
    local candidates, scores = {}, {}
    for index, goal in ipairs(state.goals) do
        goal.retrySeconds = math.max(0, (goal.retrySeconds or 0) - dt)
        goal.healingRetrySeconds = math.max(0, (goal.healingRetrySeconds or 0) - dt)
        observeActivity(goal, actor, party)
        local satisfied, reason = condition(goal, actor, party, map, traveling)
        local score = GoalSystem.getImportance(goal, actor, party)
        if satisfied or score == 0 then
            if goal.status ~= "cancelled" and goal.status ~= "completed" and goal.status ~= "invalid" then
                goal.status, goal.reason = "satisfied", nil
            end
        elseif reason then
            goal.status, goal.reason = "blocked", reason
        else
            goal.status, goal.reason = goal.activity and "active" or "pending", nil
            if goal.retrySeconds <= 0 or goal.activity or goal == previous or goal.type == "provide_service"
                or goal.type == "rest_and_recover" then
                candidates[#candidates + 1] = {goal = goal, index = index, importance = score}
                scores[goal] = score
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.importance == b.importance then return a.index < b.index end
        return a.importance > b.importance
    end)
    local best = candidates[1]
    if previous and scores[previous] and (not best or best.importance < scores[previous] + 5) then
        best = {goal = previous, index = state.selectedGoalIndex, importance = scores[previous]}
    end
    local selected = best and best.goal
    if previous ~= selected then
        local reason = previous and (scores[previous] and "higher_importance" or "goal_ineligible") or "goal_available"
        if not release(previous, actor, previous and previous.reason or (selected and "goal_interrupted" or "goal_satisfied")) then return end
        state.previousDominantGoal = previous and previous.type
        state.lastSwitchReason = reason
    end
    state.selectedGoalIndex = best and best.index
    -- Clear any no-longer-eligible owned attempt, even after service resolution cleared selection.
    for _, goal in ipairs(state.goals) do
        if goal ~= selected and goal.activity then
            if not release(goal, actor, "goal_interrupted") then return end
        end
    end
    if not selected then return end
    local ordered = {{goal = selected, index = state.selectedGoalIndex}}
    for _, candidate in ipairs(candidates) do
        if candidate.goal ~= selected then ordered[#ordered + 1] = candidate end
    end
    for _, candidate in ipairs(ordered) do
        selected = candidate.goal
        if candidate.goal ~= best.goal then
            state.previousDominantGoal, state.lastSwitchReason = best.goal.type, "goal_unavailable"
        end
        state.selectedGoalIndex = candidate.index
        local activity = party and party.world_activity
        if actor.activeEncounterId or (party and party.activeEncounterId) or (party and party == playerParty) then
            selected.status, selected.reason = "blocked", "party_unavailable"; return
        end
        if selected.type == "return_home" then
            local _, atHome = Importance.home(actor, map)
            if atHome then selected.status = "active"; return end
        end
        if selected.type == "rest_and_recover" then
            selected.recovering = true
            Services.tryRecoveryHealing(actor, selected, {world = actor.__world, map = map})
            if Importance.recoveryHealth(selected, actor, party) == 0
                and GoalSystem.getImportance(selected, actor, party) > 0 then
                local reason = Treatment.recoveryState(actor, party)
                release(selected, actor, reason)
                selected.status, selected.reason = "blocked", reason
                state.selectedGoalIndex = nil
                return
            end
            if GoalSystem.getImportance(selected, actor, party) == 0 then
                release(selected, actor, "goal_satisfied")
                selected.status, state.selectedGoalIndex = "satisfied", nil
                return
            end
        end
        if selected.activity then
            selected.status = "active"
            if selected.type == "acquire_gold" and activity and activity.type == "roam" and state.capabilities.raid then
                local target = RaidActivity.selectTarget(party, map, playerParty)
                if target and WorldActivitySystem.cancel(party, "opportunity_detected") then selected.detectedTargetId = target.id end
            end
            return
        end
        if (activity and (activity.status ~= "idle" or (activity.retryCooldownSeconds or 0) > 0))
            or (map.partyEncounterCooldowns and (map.partyEncounterCooldowns[party and party.id] or 0) > 0) then
            selected.status, selected.reason = "blocked", "party_already_active"; return
        end
        if selected.retrySeconds > 0 and not (selected.type == "rest_and_recover" and not party) then return end
        local started, reason
        if selected.type == "rest_and_recover" and not party then
            selected.status = "active"; return
        elseif selected.type == "provide_service" then
            started, reason = provideService(selected, actor, party, map, playerParty, traveling)
        elseif selected.type == "acquire_knowledge" then
            started, reason = Investigations.commission(actor, selected, {world = actor.__world, map = map})
        elseif selected.type == "fulfill_obligation" then
            selected.status, selected.reason = "active", "awaiting_service_execution"; return
        elseif selected.type == "acquire_gold" and state.capabilities.caravanFormation then
            started, reason = Caravans.begin(actor, {world = actor.__world, map = map})
            if not started and party and state.capabilities.raid then
                started, reason = requestActivity(selected, actor, party, map, playerParty, traveling)
            end
        elseif party then
            started, reason = requestActivity(selected, actor, party, map, playerParty, traveling)
        else reason = "no_commanded_party" end
        if started then selected.status = "active"; return end
        selected.status, selected.reason = "blocked", reason
        if selected.type == "rest_and_recover" then selected.recovering = nil end
        selected.retrySeconds = GoalSystem.retrySeconds
        state.selectedGoalIndex = nil
    end
end

-- dt is elapsed world-simulation seconds, never render-frame time.
function GoalSystem.update(dt, map, playerParty)
    if not map or dt <= 0 or not EcsWorld.campaign then return end
    -- Concord queries see committed entities; include freshly created actors too.
    EcsWorld.campaign:__flush()
    GoalSystem.evaluate(dt, map, playerParty)
end

-- CampaignRuntime has already flushed before service/caravan coordination.
function GoalSystem.evaluate(dt, map, playerParty)
    if not map or dt <= 0 or not EcsWorld.campaign then return end
    local world = EcsWorld.campaign
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
    local actors = world:query({"unit", "npc_goals"})
    -- Arrival work precedes every leader's departure, including a passenger's leader.
    for _, actor in ipairs(actors) do
        if not actor.player and (actor.hp or 0) > 0 and EcsWorld.findActorById(actor.id, world) == actor then
            if actor.memory and (not actor.personality or actor.responsibility ~= nil) then
                require("src.data.types.personality").normalize(actor)
            end
            for _, goal in ipairs(actor.npc_goals.goals) do
                local spec = Definitions.goals[goal.type]
                if spec and spec.advanceImportance then spec.advanceImportance(goal, actor, commanded[actor.id], dt, map) end
                if goal.accumulatedImportance ~= nil then goal.accumulatedImportance = Importance.clamp(goal.accumulatedImportance) end
                if goal.type == "provide_service" and goal.pursuedServiceId
                    and goal.status ~= "cancelled" and goal.status ~= "invalid" and goal.status ~= "completed"
                    and Services.isProviding(actor, {world = world, map = map}) then
                    provideService(goal, actor, commanded[actor.id], map, playerParty, traveling, true)
                end
            end
        end
    end
    for _, actor in ipairs(actors) do
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
