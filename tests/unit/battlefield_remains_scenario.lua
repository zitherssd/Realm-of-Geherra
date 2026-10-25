local EcsWorld = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local Unit = require("src.ecs.assemblages.unit")
local PartySystem = require("src.systems.party_system")
local Map = require("src.world.map")
local GameContext = require("src.game.game_context")
local EventBus = require("src.core.event_bus")
local TimeSystem = require("src.systems.time_system")
local WorldEncounterSystem = require("src.systems.world_encounter_system")
local LootResolver = require("src.systems.loot_resolver")
local LootApplication = require("src.systems.loot_application")
local BattlefieldRemainsSystem = require("src.systems.battlefield_remains_system")

local function makeActor(world, id, properties)
    local actor = Unit.create(world, "soldier", id)
    for key, value in pairs(properties or {}) do
        actor[key] = value
    end
    return actor
end

local function makeParty(world, map, id, actors)
    local party = Party.create(world, id, nil, id)
    party.inventory = {{id = id .. "-cargo", quantity = 4, metadata = {quality = "good"}}}
    party.treasury = 25
    for _, actor in ipairs(actors or {}) do
        PartySystem.addActor(party, actor)
    end
    map:addParty(party)
    return party
end

local function makeActorResult(party, actor, hp)
    return {
        partyId = party.id,
        finalHp = hp,
        defeated = hp <= 0
    }
end

local function testPartialCasualtiesAndPausedState()
    local world = EcsWorld.init()
    local map = Map.new("partial-remains-map")
    local actorADead = makeActor(world, "partial-a-dead", {
        name = "A Fallen",
        troopType = "soldier",
        inventory = {bread = 2}
    })
    local actorAAlive = makeActor(world, "partial-a-alive", {name = "A Survivor"})
    local actorBDead = makeActor(world, "partial-b-dead", {
        name = "B Fallen",
        troopType = "soldier",
        equipment = {mainHand = "iron_sword"},
        itemDurability = {iron_sword = 7}
    })
    local actorBAlive = makeActor(world, "partial-b-alive", {name = "B Survivor"})
    local partyA = makeParty(world, map, "partial-a", {actorADead, actorAAlive})
    local partyB = makeParty(world, map, "partial-b", {actorBDead, actorBAlive})
    local result = {
        partyAId = partyA.id,
        partyBId = partyB.id,
        outcome = "timeout",
        actors = {
            [actorADead.id] = makeActorResult(partyA, actorADead, 0),
            [actorAAlive.id] = makeActorResult(partyA, actorAAlive, 30),
            [actorBDead.id] = makeActorResult(partyB, actorBDead, 0),
            [actorBAlive.id] = makeActorResult(partyB, actorBAlive, 30)
        }
    }
    local encounter = {
        id = "partial-encounter",
        partyAId = partyA.id,
        partyBId = partyB.id,
        partyA = partyA,
        partyB = partyB,
        x = 123,
        y = 456
    }
    local lootResult = LootResolver.resolve(
        partyA, partyB, result, {plunderAllowed = false}, function() return 0.5 end
    )
    local cargoAllocation
    for _, resource in ipairs(lootResult.retainedResources.items) do
        if resource.sourceKind == "party_inventory" then
            cargoAllocation = resource
            break
        end
    end
    local originalQuantity = cargoAllocation.item.quantity
    cargoAllocation.item.quantity = originalQuantity + 1
    local malformedAccepted = pcall(function()
        LootApplication.prepare(lootResult, {
            map = map,
            encounter = encounter,
            battleResult = result,
            worldTime = {day = 4, hour = 9.5}
        })
    end)
    cargoAllocation.item.quantity = originalQuantity
    assert(not malformedAccepted, "invalid loot accounting was accepted")
    assert(#map:getBattlefieldRemains() == 0 and partyA.inventory[1].quantity == 4,
        "invalid loot changed campaign state before validation")

    local plan = LootApplication.prepare(lootResult, {
        map = map,
        encounter = encounter,
        battleResult = result,
        worldTime = {day = 4, hour = 9.5}
    })
    LootApplication.apply(plan)
    assert(#map:getBattlefieldRemains() == 1, "casualties did not create a remains site")
    local remains = map:getBattlefieldRemains()[1]
    assert(#remains.corpses == 2, "living actors were recorded as corpses")
    assert(remains.corpses[1].actorId == actorADead.id and
        remains.corpses[2].actorId == actorBDead.id, "corpse actor IDs were not preserved")
    assert(remains.loot.gold == 0 and #remains.loot.items == 0,
        "surviving parties' retained resources were incorrectly abandoned")
    local retainedBread, retainedSword = false, false
    for _, item in ipairs(partyA.inventory) do
        if item.id == "bread" and item.quantity == 2 then retainedBread = true end
    end
    for _, item in ipairs(partyB.inventory) do
        if item.id == "iron_sword" and item.durabilityRemaining == 7 then retainedSword = true end
    end
    assert(retainedBread and retainedSword, "possessions of fallen actors were not retained by surviving parties")

    local beforePause = BattlefieldRemainsSystem.serialize(map)
    WorldEncounterSystem.update(0, map)
    local afterPause = BattlefieldRemainsSystem.serialize(map)
    assert(#afterPause.sites == #beforePause.sites and
        afterPause.sites[1].history.encounterId == beforePause.sites[1].history.encounterId,
        "remains changed while the world was paused")
    assert(encounter.lootApplied and encounter.remainsCreated,
        "application lifecycle flags were not set")
    assert(not pcall(function() LootApplication.apply(plan) end),
        "duplicate loot application was accepted")
end

local function testEliminatedPartyResourcesAndNonRaidEncounter()
    local world = EcsWorld.init()
    local map = Map.new("nonraid-remains-map")
    local winnerActor = makeActor(world, "nonraid-winner", {
        stats = {health = 500, attack = 500, defense = 100, battle_speed = 120},
        hp = 500,
        maxHp = 500
    })
    local deadActor = makeActor(world, "nonraid-dead", {
        stats = {health = 30, attack = 0, defense = 0, battle_speed = 120},
        hp = 30,
        maxHp = 30,
        name = "Lost Guard",
        troopType = "soldier",
        species = "human",
        race = "riverfolk",
        factions = {watch = true},
        inventory = {bread = 1}
    })
    local winner = makeParty(world, map, "nonraid-winner-party", {winnerActor})
    local defeated = makeParty(world, map, "nonraid-defeated-party", {deadActor})
    defeated.inventory = {
        {id = "spice", quantity = 10, metadata = {grade = "rare", seal = {intact = true}}}
    }
    defeated.treasury = 50

    GameContext.data.playerParty = nil
    GameContext.data.currentMap = map
    EventBus.init()
    TimeSystem.setPaused(false)
    TimeSystem.setTimeScale(1)
    WorldEncounterSystem.init()
    local started, encounter = WorldEncounterSystem.start(map, winner, defeated, {
        maxTicks = 4000,
        ticksPerWorldHour = 4000,
        lootPolicy = {plunderAllowed = false}
    })
    assert(started)
    local oldRandom = math.random
    math.random = function(first)
        if first then return first end
        return 0.5
    end
    local ok, err = xpcall(function() WorldEncounterSystem.update(1, map) end, debug.traceback)
    math.random = oldRandom
    if not ok then error(err, 0) end

    assert(encounter.state == "completed" and encounter.lootApplied)
    assert(encounter.lootResult.plunder.eligible == false,
        "non-Raid encounter unexpectedly enabled plunder")
    assert(#defeated.actors == 0 and #defeated.inventory == 0 and defeated.treasury == 0,
        "eliminated party retained duplicate cargo")
    assert(#map:getBattlefieldRemains() == 1,
        "non-Raid encounter casualties did not create battlefield remains")
    local site = map:getBattlefieldRemains()[1]
    assert(#site.corpses == 1, "dead campaign actor was not recorded")
    local corpse = site.corpses[1]
    assert(corpse.actorId == deadActor.id and corpse.name == "Lost Guard" and
        corpse.unitTypeId == "soldier" and corpse.species == "human" and
        corpse.race == "riverfolk" and corpse.faction == defeated.faction,
        "corpse identity and affiliations were not preserved")
    assert(corpse.factions[1] == "watch", "actor faction affiliations were omitted")
    assert(site.loot.gold == 50, "retained gold from an eliminated party was lost")
    assert(#site.loot.items == 1 and site.loot.items[1].item.id == "spice" and
        site.loot.items[1].item.quantity == 10 and
        site.loot.items[1].item.metadata.seal.intact,
        "eliminated party item metadata or quantity was not preserved")
    assert(winner.treasury == 25,
        "ordinary combat transferred gold despite plunder being disallowed")
    local winnerHasBread = false
    for _, item in ipairs(winner.inventory) do
        if item.id == "bread" and item.quantity == 1 then winnerHasBread = true end
    end
    assert(winnerHasBread, "actual defeated combatant possessions were not recovered")

    local serialized = BattlefieldRemainsSystem.serialize(map)
    local restoredMap = Map.new(map.id)
    BattlefieldRemainsSystem.restore(restoredMap, serialized)
    local restored = BattlefieldRemainsSystem.getAll(restoredMap)
    assert(#restored == 1 and restored[1].id == site.id and
        restored[1].corpses[1].actorId == corpse.actorId and
        restored[1].loot.items[1].item.metadata.seal.intact,
        "battlefield remains did not survive the map-state serialization round trip")
    assert(restoredMap.nextBattlefieldRemainsSequence == map.nextBattlefieldRemainsSequence,
        "remains ID sequence was not restored")
    GameContext.data.playerParty = nil
end

local Scenario = {}

function Scenario.run()
    testPartialCasualtiesAndPausedState()
    testEliminatedPartyResourcesAndNonRaidEncounter()
end

return Scenario
