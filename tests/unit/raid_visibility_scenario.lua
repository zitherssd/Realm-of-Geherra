local EcsWorld = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local RaidActivity = require("src.systems.world_activities.raid_activity")
local VisibilitySystem = require("src.systems.parties.visibility_system")
local WorldActivitySystem = require("src.systems.world_activities.world_activity_system")

local function createParty(world, id, x, y, sight, profile)
    local party = Party.create(world, id, nil, id)
    party.x, party.y = x, y
    party.hostile = true
    party.actors = {{id = id .. "-actor", sight = sight, profile = profile}}
    return party
end

local function createMap(parties)
    return {
        id = "raid-visibility-map",
        parties = parties,
        getParties = function(self) return self.parties end
    }
end

local function startRaid(raider, map, playerParty)
    assert(WorldActivitySystem.start(raider, "raid"))
    return RaidActivity.update(raider, raider.world_activity, 0, map, playerParty)
end

local function testVisibilityTargetAcquisition(world)
    local raider = createParty(world, "visibility-raider", 0, 0, 80, 0)
    local merchant = createParty(world, "visible-merchant", 15, 0, 0, 0)
    merchant.isTraderParty = true
    merchant.state = "travel"
    local player = createParty(world, "distant-player", 1000, 0, 0, 0)
    local map = createMap({raider, merchant, player})

    assert(VisibilitySystem.canSee(raider, merchant))
    assert(not VisibilitySystem.canSee(merchant, raider),
        "party detection should remain asymmetric")
    local result, reason = startRaid(raider, map, player)
    assert(result == "pursuing", "visible merchant pursuit returned " .. tostring(result) .. ":" .. tostring(reason))
    assert(raider.world_activity.targetId == merchant.id,
        "Raid did not acquire the visible merchant")

    local hiddenRaider = createParty(world, "hidden-raider", 0, 0, 20, 0)
    local hiddenMerchant = createParty(world, "hidden-merchant", 100, 0, 0, 0)
    hiddenMerchant.isTraderParty = true
    hiddenMerchant.state = "travel"
    local hiddenMap = createMap({hiddenRaider, hiddenMerchant})
    local hiddenResult, hiddenReason = startRaid(hiddenRaider, hiddenMap, nil)
    assert(hiddenResult == "failed" and hiddenReason == "no_target",
        "Raid acquired a target outside the observer's sight")
end

local function testPlayerTargetAcquisition(world)
    local raider = createParty(world, "player-target-raider", 0, 0, 80, 0)
    local player = createParty(world, "visible-player-target", 15, 0, 0, 0)
    local map = createMap({raider, player})

    local result = startRaid(raider, map, player)
    assert(result == "pursuing")
    assert(raider.world_activity.targetId == player.id,
        "Raid did not acquire the visible player party")

    local hiddenRaider = createParty(world, "hidden-player-raider", 0, 0, 20, 0)
    local hiddenPlayer = createParty(world, "hidden-player-target", 100, 0, 0, 0)
    local hiddenMap = createMap({hiddenRaider, hiddenPlayer})
    local hiddenResult, hiddenReason = startRaid(hiddenRaider, hiddenMap, hiddenPlayer)
    assert(hiddenResult == "failed" and hiddenReason == "no_target",
        "Raid acquired an undetected player party")
end

local function testWanderingTraderTargetAcquisition(world)
    local raider = createParty(world, "wandering-trader-raider", 0, 0, 80, 0)
    local trader = createParty(world, "wandering-trader-target", 15, 0, 0, 0)
    trader.isTraderParty = true
    trader.state = "wander"
    local map = createMap({raider, trader})

    local result = startRaid(raider, map, nil)
    assert(result == "pursuing",
        "Raid did not acquire a visible wandering trader")
    assert(raider.world_activity.targetId == trader.id,
        "Raid did not retain the wandering trader as its target")
end

local function testLostSightAndReacquisition(world)
    local raider = createParty(world, "memory-raider", 0, 0, 80, 0)
    local merchant = createParty(world, "memory-merchant", 15, 0, 0, 0)
    merchant.isTraderParty = true
    merchant.state = "travel"
    local map = createMap({raider, merchant})

    assert(startRaid(raider, map, nil) == "pursuing")
    local activity = raider.world_activity
    assert(activity.lastKnownX == 15)

    merchant.x = 200
    local lostResult = RaidActivity.update(raider, activity, 0.1, map, nil)
    assert(lostResult == "pursuing")
    assert(raider.x > 0 and raider.x < 15,
        "Raid did not pursue the last known position")
    assert(activity.targetLostSeconds > 0)
    assert(activity.lastKnownX == 15,
        "Raid updated its memory from an undetected target's live coordinates")

    merchant.x = 10
    local reacquiredResult = RaidActivity.update(raider, activity, 0, map, nil)
    assert(reacquiredResult == "contact",
        "Raid did not reacquire a visible target near its last known position")
    assert(activity.targetLostSeconds == 0)
    assert(activity.lastKnownX == merchant.x)

    local lostRaider = createParty(world, "lost-raider", 0, 0, 80, 0)
    local lostMerchant = createParty(world, "lost-merchant", 15, 0, 0, 0)
    lostMerchant.isTraderParty = true
    lostMerchant.state = "travel"
    local lostMap = createMap({lostRaider, lostMerchant})
    assert(WorldActivitySystem.start(lostRaider, "raid"))
    WorldActivitySystem.update(0.01, lostMap, nil)
    lostMerchant.x = 200

    for _ = 1, RaidActivity.maxLostSightSeconds do
        WorldActivitySystem.update(1, lostMap, nil)
    end
    assert(lostRaider.world_activity.status == "cancelled")
    assert(lostRaider.world_activity.reason == "target_lost")
    WorldActivitySystem.update(0.1, lostMap, nil)
    assert(lostRaider.world_activity.status == "idle")
    assert(lostRaider.world_activity.type == nil)
    assert(lostRaider.world_activity.lastActivity.reason == "target_lost")
end

local Scenario = {}

function Scenario.run()
    local world = EcsWorld.init()
    testVisibilityTargetAcquisition(world)
    testPlayerTargetAcquisition(world)
    testWanderingTraderTargetAcquisition(world)
    testLostSightAndReacquisition(world)
end

return Scenario
