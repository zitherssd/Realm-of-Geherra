-- Owns the transient ECS world and context for one battle.

local BattleContext = require("src.game.battle.battle_context")
local BattleUnit = require("src.ecs.assemblages.battle_unit")
local BattleUnitSystem = require("src.systems.battle.battle_unit_system")
local EcsWorld = require("src.ecs.world")
local DecisionSystem = require("src.systems.battle.decision_system")
local ExecutionSystem = require("src.systems.battle.execution_system")

local InventorySystem = require("src.systems.items.inventory_system")

local BattleSimulation = {}

local WORLD_BOUNDS = {
    width = 1260,
    height = 546
}

local function addPartyUnits(simulation, party, team, isControlled)
    if not party or not party.actors then return end

    local Squads = require("src.game.battle.squads")
    local layouts = Squads.layout(party)
    local byId, leader = {}, nil
    for _, actor in ipairs(party.actors) do
        local unit = BattleUnit.create(simulation.world, actor, 0, 0, team)
        simulation.context.addUnit(unit)
        byId[actor.id] = unit
        if actor.id == party.leaderId then leader = unit end
    end
    leader = leader or byId[party.actors[1] and party.actors[1].id]
    if not leader then return end
    leader.x, leader.y = team == "player" and 500 or 760, 273
    if isControlled then
        simulation.context.data.selectedUnitId = leader.id
        simulation.context.data.playerUnit = leader
        for _, id in ipairs({"on_me", "charge"}) do
            leader.skills[id] = {level = 1}
            table.insert(leader.skillList, id)
        end
    end
    for i, layout in ipairs(layouts) do
        local config, circles, members = layout.config, layout.circles, {}
        for _, actor in ipairs(layout.members) do members[#members+1] = byId[actor.id] end
        local squad = {id=i, config=config, members=members, leader=leader,
            team=team, direction=team == "player" and 1 or -1,
            offsetX=(config.x-500)*(team == "player" and 1 or -1),
            order=isControlled and "hold" or "charge"}
        table.insert(simulation.context.data.squads, squad)
        for j, unit in ipairs(members) do
            local c = circles[j]
            unit.x = team == "player" and c.x or WORLD_BOUNDS.width-c.x
            unit.y, unit.squad = c.y, squad
        end
    end
    for _, unit in pairs(byId) do BattleUnitSystem.snapToWorld(unit) end
end

function BattleSimulation.new(partyA, partyB, controlPartyA)
    local simulation = setmetatable({
        partyA = partyA,
        partyB = partyB,
        context = BattleContext.new(WORLD_BOUNDS),
        world = EcsWorld.startBattle()
    }, {__index = BattleSimulation})

    simulation.world:addSystems(DecisionSystem, ExecutionSystem)

    simulation.context.data.squads = {}
    addPartyUnits(simulation, partyA, "player", controlPartyA == true)
    addPartyUnits(simulation, partyB, "enemy", false)

    return simulation
end

function BattleSimulation:tick()
    self.context.data.tick = self.context.data.tick + 1
    self.world:emit("update", self.context)
    self.context.removeDeadUnits()
end

local function getLivingCounts(context)
    local livingByTeam = {player = 0, enemy = 0}
    for _, unit in ipairs(context.data.unitList) do
        if unit.hp > 0 then
            livingByTeam[unit.team] = (livingByTeam[unit.team] or 0) + 1
        end
    end
    return livingByTeam.player, livingByTeam.enemy
end

function BattleSimulation:getOutcome()
    local context, partyA, partyB = self.context, self.partyA, self.partyB
    local partyAAlive, partyBAlive = getLivingCounts(context)
    if partyAAlive == 0 and partyBAlive == 0 then
        return "draw", nil
    elseif partyAAlive == 0 then
        return "victory", partyB.id
    elseif partyBAlive == 0 then
        return "victory", partyA.id
    end
    return nil, nil
end

local function collectBattleUnits(context)
    local unitsByActorId = {}
    for _, unit in ipairs(context.data.unitList) do
        unitsByActorId[unit.id] = unit
    end
    for _, unit in ipairs(context.data.casualties) do
        unitsByActorId[unit.id] = unit
    end
    return unitsByActorId
end

local function addActorResults(result, party, unitsByActorId)
    for _, actor in ipairs(party.actors) do
        local battleUnit = unitsByActorId[actor.id]
        local maxHp = actor.maxHp or (actor.stats and actor.stats.health) or 100
        local finalHp = battleUnit and battleUnit.hp or actor.hp or maxHp

        result.actors[actor.id] = {
            partyId = party.id,
            finalHp = finalHp,
            maxHp = battleUnit and battleUnit.maxHp or maxHp,
            statusEffects = InventorySystem.deepClone(battleUnit and battleUnit.statusEffects or actor.statusEffects or {}),
            defeated = finalHp <= 0,
            injuries = InventorySystem.deepClone(battleUnit and battleUnit.injuries or actor.injuries or {}),
            equipment = InventorySystem.deepClone(battleUnit and battleUnit.equipment or actor.equipment or {}),
            itemDurability = InventorySystem.deepClone(battleUnit and battleUnit.itemDurability or actor.itemDurability or {})
        }
    end
end

function BattleSimulation:buildResult(outcome, winnerPartyId)
    local partyA, partyB = self.partyA, self.partyB
    local result = {
        partyAId = partyA.id,
        partyBId = partyB.id,
        outcome = outcome,
        winnerPartyId = winnerPartyId,
        loserPartyId = nil,
        actors = {},
        ticks = self.context.data.tick
    }

    if winnerPartyId == partyA.id then
        result.loserPartyId = partyB.id
    elseif winnerPartyId == partyB.id then
        result.loserPartyId = partyA.id
    end

    local unitsByActorId = collectBattleUnits(self.context)
    addActorResults(result, partyA, unitsByActorId)
    addActorResults(result, partyB, unitsByActorId)
    return result
end

function BattleSimulation:destroy()
    if self.world then
        EcsWorld.endBattle(self.world)
        self.world = nil
    end
end

return BattleSimulation
