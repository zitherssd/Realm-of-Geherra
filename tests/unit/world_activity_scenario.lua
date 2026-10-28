local EcsWorld = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local EventBus = require("src.core.event_bus")
local PartyAiSystem = require("src.systems.parties.party_ai_system")
local WorldActivitySystem = require("src.systems.world_activities.world_activity_system")
local RaidActivity = require("src.systems.world_activities.raid_activity")

local function newMap(parties)
    return {
        parties = parties,
        getParties = function(self) return self.parties end,
        getLocations = function() return {} end,
        getTravelSpeedMod = function() return 1 end,
        isWalkable = function(_, x, y) return x >= 0 and y >= 0 end
    }
end

local function createParty(world, id, x, y)
    local party = Party.create(world, id, nil, id)
    party.x, party.y = x, y
    party.actors = {{id = id .. "-actor", sight = 20000, profile = 0}}
    return party
end

local function runRaidScenario(world)
    EventBus.init()

    local raider = createParty(world, "raider", 100, 100)
    raider.hostile = true
    raider.state = "wander"
    raider.wanderTarget = { x = 0, y = 500 }

    local caravan = createParty(world, "caravan", 300, 100)
    caravan.state = "wander"
    caravan.isTraderParty = true
    caravan.wanderTarget = { x = 10000, y = 100 }

    local playerParty = createParty(world, "player", 4000, 4000)
    local map = newMap({ raider, caravan, playerParty })
    local contacts = {}
    EventBus.subscribe("party_contact", function(event)
        contacts[#contacts + 1] = event
    end)

    assert(WorldActivitySystem.start(raider, "raid"))
    assert(not WorldActivitySystem.start(raider, "raid"))

    local initialCaravanX = caravan.x
    local initialRaiderX = raider.x
    local oldRaidSpeed = RaidActivity.speed
    RaidActivity.speed = 400
    for _ = 1, 200 do
        PartyAiSystem.update(0.25, map, playerParty)
        WorldActivitySystem.update(0.25, map, playerParty)
        if raider.world_activity.phase == "contact" then
            break
        end
    end
    RaidActivity.speed = oldRaidSpeed

    assert(raider.world_activity.targetId == caravan.id, "raider did not acquire the caravan")
    assert(caravan.x > initialCaravanX, "fallback movement did not move the caravan")
    assert(raider.x > initialRaiderX, "raid pursuit did not move the raider")
    assert(raider.world_activity.status == "active" and raider.world_activity.phase == "contact",
        "raider did not enter the contact handoff phase")
    assert(#contacts == 1, "raid should emit exactly one party_contact event")
    assert(contacts[1].sourcePartyId == raider.id and contacts[1].targetPartyId == caravan.id)
    assert(caravan.state == "wander", "raid changed the target's movement state")

    WorldActivitySystem.update(1, map, playerParty)
    assert(#contacts == 1, "completed raid emitted a duplicate contact")

    local serialized = raider.world_activity:serialize()
    assert(serialized.type == "raid" and serialized.status == "active")
    assert(type(serialized.params) == "table")
    for key, value in pairs(serialized.params) do
        assert(type(key) == "string")
        assert(type(value) == "string" or type(value) == "number" or type(value) == "boolean")
    end
end

local function runFailureScenarios(world)
    local raider = createParty(world, "missing-target-raider", 0, 0)
    raider.hostile = true
    local caravan = createParty(world, "vanishing-caravan", 100, 0)
    caravan.state = "wander"
    caravan.isTraderParty = true
    local playerParty = createParty(world, "failure-test-player", 500, 500)
    local map = newMap({ raider, caravan, playerParty })

    assert(WorldActivitySystem.start(raider, "raid"))
    WorldActivitySystem.update(0.1, map, playerParty)
    table.remove(map.parties, 2)
    WorldActivitySystem.update(0.1, map, playerParty)
    assert(raider.world_activity.status == "cancelled")
    assert(raider.world_activity.reason == "target_missing")

    local blockedRaider = createParty(world, "blocked-raider", 0, 0)
    blockedRaider.hostile = true
    local blockedCaravan = createParty(world, "blocked-caravan", 100, 0)
    blockedCaravan.state = "wander"
    blockedCaravan.isTraderParty = true
    local blockedMap = newMap({ blockedRaider, blockedCaravan, playerParty })
    blockedMap.isWalkable = function() return false end

    assert(WorldActivitySystem.start(blockedRaider, "raid"))
    for _ = 1, 40 do
        WorldActivitySystem.update(0.25, blockedMap, playerParty)
    end
    assert(blockedRaider.world_activity.status == "idle")
    assert(blockedRaider.world_activity.lastActivity.status == "cancelled")
    assert(blockedRaider.world_activity.lastActivity.reason == "pursuit_stalled")
    assert(blockedRaider.world_activity.retryCooldownSeconds > 0,
        "failed pursuit did not get a retry cooldown")

    local cancelledRaider = createParty(world, "cancelled-raider", 0, 0)
    assert(WorldActivitySystem.start(cancelledRaider, "raid"))
    assert(WorldActivitySystem.cancel(cancelledRaider, "test_cancel"))
    assert(cancelledRaider.world_activity.status == "cancelled")
    assert(cancelledRaider.world_activity.reason == "test_cancel")

    local availableMap = newMap({cancelledRaider, playerParty})
    cancelledRaider.state = "wander"
    cancelledRaider.wanderTarget = {x = 100, y = 0}
    WorldActivitySystem.update(0.1, availableMap, playerParty)
    assert(cancelledRaider.world_activity.status == "idle")
    assert(cancelledRaider.world_activity.type == nil)
    assert(cancelledRaider.world_activity.lastActivity.status == "cancelled")
    local previousX = cancelledRaider.x
    PartyAiSystem.update(0.1, availableMap, playerParty)
    assert(cancelledRaider.x > previousX,
        "fallback wandering did not resume after terminal activity cleanup")
    local restarted, restartReason = WorldActivitySystem.start(cancelledRaider, "raid")
    assert(not restarted and restartReason == "activity_cooldown",
        "cancelled activity restarted during its retry cooldown")

    for _, terminalStatus in ipairs({"completed", "cancelled", "failed"}) do
        local terminalParty = createParty(world, "terminal-" .. terminalStatus, 0, 0)
        assert(WorldActivitySystem.start(terminalParty, "raid"))
        terminalParty.world_activity.status = terminalStatus
        terminalParty.world_activity.phase = terminalStatus
        terminalParty.world_activity.reason = "test_terminal"
        WorldActivitySystem.update(0, newMap({terminalParty}), nil)
        assert(terminalParty.world_activity.status == "idle",
            terminalStatus .. " activity was not cleaned")
        assert(terminalParty.world_activity.type == nil)
        assert(terminalParty.world_activity.lastActivity.status == terminalStatus)
        assert(terminalParty.world_activity.lastActivity.reason == "test_terminal")
    end
end

local Scenario = {}

function Scenario.run()
    local world = EcsWorld.init()
    runRaidScenario(world)
    runFailureScenarios(world)
end

return Scenario
