local EcsWorld = require("src.ecs.world")
local Location = require("src.ecs.assemblages.location")
local Party = require("src.ecs.assemblages.party")
local Unit = require("src.ecs.assemblages.unit")
local EventBus = require("src.core.event_bus")
local LocationSystem = require("src.systems.locations.location_system")
local PartyAiSystem = require("src.systems.parties.party_ai_system")
local PartySystem = require("src.systems.parties.party_system")
local RaidActivity = require("src.systems.world_activities.raid_activity")
local WorldActivitySystem = require("src.systems.world_activities.world_activity_system")
local Map = require("src.world.map")

local function createMap(world, mapId)
    local map = Map.new(mapId)
    local origin = Location.create(world, mapId .. "-origin", "Origin")
    origin.siteId, origin.x, origin.y = mapId .. "-site-a", 100, 100
    local destination = Location.create(world, mapId .. "-destination", "Destination")
    destination.siteId, destination.x, destination.y = mapId .. "-site-b", 500, 100
    map:addLocation(origin)
    map:addLocation(destination)
    map.worldGen = {
        roads = {{
            from = origin.siteId,
            to = destination.siteId,
            points = {
                {x = origin.x, y = origin.y},
                {x = 300, y = 100},
                {x = destination.x, y = destination.y}
            }
        }}
    }
    return map, origin, destination
end

local function createParty(world, map, location, id, troopType, config)
    config = config or {}
    local actor = Unit.create(world, troopType or "soldier", id .. "-leader")
    actor.dialogueId = config.dialogueId
    actor.sight = config.sight or 0
    actor.inventory = config.personalInventory or {{id = "bread", quantity = 2}}
    actor.equipment.mainHand = "iron_sword"

    local party = Party.create(world, config.name or id, actor.id, id)
    party.x, party.y = config.x or location.x, config.y or location.y
    party.hostile = config.hostile or false
    party.faction = config.faction
    party.isTraderParty = config.isTraderParty or false
    party.inventory = config.inventory or {}
    party.treasury = config.treasury or 0
    PartySystem.addActor(party, actor)
    assert(map:stationParty(location, party), "test party stationing failed")
    return party, actor
end

local function countParty(location, partyId)
    local count = 0
    for _, party in ipairs(location.stationedParties or {}) do
        if party.id == partyId then count = count + 1 end
    end
    return count
end

local function mapHasParty(map, partyId)
    for _, party in ipairs(map:getParties()) do
        if party.id == partyId then return true end
    end
    return false
end

local function testGenericTravelAndPreservation()
    local world = EcsWorld.init()
    local map, origin, destination = createMap(world, "travel-main")
    local resident = Unit.create(world, "guard", "travel-resident")
    LocationSystem.addNPC(origin, resident)

    local trader, leader = createParty(world, map, origin, "travelling-merchant", "trader", {
        dialogueId = "trader_greeting",
        isTraderParty = true,
        name = "Caravan",
        inventory = {
            {id = "wine", quantity = 3, metadata = {vintage = "spring"}}
        },
        treasury = 125
    })
    local cargo = trader.inventory
    local cargoQuantity = cargo[1].quantity
    local actorInventory = leader.inventory
    local leaderEquipment = leader.equipment.mainHand
    local bandit, banditLeader = createParty(world, map, origin, "travelling-bandits", "bandit", {
        hostile = true,
        faction = "bandits"
    })

    local started, reason = WorldActivitySystem.start(trader, "travel", {
        destinationLocationId = destination.id
    }, map)
    assert(started, "merchant travel did not start: " .. tostring(reason))
    assert(#origin.stationedParties == 1 and origin.stationedParties[1] == bandit,
        "travel departure left the merchant stationed at its origin")
    assert(map:getParties()[1] == trader, "departing party was not added to the map")
    assert(trader.world_activity.status == "active" and trader.state == "travel")
    assert(trader.actors[1] == leader and leader.id == trader.leaderId,
        "travel changed the party leader identity")
    assert(LocationSystem.getAvailableNpcs(origin)[1] == resident,
        "departure affected an independent resident")
    assert(not WorldActivitySystem.start(trader, "travel", {
        destinationLocationId = destination.id
    }, map), "a party accepted a second activity while traveling")

    local initialX = trader.x
    PartyAiSystem.update(1, map, nil)
    assert(trader.x == initialX, "fallback wandering controlled an active traveler")
    WorldActivitySystem.update(0, map, nil)
    assert(trader.x == initialX, "paused world time advanced travel")

    local banditStarted, banditReason = WorldActivitySystem.start(bandit, "travel", {
        destinationLocationId = destination.id
    }, map)
    assert(banditStarted, "non-merchant travel did not start: " .. tostring(banditReason))
    WorldActivitySystem.ensureDefaultActivities(map, nil)
    assert(bandit.world_activity.type == "travel",
        "default Raid assignment replaced active travel")

    local moved = false
    for _ = 1, 30 do
        local previousX = trader.x
        WorldActivitySystem.update(1, map, nil)
        if trader.x > previousX then moved = true end
    end
    assert(moved, "road travel did not move the merchant")
    assert(trader.world_activity.lastActivity
        and trader.world_activity.lastActivity.status == "completed",
        "merchant travel did not complete")
    assert(bandit.world_activity.lastActivity
        and bandit.world_activity.lastActivity.status == "completed",
        "non-merchant travel did not complete")
    assert(countParty(destination, trader.id) == 1 and countParty(destination, bandit.id) == 1,
        "travel arrival did not station each party exactly once")
    assert(countParty(origin, trader.id) == 0 and countParty(origin, bandit.id) == 0,
        "arrival left stale origin memberships")
    assert(#destination.npcs == 0, "travel copied party members into location residents")

    local available = LocationSystem.getAvailableNpcs(destination)
    assert(available[1] == leader and leader.dialogueId == "trader_greeting",
        "arrival changed the leader or dialogue identity")
    assert(trader.actors[1] == leader and trader.leaderId == leader.id,
        "party roster changed during travel")
    assert(trader.inventory == cargo and trader.inventory[1].quantity == cargoQuantity,
        "travel changed or replaced party cargo")
    assert(trader.treasury == 125, "travel changed party treasury")
    assert(leader.inventory == actorInventory and leader.equipment.mainHand == leaderEquipment,
        "travel changed personal possessions")

    local outcome = trader.world_activity:serialize().outcome
    assert(outcome.destinationLocationId == destination.id
        and outcome.status == "completed" and outcome.reason == "arrived",
        "travel outcome was not serializable or complete")
    WorldActivitySystem.update(1, map, nil)
    assert(countParty(destination, trader.id) == 1,
        "a completed travel activity repeated its arrival")
    assert(banditLeader.id == bandit.leaderId, "non-merchant leader identity changed")
end

local function testRaidEncounterPausesTravel()
    EventBus.init()
    local world = EcsWorld.init()
    local map, origin, destination = createMap(world, "travel-raid")
    local raider = Party.create(world, "Road Raider", "travel-raider-leader", "travel-raider")
    raider.x, raider.y = 90, 100
    raider.hostile = true
    local raiderLeader = Unit.create(world, "bandit", "travel-raider-leader")
    raiderLeader.sight = 1000
    PartySystem.addActor(raider, raiderLeader)
    assert(map:addParty(raider))

    local caravan, caravanLeader = createParty(world, map, origin, "raid-target-caravan", "trader", {
        dialogueId = "trader_greeting",
        isTraderParty = true,
        sight = 1000
    })
    local contacts = {}
    EventBus.subscribe("party_contact", function(event)
        contacts[#contacts + 1] = event
    end)
    WorldActivitySystem.init()
    assert(WorldActivitySystem.start(caravan, "travel", {
        destinationLocationId = destination.id
    }, map))
    assert(WorldActivitySystem.start(raider, "raid"))
    local oldRaidSpeed = RaidActivity.speed
    RaidActivity.speed = 400
    WorldActivitySystem.update(0.1, map, nil)
    RaidActivity.speed = oldRaidSpeed

    assert(#contacts == 1 and contacts[1].targetPartyId == caravan.id,
        "Raid did not contact a party with active TravelActivity")
    assert(caravan.world_activity.type == "travel" and caravan.world_activity.status == "active",
        "Raid replaced or cancelled the travel activity")

    caravan.activeEncounterId = "reserved-encounter"
    local reservedX, reservedY = caravan.x, caravan.y
    PartyAiSystem.update(0.5, map, nil)
    WorldActivitySystem.update(0.5, map, nil)
    assert(caravan.x == reservedX and caravan.y == reservedY,
        "travel movement ignored an active encounter reservation")
    caravan.activeEncounterId = nil

    WorldActivitySystem.update(0.5, map, nil)
    assert(caravan.x > reservedX,
        "travel did not resume after the encounter reservation was released")
    assert(caravan.actors[1] == caravanLeader,
        "Raid contact changed the traveling roster")
end

local function testCancellationFailuresAndRemoval()
    local world = EcsWorld.init()
    local map, origin, destination = createMap(world, "travel-lifecycle")
    local cancelled = createParty(world, map, origin, "cancelled-traveller")
    assert(WorldActivitySystem.start(cancelled, "travel", {
        destinationLocationId = destination.id
    }, map))
    assert(WorldActivitySystem.cancel(cancelled, "user_cancel"))
    WorldActivitySystem.update(0, map, nil)
    assert(cancelled.world_activity.lastActivity.status == "cancelled"
        and cancelled.world_activity.lastActivity.reason == "user_cancel",
        "cancelled travel did not preserve its outcome")
    assert(cancelled.state == "idle", "cancellation did not release movement ownership")
    assert(countParty(origin, cancelled.id) == 0,
        "cancellation incorrectly restationed the party at its departure point")

    local invalidDestination = createParty(world, map, origin, "invalid-destination-traveller")
    local invalidStarted, invalidReason = WorldActivitySystem.start(invalidDestination, "travel", {
        destinationLocationId = "missing-location"
    }, map)
    assert(not invalidStarted and invalidReason == "destination_missing",
        "travel accepted an invalid destination or returned the wrong reason")
    assert(countParty(origin, invalidDestination.id) == 1
        and not mapHasParty(map, invalidDestination.id),
        "invalid travel partially changed location membership")

    local blocked = createParty(world, map, origin, "blocked-route-traveller")
    assert(WorldActivitySystem.start(blocked, "travel", {
        destinationLocationId = destination.id
    }, map))
    map.isWalkable = function() return false end
    for _ = 1, 16 do
        WorldActivitySystem.update(1, map, nil)
    end
    map.isWalkable = nil
    assert(blocked.world_activity.lastActivity
        and blocked.world_activity.lastActivity.reason == "route_stalled",
        "walkability constraints did not stop a blocked route")

    local disappearing = createParty(world, map, origin, "disappearing-destination-traveller")
    assert(WorldActivitySystem.start(disappearing, "travel", {
        destinationLocationId = destination.id
    }, map))
    map.locations[2] = nil
    WorldActivitySystem.update(0.1, map, nil)
    assert(disappearing.world_activity.status == "cancelled"
        and disappearing.world_activity.reason == "destination_missing",
        "disappearing destination did not cancel travel")
    assert(countParty(destination, disappearing.id) == 0,
        "travel arrived at a removed destination")

    map.locations[2] = destination
    local removed = createParty(world, map, origin, "removed-traveller")
    assert(WorldActivitySystem.start(removed, "travel", {
        destinationLocationId = destination.id
    }, map))
    assert(map:removeParty(removed.id), "party removal failed")
    assert(removed.world_activity.status == "cancelled"
        and removed.world_activity.outcome.reason == "party_removed",
        "party removal did not terminate travel")
    WorldActivitySystem.update(10, map, nil)
    assert(countParty(destination, removed.id) == 0,
        "removed party later arrived at its destination")

    local destroyed = createParty(world, map, origin, "destroyed-traveller")
    assert(WorldActivitySystem.start(destroyed, "travel", {
        destinationLocationId = destination.id
    }, map))
    destroyed:destroy()
    WorldActivitySystem.update(1, map, nil)
    assert(destroyed.world_activity.status == "cancelled"
        and destroyed.world_activity.outcome.reason == "party_removed",
        "destroyed party did not cancel its active travel")
    assert(not mapHasParty(map, destroyed.id), "destroyed traveling party remained on the map")
end

local Scenario = {}

function Scenario.run()
    testGenericTravelAndPreservation()
    testRaidEncounterPausesTravel()
    testCancellationFailuresAndRemoval()
end

return Scenario
