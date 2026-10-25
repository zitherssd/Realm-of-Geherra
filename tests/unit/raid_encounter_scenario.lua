local EcsWorld = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local Unit = require("src.ecs.assemblages.unit")
local PartySystem = require("src.systems.party_system")
local Map = require("src.world.map")
local GameContext = require("src.game.game_context")
local EventBus = require("src.core.event_bus")
local TimeSystem = require("src.systems.time_system")
local PartyAiSystem = require("src.systems.party_ai_system")
local WorldActivitySystem = require("src.systems.world_activity_system")
local WorldEncounterSystem = require("src.systems.world_encounter_system")
local RaidActivity = require("src.systems.world_activities.raid_activity")
local StateManager = require("src.core.state_manager")
local WorldState = require("src.game.states.world_state")

local function createParty(world, map, id, actorPrefix, config)
    local party = Party.create(world, id, nil, id)
    party.x, party.y = config.x, config.y
    party.state = config.state or "idle"
    party.hostile = config.hostile or false
    party.visible = true
    party.isTraderParty = config.isTraderParty or false
    party.inventory = {{id = id .. "-goods", quantity = 3}}
    party.treasury = 40

    for index = 1, config.actorCount do
        local actor = Unit.create(world, "soldier", actorPrefix .. "-" .. index)
        actor.stats.health = config.health
        actor.stats.attack = config.attack
        actor.stats.defense = config.defense or 0
        actor.stats.battle_speed = 120
        actor.sight = config.sight or actor.sight
        actor.profile = config.profile or actor.profile
        actor.hp = config.health
        actor.maxHp = config.health
        actor.inventory = {bread = 2}
        actor.skills = config.skills or {}
        PartySystem.addActor(party, actor)
    end

    map:addParty(party)
    return party
end

local function mapPartiesContains(map, partyId)
    for _, party in ipairs(map:getParties()) do
        if party.id == partyId then return true end
    end
    return false
end

local function setupServices(map)
    EventBus.init()
    WorldEncounterSystem.init()
    WorldActivitySystem.init()
    GameContext.data.currentMap = map
    GameContext.data.playerParty = nil
    TimeSystem.setPaused(false)
    TimeSystem.setTimeScale(1)
end

local function runContactToCompletion(world)
    local map = Map.new("raid-contact-map")
    local raider = createParty(world, map, "contact-raider", "contact-raider-actor", {
        x = 100,
        y = 100,
        hostile = true,
        state = "wander",
        actorCount = 2,
        sight = 500,
        health = 500,
        attack = 500,
        defense = 100,
        skills = {javelin_throw = {learned = true}}
    })
    raider.wanderTarget = {x = 100, y = 500}

    local caravan = createParty(world, map, "contact-caravan", "contact-caravan-actor", {
        x = 300,
        y = 100,
        state = "wander",
        isTraderParty = true,
        actorCount = 1,
        health = 200,
        attack = 20
    })
    caravan.wanderTarget = {x = 10000, y = 100}
    local caravanActor = caravan.actors[1]
    caravan.inventory[1].metadata = {origin = "caravan", quality = "fine"}
    local originalCaravanCargo = caravan.inventory[1]
    local originalCaravanTreasury = caravan.treasury
    local player = createParty(world, map, "contact-player", "contact-player-actor", {
        x = 1000,
        y = 1000,
        actorCount = 1,
        health = 100,
        attack = 10
    })
    GameContext.data.playerParty = player
    setupServices(map)
    GameContext.data.playerParty = player

    local contacts, startedEvents, finishedEvents = {}, {}, {}
    EventBus.subscribe("party_contact", function(event)
        contacts[#contacts + 1] = event
    end)
    EventBus.subscribe("party_encounter_started", function(event)
        startedEvents[#startedEvents + 1] = event
    end)
    EventBus.subscribe("party_encounter_finished", function(event)
        finishedEvents[#finishedEvents + 1] = event
    end)

    local oldRaidSpeed = RaidActivity.speed
    RaidActivity.speed = 400
    local caravanStartX = caravan.x
    local contactSeen = false
    for _ = 1, 100 do
        local dt = 0.1
        WorldActivitySystem.ensureDefaultActivities(map, player)
        PartyAiSystem.update(dt, map, player)
        WorldActivitySystem.update(dt, map, player)
        if raider.world_activity.phase == "engaged" then
            contactSeen = true
            break
        end
    end
    RaidActivity.speed = oldRaidSpeed

    assert(contactSeen, "raid did not transition to engaged on contact")
    assert(raider.world_activity.type == "raid", "hostile party did not receive a default RaidActivity")
    assert(#contacts == 1 and #startedEvents == 1, "contact did not start exactly one encounter")
    assert(contacts[1].sourcePartyId == raider.id and contacts[1].targetPartyId == caravan.id)
    assert(contacts[1].lootPolicy and contacts[1].lootPolicy.plunderAllowed == true,
        "Raid contact did not provide explicit plunder eligibility")
    local encounterId = startedEvents[1].encounterId
    local encounter = map.activeEncounters[encounterId]
    assert(raider.world_activity.encounterId == encounterId)
    assert(raider.activeEncounterId == encounterId and caravan.activeEncounterId == encounterId)
    assert(caravan.x ~= caravanStartX, "merchant did not move before contact")

    local raiderContactX, caravanContactX = raider.x, caravan.x
    EventBus.emit("party_contact", contacts[1])
    EventBus.emit("party_contact", contacts[1])
    assert(#startedEvents == 1, "duplicate contacts started additional encounters")
    assert(raider.world_activity.phase == "engaged")

    local stationaryWhileEngaged = false
    for _ = 1, 4000 do
        local dt = 0.1
        WorldActivitySystem.ensureDefaultActivities(map, player)
        PartyAiSystem.update(dt, map, player)
        WorldActivitySystem.update(dt, map, player)
        assert(raider.x == raiderContactX and caravan.x == caravanContactX,
            "engaged parties moved during combat")
        stationaryWhileEngaged = true
        WorldEncounterSystem.update(TimeSystem.update(dt), map)
        if raider.world_activity.status ~= "active" then break end
    end

    assert(stationaryWhileEngaged, "combat did not remain active for a world update")
    assert(raider.x == raiderContactX and caravan.x == caravanContactX,
        "engaged parties moved during combat")
    assert(raider.world_activity.status == "completed", "successful raid did not complete")
    assert(raider.world_activity.phase == "complete")
    assert(raider.world_activity.encounterId == nil)
    assert(#finishedEvents == 1 and finishedEvents[1].outcome == "victory")
    assert(finishedEvents[1].winnerPartyId == raider.id)
    assert(caravanActor.hp == 0 and #caravan.actors == 0)
    assert(encounter.lootApplied and encounter.remainsCreated,
        "NPC Raid loot was not applied exactly once")
    assert(#caravan.inventory == 0 and caravan.treasury == 0,
        "eliminated party retained resources after removal")
    assert(next(caravanActor.inventory) == nil and next(caravanActor.equipment) == nil,
        "defeated actor possessions remained available after transfer")
    assert(caravan.actors[1] == nil, "defeated caravan actor remained in its roster")
    assert(not mapPartiesContains(map, caravan.id), "eliminated caravan remained on the map")
    assert(#raider.actors == 2, "surviving raider roster was not preserved")
    local hasRecoveredBread = false
    for _, item in ipairs(raider.inventory) do
        if item.id == "bread" and item.quantity == 2 then hasRecoveredBread = true end
    end
    assert(hasRecoveredBread, "raider did not receive defeated combatant possessions")
    local remains = map:getBattlefieldRemains()
    assert(#remains == 1, "encounter casualties did not create battlefield remains")
    assert(#remains[1].corpses == 1 and remains[1].corpses[1].actorId == caravanActor.id,
        "battlefield corpse did not preserve the actual casualty identity")
    assert(remains[1].loot.gold + (raider.treasury - 40) == originalCaravanTreasury,
        "caravan gold was not conserved between raiders and remains")
    local cargoTotal = 0
    local retainedCargo = 0
    local destroyedCargo = 0
    for _, item in ipairs(raider.inventory) do
        if item.id == originalCaravanCargo.id then cargoTotal = cargoTotal + item.quantity end
    end
    for _, item in ipairs(remains[1].loot.items) do
        if item.item.id == originalCaravanCargo.id then
            retainedCargo = retainedCargo + item.item.quantity
        end
    end
    for _, resource in ipairs(encounter.lootResult.destroyedResources.items) do
        if resource.sourcePartyId == caravan.id and resource.item.id == originalCaravanCargo.id then
            destroyedCargo = destroyedCargo + resource.item.quantity
        end
    end
    assert(cargoTotal + retainedCargo + destroyedCargo == originalCaravanCargo.quantity,
        "caravan cargo was lost or duplicated")
    local receivedMetadata = false
    for _, item in ipairs(raider.inventory) do
        if item.id == originalCaravanCargo.id then
            receivedMetadata = item.metadata and item.metadata.origin == "caravan"
        end
    end
    for _, resource in ipairs(remains[1].loot.items) do
        if resource.item.id == originalCaravanCargo.id then
            receivedMetadata = resource.item.metadata and resource.item.metadata.origin == "caravan"
        end
    end
    assert(receivedMetadata, "cargo metadata was not preserved in loot allocations")
    assert(remains[1].history.encounterId == encounter.id, "battlefield history lost encounter ID")
    for _, actor in ipairs(raider.actors) do
        assert(actor.hp == encounter.result.actors[actor.id].finalHp,
            "surviving actor HP did not match the applied encounter result")
    end
    assert(raider.activeEncounterId == nil, "surviving raider was not released")
    assert(#startedEvents == 1, "encounter count changed after completion")

    WorldActivitySystem.update(0.1, map, player)
    assert(raider.world_activity.status == "idle" and raider.world_activity.type == nil,
        "completed Raid did not release its activity slot")
    assert(raider.world_activity.lastActivity.status == "completed",
        "terminal Raid outcome was not retained for inspection")
    raider.wanderTarget = {x = raider.x + 100, y = raider.y}
    local previousRaiderX = raider.x
    PartyAiSystem.update(0.1, map, player)
    assert(raider.x > previousRaiderX,
        "fallback wandering did not resume after a successful Raid")

    return map, raider, player
end

local function testPlayerRaidUsesInteractiveBattle(world)
    local map = Map.new("raid-player-map")
    local raider = createParty(world, map, "player-raid-raider", "player-raid-raider-actor", {
        x = 100,
        y = 100,
        hostile = true,
        state = "wander",
        actorCount = 1,
        health = 100,
        attack = 20
    })
    local player = createParty(world, map, "raid-target-player", "raid-target-player-actor", {
        x = 100,
        y = 100,
        actorCount = 1,
        health = 100,
        attack = 20
    })
    setupServices(map)
    GameContext.data.playerParty = player
    WorldState.currentMap = map
    WorldState.pendingRaidBattle = nil
    EventBus.subscribe("party_contact", WorldState._onPartyContact)

    local contact
    EventBus.subscribe("party_contact", function(event)
        contact = event
    end)
    WorldActivitySystem.update(0.01, map, player)
    assert(raider.world_activity.targetId == player.id, "hostile did not select the player party")
    assert(raider.world_activity.phase == "engaged", "player contact did not engage the raid")
    assert(WorldState.pendingRaidBattle, "player contact did not queue an interactive battle")
    local encounterId = WorldState.pendingRaidBattle.encounterId
    WorldState._onPartyContact(contact)
    assert(WorldState.pendingRaidBattle.encounterId == encounterId,
        "duplicate player contact created another encounter")

    local oldSwap = StateManager.swap
    local requestedState, battleParams
    StateManager.swap = function(stateName, params)
        requestedState, battleParams = stateName, params
    end

    assert(WorldState._startPendingRaidBattle())
    StateManager.swap = oldSwap
    assert(requestedState == "battle", "player encounter did not enter BattleState")
    assert(battleParams.enemyParty == raider, "interactive battle used the wrong enemy party")

    battleParams.onComplete({
        outcome = "victory",
        winnerPartyId = raider.id
    })
    assert(raider.world_activity.status == "completed",
        "RaidActivity did not complete after the raider won the player battle")
    assert(raider.world_activity.phase == "complete")

    EventBus.unsubscribe("party_contact", WorldState._onPartyContact)
    WorldState.currentMap = nil
    WorldState.pendingRaidBattle = nil
end

local function testCooldownAfterTimeout(world)
    local map = Map.new("raid-cooldown-map")
    local raider = createParty(world, map, "cooldown-raider", "cooldown-raider-actor", {
        x = 100,
        y = 100,
        hostile = true,
        actorCount = 1,
        health = 1000,
        attack = 0
    })
    local caravan = createParty(world, map, "cooldown-caravan", "cooldown-caravan-actor", {
        x = 100,
        y = 100,
        state = "wander",
        isTraderParty = true,
        actorCount = 1,
        health = 1000,
        attack = 0
    })
    caravan.wanderTarget = {x = 10000, y = 100}
    setupServices(map)
    local previousMaxTicks = WorldEncounterSystem.maxCombatTicks
    WorldEncounterSystem.maxCombatTicks = 0

    assert(WorldActivitySystem.start(raider, "raid"))
    WorldActivitySystem.update(0.01, map, nil)
    assert(raider.world_activity.phase == "engaged")
    WorldEncounterSystem.update(0, map)
    assert(raider.world_activity.status == "cancelled")
    assert(raider.world_activity.reason == "encounter_timeout")
    assert(map.partyEncounterCooldowns[raider.id] > 0)

    WorldActivitySystem.update(0.01, map, nil)
    assert(raider.world_activity.status == "idle" and raider.world_activity.type == nil,
        "timed-out Raid did not release its activity slot")
    assert(raider.world_activity.lastActivity.reason == "encounter_timeout")
    assert(WorldActivitySystem.start(raider, "raid"))
    WorldActivitySystem.update(0.01, map, nil)
    assert(raider.world_activity.status == "cancelled")
    assert(raider.world_activity.reason == "no_target")
    assert(raider.activeEncounterId == nil and caravan.activeEncounterId == nil)

    WorldEncounterSystem.update(WorldEncounterSystem.reengagementCooldownHours, map)
    WorldEncounterSystem.maxCombatTicks = previousMaxTicks
end

local function testDefeatedRaidCleanup(world)
    local map = Map.new("raid-defeat-map")
    local raider = createParty(world, map, "defeated-raider", "defeated-raider-actor", {
        x = 100,
        y = 100,
        hostile = true,
        actorCount = 1,
        health = 100
    })
    local target = createParty(world, map, "defeated-target", "defeated-target-actor", {
        x = 100,
        y = 100,
        state = "travel",
        isTraderParty = true,
        actorCount = 1,
        health = 100
    })
    setupServices(map)
    assert(WorldActivitySystem.start(raider, "raid"))
    raider.world_activity.phase = "engaged"
    raider.world_activity.targetId = target.id
    raider.world_activity.encounterId = "raid-defeat-map:encounter:test"
    assert(RaidActivity.onEncounterFinished(raider.world_activity, {
        encounterId = raider.world_activity.encounterId,
        outcome = "victory",
        winnerPartyId = target.id,
        sourcePartyId = raider.id
    }))
    assert(raider.world_activity.status == "cancelled")
    assert(raider.world_activity.reason == "raider_defeated")

    WorldActivitySystem.update(0.1, map, nil)
    assert(raider.world_activity.status == "idle" and raider.world_activity.type == nil)
    assert(raider.world_activity.lastActivity.reason == "raider_defeated")
    assert(raider.world_activity.retryCooldownSeconds > 0)
end

local Scenario = {}

function Scenario.run()
    local world = EcsWorld.init()
    runContactToCompletion(world)
    testPlayerRaidUsesInteractiveBattle(world)
    testCooldownAfterTimeout(world)
    testDefeatedRaidCleanup(world)
    GameContext.data.currentMap = nil
    GameContext.data.playerParty = nil
    TimeSystem.setPaused(true)
end

return Scenario
