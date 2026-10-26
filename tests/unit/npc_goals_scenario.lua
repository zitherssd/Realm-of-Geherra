local EcsWorld = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Location = require("src.ecs.assemblages.location")
local Map = require("src.world.map")
local PartySystem = require("src.systems.party_system")
local GoalSystem = require("src.systems.goal_system")
local WorldActivitySystem = require("src.systems.world_activity_system")
local WorldEncounterSystem = require("src.systems.world_encounter_system")
local GameContext = require("src.game.game_context")
local EventBus = require("src.core.event_bus")
local PartyAiSystem = require("src.systems.party_ai_system")

local function setup()
    EventBus.init()
    local world = EcsWorld.init()
    local map = Map.new("goals-map")
    GameContext.data.currentMap = map
    GameContext.data.playerParty = nil
    WorldActivitySystem.init()
    WorldEncounterSystem.init()
    return world, map
end

local function partyAt(world, map, id, x)
    local actor = Unit.create(world, "soldier", id .. "-actor")
    actor.sight, actor.profile = 10000, 0
    local party = Party.create(world, id, actor.id, id)
    PartySystem.addActor(party, actor)
    party.x, party.y = x or 100, 100
    assert(map:addParty(party))
    return party, actor
end

local function tick(map, dt)
    GoalSystem.update(dt, map, nil)
    WorldActivitySystem.update(dt, map, nil)
end

local function travelSelectionAndArrival()
    local world, map = setup()
    local origin = Location.create(world, "goal-origin", "Origin")
    local destination = Location.create(world, "goal-destination", "Destination")
    origin.x, origin.y, origin.siteId = 100, 100, "a"
    destination.x, destination.y, destination.siteId = 500, 100, "b"
    map:addLocation(origin)
    map:addLocation(destination)
    map.worldGen = {roads = {{from = "a", to = "b", points = {
        {x = 100, y = 100}, {x = 500, y = 100}
    }}}}
    local party, actor = partyAt(world, map, "goal-traveler")
    party.hostile = true
    assert(map:stationParty(origin, party))
    local state = GoalSystem.configure(actor, {
        {type = "acquire_gold", amount = 500, priority = 100},
        {type = "reach_location", destinationLocationId = destination.id, priority = 20}
    }, {travel = true})
    tick(map, 0)
    assert(party.world_activity.status == "idle", "paused goal evaluation started travel")
    tick(map, 0.1)
    assert(party.world_activity.type == "travel", "unavailable high-priority goal blocked travel")
    local sequence = party.world_activity.sequence
    GoalSystem.addGoal(actor, {type = "reach_location", destinationLocationId = origin.id, priority = 200})
    tick(map, 1)
    assert(party.world_activity.sequence == sequence, "new priority preempted an active goal")
    -- Remove the extra pending condition so this scenario observes a single journey.
    table.remove(state.goals)
    for _ = 1, 100 do
        tick(map, 0.25)
        if state.goals[2].status == "satisfied" then break end
    end
    assert(state.goals[2].status == "satisfied", "actual travel arrival did not satisfy the goal")
    assert(destination.stationedParties[1] == party and #map:getParties() == 0)
    assert(state.goals[2].lastOutcome.status == "completed")
    assert(actor.npc_goals:serialize().goals[2].destinationLocationId == destination.id)
    -- Terminal cooldowns must also advance on stationed parties for future departures.
    for _ = 1, 8 do tick(map, 1) end
    assert(party.world_activity.retryCooldownSeconds == 0)
    assert(party.world_activity.sequence == sequence, "satisfied goal restarted travel")

    local returnGoal = GoalSystem.addGoal(actor, {
        type = "reach_location", destinationLocationId = origin.id, priority = 50
    })
    -- Explicit activities retain ownership even if a configured goal wants the same trip.
    assert(WorldActivitySystem.start(party, "travel", {destinationLocationId = origin.id}, map))
    tick(map, 1)
    assert(returnGoal.activity == nil and party.world_activity.sequence == sequence + 1,
        "goal replaced or claimed an externally assigned activity")
    WorldActivitySystem.cancel(party, "external_cancel")
    for _ = 1, 8 do tick(map, 1) end
    assert(returnGoal.activity and returnGoal.status == "active")
    origin:destroy()
    tick(map, 1)
    tick(map, 1)
    assert(returnGoal.status == "blocked" and returnGoal.reason == "destination_missing",
        "removed destination did not block the in-flight goal")
    assert(returnGoal.lastOutcome.reason == "destination_missing")
    local returnAttempts = returnGoal.attempts
    for _ = 1, 12 do tick(map, 1) end
    assert(returnGoal.attempts == returnAttempts, "removed destination caused a restart loop")
end

local function outcomesBackoffAndLegacy()
    local world, map = setup()
    local party, actor = partyAt(world, map, "goal-raider")
    party.hostile = true
    local target = partyAt(world, map, "goal-target", 2000)
    target.isTraderParty, target.state = true, "wander"
    local goal = GoalSystem.configure(actor, {
        {type = "acquire_gold", amount = 100}
    }, {raid = true}).goals[1]
    map.partyEncounterCooldowns[party.id] = 1
    tick(map, 0.1)
    assert(party.world_activity.status == "idle", "goals ignored encounter cooldown")
    map.partyEncounterCooldowns[party.id] = nil
    party.activeEncounterId = "reserved"
    tick(map, 1)
    assert(party.world_activity.status == "idle", "goals ignored an encounter reservation")
    party.activeEncounterId = nil
    tick(map, 1)
    assert(goal.status == "active" and party.world_activity.type == "raid")
    local attempts = goal.attempts
    -- An executor's reported success cannot manufacture the desired gold.
    party.world_activity.status = "completed"
    tick(map, 1)
    assert(goal.status ~= "satisfied" and goal.retrySeconds > 0)
    local evaluationCooldown = actor.npc_goals.evaluationCooldownSeconds
    tick(map, 0)
    assert(goal.retrySeconds == GoalSystem.retrySeconds, "paused goal backoff advanced")
    assert(actor.npc_goals.evaluationCooldownSeconds == evaluationCooldown,
        "paused goal evaluation timer advanced")
    for _ = 1, 3 do tick(map, 1) end
    assert(goal.attempts == attempts, "goal restarted during outcome backoff")
    -- A later explicit activity's outcome must not replace the goal's own outcome.
    WorldActivitySystem.update(5, map, nil)
    assert(WorldActivitySystem.start(party, "raid"))
    WorldActivitySystem.cancel(party, "external_cancel")
    tick(map, 1)
    assert(goal.lastOutcome.status == "completed" and goal.lastOutcome.reason ~= "external_cancel",
        "a different activity sequence was attributed to this goal")
    for _ = 1, 12 do tick(map, 1) end
    assert(goal.attempts > attempts, "unsatisfied goal never retried")
    WorldActivitySystem.cancel(party, "test_cancel")
    tick(map, 1)
    assert(goal.lastOutcome.status == "cancelled" and goal.lastOutcome.reason == "test_cancel")
    PartySystem.addTreasury(party, 100)
    tick(map, 1)
    assert(goal.status == "satisfied")
    WorldActivitySystem.ensureDefaultActivities(map, nil)
    assert(party.world_activity.type == nil, "legacy Raid restarted a satisfied goal")

    local incapable, incapableActor = partyAt(world, map, "incapable", 100)
    incapable.hostile = true
    GoalSystem.configure(incapableActor, {{type = "acquire_gold", amount = 10}}, {})
    local legacy = partyAt(world, map, "legacy", 100)
    legacy.hostile = true
    tick(map, 1)
    assert(incapable.world_activity.status == "idle", "hostility bypassed explicit capability")
    assert(legacy.world_activity.type == "raid", "legacy automatic Raid no longer works")

    local resident = Unit.create(world, "soldier")
    local stranded = GoalSystem.configure(resident, {{type = "acquire_gold", amount = 50}}, {raid = true})
    local partyCount = #map:getParties()
    tick(map, 1)
    assert(stranded.goals[1].reason == "no_commanded_party" and #map:getParties() == partyCount)
    local invalid = GoalSystem.addGoal(actor, {type = "reach_location", destinationLocationId = "removed"})
    tick(map, 1)
    assert(invalid.status == "blocked" and invalid.reason == "destination_missing")
    party:destroy()
    tick(map, 1)
    assert(goal.status == "blocked" and goal.reason == "no_commanded_party")
end

local function realRaidTreasuryFeedback()
    local world, map = setup()
    local party, actor = partyAt(world, map, "wealth-raider")
    party.hostile = true
    actor.hp, actor.maxHp, actor.stats.health = 10000, 10000, 10000
    actor.stats.attack, actor.stats.defense, actor.stats.battle_speed = 500, 100, 120
    actor.skills = {javelin_throw = {learned = true}}
    local target, victim = partyAt(world, map, "wealth-caravan", 4000)
    target.state, target.isTraderParty, target.treasury = "wander", true, 200
    victim.hp, victim.maxHp, victim.stats.health = 20, 20, 20
    victim.skills = {}
    local goal = GoalSystem.configure(actor, {{type = "acquire_gold", amount = 1,
        roam = {originX = 100, originY = 100, radius = 80}}}, {raid = true, roam = true}).goals[1]
    tick(map, 0.1)
    assert(party.world_activity.type == "roam", "gold goal did not seek an unseen opportunity")
    target.x, target.y = party.x + 10, party.y
    tick(map, 1)
    assert(party.world_activity.status == "idle" and goal.detectedTargetId == target.id)
    tick(map, 0.1)
    assert(party.activeEncounterId, "goal-selected raid did not enter the real encounter pipeline")
    for _ = 1, 200 do
        WorldEncounterSystem.update(0.25, map)
        tick(map, 0.25)
        if goal.status == "satisfied" then break end
    end
    assert(goal.status == "satisfied" and party.treasury >= 1,
        "real raid loot did not feed back into the wealth goal")
    local attempts = goal.attempts
    for _ = 1, 20 do tick(map, 1) end
    assert(goal.attempts == attempts and party.world_activity.type == nil,
        "wealth goal kept raiding after reaching the actual treasury target")
end

local function roamingOpportunityOwnership()
    local world, map = setup()
    local party, actor = partyAt(world, map, "seeker")
    actor.sight, party.hostile = 400, true
    local target = partyAt(world, map, "opportunity", 1500)
    target.isTraderParty, target.state = true, "wander"
    local territory = {originX = 100, originY = 100, radius = 80, durationSeconds = 30}
    local goal = GoalSystem.configure(actor, {{type = "acquire_gold", amount = 100, roam = territory}},
        {raid = true, roam = true}).goals[1]
    -- Explicit roaming is never claimed or interrupted, even with visible prey.
    assert(WorldActivitySystem.start(party, "roam", territory, map))
    target.x = 150
    GoalSystem.update(1, map)
    assert(not goal.activity and party.world_activity.status == "active")
    WorldActivitySystem.cancel(party, "manual_stop")
    WorldActivitySystem.update(0, map)
    WorldActivitySystem.update(5, map)
    target.x = 1500
    tick(map, 1)
    local activity = party.world_activity
    assert(activity.type == "roam" and activity.goalActorId == actor.id)
    local sequence, x, y = activity.sequence, party.x, party.y
    target.x, target.y = x + 80, y
    goal.retrySeconds = 100 -- Active observation must not use attempt backoff.
    tick(map, 0)
    assert(activity.sequence == sequence and activity.status == "active" and not goal.detectedTargetId)
    assert(party.x == x and party.y == y and goal.retrySeconds == 100)
    party.activeEncounterId = "reservation"
    tick(map, 1)
    assert(activity.status == "active" and not goal.detectedTargetId)
    party.activeEncounterId = nil
    GoalSystem.update(1, map)
    assert(activity.status == "cancelled" and activity.sequence == sequence)
    assert(goal.detectedTargetId == target.id and activity.waypoints, "handoff bypassed cancellation")
    PartyAiSystem.update(1, map, {})
    WorldActivitySystem.update(1, map)
    assert(activity.status == "idle" and not activity.waypoints and activity.retryCooldownSeconds == 0)
    assert(party.x == x and party.y == y, "cancelled Roam kept moving")
    GoalSystem.update(0.1, map)
    assert(activity.type == "raid" and activity.params.targetPartyId == target.id)
    assert(goal.activity.sequence == sequence + 1 and goal.lastOutcome.reason == "opportunity_detected")
    -- Losing the selected target before acquisition cannot silently select another.
    target.x = 1500
    local other = partyAt(world, map, "other-caravan", x + 50)
    other.y, other.isTraderParty, other.state = y, true, "wander"
    WorldActivitySystem.update(0.1, map)
    assert(activity.status == "cancelled" and activity.reason == "no_target" and not activity.targetId)
    tick(map, 1)
    assert(goal.lastOutcome.reason == "no_target" and goal.retrySeconds > 0)
    other.x = 1500
    for _ = 1, 11 do tick(map, 1) end
    assert(activity.type == "roam", "failed raid did not return to seeking")
    PartySystem.addTreasury(party, 100)
    tick(map, 1)
    assert(goal.status == "satisfied" and activity.status == "idle")
    assert(activity.lastActivity.reason == "goal_satisfied")
end

local function disappearingOpportunityAndDuration()
    local world, map = setup()
    local party, actor = partyAt(world, map, "short-seeker")
    actor.sight, party.hostile = 400, true
    local target = partyAt(world, map, "vanishing-caravan", 1500)
    target.isTraderParty, target.state = true, "wander"
    local goal = GoalSystem.configure(actor, {{type = "acquire_gold", amount = 100,
        roam = {originX = 100, originY = 100, radius = 80, durationSeconds = 2}}},
        {raid = true, roam = true}).goals[1]
    party.state = "wander"
    party.wanderTarget = {x = 1500, y = 1500}
    tick(map, 0.1)
    target.x, target.y = party.x + 50, party.y
    tick(map, 1)
    assert(goal.detectedTargetId == target.id)
    target.x = 1500
    tick(map, 0.1)
    assert(party.world_activity.type == "roam" and not goal.detectedTargetId)
    tick(map, 2)
    tick(map, 0.1)
    assert(goal.status ~= "satisfied" and goal.lastOutcome.reason == "duration_elapsed" and goal.retrySeconds > 0)
    local attempts = goal.attempts
    local x, y = party.x, party.y
    tick(map, 0)
    assert(goal.attempts == attempts and goal.retrySeconds == GoalSystem.retrySeconds)
    for _ = 1, 5 do
        tick(map, 1)
        PartyAiSystem.update(1, map, {})
    end
    assert(party.x == x and party.y == y, "legacy wandering moved a seeker during backoff")
    for _ = 1, 6 do tick(map, 1) end
    assert(goal.attempts > attempts, "duration-limited seeking did not retry")
end

local function invalidCommandOwners()
    -- Each invalidation leaves direct map/roster references behind deliberately.
    for _, invalidation in ipairs({"removed_actor", "dead_actor", "changed_leader", "destroyed_party"}) do
        local world, map = setup()
        local party, actor = partyAt(world, map, "owner-raider")
        party.hostile = true
        local target = partyAt(world, map, "owner-target", 2000)
        target.isTraderParty, target.state = true, "wander"
        local goal = GoalSystem.configure(actor, {
            {type = "acquire_gold", amount = 100}
        }, {raid = true}).goals[1]
        tick(map, 0.1)
        assert(goal.activity and party.world_activity.goalActorId == actor.id)
        local attempts, sequence, x = goal.attempts, party.world_activity.sequence, party.x
        if invalidation == "removed_actor" then
            actor:destroy()
        elseif invalidation == "dead_actor" then
            actor.hp = 0
        elseif invalidation == "changed_leader" then
            local successor = Unit.create(world, "soldier")
            PartySystem.addActor(party, successor)
            PartySystem.setLeader(party, successor.id)
            GoalSystem.configure(successor, {}, {})
        else
            party:destroy()
        end
        -- A reserved battle owns its lifecycle until released.
        party.activeEncounterId = "reserved"
        tick(map, 1)
        assert(party.world_activity.status == "active")
        party.activeEncounterId = nil
        tick(map, 1)
        assert(party.world_activity.status == "idle" and party.x == x,
            invalidation .. " left its goal activity executing")
        assert(party.world_activity.lastActivity.reason == "goal_lost_command")
        for _ = 1, 12 do tick(map, 1) end
        assert(goal.attempts == attempts and party.world_activity.sequence == sequence,
            invalidation .. " issued another goal command")
        if invalidation == "changed_leader" then
            assert(goal.lastOutcome.reason == "goal_lost_command",
                "cancellation was not attributed to the original goal")
        end
    end
end

local Scenario = {}
function Scenario.run()
    travelSelectionAndArrival()
    outcomesBackoffAndLegacy()
    realRaidTreasuryFeedback()
    roamingOpportunityOwnership()
    disappearingOpportunityAndDuration()
    invalidCommandOwners()
    GameContext.data.currentMap = nil
    GameContext.data.playerParty = nil
end
return Scenario
