local Ecs = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local Unit = require("src.ecs.assemblages.unit")
local Parties = require("src.systems.parties.party_system")
local Map = require("src.world.map")
local Game = require("src.game.game_context")
local Events = require("src.systems.campaign.world_events")
local Knowledge = require("src.systems.knowledge.knowledge_system")
local EventBus = require("src.core.event_bus")
local BattleState = require("src.game.states.battle_state")
local Encounters = require("src.systems.campaign.world_encounter_system")
local Resolution = require("src.systems.campaign.campaign_battle_resolution")
local StateManager = require("src.core.state_manager")
local Drops = require("src.systems.items.loot_generator_system")

local function equal(a, b)
    assert(type(a) == type(b), "Terminal result types differ")
    if type(a) ~= "table" then assert(a == b, "Terminal result values differ"); return end
    for key, value in pairs(a) do equal(value, b[key]) end
    for key in pairs(b) do assert(a[key] ~= nil, "Terminal result gained a field") end
end

local function fixture(player, detached)
    local world = Ecs.init()
    Game.init()
    EventBus.init()
    local map = Map.new("resolution-map")
    local parties, actors = {}, {}
    for _, id in ipairs({"a", "b"}) do
        local party = Party.create(world, id, nil, id)
        party.inventory = {{id = "bread", quantity = 10}}
        party.treasury = 100
        parties[#parties + 1] = party
        for i = 1, 2 do
            local actor = Unit.create(world, "soldier", id .. i)
            actor.hp, actor.maxHp, actor.stats.health = 100, 100, 100
            actor.stats.attack, actor.stats.defense = 10, 10
            actor.equipment = {offHand = "wooden_shield"}
            actor.itemDurability = {wooden_shield = 5}
            actor.inventory = {{id = "iron_sword", quantity = 1}}
            actor.statusEffects = {}
            actor:give("memory")
            Parties.addActor(party, actor)
            actors[actor.id] = actor
        end
        if not detached or id == "a" then map:addParty(party) end
    end
    Game.setPlayer(actors.a1)
    actors.a1.favor = 11
    if player then Game.setPlayerParty(parties[1]) end
    Game.data.currentMap = map
    return world, map, parties, actors
end

local function terminal(simulation, winner)
    for _, unit in ipairs(simulation.context.data.unitList) do
        local survives = (winner == "a" and unit.id == "a1") or
            (winner == "b" and unit.id == "b1") or
            (winner == "timeout" and (unit.id == "a1" or unit.id == "b1"))
        unit.hp = survives and 37 or 0
        unit.statusEffects = {stun = {remaining = 2}}
        unit.equipment = {}
        unit.itemDurability = {}
    end
    simulation.context.removeDeadUnits()
end

local function runMode(player, winner, detached)
    local world, map, parties, actors = fixture(player, detached)
    local encounter, simulation, presentation, runner
    local completions, victories, finishes, killed, rolls = 0, 0, 0, 0, 0
    local previousSwap, previousDrop = StateManager.swap, Drops.generateFromTroop
    StateManager.swap = function(name, params) presentation = {name = name, params = params} end
    Drops.generateFromTroop = function(_, loot)
        rolls = rolls + 1
        loot[#loot + 1] = {id = "bread", quantity = 1}
        return loot, 7
    end
    local ok, snapshot = xpcall(function()
        if player then
            BattleState.enter({enemyParty = parties[2],
                onVictory = function() victories = victories + 1; BattleState.checkBattleEnd() end,
                onComplete = function()
                    completions = completions + 1
                    assert(Events.count(world) == 1, "Completion preceded history")
                    BattleState.checkBattleEnd()
                end})
            encounter, simulation = BattleState.encounter, BattleState.simulation
            BattleState.checkBattleEnd()
            assert(rolls == 0, "Nonterminal player checks rolled rewards")
        else
            local started
            started, encounter = Encounters.start(map, parties[1], parties[2], {
                maxTicks = 0, activitySourceId = "a", activityType = "raid", targetPartyId = "b",
                lootPolicy = {plunderAllowed = true, stolenProportion = 0.4, destroyedProportion = 0.1}
            })
            assert(started)
            runner, simulation = encounter.runner, encounter.runner.simulation
            EventBus.subscribe("party_encounter_finished", function()
                finishes = finishes + 1
                Encounters.update(0, map)
            end)
        end
        terminal(simulation, winner)
        local outcome, winnerId = simulation:getOutcome()
        local result = simulation:buildResult(outcome or "timeout", winnerId)
        EventBus.subscribe("party_killed", function()
            killed = killed + 1
            assert(Resolution.resolve(result, {encounter = encounter}) == nil,
                "Reentrant resolution should wait for the outer resolution")
        end)
        if player then BattleState.checkBattleEnd() else Encounters.update(0, map) end
        local resolved = encounter.resolution
        assert(resolved and encounter.resultApplied)
        equal(encounter.result, result)
        for _ = 1, 3 do
            assert(Resolution.resolve(result, {encounter = encounter}) == resolved,
                "Duplicate completion did not return its original resolution")
            if player then BattleState.checkBattleEnd() else Encounters.update(0, map) end
        end
        assert(Events.count(world) == 1, "Duplicate history")
        assert(killed == (winner == "draw" and 2 or (winner == "timeout" and 0 or 1)))
        assert(#map:getParties() == (detached and 1 or (winner == "draw" and 0 or (winner == "timeout" and 2 or 1))))
        local event = resolved.event
        for id, actor in pairs(actors) do
            assert(actor.hp == result.actors[id].finalHp and actor.maxHp == result.actors[id].maxHp)
            equal(actor.statusEffects, require("src.systems.actors.conditions").persistentStatuses(result.actors[id]))
            assert(Knowledge.knows(actor, event.id, world) == not result.actors[id].defeated)
            if not result.actors[id].defeated then assert(next(actor.equipment) == nil) end
        end
        for _, party in ipairs(parties) do
            assert(Knowledge.knows(party, event.id, world) == (#party.actors > 0))
        end
        if player then
            assert(completions == 1 and victories == (winner == "a" and 1 or 0))
            assert(rolls == (winner == "b" and 1 or 2), "Player troop drops rolled more than once")
            assert(#map.battlefieldRemains == 0 and encounter.lootResult == nil)
            assert(parties[2].treasury == 100 and #parties[2].inventory == 1,
                "Player rewards used NPC plunder")
            if winner == "a" then
                assert(presentation.name == "battle_end" and presentation.params.victory)
                assert(parties[1].treasury == 114 and presentation.params.gold == 14)
                assert(#presentation.params.loot == 2 and #parties[1].inventory == 1,
                    "Player loot was credited before selection")
                assert(presentation.params.favor == 20 and actors.a1.favor == 31,
                    "Favor lost pre-casualty enemy/post-casualty player strength")
                assert(#presentation.params.playerCasualties == 1 and #presentation.params.enemyCasualties == 2)
            else
                assert(presentation.name == "menu" and actors.a1.favor == 11)
                assert(parties[1].treasury == 100, "Defeat/draw granted gold")
            end
        else
            assert(rolls == 0 and actors.a1.favor == 11 and finishes == 1)
            assert(not parties[1].activeEncounterId and not parties[2].activeEncounterId)
            assert(next(map.activeEncounters) == nil and encounter.runner == nil and runner.state == "cleaned")
            assert(map.partyEncounterCooldowns.a and map.partyEncounterCooldowns.b)
            assert(#map.battlefieldRemains == 1 and map.battlefieldRemains[1].history.eventId == event.id)
            if winner == "a" then
                assert(parties[1].treasury == 140 and parties[2].treasury == 0)
                assert(map.battlefieldRemains[1].loot.gold == 60)
                assert(#encounter.lootResult.combatLoot == 2)
                assert(next(actors.b1.inventory) == nil and next(actors.b2.inventory) == nil)
            end
        end
        return {result = result, participants = event.participants, defeated = event.defeatedPartyIds,
            eliminated = event.eliminatedPartyIds}
    end, debug.traceback)
    if player then BattleState.exit() end
    StateManager.swap, Drops.generateFromTroop = previousSwap, previousDrop
    if not ok then error(snapshot, 0) end
    return snapshot
end

local Scenario = {}
function Scenario.run()
    for _, outcome in ipairs({"a", "b", "draw"}) do
        equal(runMode(true, outcome), runMode(false, outcome))
    end
    runMode(false, "timeout")
    runMode(true, "a", true) -- Ruin/camp opponents need not be traveling map parties.
end
return Scenario
