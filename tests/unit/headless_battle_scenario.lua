local EcsWorld = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local Unit = require("src.ecs.assemblages.unit")
local PartySystem = require("src.systems.parties.party_system")
local HeadlessBattleRunner = require("src.game.battle.headless_battle_runner")

local function copyTable(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do
        copy[key] = copyTable(child)
    end
    return copy
end

local function assertTablesEqual(actual, expected, label)
    assert(type(actual) == type(expected), label .. " changed type")
    if type(expected) ~= "table" then
        assert(actual == expected, label .. " changed")
        return
    end
    for key, value in pairs(expected) do
        assertTablesEqual(actual[key], value, label .. "." .. tostring(key))
    end
    for key in pairs(actual) do
        assert(expected[key] ~= nil, label .. " gained field " .. tostring(key))
    end
end

local function assertSerializable(value, label)
    local valueType = type(value)
    assert(valueType == "nil" or valueType == "string" or valueType == "number" or
        valueType == "boolean" or valueType == "table", label .. " contains a non-primitive value")
    if valueType == "table" then
        for key, child in pairs(value) do
            assert(type(key) == "string" or type(key) == "number", label .. " has a non-primitive key")
            assertSerializable(child, label .. "." .. tostring(key))
        end
    end
end

local function withDeterministicRandom(callback)
    local previousRandom = math.random
    math.random = function(first, second)
        if first == nil then
            return 0.5
        elseif second == nil then
            if first == 100 then return 1 end
            return first
        end
        return second
    end

    local ok, result = xpcall(callback, debug.traceback)
    math.random = previousRandom
    if not ok then
        error(result, 0)
    end
    return result
end

local function createActor(world, actorId, config)
    config = config or {}
    local actor = Unit.create(world, "soldier", actorId)
    actor.stats.health = config.health or 100
    actor.stats.attack = config.attack or 10
    actor.stats.strength = config.strength or 0
    actor.stats.defense = config.defense or 0
    actor.stats.battle_speed = config.battleSpeed or 120
    actor.hp = actor.stats.health
    actor.maxHp = actor.stats.health
    actor.skills = config.skills or {}
    actor.statusEffects = config.statusEffects and copyTable(config.statusEffects) or {}
    actor.inventory = {{id = "actor_supply", quantity = 2, metadata = {bound = false}}}
    actor.equipment = config.equipment or {}
    actor.itemDurability = {}
    return actor
end

local function createParty(world, partyId, actorId, config)
    local party = Party.create(world, partyId, nil, partyId)
    party.inventory = {{id = "party_supply", quantity = 3, metadata = {quality = "good"}}}
    local actor = createActor(world, actorId, config)
    PartySystem.addActor(party, actor)
    return party, actor
end

local function snapshotCampaign(partyA, partyB)
    local snapshot = {}
    for _, party in ipairs({partyA, partyB}) do
        local actorSnapshots = {}
        for _, actor in ipairs(party.actors) do
            actorSnapshots[#actorSnapshots + 1] = {
                actor = actor,
                hp = actor.hp,
                maxHp = actor.maxHp,
                stats = copyTable(actor.stats),
                skills = copyTable(actor.skills),
                statusEffects = copyTable(actor.statusEffects),
                inventory = copyTable(actor.inventory),
                equipment = copyTable(actor.equipment),
                itemDurability = copyTable(actor.itemDurability)
            }
        end
        snapshot[#snapshot + 1] = {
            party = party,
            actors = {unpack(party.actors)},
            inventory = copyTable(party.inventory),
            actorSnapshots = actorSnapshots
        }
    end
    return snapshot
end

local function assertCampaignUnchanged(snapshot)
    for _, partySnapshot in ipairs(snapshot) do
        local party = partySnapshot.party
        assert(#party.actors == #partySnapshot.actors, "party roster size changed")
        for i, actor in ipairs(partySnapshot.actors) do
            assert(party.actors[i] == actor, "party roster membership changed")
        end
        assertTablesEqual(party.inventory, partySnapshot.inventory, "party inventory")
        for _, actorSnapshot in ipairs(partySnapshot.actorSnapshots) do
            local actor = actorSnapshot.actor
            assert(actor.hp == actorSnapshot.hp, "runner modified campaign actor HP")
            assert(actor.maxHp == actorSnapshot.maxHp, "runner modified campaign actor max HP")
            assertTablesEqual(actor.stats, actorSnapshot.stats, "actor stats")
            assertTablesEqual(actor.skills, actorSnapshot.skills, "actor skills")
            assertTablesEqual(actor.statusEffects, actorSnapshot.statusEffects, "actor status effects")
            assertTablesEqual(actor.inventory, actorSnapshot.inventory, "actor inventory")
            assertTablesEqual(actor.equipment, actorSnapshot.equipment, "actor equipment")
            assertTablesEqual(actor.itemDurability, actorSnapshot.itemDurability, "actor equipment durability")
        end
    end
end

local function testVictoryForBothSides()
    local world = EcsWorld.init()
    local strongA, strongAActor = createParty(world, "strong-a", "strong-a-actor", {
        health = 10000,
        attack = 1000,
        strength = 1000,
        equipment = {mainHand = "iron_sword", rangedWeapon = "javelin"},
        defense = 1000,
        skills = {javelin_throw = {learned = true}}
    })
    local weakB, weakBActor = createParty(world, "weak-b", "weak-b-actor", {
        health = 30,
        attack = 0,
        skills = {javelin_throw = {learned = true}}
    })

    local snapshot = snapshotCampaign(strongA, weakB)
    local resultA = HeadlessBattleRunner.run(strongA, weakB, {maxTicks = 4000})
    assert(resultA.outcome == "victory" and resultA.winnerPartyId == strongA.id,
        string.format("first matchup ended %s, winner=%s, ticks=%d, HPs=%s/%s",
            tostring(resultA.outcome), tostring(resultA.winnerPartyId), resultA.ticks,
            tostring(resultA.actors[strongAActor.id].finalHp), tostring(resultA.actors[weakBActor.id].finalHp)))
    assert(resultA.loserPartyId == weakB.id)
    assert(resultA.actors[weakBActor.id].defeated)
    assert(resultA.actors[strongAActor.id].finalHp > 0)
    assert(resultA.ticks > 0 and resultA.ticks <= 4000)
    assertSerializable(resultA, "EncounterResult")
    assertCampaignUnchanged(snapshot)
    print(string.format(
        "Sample EncounterResult: parties=%s/%s winner=%s outcome=%s ticks=%d defeated=%s finalHp=%d",
        resultA.partyAId, resultA.partyBId, resultA.winnerPartyId, resultA.outcome,
        resultA.ticks, tostring(resultA.actors[weakBActor.id].defeated),
        resultA.actors[strongAActor.id].finalHp
    ))

    local strongB, strongBActor = createParty(world, "strong-b", "strong-b-actor", {
        health = 10000,
        attack = 1000,
        strength = 1000,
        equipment = {mainHand = "iron_sword", rangedWeapon = "javelin"},
        defense = 1000,
        skills = {javelin_throw = {learned = true}}
    })
    local weakA, weakAActor = createParty(world, "weak-a", "weak-a-actor", {
        health = 30,
        attack = 0,
        skills = {javelin_throw = {learned = true}}
    })
    local reverseSnapshot = snapshotCampaign(strongB, weakA)
    local resultB = HeadlessBattleRunner.run(weakA, strongB, {maxTicks = 4000})
    assert(resultB.outcome == "victory" and resultB.winnerPartyId == strongB.id)
    assert(resultB.loserPartyId == weakA.id)
    assert(resultB.actors[weakAActor.id].defeated)
    assert(resultB.actors[strongBActor.id].finalHp > 0)
    assertCampaignUnchanged(reverseSnapshot)
end

local function testTimeoutAndDraw()
    local world = EcsWorld.init()
    local partyA = createParty(world, "timeout-a", "timeout-actor-a", {
        health = 100000,
        skills = {}
    })
    local partyB = createParty(world, "timeout-b", "timeout-actor-b", {
        health = 100000,
        skills = {}
    })
    local result = HeadlessBattleRunner.run(partyA, partyB, {maxTicks = 3})
    assert(result.outcome == "timeout")
    assert(result.winnerPartyId == nil and result.loserPartyId == nil)
    assert(result.ticks == 3)

    local emptyA = Party.create(world, "empty-a", nil, "empty-a")
    local emptyB = Party.create(world, "empty-b", nil, "empty-b")
    local draw = HeadlessBattleRunner.run(emptyA, emptyB)
    assert(draw.outcome == "draw")
    assert(draw.winnerPartyId == nil)
    assert(draw.ticks == 0)
end

local function testIncrementalEncounters()
    local world = EcsWorld.init()
    local continuousA, continuousActorA = createParty(world, "continuous-a", "continuous-actor-a", {
        health = 10000,
        attack = 1000,
        strength = 1000,
        equipment = {mainHand = "iron_sword", rangedWeapon = "javelin"},
        defense = 1000,
        skills = {javelin_throw = {learned = true}}
    })
    local continuousB, continuousActorB = createParty(world, "continuous-b", "continuous-actor-b", {
        health = 30,
        attack = 0,
        skills = {javelin_throw = {learned = true}}
    })
    local continuousResult = HeadlessBattleRunner.run(continuousA, continuousB, {maxTicks = 4000})

    local batchA, batchActorA = createParty(world, "batch-a", "batch-actor-a", {
        health = 10000,
        attack = 1000,
        strength = 1000,
        equipment = {mainHand = "iron_sword", rangedWeapon = "javelin"},
        defense = 1000,
        skills = {javelin_throw = {learned = true}}
    })
    local batchB, batchActorB = createParty(world, "batch-b", "batch-actor-b", {
        health = 30,
        attack = 0,
        skills = {javelin_throw = {learned = true}}
    })
    local snapshot = snapshotCampaign(batchA, batchB)
    local encounter = HeadlessBattleRunner.start(batchA, batchB, {maxTicks = 4000})
    local battleUnit = encounter.simulation.context.data.unitList[1]

    assert(encounter.state == "active")
    assert(encounter:advance(1) == nil)
    assert(encounter.simulation.context.data.tick == 1)
    assert(encounter.simulation.context.data.unitList[1] == battleUnit,
        "battle unit was not preserved between advances")

    local result
    while not result do
        result = encounter:advance(17)
    end
    assert(encounter.state == "completed")
    assert(encounter:getResult() == result)
    assert(result.outcome == continuousResult.outcome)
    assert(result.winnerPartyId == batchA.id)
    assert(result.ticks == continuousResult.ticks)
    assert(result.actors[batchActorA.id].finalHp == continuousResult.actors[continuousActorA.id].finalHp)
    assert(result.actors[batchActorB.id].finalHp == continuousResult.actors[continuousActorB.id].finalHp)
    assert(result.actors[batchActorA.id].defeated == continuousResult.actors[continuousActorA.id].defeated)
    assert(result.actors[batchActorB.id].defeated == continuousResult.actors[continuousActorB.id].defeated)
    assertCampaignUnchanged(snapshot)

    local ok, err = pcall(function() encounter:advance(1) end)
    assert(not ok and string.find(err, "completed", 1, true),
        "completed encounter accepted another advance")

    local simulation = encounter.simulation
    local battleWorld = simulation.world
    encounter:cleanup()
    assert(encounter.state == "cleaned")
    assert(encounter.simulation == nil)
    assert(simulation.world == nil, "cleanup retained the battle world")
    assert(battleWorld ~= nil)
    ok, err = pcall(function() encounter:advance(1) end)
    assert(not ok and string.find(err, "cleaned", 1, true),
        "cleaned encounter accepted another advance")
    encounter:cleanup()
end

local function testIncrementalTimeoutAndIndependentEncounters()
    local world = EcsWorld.init()
    local timeoutA = createParty(world, "incremental-timeout-a", "incremental-timeout-actor-a", {
        health = 100000,
        skills = {}
    })
    local timeoutB = createParty(world, "incremental-timeout-b", "incremental-timeout-actor-b", {
        health = 100000,
        skills = {}
    })
    local timeout = HeadlessBattleRunner.start(timeoutA, timeoutB, {maxTicks = 3})
    assert(timeout:advance(1) == nil)
    assert(timeout:advance(1) == nil)
    local timeoutResult = timeout:advance(5)
    assert(timeoutResult.outcome == "timeout" and timeoutResult.ticks == 3)
    timeout:cleanup()

    local firstA = createParty(world, "independent-first-a", "independent-first-actor-a", {
        health = 100000,
        skills = {}
    })
    local firstB = createParty(world, "independent-first-b", "independent-first-actor-b", {
        health = 100000,
        skills = {}
    })
    local secondA = createParty(world, "independent-second-a", "independent-second-actor-a", {
        health = 100000,
        skills = {}
    })
    local secondB = createParty(world, "independent-second-b", "independent-second-actor-b", {
        health = 100000,
        skills = {}
    })
    local first = HeadlessBattleRunner.start(firstA, firstB, {maxTicks = 20})
    local second = HeadlessBattleRunner.start(secondA, secondB, {maxTicks = 20})
    local firstSimulation = first.simulation
    local secondSimulation = second.simulation
    assert(firstSimulation ~= secondSimulation)
    assert(firstSimulation.world ~= secondSimulation.world)
    assert(firstSimulation.context ~= secondSimulation.context)

    first:advance(4)
    second:advance(7)
    assert(first.simulation.context.data.tick == 4)
    assert(second.simulation.context.data.tick == 7)
    first:advance(2)
    assert(first.simulation.context.data.tick == 6)
    assert(second.simulation.context.data.tick == 7,
        "advancing one encounter changed the other encounter")

    first:cleanup()
    second:cleanup()
    assert(firstSimulation.world == nil and secondSimulation.world == nil)
end

local function testStatusEffectSkill()
    local Skills = require("src.data.skills")
    local oldSkill = Skills.test_headless_burn
    Skills.test_headless_burn = {
        id = "test_headless_burn",
        name = "Test Burn",
        type = "spell",
        range = 8,
        baseDamage = 0,
        damageType = "fire",
        windup = 0,
        cooldown = 1,
        onHitStatuses = {
            burn = {
                duration = 5,
                damagePerTick = 25,
                tickEvery = 1
            }
        }
    }

    local ok, err = xpcall(function()
        local world = EcsWorld.init()
        local partyA = createParty(world, "status-a", "status-actor-a", {
            health = 1000,
            attack = 1000,
            skills = {test_headless_burn = {learned = true}}
        })
        local partyB, actorB = createParty(world, "status-b", "status-actor-b", {
            health = 20,
            skills = {}
        })
        local result = HeadlessBattleRunner.run(partyA, partyB, {maxTicks = 4000})
        assert(result.winnerPartyId == partyA.id)
        assert(result.actors[actorB.id].defeated, "status skill did not defeat its target")
        assert(actorB.hp == 20, "status skill changed persistent actor HP")
    end, debug.traceback)

    Skills.test_headless_burn = oldSkill
    if not ok then
        error(err, 0)
    end
end

local function runBenchmark(label, actorCount, maxTicks, repeats)
    local world = EcsWorld.init()
    local partyA = Party.create(world, label .. "-a", nil, label .. "-a")
    local partyB = Party.create(world, label .. "-b", nil, label .. "-b")
    for i = 1, actorCount do
        local actorA = createActor(world, label .. "-actor-a-" .. i, {
            health = 100000,
            skills = {attack = {learned = true}}
        })
        local actorB = createActor(world, label .. "-actor-b-" .. i, {
            health = 100000,
            skills = {attack = {learned = true}}
        })
        PartySystem.addActor(partyA, actorA)
        PartySystem.addActor(partyB, actorB)
    end

    local startedAt = os.clock()
    local result
    for _ = 1, repeats do
        result = HeadlessBattleRunner.run(partyA, partyB, {maxTicks = maxTicks})
    end
    local elapsed = os.clock() - startedAt
    assert(result.outcome == "timeout" and result.ticks == maxTicks)
    print(string.format("Headless benchmark %s (%d vs %d, %d ticks, %d runs): %.3fms/run",
        label, actorCount, actorCount, result.ticks, repeats, elapsed * 1000 / repeats))
    return elapsed
end

local Scenario = {}

function Scenario.run()
    withDeterministicRandom(function()
        testVictoryForBothSides()
        testTimeoutAndDraw()
        testIncrementalEncounters()
        testIncrementalTimeoutAndIndependentEncounters()
        testStatusEffectSkill()
        runBenchmark("small", 1, 200, 25)
        runBenchmark("moderate", 5, 200, 15)
    end)
end

return Scenario
