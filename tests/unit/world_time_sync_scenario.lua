local EcsWorld = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local Location = require("src.ecs.assemblages.location")
local Unit = require("src.ecs.assemblages.unit")
local PartySystem = require("src.systems.parties.party_system")
local Map = require("src.world.map")
local GameContext = require("src.game.game_context")
local Input = require("src.core.input")
local TimeSystem = require("src.systems.campaign.time_system")
local WorldActivitySystem = require("src.systems.world_activities.world_activity_system")
local WorldState = require("src.game.states.world_state")
local WorldEncounterSystem = require("src.systems.campaign.world_encounter_system")

local function addParty(world, map, id, x, y, config)
    config = config or {}
    local party = Party.create(world, id, nil, id)
    party.x, party.y = x, y
    party.state = config.state or "idle"
    party.hostile = config.hostile or false
    party.isTraderParty = config.isTraderParty or false
    for index = 1, config.actorCount or 1 do
        local actor = Unit.create(world, config.troopType or "soldier", id .. "-actor-" .. index)
        if config.health then
            actor.stats.health = config.health
            actor.hp = config.health
            actor.maxHp = config.health
        end
        actor.sight = config.sight or 0
        actor.profile = config.profile or 0
        PartySystem.addActor(party, actor)
    end

    map:addParty(party)
    return party
end

local function runWorldUpdate(keys, dt)
    Input.isKeyDown = function(key)
        return keys[key] == true
    end
    WorldState.update(dt)
end

local function runScenario()
    local world = EcsWorld.init()
    local map = Map.new("world-time-sync-map")
    map.width, map.height = 2000, 2000
    local origin = Location.create(world, "time-origin", "Origin")
    origin.siteId, origin.x, origin.y = "time-origin-site", 300, 300
    local destination = Location.create(world, "time-destination", "Destination")
    destination.siteId, destination.x, destination.y = "time-destination-site", 1500, 300
    map:addLocation(origin)
    map:addLocation(destination)
    map.worldGen = {
        roads = {{
            from = origin.siteId,
            to = destination.siteId,
            points = {{x = origin.x, y = origin.y}, {x = destination.x, y = destination.y}}
        }}
    }
    local player = addParty(world, map, "time-player", 20, 20)
    local caravan = addParty(world, map, "time-caravan", 300, 300, {
        isTraderParty = true
    })
    assert(map:removeParty(caravan.id))
    assert(map:stationParty(origin, caravan))
    assert(WorldActivitySystem.start(caravan, "travel", {
        destinationLocationId = destination.id
    }, map))
    -- Consume the initial waypoint at the origin before comparing movement deltas.
    WorldActivitySystem.update(0.01, map, player)
    local wanderingTrader = addParty(world, map, "time-wandering-trader", 645, 600, {
        state = "wander",
        isTraderParty = true,
        sight = 0,
        profile = 0
    })
    wanderingTrader.wanderTarget = {x = 1000, y = 600}

    local raider = addParty(world, map, "time-lost-sight-raider", 100, 300, {
        state = "wander",
        hostile = true,
        sight = 0
    })
    local rememberedTarget = addParty(world, map, "time-remembered-target", 500, 300, {
        state = "wander",
        isTraderParty = true
    })
    rememberedTarget.wanderTarget = {x = 700, y = 300}
    local WorldActivitySystem = require("src.systems.world_activities.world_activity_system")
    assert(WorldActivitySystem.start(raider, "raid"))
    raider.world_activity.phase = "pursuit"
    raider.world_activity.targetId = rememberedTarget.id
    raider.world_activity.lastKnownX = 200
    raider.world_activity.lastKnownY = 300
    raider.world_activity.targetLostSeconds = 0

    local readyBandit = addParty(world, map, "time-ready-bandit", 600, 600, {
        state = "wander",
        hostile = true,
        sight = 1000
    })
    readyBandit.wanderTarget = {x = 500, y = 600}

    local encounterA = addParty(world, map, "time-encounter-a", 1000, 1000, {health = 100000})
    local encounterB = addParty(world, map, "time-encounter-b", 1200, 1000, {health = 100000})
    local started, encounter = WorldEncounterSystem.start(map, encounterA, encounterB, {
        maxTicks = 100000
    })
    assert(started)

    map.partyEncounterCooldowns = {[raider.id] = 1}
    GameContext.data.currentMap = map
    GameContext.data.playerParty = player
    GameContext.data.time = {day = 1, hour = 0}
    TimeSystem.setPaused(false)
    TimeSystem.setTimeScale(1)
    WorldState.currentMap = map
    WorldState.camera = {
        update = function() end,
        screenToWorld = function() return 0, 0 end,
        getZoom = function() return 1 end
    }
    WorldState.isResting = false
    WorldState.restInputLock = 0
    WorldState.restStartTotalHour = nil
    WorldState.interactionCooldowns = {}
    WorldState.popup = nil

    local loveMouse = love.mouse
    love.mouse = {getPosition = function() return 0, 0 end}
    local initialCaravanX = caravan.x
    local initialWandererX = wanderingTrader.x
    local initialRaiderX = raider.x
    local initialEncounterTicks = encounter.runner.simulation.context.data.tick
    local initialTargetLost = raider.world_activity.targetLostSeconds
    local recoveringActor = caravan.actors[1]
    recoveringActor.hp = recoveringActor.maxHp * 0.5
    local initialHp = recoveringActor.hp

    runWorldUpdate({}, 0.1)
    assert(TimeSystem.isPaused())
    assert(recoveringActor.hp == initialHp, "NPC healed while world time was paused")
    assert(caravan.x == initialCaravanX and wanderingTrader.x == initialWandererX,
        "NPC traders moved while world time was paused")
    assert(raider.x == initialRaiderX, "raider moved while world time was paused")
    assert(readyBandit.world_activity.status == "idle",
        "bandit acquired a target while world time was paused")
    assert(raider.world_activity.targetLostSeconds == initialTargetLost,
        "lost-sight timer advanced while world time was paused")
    assert(map.partyEncounterCooldowns[raider.id] == 1,
        "encounter cooldown advanced while world time was paused")
    assert(encounter.runner.simulation.context.data.tick == initialEncounterTicks,
        "active battle advanced while world time was paused")

    runWorldUpdate({space = true}, 0.1)
    assert(math.abs(recoveringActor.hp - initialHp - recoveringActor.maxHp / 300 * 0.1) < 1e-7,
        "WorldState did not apply passive recovery to NPC parties exactly once")
    assert(caravan.x > initialCaravanX, "waiting did not advance trader travel")
    assert(wanderingTrader.x ~= initialWandererX, "waiting did not advance fallback wandering")
    assert(raider.x > initialRaiderX,
        "waiting did not advance lost-target pursuit: x=" .. tostring(raider.x) ..
        ", phase=" .. tostring(raider.world_activity.phase) ..
        ", status=" .. tostring(raider.world_activity.status) ..
        ", reason=" .. tostring(raider.world_activity.reason))
    assert(readyBandit.world_activity.status == "active",
        "waiting did not allow the bandit to acquire its visible target")
    assert(raider.world_activity.targetLostSeconds > initialTargetLost,
        "lost-sight timer did not advance with world time")
    assert(map.partyEncounterCooldowns[raider.id] < 1,
        "encounter cooldown did not advance with world time")
    local normalTicks = encounter.runner.simulation.context.data.tick
    assert(normalTicks > initialEncounterTicks, "waiting did not advance an active encounter")

    local previousCaravanX = caravan.x
    WorldState.isResting = true
    runWorldUpdate({}, 0.1)
    WorldState.isResting = false
    local restTravel = caravan.x - previousCaravanX
    assert(restTravel > 0, "resting did not advance trader travel")

    local previousCaravanXAtNormalScale = caravan.x
    local hpBeforeAcceleration = recoveringActor.hp
    TimeSystem.setTimeScale(2)
    runWorldUpdate({space = true}, 0.1)
    local acceleratedTravel = caravan.x - previousCaravanXAtNormalScale
    assert(math.abs(recoveringActor.hp - hpBeforeAcceleration - recoveringActor.maxHp / 300 * 0.2) < 1e-7,
        "accelerated world time did not scale recovery proportionally")
    assert(math.abs(acceleratedTravel - restTravel * 2) < 1e-6,
        "time acceleration did not scale world movement consistently")

    local previousPlayerX = player.x
    local previousCaravanXAtAcceleratedScale = caravan.x
    runWorldUpdate({right = true}, 0.1)
    assert(math.abs(player.x - previousPlayerX - WorldState.playerPartySpeed * 0.1) < 1e-6,
        "player movement speed changed with world time acceleration")
    assert(math.abs((caravan.x - previousCaravanXAtAcceleratedScale) -
        acceleratedTravel) < 1e-6,
        "NPC movement did not retain accelerated world-time speed")

    assert(math.abs(TimeSystem.worldHoursToSeconds(0.15) - 0.1) < 1e-7,
        "world-hour to world-second conversion is incorrect")

    -- Completion during the current update must not heal the time spent fighting.
    local combatActor = encounterA.actors[1]
    combatActor.hp = combatActor.maxHp / 2
    local combatHp = combatActor.hp
    local originalEncounterUpdate = WorldEncounterSystem.update
    WorldEncounterSystem.update = function()
        encounterA.activeEncounterId, encounterB.activeEncounterId = nil, nil
        map.activeEncounters[encounter.id] = nil
    end
    local completionOk, completionError = pcall(runWorldUpdate, {space = true}, 0.1)
    WorldEncounterSystem.update = originalEncounterUpdate
    assert(completionOk, completionError)
    assert(combatActor.hp == combatHp, "encounter completion granted recovery for combat time")
    runWorldUpdate({space = true}, 0.1)
    assert(math.abs(combatActor.hp - combatHp - combatActor.maxHp / 300 * 0.2) < 1e-7,
        "passive recovery did not resume on the update after combat")
    encounter.runner:cleanup()
    map.activeEncounters[encounter.id] = nil
    encounterA.activeEncounterId, encounterB.activeEncounterId = nil, nil
    love.mouse = loveMouse
    TimeSystem.setPaused(true)
    TimeSystem.setTimeScale(1)
    WorldState.currentMap = nil
    WorldState.camera = nil
    WorldState.isResting = false
    WorldState.interactionCooldowns = {}
    GameContext.data.currentMap = nil
    GameContext.data.playerParty = nil
end

local Scenario = {}

function Scenario.run()
    local originalInput = Input.isKeyDown
    local loveMouse = love.mouse
    local ok, err = xpcall(runScenario, debug.traceback)
    Input.isKeyDown = originalInput
    love.mouse = loveMouse
    if not ok then
        error(err, 0)
    end
end

return Scenario
