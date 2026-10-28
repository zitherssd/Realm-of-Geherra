local EcsWorld = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local Unit = require("src.ecs.assemblages.unit")
local PartySystem = require("src.systems.parties.party_system")
local Map = require("src.world.map")
local GameContext = require("src.game.game_context")
local TimeSystem = require("src.systems.campaign.time_system")
local EventBus = require("src.core.event_bus")
local PartyAiSystem = require("src.systems.parties.party_ai_system")
local PartyInteractionSystem = require("src.systems.parties.party_interaction_system")
local WorldActivitySystem = require("src.systems.world_activities.world_activity_system")
local WorldEncounterSystem = require("src.systems.campaign.world_encounter_system")
local ShopScreen = require("src.ui.screens.shop_screen")
require("src.game.states.world_state")

local function createParty(world, map, partyId, actorId, config)
    config = config or {}
    local party = Party.create(world, partyId, nil, partyId)
    party.x, party.y = config.x or 100, config.y or 100
    party.state = config.state or "idle"
    party.hostile = config.hostile or false
    party.visible = true
    party.isTraderParty = config.isTraderParty or false

    if actorId then
        local actor = Unit.create(world, "soldier", actorId)
        actor.stats.health = config.health or 100
        actor.stats.attack = config.attack or 10
        actor.stats.defense = config.defense or 0
        actor.stats.battle_speed = config.battleSpeed or 120
        actor.hp = actor.stats.health
        actor.maxHp = actor.stats.health
        actor.skills = config.skills or {}
        PartySystem.addActor(party, actor)
    end

    map:addParty(party)
    return party
end

local function makeMap(world, id)
    local map = Map.new(id)
    map:setBounds(0, 0, 2000, 2000)
    return map, world
end

local function assertNear(actual, expected, message)
    assert(math.abs(actual - expected) < 1e-7, message)
end

local function withDeterministicRandom(callback)
    local oldRandom = math.random
    math.random = function(first, second)
        if first == nil then return 0.5 end
        if second == nil then return first end
        return second
    end
    local ok, err = xpcall(callback, debug.traceback)
    math.random = oldRandom
    if not ok then error(err, 0) end
end

local function testClockDeltaPauseAndAcceleration()
    GameContext.data.time = {day = 1, hour = 0}
    TimeSystem.setTimeScale(1)
    TimeSystem.setPaused(false)

    local world = EcsWorld.init()
    local map = makeMap(world, "clock-map")
    local partyA = createParty(world, map, "clock-a", "clock-actor-a", {health = 100000})
    local partyB = createParty(world, map, "clock-b", "clock-actor-b", {health = 100000})
    local started, encounter = WorldEncounterSystem.start(map, partyA, partyB, {
        maxTicks = 100,
        ticksPerWorldHour = 4
    })
    assert(started)

    local normalHours = TimeSystem.update(1 / 12)
    assertNear(normalHours, 0.125, "clock did not return elapsed game hours")
    WorldEncounterSystem.update(normalHours, map)
    assertNear(encounter.tickAccumulator, 0.5, "encounter did not consume clock time")

    TimeSystem.setPaused(true)
    local pausedHours = TimeSystem.update(10)
    assert(pausedHours == 0, "paused clock advanced world time")
    WorldEncounterSystem.update(pausedHours, map)
    assert(encounter.runner.simulation.context.data.tick == 0,
        "encounter advanced while the world clock was paused")

    TimeSystem.setPaused(false)
    TimeSystem.setTimeScale(0)
    assert(TimeSystem.isPaused() and TimeSystem.update(10) == 0,
        "zero time scale did not pause the world clock")

    TimeSystem.setPaused(false)
    TimeSystem.setTimeScale(2)
    local acceleratedHours = TimeSystem.update(1 / 12)
    assertNear(acceleratedHours, 0.25, "time scale did not accelerate world time")
    WorldEncounterSystem.update(acceleratedHours, map)
    assert(encounter.runner.simulation.context.data.tick == 1,
        "time acceleration did not advance combat")
    assert(TimeSystem.getTimeScale() == 2)

    encounter.runner:cleanup()
    map.activeEncounters[encounter.id] = nil
    partyA.activeEncounterId, partyB.activeEncounterId = nil, nil
    TimeSystem.setTimeScale(1)
end

local function testDefaultEncounterPacing(world)
    local map = makeMap(world, "default-pacing-map")
    local partyA = createParty(world, map, "default-pacing-a", "default-pacing-actor-a", {
        health = 100000
    })
    local partyB = createParty(world, map, "default-pacing-b", "default-pacing-actor-b", {
        health = 100000
    })
    local started, encounter = WorldEncounterSystem.start(map, partyA, partyB)
    assert(started)
    assert(encounter.ticksPerWorldHour == WorldEncounterSystem.combatTicksPerWorldHour,
        "default world encounter pacing was not applied")

    WorldEncounterSystem.update(1, map)
    assert(encounter.runner.simulation.context.data.tick ==
        WorldEncounterSystem.combatTicksPerWorldHour,
        "default encounter did not advance at the configured world-time rate")
    assert(encounter.state == "active",
        "a long-running battle completed during the pacing check")

    encounter.runner:cleanup()
    encounter.state = "cancelled"
    map.activeEncounters[encounter.id] = nil
    partyA.activeEncounterId, partyB.activeEncounterId = nil, nil
end

local function testFractionalAdvancementAndReservations(world)
    local map = makeMap(world, "fractional-map")
    local raider = createParty(world, map, "fractional-raider", "fractional-raider-actor", {
        hostile = true,
        state = "wander",
        x = 100,
        y = 100
    })
    raider.wanderTarget = {x = 500, y = 100}
    local caravan = createParty(world, map, "fractional-caravan", "fractional-caravan-actor", {
        isTraderParty = true,
        state = "idle",
        x = 200,
        y = 100,
    })
    local player = createParty(world, map, "fractional-player", "fractional-player-actor", {
        x = 50,
        y = 50
    })
    GameContext.data.playerParty = player

    local started, encounter = WorldEncounterSystem.start(map, raider, caravan, {
        maxTicks = 1000,
        ticksPerWorldHour = 4
    })
    assert(started and encounter.id == "fractional-map:encounter:1")
    assert(encounter.partyAId == raider.id and encounter.partyBId == caravan.id)
    assert(encounter.partyA == nil and encounter.partyB == nil,
        "map encounter record retained direct campaign-party references")
    assert(map:getActiveEncounters()[encounter.id] == encounter)
    assert(raider.activeEncounterId == encounter.id and caravan.activeEncounterId == encounter.id)
    assert(not WorldEncounterSystem.start(map, raider, player))
    assert(not WorldEncounterSystem.start(map, raider, caravan))

    local raiderX, caravanX = raider.x, caravan.x
    PartyAiSystem.update(1, map, player)
    WorldActivitySystem.update(1, map, player)
    assert(raider.x == raiderX and caravan.x == caravanX,
        "an engaged party moved through a world control system")
    local activityStarted, reason = WorldActivitySystem.start(raider, "raid")
    assert(not activityStarted and reason == "party_in_encounter")

    local shop = setmetatable({
        merchant = caravan,
        merchantStock = {{id = "reserved-stock", value = 1}},
        playerParty = player
    }, ShopScreen)
    assert(not shop:buyItem(1), "shop sold goods from an engaged trader")

    local nearby, interrupted = PartyInteractionSystem.update(0, map, player, {}, true)
    assert(nearby == nil and not interrupted, "player interacted with an engaged party")

    WorldEncounterSystem.update(0.125, map)
    assert(encounter.runner.simulation.context.data.tick == 0)
    assertNear(encounter.tickAccumulator, 0.5, "fractional combat ticks were discarded")
    local inspection = WorldEncounterSystem.getInspectionData(map, encounter.id)
    assert(inspection.status == "active")
    assert(inspection.partyAName == raider.name and inspection.partyBName == caravan.name)
    assertNear(inspection.elapsedWorldHours, 0.125, "inspection elapsed time is incorrect")
    assert(inspection.survivingPartyA == 1 and inspection.survivingPartyB == 1)
    WorldEncounterSystem.update(0.125, map)
    assert(encounter.runner.simulation.context.data.tick == 1)
    assertNear(encounter.tickAccumulator, 0, "fractional ticks did not accumulate")

    encounter.runner:cleanup()
    encounter.state = "cancelled"
    map.activeEncounters[encounter.id] = nil
    raider.activeEncounterId = nil
    caravan.activeEncounterId = nil
    map.partyEncounterCooldowns = {}
    GameContext.data.playerParty = nil
end

local function testCompletionAppliesOnceAndReleases(world)
    local map = makeMap(world, "victory-map")
    local strong = createParty(world, map, "world-strong", "world-strong-actor", {
        health = 10000,
        attack = 1000,
        defense = 1000,
        skills = {javelin_throw = {learned = true}}
    })
    local weak = createParty(world, map, "world-weak", "world-weak-actor", {
        health = 30,
        attack = 0,
        skills = {javelin_throw = {learned = true}}
    })
    local killed = {}
    EventBus.init()
    EventBus.subscribe("party_killed", function(partyId) killed[#killed + 1] = partyId end)

    local started, encounter = WorldEncounterSystem.start(map, strong, weak, {
        maxTicks = 4000,
        ticksPerWorldHour = 4000
    })
    assert(started)
    local runner = encounter.runner
    withDeterministicRandom(function()
        WorldEncounterSystem.update(1, map)
    end)

    assert(encounter.state == "completed" and encounter.outcome == "victory")
    assert(encounter.resultApplied, "campaign result was not applied")
    assert(encounter.result.actors["world-strong-actor"].finalHp > 0)
    assert(encounter.result.actors["world-weak-actor"].defeated)
    assert(strong.actors[1].hp == encounter.result.actors["world-strong-actor"].finalHp)
    assert(#weak.actors == 0)
    assert(weak.activeEncounterId == nil and strong.activeEncounterId == nil)
    assert(map.activeEncounters[encounter.id] == nil)
    assert(runner.state == "cleaned" and runner.simulation == nil)
    assert(#killed == 1 and killed[1] == weak.id, "party_killed was not emitted exactly once")
    assert(WorldEncounterSystem.getInspectionData(map, "victory-map:encounter:1") == nil,
        "completed encounter remained inspectable as active")
end

local function testTimeoutCooldownDrawAndErrorRelease(world)
    local map = makeMap(world, "timeout-map")
    local timeoutA = createParty(world, map, "timeout-a", "timeout-actor-a", {health = 1000})
    local timeoutB = createParty(world, map, "timeout-b", "timeout-actor-b", {health = 1000})
    local oldCooldown = WorldEncounterSystem.reengagementCooldownHours
    WorldEncounterSystem.reengagementCooldownHours = 0.25

    local started, timeout = WorldEncounterSystem.start(map, timeoutA, timeoutB, {
        maxTicks = 0,
        ticksPerWorldHour = 1
    })
    assert(started)
    local timeoutRunner = timeout.runner
    WorldEncounterSystem.update(0, map)
    assert(timeout.state == "completed" and timeout.outcome == "timeout")
    assert(timeout.resultApplied and timeoutRunner.state == "cleaned")
    assert(timeoutA.actors[1].hp > 0 and timeoutB.actors[1].hp > 0)
    local cooldownStarted, cooldownReason = WorldEncounterSystem.start(map, timeoutA, timeoutB)
    assert(not cooldownStarted and cooldownReason == "party_cooldown")
    WorldEncounterSystem.update(0.25, map)
    assert(WorldEncounterSystem.start(map, timeoutA, timeoutB, {maxTicks = 0}))
    local second = map.activeEncounters["timeout-map:encounter:2"]
    second.runner:cleanup()
    second.state = "cancelled"
    map.activeEncounters[second.id] = nil
    timeoutA.activeEncounterId, timeoutB.activeEncounterId = nil, nil
    map.partyEncounterCooldowns = {}

    local drawMap = makeMap(world, "draw-map")
    local emptyA = createParty(world, drawMap, "draw-a", nil)
    local emptyB = createParty(world, drawMap, "draw-b", nil)
    local drawStarted, draw = WorldEncounterSystem.start(drawMap, emptyA, emptyB)
    assert(drawStarted)
    WorldEncounterSystem.update(0, drawMap)
    assert(draw.state == "completed" and draw.outcome == "draw" and draw.resultApplied)
    assert(emptyA.activeEncounterId == nil and emptyB.activeEncounterId == nil)
    assert(#drawMap:getParties() == 0)

    local errorMap = makeMap(world, "error-map")
    local errorA = createParty(world, errorMap, "error-a", "error-actor-a")
    local errorB = createParty(world, errorMap, "error-b", "error-actor-b")
    local errorStarted, errored = WorldEncounterSystem.start(errorMap, errorA, errorB)
    assert(errorStarted)
    local errorRunner = errored.runner
    errorRunner.advance = function() error("injected encounter failure") end
    local ok = pcall(function() WorldEncounterSystem.update(1, errorMap) end)
    assert(not ok and errored.state == "failed")
    assert(errorA.activeEncounterId == nil and errorB.activeEncounterId == nil)
    assert(errorMap.activeEncounters[errored.id] == nil)
    assert(errorRunner.state == "cleaned" and errorRunner.simulation == nil)

    WorldEncounterSystem.reengagementCooldownHours = oldCooldown
end

local function testConcurrentEncountersAndUnengagedTravel(world)
    local map = makeMap(world, "concurrent-map")
    local a1 = createParty(world, map, "concurrent-a1", "concurrent-a1-actor", {health = 100000})
    local b1 = createParty(world, map, "concurrent-b1", "concurrent-b1-actor", {health = 100000})
    local a2 = createParty(world, map, "concurrent-a2", "concurrent-a2-actor", {health = 100000})
    local b2 = createParty(world, map, "concurrent-b2", "concurrent-b2-actor", {health = 100000})
    local freeTrader = createParty(world, map, "free-trader", "free-trader-actor", {
        state = "wander",
        isTraderParty = true,
        x = 100,
        y = 200
    })
    freeTrader.wanderTarget = {x = 1000, y = 200}
    local player = createParty(world, map, "concurrent-player", "concurrent-player-actor", {
        x = 1800, y = 1800
    })
    local _, first = WorldEncounterSystem.start(map, a1, b1, {
        maxTicks = 100,
        ticksPerWorldHour = 4
    })
    local _, second = WorldEncounterSystem.start(map, a2, b2, {
        maxTicks = 100,
        ticksPerWorldHour = 8
    })
    local firstRunner, secondRunner = first.runner, second.runner

    WorldEncounterSystem.update(0.25, map)
    PartyAiSystem.update(0.25, map, player)
    assert(firstRunner.simulation.context.data.tick == 1)
    assert(secondRunner.simulation.context.data.tick == 2)
    assert(freeTrader.x > 100, "engagement reservation blocked an unrelated trader")

    for _, encounter in ipairs({first, second}) do
        encounter.runner:cleanup()
        encounter.state = "cancelled"
        map.activeEncounters[encounter.id] = nil
    end
    a1.activeEncounterId, b1.activeEncounterId = nil, nil
    a2.activeEncounterId, b2.activeEncounterId = nil, nil
end

local Scenario = {}

function Scenario.run()
    testClockDeltaPauseAndAcceleration()
    local world = EcsWorld.init()
    testDefaultEncounterPacing(world)
    testFractionalAdvancementAndReservations(world)
    testCompletionAppliesOnceAndReleases(world)
    testTimeoutCooldownDrawAndErrorRelease(world)
    testConcurrentEncountersAndUnengagedTravel(world)
    TimeSystem.setPaused(true)
    TimeSystem.setTimeScale(1)
    GameContext.data.playerParty = nil
end

return Scenario
