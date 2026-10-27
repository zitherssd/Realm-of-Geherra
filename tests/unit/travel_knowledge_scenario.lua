local World = require("src.ecs.world")
local Context = require("src.game.game_context")
local Party = require("src.ecs.assemblages.party")
local Unit = require("src.ecs.assemblages.unit")
local Location = require("src.ecs.assemblages.location")
local Map = require("src.world.map")
local Parties = require("src.systems.party_system")
local Locations = require("src.systems.location_system")
local Activities = require("src.systems.world_activity_system")
local Travel = require("src.systems.world_activities.travel_activity")
local Exchange = require("src.systems.travel_knowledge_system")
local Events = require("src.systems.world_events")
local Knowledge = require("src.systems.knowledge_system")
local Visibility = require("src.systems.visibility_system")
local HistoryText = require("src.ui.world_event_text")
local KnowledgeText = require("src.ui.knowledge_text")
local Inspector = require("src.debug.inspector")
local Scenario = {}

local function setup()
    Context.init()
    local world, map = World.init(), Map.new("travel-knowledge")
    local a = Location.create(world, nil, "Oakford")
    local b = Location.create(world, nil, "Stonehaven")
    a.x, a.y, b.x, b.y = 100, 100, 500, 100
    map:addLocation(a)
    map:addLocation(b)
    return world, map, a, b
end

local function party(world, map, location, name)
    local p = Party.create(world, name or "Caravan")
    local actor, troop = Unit.create(world, "companion"), Unit.create(world, "soldier")
    Parties.addActor(p, actor)
    Parties.addActor(p, troop)
    p.x, p.y = location.x, location.y
    assert(map:stationParty(location, p))
    return p, actor, troop
end

local function resident(world, location)
    local npc = Unit.create(world, "soldier")
    npc:ensure("memory") -- Existing important-character opt-in.
    assert(Locations.addNPC(location, npc))
    return npc
end

local function start(p, destination, map)
    assert(Activities.start(p, "travel", {destinationLocationId = destination.id}, map))
end

local function finish(p, map)
    for _ = 1, 40 do
        Activities.update(0.25, map)
        if p.world_activity.status == "idle" then break end
    end
    assert(p.world_activity.lastActivity and p.world_activity.lastActivity.reason == "arrived")
end

local function testHistoryAndLifecycle()
    local world, map, a, b = setup()
    local p, actor, troop = party(world, map, a)
    local sponsor = resident(world, a)
    assert(Events.count(world) == 0, "Initial stationing emitted history")
    Context.data.time = {day = 3, hour = 9.25}
    start(p, b, map)
    local departure = Events.getByType(world, "party_departed")[1]
    assert(departure and departure.originLocationId == a.id and departure.originLocationName == "Oakford")
    assert(departure.destinationLocationId == b.id and departure.partyName == "Caravan")
    assert(departure.time.day == 3 and departure.time.hour == 9.25 and departure.x == a.x)
    assert(Knowledge.knows(p, departure.id) and Knowledge.knows(actor, departure.id) and not troop.memory)
    assert(not Knowledge.knows(sponsor, departure.id), "Remote sponsor automatically learned departure")
    assert(not Activities.start(p, "travel", {destinationLocationId = b.id}, map))
    local journey = p.world_activity.travelJourney
    Exchange.depart(p, journey, map)
    assert(#Events.getByType(world, "party_departed") == 1)
    Activities.update(0, map)
    assert(#Events.getByType(world, "party_arrived") == 0)
    Context.data.time = {day = 3, hour = 16.6666667}
    finish(p, map)
    local arrival = Events.getByType(world, "party_arrived")[1]
    assert(arrival and arrival.destinationLocationName == "Stonehaven" and arrival.originLocationId == a.id)
    assert(arrival.time.hour == Context.data.time.hour and b.stationedParties[1] == p)
    assert(Knowledge.knows(p, arrival.id) and Knowledge.knows(actor, arrival.id) and not troop.memory)
    assert(not Knowledge.knows(sponsor, arrival.id), "Global arrival informed a distant sponsor")
    local stats = p.lastArrivalExchange
    Exchange.arrive(p, journey, b, map)
    for _ = 1, 4 do Activities.update(1, map) end
    assert(not map:stationParty(b, p))
    assert(p.lastArrivalExchange == stats and Events.count(world) == 2, "Arrival was processed twice")
    assert(table.concat(Inspector.lines(map, "party", p.id), "\n"):find("Last arrival exchange", 1, true))
    assert(HistoryText.describe(departure) == "Caravan departed Oakford for Stonehaven")
    p.name, a.name, b.name = "Renamed", "New origin", "New destination"
    map:removeParty(p.id)
    p:destroy()
    assert(HistoryText.describe(Events.get(world, arrival.id)) == "Caravan arrived at Stonehaven")
    assert(HistoryText.details(Events.get(world, departure.id)):find(a.id, 1, true))
    assert(Knowledge.getKnownEvent(actor, arrival.id).partyName == "Caravan")
end

local function testFailuresAndOtherMovement()
    local world, map, a, b = setup()
    local cancelled = party(world, map, a)
    start(cancelled, b, map)
    local cancelledJourney = cancelled.world_activity.travelJourney
    Activities.cancel(cancelled)
    Travel.update(cancelled, cancelled.world_activity, 1, map)
    assert(map:stationParty(b, cancelled))
    Exchange.arrive(cancelled, cancelledJourney, b, map)
    assert(not cancelled.lastArrivalExchange, "Stale cancelled callback caused an exchange")
    Activities.update(20, map)
    assert(#Events.getByType(world, "party_arrived") == 0)
    local invalid = party(world, map, a)
    assert(not Activities.start(invalid, "travel", {destinationLocationId = "absent"}, map))
    assert(#Events.getByType(world, "party_departed") == 1)
    local blocked = party(world, map, a)
    start(blocked, b, map)
    map.isWalkable = function() return false end
    Activities.update(16, map)
    map.isWalkable = nil
    assert(#Events.getByType(world, "party_arrived") == 0 and not blocked.lastArrivalExchange)
    local removed = party(world, map, a)
    start(removed, b, map)
    removed:destroy()
    Activities.update(1, map)
    assert(not removed.lastArrivalExchange and #Events.getByType(world, "party_arrived") == 0)
    local noStation = party(world, map, a)
    start(noStation, b, map)
    noStation.x, noStation.y = b.x, b.y
    noStation.world_activity.waypointIndex = #noStation.world_activity.waypoints
    local station = map.stationParty
    map.stationParty = function() return false end
    Activities.update(1, map)
    map.stationParty = station
    assert(not noStation.lastArrivalExchange and #Events.getByType(world, "party_arrived") == 0)
    local missingDestination = party(world, map, a)
    start(missingDestination, b, map)
    map.locations[2] = nil
    Activities.update(1, map)
    map.locations[2] = b
    assert(not missingDestination.lastArrivalExchange and #Events.getByType(world, "party_arrived") == 0)
    local removedFromMap = party(world, map, a)
    start(removedFromMap, b, map)
    assert(map:removeParty(removedFromMap.id))
    Activities.update(1, map)
    assert(not removedFromMap.lastArrivalExchange and #Events.getByType(world, "party_arrived") == 0)
    -- Generic map membership changes never produce history.
    local before = Events.count(world)
    local other = party(world, map, a)
    assert(map:addParty(other))
    assert(map:stationParty(b, other))
    assert(Events.count(world) == before)
    -- Wilderness travel stays supported, without a fictional origin/departure.
    local wild = party(world, map, a)
    assert(map:addParty(wild))
    wild.x, wild.y = 200, 100
    local departures = #Events.getByType(world, "party_departed")
    start(wild, b, map)
    finish(wild, map)
    assert(#Events.getByType(world, "party_departed") == departures)
    local arrival = Events.getByType(world, "party_arrived")[1]
    assert(arrival and not arrival.originLocationId)
    -- Same-location requests are not meaningful journeys.
    local same = party(world, map, a)
    local count = Events.count(world)
    start(same, a, map)
    finish(same, map)
    assert(Events.count(world) == count and not same.lastArrivalExchange)
    local roaming = party(world, map, a)
    assert(Activities.start(roaming, "roam", {originLocationId = a.id, radius = 150}, map))
    Activities.update(0.25, map)
    assert(Events.count(world) == count, "Roaming emitted travel history")
end

local function testPartialTravelKnowledge()
    local world, map, a, b = setup()
    local p = party(world, map, a)
    start(p, b, map)
    finish(p, map)
    for _, event in ipairs(Events.getAll(world)) do
        local npc = resident(world, a)
        assert(Knowledge.learn(npc, event.id, {}))
        local view = Knowledge.getKnownEvent(npc, event.id)
        assert(not view.time and not view.partyId and not view.x and not view.destinationLocationId)
        assert(Knowledge.learn(npc, event.id, {"party"}))
        view = Knowledge.getKnownEvent(npc, event.id)
        assert(view.partyName == "Caravan" and not view.time and not view.originLocationId)
        local text = KnowledgeText.describe(view)
        assert(not text:find("Oakford", 1, true) and not text:find("Stonehaven", 1, true))
        assert(Knowledge.learn(npc, event.id, {"location"}))
        view = Knowledge.getKnownEvent(npc, event.id)
        assert(view.originLocationId == a.id and view.x and not view.time and not view.mapId and not view.subjectIds)
        if event.type == "party_departed" then
            assert(not view.destinationLocationId, "Departure location leaked intended destination")
            assert(Knowledge.learn(npc, event.id, {"destination"}))
        end
        view = Knowledge.getKnownEvent(npc, event.id)
        assert(view.destinationLocationId == b.id)
        assert(Knowledge.learn(npc, event.id, {"time"}))
        view = Knowledge.getKnownEvent(npc, event.id)
        view.time.day = 99
        assert(Events.get(world, event.id).time.day ~= 99)
        assert(Knowledge.getKnownEvent(npc, event.id).time.day ~= 99)
    end
    -- Explicit projections discard arbitrary nested and future fields.
    local event = Events.record(world, "party_departed", {
        time = {day = 1, hour = 6, secret = {value = true}}, partyId = p.id,
        partyName = {secret = true}, originLocationName = {secret = true},
        destinationLocationName = {secret = true}, secret = {value = true}
    })
    Knowledge.learn(p, event.id, Knowledge.getDetailCategories(event.id, world))
    local view = Knowledge.getKnownEvent(p, event.id)
    assert(not view.time.secret and not view.secret and not view.partyName
        and not view.originLocationName and not view.destinationLocationName)
end

local function testExchangeAndOnwardTravel()
    local world, map, a, b = setup()
    local p, actor, troop = party(world, map, a)
    local fallenTraveler = Unit.create(world, "companion")
    fallenTraveler.hp = 0
    Parties.addActor(p, fallenTraveler)
    local elder, unaware = resident(world, b), resident(world, b)
    local visiting, visitor = party(world, map, b, "Visitor")
    local dead, removed = resident(world, b), resident(world, b)
    dead.hp = 0
    removed:destroy()
    local generic = Unit.create(world, "soldier")
    Locations.addNPC(b, generic)
    local busy = resident(world, b)
    busy.activeEncounterId = "busy"
    local busyParty, busyMember = party(world, map, b)
    busyParty.activeEncounterId = "busy"
    local distant = resident(world, a)
    local battle = Events.record(world, "battle_ended", {
        time = {day = 1, hour = 6}, mapId = map.id, encounterId = "attack",
        battlefieldId = "remains", x = a.x, y = a.y, subjectIds = {"remains"},
        outcome = "victory", participants = {
            {partyId = "bandits", name = "Forest Bandits", actorIds = {}, casualties = 0},
            {partyId = "trader", name = "Wandering Trader", actorIds = {}, casualties = 2}
        }, winnerPartyId = "bandits", defeatedPartyIds = {"trader"}
    })
    -- Real 6C sight acquisition, followed by real travel and location arrival.
    assert(map:addParty(p))
    map:addBattlefieldRemains({id = "remains", history = {eventId = battle.id,
        encounterId = "attack", position = {x = a.x, y = a.y}}})
    Visibility.update(p, map)
    assert(Knowledge.knows(p, battle.id) and Knowledge.knows(actor, battle.id))
    assert(map:stationParty(a, p))
    local personal = Events.record(world, "battle_ended", {time = {day = 1, hour = 7}, participants = {}})
    Knowledge.learn(actor, personal.id, {"location"})
    Knowledge.learn(elder, personal.id, {"time"})
    local rolls = 0
    Exchange.random = function()
        rolls = rolls + 1
        return rolls == 2 and 0.9 or 0.1
    end
    start(p, b, map)
    local journey = p.world_activity.travelJourney
    finish(p, map)
    assert(rolls == 3 and p.lastArrivalExchange.eligible == 3 and p.lastArrivalExchange.participants == 2)
    assert(Knowledge.knows(elder, battle.id) and Knowledge.knows(visitor, battle.id))
    for _, npc in ipairs({unaware, dead, removed, busy, busyMember, distant}) do
        assert(not Knowledge.knows(npc, battle.id), "Absent, unavailable or unselected NPC received knowledge")
    end
    assert(not troop.memory and not generic.memory)
    assert(not Knowledge.knows(fallenTraveler, p.lastArrivalExchange.arrivalEventId),
        "Dead traveling member learned arrival")
    local flags = Knowledge.getKnownDetails(p, personal.id)
    assert(flags.location and flags.time and not flags.participants and not flags.outcome)
    flags = Knowledge.getKnownDetails(actor, personal.id)
    assert(flags.location and flags.time and not flags.outcome)
    assert(Events.count(world) == 4, "Sharing emitted new history")
    local stats = p.lastArrivalExchange
    assert(stats.detailsTransferred > 0)
    Exchange.arrive(p, journey, b, map)
    Activities.update(0, map)
    Activities.update(1, map)
    assert(rolls == 3 and p.lastArrivalExchange == stats, "Duplicate arrival rerolled exchange")
    assert(not map:stationParty(b, p))
    assert(rolls == 3)
    -- A second arrival can pick up the same battle ID and carry it onward.
    local second, secondActor = party(world, map, a, "Second traveler")
    Exchange.random = function() return 0 end
    start(second, b, map)
    finish(second, map)
    assert(Knowledge.knows(second, battle.id) and Knowledge.knows(secondActor, battle.id))
    for _ = 1, 20 do Activities.update(0.25, map) end
    start(second, a, map)
    finish(second, map)
    assert(Knowledge.knows(distant, battle.id), "Second traveler did not carry information onward")
    assert(#Events.getByType(world, "battle_ended") == 2)
    assert(Events.get(world, battle.id).participants[2].casualties == 2)
    -- Personal knowledge survives leaving the party, and joins its new party
    -- only at that party's next arrival synchronization.
    Parties.removeActor(second, secondActor)
    local nextParty = party(world, map, a, "New company")
    Parties.addActor(nextParty, secondActor)
    assert(Knowledge.knows(secondActor, battle.id) and not Knowledge.knows(nextParty, battle.id))
    start(nextParty, b, map)
    finish(nextParty, map)
    assert(Knowledge.knows(nextParty, battle.id))
end

function Scenario.run()
    local random, probability = Exchange.random, Exchange.exchangeProbability
    local ok, err = xpcall(function()
        Exchange.random = function() return 0.99 end
        Exchange.exchangeProbability = 0.5
        testHistoryAndLifecycle()
        testFailuresAndOtherMovement()
        testPartialTravelKnowledge()
        testExchangeAndOnwardTravel()
    end, debug.traceback)
    Exchange.random, Exchange.exchangeProbability = random, probability
    if not ok then error(err) end
end

return Scenario
