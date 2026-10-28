local World = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Location = require("src.ecs.assemblages.location")
local Parties = require("src.systems.parties.party_system")
local Locations = require("src.systems.locations.location_system")
local Map = require("src.world.map")
local Goals = require("src.systems.goals.goal_system")
local Definitions = require("src.systems.goals.goal_definitions")
local Activities = require("src.systems.world_activities.world_activity_system")
local Knowledge = require("src.systems.knowledge.knowledge_system")
local Events = require("src.systems.campaign.world_events")
local Visibility = require("src.systems.parties.visibility_system")
local Exchange = require("src.systems.knowledge.travel_knowledge_system")
local Time = require("src.systems.campaign.time_system")
local Context = require("src.game.game_context")
local Inspector = require("src.debug.inspector")
local Scenario = {}
local Tools = require("src.debug.campaign_tools")
local Mode = require("src.debug.mode")
local Overlay = require("src.ui.screens.debug_overlay")

local function setup()
    Context.init()
    local world, map = World.init(), Map.new("knowledge-search")
    map.width, map.height = 2000, 2000
    Context.data.currentMap = map
    local actor = Unit.create(world, "companion")
    local party = Party.create(world, "Searcher", actor.id)
    Parties.addActor(party, actor)
    party.x, party.y = 500, 500
    map:addParty(party)
    return world, map, party, actor
end

local function battle(world, subject, x)
    return Events.record(world, "battle_ended", {
        time = {day = 1, hour = 6}, mapId = "knowledge-search", encounterId = "encounter-" .. subject,
        battlefieldId = "remains-" .. subject, x = x or 500, y = 500,
        subjectIds = {subject}, participants = {{partyId = subject, actorIds = {"historical-actor"}}},
        outcome = "victory", eliminatedPartyIds = {subject}
    })
end

local function query(id)
    return {type = "acquire_knowledge", subject = {type = "party", id = id}, requiredDetails = {outcome = true}}
end

local function testMemoryAndGoals()
    local world, map, party, actor = setup()
    local definition = query("lost-party")
    local state = Goals.configure(actor, {definition}, {travel = true})
    definition.subject.id, definition.requiredDetails.outcome = "mutated", nil
    local goal = state.goals[1]
    assert(goal.subject.id == "lost-party" and goal.requiredDetails.outcome)
    local relevant, unrelated = battle(world, "lost-party"), battle(world, "other-party")
    Knowledge.learn(party, relevant.id, {"outcome"})
    Knowledge.learn(actor, unrelated.id, {"participants", "outcome"})
    local departure = Events.record(world, "party_departed", {time = {day = 1, hour = 5},
        subjectIds = {"lost-party"}, partyId = "lost-party", originLocationId = "old-place"})
    Knowledge.learn(actor, departure.id, {"party", "location"})
    Goals.update(1, map)
    assert(goal.status == "blocked" and goal.reason == "awaiting_knowledge")
    assert(party.world_activity.status == "idle", "Missing knowledge invented travel/search")
    Knowledge.learn(actor, relevant.id, {"location"})
    assert(not Knowledge.findKnownInformation(actor, {subject = goal.subject, requiredDetails = {location = true},
        eventType = "battle_ended"}), "Hidden subjects leaked from existence/location knowledge")
    Knowledge.learn(actor, relevant.id, {"participants"})
    Goals.update(1, map)
    assert(goal.status ~= "satisfied", "Partial battle satisfied an outcome query")
    Knowledge.share(party, actor, relevant.id)
    Goals.update(0, map)
    assert(goal.status ~= "satisfied", "Paused goal evaluation progressed")
    Goals.update(1, map)
    assert(goal.status == "satisfied" and goal.knownEventId == relevant.id)
    assert(Knowledge.findKnownInformation(actor, {eventId = relevant.id, requiredDetails = {outcome = true}}))
    assert(not Knowledge.findKnownInformation(actor, {eventId = "unknown", requiredDetails = {outcome = true}}))
    assert(not Knowledge.findKnownInformation(actor, {subject = goal.subject, requiredDetails = {current_location = true}}))
    assert(not pcall(Definitions.create, {type = "acquire_knowledge", subject = goal.subject,
        requiredDetails = {current_location = true}}))
    assert(not pcall(Definitions.create, {type = "acquire_knowledge", requiredDetails = {outcome = true}}))
    local form = Definitions.form(goal, party, function() end)
    local roundtrip = Definitions.create(Definitions.definition(form, function() end))
    assert(roundtrip.subject.id == goal.subject.id and roundtrip.requiredDetails.outcome)
    assert(table.concat(Inspector.lines(map, "party", party.id), "\n"):find("Knowledge subject: party / lost-party", 1, true))

    -- Independent important residents keep the same goal through recovery.
    local home = Location.create(world, nil, "Home")
    home.x, home.y = 500, 500
    map:addLocation(home)
    local resident = Unit.create(world, "companion")
    Locations.addNPC(home, resident)
    local residentState = Goals.configure(resident, {query("lost-party"), {type = "rest_and_recover"}})
    resident.hp = 1
    Goals.update(1, map)
    assert(residentState.goals[1].status ~= "satisfied" and #residentState.goals == 2)
    Knowledge.share(actor, resident, relevant.id)
    resident.hp = resident.maxHp
    Goals.update(1, map)
    assert(residentState.goals[1].status == "satisfied")

    -- Arrival's existing legitimate exchange supplies a resident's missing answer.
    local another = battle(world, "second-party")
    Knowledge.learn(actor, another.id, {"outcome"})
    local wanted = Goals.addGoal(resident, query("second-party"))
    local destination = Location.create(world, nil, "Destination")
    destination.x, destination.y = 700, 500
    map:addLocation(destination)
    Locations.removeNPC(home, resident)
    Locations.addNPC(destination, resident)
    map:stationParty(home, party)
    assert(Activities.start(party, "travel", {destinationLocationId = destination.id}, map))
    for _ = 1, 30 do Activities.update(0.25, map) end
    Goals.update(1, map)
    assert(wanted.status == "satisfied", "Arrival exchange did not satisfy resident knowledge goal")
end

local function testSearch()
    local world, map, party, actor = setup()
    local params = {originX = 500, originY = 500, radius = 150, durationSeconds = 8}
    assert(not Activities.start(party, "search", {originX = 500, originY = 500, radius = 150}, map))
    for key, value in pairs({radius = -1, durationSeconds = 0, originX = math.huge}) do
        local invalid = {originX = 500, originY = 500, radius = 150, durationSeconds = 8}
        invalid[key] = value
        assert(not Activities.start(party, "search", invalid, map))
    end
    local hidden = battle(world, "hidden-party", 1800)
    map:addBattlefieldRemains({id = hidden.battlefieldId, history = {position = {x = 1800, y = 500},
        encounterId = hidden.encounterId, eventId = hidden.id}, corpses = {}, loot = {items = {}, gold = 0}})
    Goals.configure(actor, {query("hidden-party")})
    assert(Activities.start(party, "search", params, map))
    assert(not Activities.start(party, "travel", {}, map), "Search lost activity ownership")
    assert(party.state == "search" and party.world_activity:serialize().params.durationSeconds == 8)
    assert(table.concat(Inspector.lines(map, "party", party.id), "\n"):find("Search elapsed", 1, true))
    local x, y = party.x, party.y
    Time.setPaused(true)
    Activities.update(Time.worldHoursToSeconds(Time.update(2)), map, party)
    assert(party.x == x and party.y == y and party.world_activity.elapsedSeconds == 0)
    Time.setPaused(false)
    party.activeEncounterId = "reservation"
    Activities.update(2, map, party)
    assert(party.x == x and party.y == y and party.world_activity.elapsedSeconds == 0)
    party.activeEncounterId = nil
    local moved = false
    for _ = 1, 32 do
        x, y = party.x, party.y
        Activities.update(0.25, map, party)
        Visibility.update(party, map)
        moved = moved or party.x ~= x or party.y ~= y
        assert((party.x - x)^2 + (party.y - y)^2 <= (70 * 0.25)^2 + 0.00001)
        assert((party.x - 500)^2 + (party.y - 500)^2 <= 150^2 + 0.00001)
        assert(not Knowledge.knows(actor, hidden.id), "Search learned unseen history")
    end
    assert(moved and party.world_activity.lastActivity.status == "completed")
    assert(party.world_activity.lastActivity.type == "search" and not party.world_activity.waypoints)
    assert(Events.count(world) == 1, "Search created history/discovery events")
    Goals.update(1, map)
    assert(actor.npc_goals.goals[1].status ~= "satisfied")
    Activities.update(5, map)
    assert(Activities.start(party, "search", params, map))
    -- Normal visibility, not Search, teaches a physically encountered site.
    local nearby = battle(world, "nearby-party", party.x)
    local nearbyGoal = Goals.addGoal(actor, query("nearby-party"))
    map:addBattlefieldRemains({id = nearby.battlefieldId, history = {position = {x = party.x, y = party.y},
        encounterId = nearby.encounterId, eventId = nearby.id}, corpses = {}, loot = {items = {}, gold = 0}})
    Visibility.update(party, map)
    Goals.update(1, map)
    assert(nearbyGoal.status == "satisfied" and actor.npc_goals.goals[1].status ~= "satisfied")
    assert(Activities.cancel(party, "manual_stop"))
    Activities.update(0, map)
    assert(party.world_activity.lastActivity.reason == "manual_stop" and not party.world_activity.elapsedSeconds)
    Activities.update(5, map)
    party.x = 1800
    assert(not Activities.start(party, "search", params, map), "Search accepted party outside its area")

    _, map, party = setup()
    map.isWalkable = function() return false end
    local started, reason = Activities.start(party, "search", params, map)
    assert(not started and reason == "no_roaming_destination" and party.world_activity.status == "idle")
    _, map, party = setup()
    assert(Activities.start(party, "search", params, map))
    map.isWalkable = function() return false end
    Activities.update(1, map)
    assert(party.world_activity.elapsedSeconds == 1)
    assert(map:removeParty(party.id))
    assert(party.world_activity.reason == "party_removed")
end

local function testNpcPhysicalDiscovery()
    local world, map, party, actor = setup()
    actor.sight = 40
    local troop = Unit.create(world, "soldier")
    troop.sight = 0
    Parties.addActor(party, troop)
    local player = Party.create(world, "Distant player")
    player.x, player.y = 1800, 1800
    map:addParty(player)
    local distant = Party.create(world, "Distant observer")
    local bystander = Unit.create(world, "companion")
    Parties.addActor(distant, bystander)
    distant.x, distant.y = 1500, 1500
    map:addParty(distant)
    local event = battle(world, "observed-party", 600)
    local site = {id = event.battlefieldId, profile = 0, history = {position = {x = 600, y = 500},
        encounterId = event.encounterId, eventId = event.id}, corpses = {}, loot = {items = {}, gold = 0}}
    map:addBattlefieldRemains(site)
    local goal = Goals.configure(actor, {query("observed-party")}).goals[1]
    Visibility.update(player, map)
    Goals.update(1, map, player)
    assert(not Knowledge.knows(actor, event.id) and goal.status ~= "satisfied")

    -- Force ordinary random sampling toward (620, 500), without consulting evidence.
    local random, sample = math.random, 0
    math.random = function() sample = sample + 1; return sample % 2 == 1 and 0 or 0.64 end
    local started, reason = Activities.start(party, "search", {originX = 500, originY = 500,
        radius = 150, durationSeconds = 4}, map)
    math.random = random
    assert(started, reason)
    local seen = false
    for _ = 1, 8 do
        Activities.update(0.25, map, player)
        Visibility.update(player, map)
        Goals.update(1, map, player)
        local inRange = (party.x - 600)^2 + (party.y - 500)^2 <= 10^2
        if not seen and not inRange then
            assert(not Knowledge.knows(actor, event.id) and goal.status ~= "satisfied")
        end
        seen = seen or inRange
        if seen then
            assert(Knowledge.knows(party, event.id) and Knowledge.knows(actor, event.id))
            assert(goal.status == "satisfied")
        end
        assert(not troop.memory and not Knowledge.knows(bystander, event.id))
        assert(not Knowledge.knows(distant, event.id) and not Knowledge.knows(player, event.id))
        assert(not site.discovered, "NPC observation revealed a player marker")
    end
    assert(seen and party.x > 500 and Events.count(world) == 1)
    for _ = 1, 3 do Visibility.update(player, map) end
    assert(Events.count(world) == 1, "Repeated observation duplicated history")
end

local function testDebugAndInterruption()
    local _, map, party, actor = setup()
    local enabled = Mode.enabled
    Mode.enabled = false
    assert(not Tools.searchHere(map, party.id))
    Mode.enabled = true
    local overlay = Overlay.new()
    overlay:inspect("party", party.id)
    local action
    for _, row in ipairs(overlay:rows(map)) do if row.key == "search_here" then action = row.action end end
    assert(action)
    action()
    assert(party.world_activity.type == "search")
    assert(not Tools.searchHere(map, party.id), "Debug Search overwrote active movement")
    assert(table.concat(Inspector.lines(map, "party", party.id), "\n"):find("Search waypoint:", 1, true))
    local state = Goals.configure(actor, {query("unknown"), {type = "rest_and_recover"}})
    actor.hp = 1
    Goals.update(1, map)
    assert(party.world_activity.status == "active", "Recovery cancelled an externally owned Search")
    local objective = state.goals[1]
    objective.activity = {partyId = party.id, sequence = party.world_activity.sequence}
    party.world_activity.goalActorId = actor.id
    Goals.update(1, map)
    assert(party.world_activity.reason == "goal_interrupted")
    Activities.update(0, map)
    assert(not party.world_activity.waypoints and not party.world_activity.elapsedSeconds)
    actor.hp = actor.maxHp
    Goals.update(1, map)
    assert(state.goals[1] == objective and objective.subject.id == "unknown")
    Activities.update(5, map)
    for _, center in ipairs({{x = 500, y = 500}, {x = 600, y = 500}}) do
        assert(Activities.start(party, "search", {originX = center.x, originY = center.y,
            radius = 300, durationSeconds = 1}, map))
        Activities.update(1, map)
        assert(party.world_activity.lastActivity.status == "completed")
        Activities.update(5, map)
    end
    Mode.enabled = enabled
end

function Scenario.run()
    local random, exchangeRandom = math.random, Exchange.random
    local index = 0
    math.random = function() index = index + 1; return ((index * 37) % 101) / 101 end
    Exchange.random = function() return 0 end
    local ok, err = xpcall(function()
        testMemoryAndGoals()
        testSearch()
        testNpcPhysicalDiscovery()
        testDebugAndInterruption()
    end, debug.traceback)
    math.random, Exchange.random = random, exchangeRandom
    Time.setPaused(true)
    assert(ok, err)
end
return Scenario
