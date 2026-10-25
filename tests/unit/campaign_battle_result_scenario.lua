local EcsWorld = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local Unit = require("src.ecs.assemblages.unit")
local PartySystem = require("src.systems.party_system")
local Map = require("src.world.map")
local EventBus = require("src.core.event_bus")
local ResultApplier = require("src.systems.campaign_battle_result_applier")

local function createParty(world, map, partyId, actorIds)
    local party = Party.create(world, partyId, nil, partyId)
    party.inventory = {{id = "party_goods", quantity = 5}}
    party.treasury = 125
    for _, actorId in ipairs(actorIds) do
        local actor = Unit.create(world, "soldier", actorId)
        actor.hp = 100
        actor.maxHp = 100
        actor.stats.health = 100
        actor.inventory = {{id = "personal_goods", quantity = 2}}
        actor.equipment = {weapon = "sword"}
        actor.itemDurability = {sword = 8}
        PartySystem.addActor(party, actor)
    end
    map:addParty(party)
    return party
end

local function makeResult(partyA, partyB, outcome, winnerPartyId, finalHpById)
    local result = {
        partyAId = partyA.id,
        partyBId = partyB.id,
        outcome = outcome,
        winnerPartyId = winnerPartyId,
        actors = {}
    }
    if winnerPartyId then
        result.loserPartyId = winnerPartyId == partyA.id and partyB.id or partyA.id
    end
    for _, party in ipairs({partyA, partyB}) do
        for _, actor in ipairs(party.actors) do
            local hp = finalHpById[actor.id]
            result.actors[actor.id] = {
                partyId = party.id,
                finalHp = hp,
                defeated = hp <= 0
            }
        end
    end
    return result
end

local function makeContext(map)
    return {map = map, encounter = {state = "completed"}}
end

local function countParty(map, partyId)
    for _, party in ipairs(map:getParties()) do
        if party.id == partyId then return 1 end
    end
    return 0
end

local function snapshot(parties)
    local state = {}
    for i, party in ipairs(parties) do
        state[i] = {
            party = party,
            actors = {unpack(party.actors)},
            inventory = party.inventory,
            treasury = party.treasury,
            actorData = {}
        }
        for _, actor in ipairs(party.actors) do
            state[i].actorData[actor.id] = {
                hp = actor.hp,
                inventory = actor.inventory,
                equipment = actor.equipment,
                itemDurability = actor.itemDurability
            }
        end
    end
    return state
end

local function assertUnchangedExceptHpAndRoster(state)
    for _, before in ipairs(state) do
        local party = before.party
        assert(party.inventory == before.inventory, "party inventory reference changed")
        assert(party.treasury == before.treasury, "party treasury changed")
        for _, actor in ipairs(before.actors) do
            local old = before.actorData[actor.id]
            assert(actor.inventory == old.inventory, "actor inventory changed")
            assert(actor.equipment == old.equipment, "actor equipment changed")
            assert(actor.itemDurability == old.itemDurability, "actor equipment durability changed")
        end
    end
end

local function testVictoryForEitherSideAndElimination()
    for _, winnerIsA in ipairs({true, false}) do
        local world = EcsWorld.init()
        local map = Map.new("result-map")
        local partyA = createParty(world, map, "result-a-" .. tostring(winnerIsA), {"a-survivor-" .. tostring(winnerIsA)})
        local partyB = createParty(world, map, "result-b-" .. tostring(winnerIsA), {"b-survivor-" .. tostring(winnerIsA)})
        local winner = winnerIsA and partyA or partyB
        local loser = winnerIsA and partyB or partyA
        local winnerActor = winner.actors[1]
        local loserActor = loser.actors[1]
        local hp = {[winnerActor.id] = 63, [loserActor.id] = 0}
        local result = makeResult(partyA, partyB, "victory", winner.id, hp)
        local killed = {}
        EventBus.init()
        EventBus.subscribe("party_killed", function(partyId) killed[#killed + 1] = partyId end)

        local before = snapshot({partyA, partyB})
        local applied = ResultApplier.apply(result, makeContext(map))
        assert(winnerActor.hp == 63, "winner HP was not persisted")
        assert(#winner.actors == 1 and winner.actors[1] == winnerActor)
        assert(loserActor.hp == 0 and #loser.actors == 0)
        assert(countParty(map, winner.id) == 1 and countParty(map, loser.id) == 0)
        assert(#killed == 1 and killed[1] == loser.id, "party_killed was not limited to the eliminated party")
        assert(#applied.eliminatedPartyIds == 1 and applied.eliminatedPartyIds[1] == loser.id)
        assertUnchangedExceptHpAndRoster(before)
    end
end

local function testPartialCasualtiesTimeoutAndDraw()
    local world = EcsWorld.init()
    local map = Map.new("partial-result-map")
    local partyA = createParty(world, map, "partial-a", {"partial-a-dead", "partial-a-alive"})
    local partyB = createParty(world, map, "partial-b", {"partial-b-dead", "partial-b-alive"})
    local result = makeResult(partyA, partyB, "timeout", nil, {
        ["partial-a-dead"] = 0,
        ["partial-a-alive"] = 44,
        ["partial-b-dead"] = 0,
        ["partial-b-alive"] = 71
    })
    local killed = {}
    EventBus.init()
    EventBus.subscribe("party_killed", function(partyId) killed[#killed + 1] = partyId end)

    local before = snapshot({partyA, partyB})
    ResultApplier.apply(result, makeContext(map))
    assert(partyA.actors[1].id == "partial-a-alive" and partyA.actors[1].hp == 44)
    assert(partyB.actors[1].id == "partial-b-alive" and partyB.actors[1].hp == 71)
    assert(countParty(map, partyA.id) == 1 and countParty(map, partyB.id) == 1)
    assert(#killed == 0, "timeout emitted party_killed despite survivors")
    assertUnchangedExceptHpAndRoster(before)

    local drawWorld = EcsWorld.init()
    local drawMap = Map.new("draw-result-map")
    local drawA = createParty(drawWorld, drawMap, "draw-a", {"draw-actor-a"})
    local drawB = createParty(drawWorld, drawMap, "draw-b", {"draw-actor-b"})
    local draw = makeResult(drawA, drawB, "draw", nil, {
        ["draw-actor-a"] = 0,
        ["draw-actor-b"] = 0
    })
    local drawEvents = {}
    EventBus.init()
    EventBus.subscribe("party_killed", function(partyId) drawEvents[#drawEvents + 1] = partyId end)
    ResultApplier.apply(draw, makeContext(drawMap))
    assert(#drawA.actors == 0 and #drawB.actors == 0)
    assert(countParty(drawMap, drawA.id) == 0 and countParty(drawMap, drawB.id) == 0)
    assert(#drawEvents == 2, "draw elimination did not emit one event per eliminated party")
end

local function testDuplicateAndInvalidResultsAreAtomic()
    local world = EcsWorld.init()
    local map = Map.new("validation-result-map")
    local partyA = createParty(world, map, "validation-a", {"validation-actor-a"})
    local partyB = createParty(world, map, "validation-b", {"validation-actor-b"})
    local result = makeResult(partyA, partyB, "timeout", nil, {
        ["validation-actor-a"] = 80,
        ["validation-actor-b"] = 90
    })
    local encounter = {state = "completed"}
    ResultApplier.apply(result, {map = map, encounter = encounter})
    assert(encounter.resultApplied)
    local hpA, hpB = partyA.actors[1].hp, partyB.actors[1].hp
    local ok, err = pcall(function()
        ResultApplier.apply(result, {map = map, encounter = encounter})
    end)
    assert(not ok and string.find(err, "already been applied", 1, true),
        "duplicate result application was accepted")
    assert(partyA.actors[1].hp == hpA and partyB.actors[1].hp == hpB)

    local function assertInvalidIsAtomic(mutator)
        local invalid = makeResult(partyA, partyB, "timeout", nil, {
            ["validation-actor-a"] = 50,
            ["validation-actor-b"] = 60
        })
        mutator(invalid)
        local oldHpA, oldHpB = partyA.actors[1].hp, partyB.actors[1].hp
        local freshEncounter = {state = "completed"}
        local success = pcall(function()
            ResultApplier.apply(invalid, {map = map, encounter = freshEncounter})
        end)
        assert(not success, "invalid result was accepted")
        assert(partyA.actors[1].hp == oldHpA and partyB.actors[1].hp == oldHpB,
            "invalid result partially changed actor HP")
        assert(#partyA.actors == 1 and #partyB.actors == 1,
            "invalid result partially changed party rosters")
        assert(not freshEncounter.resultApplied, "invalid result marked encounter applied")
    end

    assertInvalidIsAtomic(function(invalid) invalid.partyBId = "missing-party" end)
    assertInvalidIsAtomic(function(invalid)
        invalid.actors["not-a-campaign-actor"] = {
            partyId = partyA.id,
            finalHp = 10,
            defeated = false
        }
    end)
    assertInvalidIsAtomic(function(invalid)
        invalid.actors["validation-actor-a"].partyId = partyB.id
    end)
    assertInvalidIsAtomic(function(invalid)
        invalid.actors["validation-actor-a"] = nil
    end)
end

local Scenario = {}

function Scenario.run()
    testVictoryForEitherSideAndElimination()
    testPartialCasualtiesTimeoutAndDraw()
    testDuplicateAndInvalidResultsAreAtomic()
end

return Scenario
