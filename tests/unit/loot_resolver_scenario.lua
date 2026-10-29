local EcsWorld = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local Unit = require("src.ecs.assemblages.unit")
local PartySystem = require("src.systems.parties.party_system")
local LootResolver = require("src.systems.items.loot_resolver")

local function copyTable(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do
        copy[key] = copyTable(child)
    end
    return copy
end

local function assertEqual(actual, expected, message)
    assert(actual == expected, (message or "values differ") ..
        ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function assertDeepEqual(actual, expected, message)
    assert(type(actual) == type(expected), message .. " type differs")
    if type(expected) ~= "table" then
        assertEqual(actual, expected, message)
        return
    end
    for key, value in pairs(expected) do
        assertDeepEqual(actual[key], value, message .. "." .. tostring(key))
    end
    for key in pairs(actual) do
        assert(expected[key] ~= nil, message .. " has unexpected field " .. tostring(key))
    end
end

local function assertSerializable(value, label)
    local valueType = type(value)
    assert(valueType == "nil" or valueType == "string" or valueType == "number" or
        valueType == "boolean" or valueType == "table", label .. " is not serializable")
    if valueType == "table" then
        for key, child in pairs(value) do
            assert(type(key) == "string" or type(key) == "number", label .. " key is not primitive")
            assertSerializable(child, label .. "." .. tostring(key))
        end
    end
end

local function makeParties()
    local world = EcsWorld.init()
    local partyA = Party.create(world, "A", nil, "party-a")
    local partyB = Party.create(world, "B", nil, "party-b")
    local actorA = Unit.create(world, "soldier", "actor-a")
    local actorB = Unit.create(world, "soldier", "actor-b")
    PartySystem.addActor(partyA, actorA)
    PartySystem.addActor(partyB, actorB)
    return world, partyA, partyB, actorA, actorB
end

local function makeResult(partyA, partyB, outcome, winner, hpA, hpB)
    local actors = {
        ["actor-a"] = {partyId = partyA.id, finalHp = hpA, defeated = hpA <= 0},
        ["actor-b"] = {partyId = partyB.id, finalHp = hpB, defeated = hpB <= 0}
    }
    return {
        partyAId = partyA.id,
        partyBId = partyB.id,
        outcome = outcome,
        winnerPartyId = winner,
        actors = actors
    }
end

local function deterministicRandom(value)
    return function() return value end
end

local function findResource(resources, sourcePartyId, itemId)
    for _, resource in ipairs(resources) do
        if resource.sourcePartyId == sourcePartyId and resource.item.id == itemId then
            return resource
        end
    end
    return nil
end

local function countPartyCargo(resources)
    local count = 0
    for _, resource in ipairs(resources) do
        if resource.sourceKind == "party_inventory" then
            count = count + 1
        end
    end
    return count
end

local function testPurityAndCombatPossessions()
    local _, partyA, partyB, actorA, actorB = makeParties()
    actorB.inventory = {{id = "bread", quantity = 2}}
    actorB.equipment = {mainHand = "iron_sword"}
    actorB.itemDurability = {iron_sword = 9}
    local partyAInventory = {{id = "bread", quantity = 4, metadata = {quality = "fine"}}}
    partyA.inventory = partyAInventory
    partyA.treasury = 20
    partyB.inventory = {{id = "dried_meat", quantity = 2, metadata = {batch = "north"}}}
    partyB.treasury = 100
    local snapshot = {
        actorInventory = copyTable(actorB.inventory),
        actorEquipment = copyTable(actorB.equipment),
        partyAInventory = copyTable(partyA.inventory),
        partyBInventory = copyTable(partyB.inventory),
        treasuryA = partyA.treasury,
        treasuryB = partyB.treasury
    }
    local result = LootResolver.resolve(
        partyA,
        partyB,
        makeResult(partyA, partyB, "victory", partyA.id, 80, 0),
        {plunderAllowed = false},
        deterministicRandom(0.5)
    )

    assertDeepEqual(actorB.inventory, snapshot.actorInventory, "actor inventory mutated")
    assertDeepEqual(actorB.equipment, snapshot.actorEquipment, "actor equipment mutated")
    assertDeepEqual(partyA.inventory, snapshot.partyAInventory, "winner cargo mutated")
    assertDeepEqual(partyB.inventory, snapshot.partyBInventory, "loser cargo mutated")
    assertEqual(partyA.treasury, snapshot.treasuryA, "winner treasury mutated")
    assertEqual(partyB.treasury, snapshot.treasuryB, "loser treasury mutated")
    assertEqual(result.combatLoot[1].item.id, "bread", "personal inventory not recovered")
    assertEqual(result.combatLoot[1].item.quantity, 2, "personal inventory quantity lost")
    assertEqual(result.combatLoot[1].sourceKind, "inventory", "inventory source missing")
    assertEqual(result.combatLoot[2].item.id, "iron_sword", "equipment not recovered")
    assertEqual(result.combatLoot[2].durabilityRemaining, 9, "equipment durability not preserved")
    assertEqual(result.combatLoot[2].recipientPartyId, partyA.id, "combat loot recipient missing")
    assertEqual(result.plunder.eligible, false, "disallowed plunder marked eligible")
    local retainedWinnerCargo = findResource(result.retainedResources.items, partyA.id, "bread")
    assert(retainedWinnerCargo, "winner's cargo was not represented as retained")
    assertEqual(retainedWinnerCargo.item.metadata.quality, "fine",
        "winner's cargo metadata not preserved")
    assertSerializable(result, "LootResult")
end

local function testDeterministicPlunderAndAccounting()
    local _, partyA, partyB = makeParties()
    partyB.inventory = {
        {id = "bread", quantity = 100, metadata = {quality = "stale", source = {wagon = 3}}}
    }
    partyB.treasury = 100
    local battle = makeResult(partyA, partyB, "victory", partyA.id, 50, 0)
    local policy = {plunderAllowed = true}
    local result = LootResolver.resolve(partyA, partyB, battle, policy, deterministicRandom(0.5))

    assertEqual(result.plunder.eligible, true, "plunder was not enabled by explicit policy")
    assertEqual(result.plunder.itemAllocations[1].item.quantity, 40, "stolen item share incorrect")
    assertEqual(result.destroyedResources.items[1].item.quantity, 15, "destroyed item share incorrect")
    assertEqual(result.retainedResources.items[1].item.quantity, 45, "retained item share incorrect")
    assertEqual(result.plunder.goldAllocations[1].amount, 40, "stolen gold share incorrect")
    assertEqual(result.retainedResources.gold[1].amount, 60, "retained gold share incorrect")
    assertEqual(result.destroyedResources.gold, 0, "gold was destroyed")
    local itemTotal = result.plunder.itemAllocations[1].item.quantity +
        result.destroyedResources.items[1].item.quantity +
        result.retainedResources.items[1].item.quantity
    assertEqual(itemTotal, 100, "cargo quantity was not conserved")
    assertEqual(result.plunder.goldAllocations[1].amount +
        result.retainedResources.gold[1].amount, 100, "gold was not conserved")
    assertDeepEqual(result.plunder.itemAllocations[1].item.metadata,
        partyB.inventory[1].metadata, "stolen item metadata changed")
    assertDeepEqual(result.destroyedResources.items[1].item.metadata,
        partyB.inventory[1].metadata, "destroyed item metadata changed")

    local replay = LootResolver.resolve(partyA, partyB, battle, policy, deterministicRandom(0.5))
    assertDeepEqual(replay, result, "injected random source was not deterministic")
end

local function testFractionalAllocation()
    local _, partyA, partyB = makeParties()
    partyB.inventory = {{id = "bread", quantity = 1}}
    partyB.treasury = 1
    local result = LootResolver.resolve(
        partyA,
        partyB,
        makeResult(partyA, partyB, "victory", partyA.id, 10, 0),
        {plunderAllowed = true},
        deterministicRandom(0.1)
    )
    local stolen = result.plunder.itemAllocations[1] and result.plunder.itemAllocations[1].item.quantity or 0
    local destroyed = result.destroyedResources.items[1] and result.destroyedResources.items[1].item.quantity or 0
    local retained = result.retainedResources.items[1] and result.retainedResources.items[1].item.quantity or 0
    assertEqual(stolen + destroyed + retained, 1, "fractional split lost item quantity")
    assertEqual(result.plunder.goldAllocations[1].amount +
        result.retainedResources.gold[1].amount, 1, "fractional split lost gold")
end

local function testDrawTimeoutAndElimination()
    local _, partyA, partyB = makeParties()
    partyA.inventory = {{id = "bread", quantity = 2}}
    partyB.inventory = {{id = "dried_meat", quantity = 3}}
    partyA.treasury = 7
    partyB.treasury = 11

    local draw = LootResolver.resolve(
        partyA,
        partyB,
        makeResult(partyA, partyB, "draw", nil, 0, 0),
        {plunderAllowed = true},
        deterministicRandom(0.5)
    )
    assertEqual(#draw.combatLoot, 0, "draw awarded combat loot")
    assertEqual(draw.plunder.eligible, false, "draw enabled plunder")
    assertEqual(countPartyCargo(draw.retainedResources.items), 2,
        "draw did not retain both cargo inventories")
    assertEqual(#draw.retainedResources.gold, 2, "draw did not retain both treasuries")
    assert(findResource(draw.retainedResources.items, partyA.id, "bread"),
        "draw lost Party A's cargo")

    local timeout = LootResolver.resolve(
        partyA,
        partyB,
        makeResult(partyA, partyB, "timeout", nil, 20, 15),
        {plunderAllowed = true},
        deterministicRandom(0.5)
    )
    assertEqual(#timeout.combatLoot, 0, "timeout awarded combat loot")
    assertEqual(timeout.plunder.eligible, false, "timeout enabled plunder")
    assertEqual(countPartyCargo(timeout.retainedResources.items), 2, "timeout cargo was not retained")

    local eliminated = LootResolver.resolve(
        partyA,
        partyB,
        makeResult(partyA, partyB, "victory", partyA.id, 20, 0),
        {plunderAllowed = true},
        deterministicRandom(0.5)
    )
    assertEqual(eliminated.plunder.sourcePartyEliminated, true,
        "eliminated defeated party was not represented")
    assertEqual(eliminated.plunder.sourcePartyId, partyB.id, "eliminated party source missing")
    assertEqual(eliminated.plunder.goldAllocations[1].amount +
        eliminated.retainedResources.gold[1].amount, partyB.treasury,
        "eliminated party gold accounting failed")

    local world = EcsWorld.init()
    local survivorPartyA = Party.create(world, "Survivor winner", nil, "survivor-winner")
    local survivorPartyB = Party.create(world, "Surviving defeated party", nil, "surviving-loser")
    local winnerActor = Unit.create(world, "soldier", "survivor-winner-actor")
    local defeatedActor = Unit.create(world, "soldier", "defeated-loser-actor")
    local survivingActor = Unit.create(world, "soldier", "surviving-loser-actor")
    PartySystem.addActor(survivorPartyA, winnerActor)
    PartySystem.addActor(survivorPartyB, defeatedActor)
    PartySystem.addActor(survivorPartyB, survivingActor)
    local survivingResult = {
        partyAId = survivorPartyA.id,
        partyBId = survivorPartyB.id,
        outcome = "victory",
        winnerPartyId = survivorPartyA.id,
        loserPartyId = survivorPartyB.id,
        actors = {
            [winnerActor.id] = {partyId = survivorPartyA.id, finalHp = 10, defeated = false},
            [defeatedActor.id] = {partyId = survivorPartyB.id, finalHp = 0, defeated = true},
            [survivingActor.id] = {partyId = survivorPartyB.id, finalHp = 5, defeated = false}
        }
    }
    local survivingLoss = LootResolver.resolve(
        survivorPartyA,
        survivorPartyB,
        survivingResult,
        {plunderAllowed = true},
        deterministicRandom(0.5)
    )
    assertEqual(survivingLoss.plunder.sourcePartyEliminated, false,
        "surviving defeated party was marked eliminated")
    assertEqual(survivingLoss.plunder.sourcePartyId, survivorPartyB.id,
        "surviving defeated party source missing")
end

local function testInvalidPoliciesAndResults()
    local _, partyA, partyB = makeParties()
    local victory = makeResult(partyA, partyB, "victory", partyA.id, 10, 0)
    partyB.inventory = {{id = "bread", quantity = 1}}
    local function expectError(callback, label)
        local ok = pcall(callback)
        assert(not ok, label .. " was accepted")
    end
    expectError(function()
        LootResolver.resolve(partyA, partyB, victory, {}, deterministicRandom(0.5))
    end, "policy without explicit eligibility")
    expectError(function()
        LootResolver.resolve(partyA, partyB, victory,
            {plunderAllowed = true, stolenProportion = 0.8, destroyedProportion = 0.3},
            deterministicRandom(0.5))
    end, "proportions exceeding 100 percent")
    expectError(function()
        LootResolver.resolve(partyA, partyB, victory, {plunderAllowed = true},
            function() return 1 end)
    end, "invalid random value")
end

local Scenario = {}

function Scenario.run()
    testPurityAndCombatPossessions()
    testDeterministicPlunderAndAccounting()
    testFractionalAllocation()
    testDrawTimeoutAndElimination()
    testInvalidPoliciesAndResults()
end

return Scenario
