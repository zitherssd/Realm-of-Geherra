local EcsWorld = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Location = require("src.ecs.assemblages.location")
local Map = require("src.world.map")
local LocationSystem = require("src.systems.locations.location_system")
local PartySystem = require("src.systems.parties.party_system")
local Goals = require("src.systems.goals.goal_system")
local Activities = require("src.systems.world_activities.world_activity_system")
local Recovery = require("src.systems.actors.recovery")
local Time = require("src.systems.campaign.time_system")
local Movement = require("src.systems.parties.party_ai_system")
local Inspector = require("src.debug.inspector")
local Tools = require("src.debug.campaign_tools")
local Mode = require("src.debug.mode")

local function setup()
    local world = EcsWorld.init()
    local map = Map.new("recovery-map")
    local location = Location.create(world, "recovery-home", "Home")
    location.x, location.y = 100, 100
    map:addLocation(location)
    local actor = Unit.create(world, "soldier", "important-resident")
    actor:ensure("memory") -- Existing explicit important-character convention.
    actor.hp, actor.maxHp = 40, 100
    LocationSystem.addNPC(location, actor)
    Goals.configure(actor, {{type = "acquire_gold", amount = 100, priority = 2000},
        {type = "rest_and_recover"}}, {travel = true})
    return world, map, location, actor
end

local function tick(map, dt)
    Goals.update(dt, map)
    Recovery.update(dt, map)
    Movement.update(dt, map, {})
    Activities.update(dt, map)
end

local function residents()
    local world, map, location, actor = setup()
    local generic = Unit.create(world, "soldier")
    generic.hp = 10
    LocationSystem.addNPC(location, generic)
    Goals.configure(generic, {{type = "rest_and_recover"}}, {})
    local state, rest = actor.npc_goals, actor.npc_goals.goals[2]
    Time.setPaused(true)
    tick(map, Time.worldHoursToSeconds(Time.update(10)))
    assert(actor.hp == 40 and rest.status == "pending")
    Time.setPaused(false)
    tick(map, Time.worldHoursToSeconds(Time.update(1)))
    assert(actor.hp == 40 + 100 / Recovery.passiveHealSecondsToFull * Recovery.restHealMultiplier)
    assert(rest.status == "active" and state.evaluationMode == "independent resident")
    assert(state.goals[1].attempts == 0 and #map:getParties() == 0)
    assert(generic.hp == 10 and generic.npc_goals.evaluationMode == "inactive")
    local hp = actor.hp
    tick(map, 0)
    assert(actor.hp == hp)
    tick(map, 64)
    tick(map, 1) -- Goal satisfaction observes health from the previous healing pass.
    assert(actor.hp <= 100 and rest.status == "satisfied", tostring(actor.hp) .. ": " .. rest.status .. ": " .. tostring(rest.reason))
    tick(map, 1)
    assert(state.goals[1].reason == "no_commanded_party")
    actor.hp = 70
    tick(map, 1)
    assert(actor.hp > 70 and rest.status == "active" and rest.recovering,
        "state-dependent recovery must react above the former injury threshold")
    actor.hp = 59
    tick(map, 1)
    assert(actor.hp > 59)
    local lines = table.concat(Inspector.lines(map, "unit", actor.id), "\n")
    assert(lines:find("independent resident") and lines:find("HP:") and lines:find("rest_and_recover"))
    Mode.enabled = true
    assert(Tools.addRecoveryGoal(map, actor.id))
    assert(#state.goals == 2, "debug action duplicated recovery goal")
    assert(not Tools.addRecoveryGoal(map, generic.id))
    Mode.enabled = false
    actor.activeEncounterId = "reserved"
    hp = actor.hp
    tick(map, 1)
    assert(actor.hp == hp)
    actor.activeEncounterId = nil
    LocationSystem.removeNPC(location, actor)
    tick(map, 1)
    assert(actor.hp == hp and state.evaluationMode == "inactive")
    LocationSystem.addNPC(location, actor)
    actor.hp = 0
    tick(map, 10)
    assert(actor.hp == 0)
    actor.hp = hp
    actor:destroy()
    tick(map, 10)
    assert(actor.hp == hp)
end

local function partyRecovery()
    local world, map, location, actor = setup()
    LocationSystem.removeNPC(location, actor)
    local party = Party.create(world, "Resting party", actor.id)
    PartySystem.addActor(party, actor)
    party.x, party.y = 100, 100
    assert(map:addParty(party))
    assert(map:stationParty(location, party)) -- Already arrived: exercise Rest rather than recovery travel.
    party.state, party.wanderTarget = "wander", {x = 900, y = 100}
    -- A stale resident reference must never produce a second evaluation.
    location.npcs[#location.npcs + 1] = actor
    tick(map, 1)
    local rest = actor.npc_goals.goals[2]
    assert(actor.npc_goals.evaluationMode == "party leader")
    assert(party.world_activity.type == "rest" and rest.activity)
    assert(actor.hp == 40 + 100 / Recovery.passiveHealSecondsToFull * Recovery.restHealMultiplier
        and party.x == 100, "duplicate recovery or movement during Rest")
    local hp = actor.hp
    party.activeEncounterId = "reserved"
    tick(map, 5)
    assert(actor.hp == hp and party.world_activity.type == "rest")
    assert(not Goals.cancelActivities(actor))
    party.activeEncounterId = nil
    tick(map, 0)
    assert(actor.hp == hp)
    LocationSystem.removeNPC(location, actor)
    tick(map, 40)
    assert(actor.hp <= actor.maxHp and party.world_activity.lastActivity.reason == "recovered")
    tick(map, 1)
    assert(rest.status == "satisfied" and not rest.activity)
    assert(actor.npc_goals.goals[1].status ~= "satisfied")
    -- Membership changes preserve exactly the same goal objects.
    PartySystem.removeActor(party, actor)
    LocationSystem.addNPC(location, actor)
    actor.hp = 40
    tick(map, 1)
    assert(rest == actor.npc_goals.goals[2] and rest.status == "active")
    assert(actor.npc_goals.evaluationMode == "independent resident")
    PartySystem.addActor(party, actor)
    local successor = Unit.create(world, "soldier")
    PartySystem.addActor(party, successor)
    PartySystem.setLeader(party, successor.id)
    hp = actor.hp
    tick(map, 5)
    assert(actor.hp > hp and actor.npc_goals.evaluationMode == "local party member",
        "non-leader member should receive passive party recovery without commanding party rest")
end

local function interruptionAndResume()
    local world, map, location, actor = setup()
    actor.hp = 100
    LocationSystem.removeNPC(location, actor)
    local party = Party.create(world, "Traveler", actor.id)
    PartySystem.addActor(party, actor)
    party.x, party.y = 100, 100
    map:addParty(party)
    local destination = Location.create(world, "recovery-destination", "Destination")
    destination.x, destination.y = 900, 100
    map:addLocation(destination)
    Goals.configure(actor, {{type = "reach_location", destinationLocationId = destination.id},
        {type = "rest_and_recover"}}, {travel = true})
    tick(map, 0.1)
    local travel, rest = unpack(actor.npc_goals.goals)
    assert(party.world_activity.type == "travel")
    actor.hp = 40
    local x = party.x
    tick(map, 1)
    assert(party.world_activity.lastActivity.reason == "goal_interrupted" and party.x == x)
    assert(travel.status ~= "satisfied")
    for _ = 1, 60 do tick(map, 1) end
    assert(rest.status == "satisfied" and travel.attempts >= 2, "ordinary goal did not resume")
    -- Explicit activities are never interrupted or claimed.
    Goals.cancelActivities(actor)
    Activities.update(5, map)
    assert(Activities.start(party, "roam", {originX = party.x, originY = party.y, radius = 50}, map))
    actor.hp = 40
    Goals.update(1, map)
    assert(not rest.activity and party.world_activity.type == "roam" and party.world_activity.status == "active")
    assert(rest.reason == "party_already_active", tostring(rest.reason) .. ": " .. tostring(actor.npc_goals.selectedGoalIndex))
end

local function invalidRestOwners()
    for _, invalidation in ipairs({"dead", "removed", "new_leader", "removed_party"}) do
        local world, map, location, actor = setup()
        LocationSystem.removeNPC(location, actor)
        local party = Party.create(world, "Rest owner", actor.id)
        PartySystem.addActor(party, actor)
        map:addParty(party)
        assert(map:stationParty(location, party))
        tick(map, 1)
        assert(party.world_activity.type == "rest")
        if invalidation == "dead" then
            actor.hp = 0
        elseif invalidation == "removed" then
            actor:destroy()
        elseif invalidation == "new_leader" then
            local successor = Unit.create(world, "soldier")
            PartySystem.addActor(party, successor)
            PartySystem.setLeader(party, successor.id)
        else
            party:destroy()
        end
        local hp = actor.hp
        tick(map, 5)
        if invalidation == "new_leader" then
            assert(actor.hp == hp + 100 / Recovery.passiveHealSecondsToFull * 5,
                "former leader should receive only passive healing")
        else
            assert(actor.hp == hp, invalidation .. " continued healing")
        end
        assert(party.world_activity.status == "idle" and party.state ~= "rest")
    end
end

local function allPartyMembers()
    local world, map, home, resident = setup()
    -- No goal configuration or personal memory is required for party healing.
    local function makeParty(name, stationed)
        local party = Party.create(world, name)
        local troop = Unit.create(world, "soldier")
        local companion = Unit.create(world, "companion")
        troop.maxHp, companion.maxHp = 100, 100
        troop.hp, companion.hp = 40, 40
        PartySystem.addActor(party, troop)
        PartySystem.addActor(party, companion)
        map:addParty(party)
        if stationed then assert(map:stationParty(home, party)) end
        return party, troop, companion
    end
    local player, playerActor = makeParty("Player")
    local playerCharacter = Unit.create(world, "player")
    playerCharacter:ensure("player")
    playerCharacter.hp, playerCharacter.maxHp = 40, 100
    PartySystem.addActor(player, playerCharacter)
    local traveling, troop, companion = makeParty("Traveling NPC")
    local stationed, stationedActor = makeParty("Stationed NPC", true)
    local dead = Unit.create(world, "soldier")
    dead.hp = 0
    PartySystem.addActor(traveling, dead)
    local removed = Unit.create(world, "soldier")
    removed.hp = 20
    PartySystem.addActor(traveling, removed)
    removed:destroy()
    Recovery.update(0, map, player)
    assert(troop.hp == 40 and playerActor.hp == 40)
    Recovery.update(3, map, player)
    for _, actor in ipairs({playerCharacter, playerActor, player.actors[2], troop, companion, stationedActor}) do
        assert(math.abs(actor.hp - (40 + actor.maxHp / 100)) < 1e-8,
            "party member did not receive the existing passive rate")
    end
    assert(dead.hp == 0 and removed.hp == 20 and resident.hp == 41,
        "independent residents should receive the same passive rate without choosing Rest")
    -- Player rest bonus is local to the player party, including its companions.
    local hp, otherHp = playerActor.hp, troop.hp
    Recovery.update(3, map, player, true)
    assert(math.abs(playerActor.hp - hp - playerActor.maxHp / 10) < 1e-8)
    assert(math.abs(playerCharacter.hp - 51) < 1e-8, "player character did not use the shared Rest multiplier")
    assert(math.abs(troop.hp - otherHp - troop.maxHp / 100) < 1e-8)
    local important = stationedActor
    important:ensure("memory")
    assert(Activities.start(stationed, "rest", {actorId = important.id}, map))
    local companionHp = stationed.actors[2].hp
    hp = important.hp
    Recovery.update(3, map, player)
    assert(math.abs(important.hp - hp - important.maxHp / 10) < 1e-8)
    assert(math.abs(stationed.actors[2].hp - companionHp - stationed.actors[2].maxHp / 10) < 1e-8,
        "Rest did not heal other party members")
    hp = troop.hp
    traveling.activeEncounterId = "reserved"
    Recovery.update(30, map, player)
    assert(troop.hp == hp and dead.hp == 0)
    traveling.activeEncounterId = nil
    companion.activeEncounterId = "reserved"
    hp = companion.hp
    Recovery.update(30, map, player)
    assert(companion.hp == hp)
    companion.activeEncounterId = nil
    Recovery.update(1000, map, player)
    assert(troop.hp == troop.maxHp and companion.hp == companion.maxHp)
    -- Even duplicate references across collections receive one healing step.
    troop.hp = 40
    home.stationedParties[#home.stationedParties + 1] = traveling
    Recovery.update(3, map, player)
    assert(math.abs(troop.hp - (40 + troop.maxHp / 100)) < 1e-8)
end

local function singleResidentPassAndMembership()
    local world, map, home, actor = setup()
    local originalGoals = actor.npc_goals
    -- Goal evaluation selects rest but must never change HP itself.
    Goals.update(1, map)
    assert(actor.hp == 40 and actor.npc_goals.goals[2].status == "active")
    home.npcs[#home.npcs + 1] = actor
    Recovery.update(3, map)
    assert(actor.hp == 50, "resident Rest applied extra healing or failed to deduplicate")
    assert(actor.lastRecovery.mode == "resting" and actor.lastRecovery.context == "independent resident")
    local lines = table.concat(Inspector.lines(map, "unit", actor.id), "\n")
    assert(lines:find("resting | independent resident", 1, true))
    actor.activeEncounterId = "reserved"
    local reserved = Recovery.encounterReservations(map)
    actor.activeEncounterId = nil -- Encounter completed during this tick.
    Recovery.update(3, map, nil, false, reserved)
    assert(actor.hp == 50 and actor.lastRecovery.mode == "suspended")
    Recovery.update(3, map)
    assert(actor.hp == 60, "resident recovery did not resume after an encounter")
    -- Joining a party between decision and recovery must switch to the party's
    -- passive rate, even with a stale local Rest flag/resident reference.
    local party = Party.create(world, "New party", actor.id)
    PartySystem.addActor(party, actor)
    LocationSystem.removeNPC(home, actor)
    LocationSystem.removeNPC(home, actor)
    assert(map:addParty(party))
    home.npcs[#home.npcs + 1] = actor -- Deliberately stale resident reference.
    Recovery.update(3, map)
    assert(actor.hp == 61 and actor.lastRecovery.context == "party member")
    -- Leaving between decision and recovery must not skip the resident's step.
    PartySystem.removeActor(party, actor)
    Recovery.update(3, map)
    assert(actor.hp == 71 and actor.lastRecovery.context == "independent resident")
    actor.hp = 89
    tick(map, 0.3)
    assert(actor.hp == 90)
    tick(map, 1)
    assert(actor.npc_goals.goals[2].status == "active" and actor.npc_goals.goals[2].recovering,
        "90% health must not silently disable positive recovery importance")
    tick(map, 3)
    tick(map, 1)
    assert(actor.hp == 100 and actor.npc_goals.goals[2].status == "satisfied")
    actor.hp = 90 -- Verify the ordinary passive rate without reevaluating motivation.
    assert(actor.npc_goals.goals[1].reason == "no_commanded_party")
    assert(actor.npc_goals == originalGoals, "recovery replaced unrelated goal data")
    local hp = actor.hp
    Recovery.update(3, map)
    assert(actor.hp == hp + 1 and actor.lastRecovery.mode == "passive")
    local unconfigured = Unit.create(world, "soldier")
    unconfigured:ensure("memory")
    unconfigured.hp, unconfigured.maxHp = 40, 100
    LocationSystem.addNPC(home, unconfigured)
    Recovery.update(3, map)
    assert(unconfigured.hp == 41 and not unconfigured.npc_goals,
        "independent important residents should not need goals for passive healing")
end

local Scenario = {}
function Scenario.run()
    residents()
    partyRecovery()
    interruptionAndResume()
    invalidRestOwners()
    allPartyMembers()
    singleResidentPassAndMembership()
    Time.setPaused(false)
end
return Scenario

