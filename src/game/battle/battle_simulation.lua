-- Owns the transient ECS world and context for one battle.

local BattleContext = require("src.game.battle.battle_context")
local BattleUnit = require("src.ecs.assemblages.battle_unit")
local BattleUnitSystem = require("src.systems.battle.battle_unit_system")
local EcsWorld = require("src.ecs.world")
local DecisionSystem = require("src.ecs.systems.decision_system")
local ExecutionSystem = require("src.ecs.systems.execution_system")

local InventorySystem = require("src.systems.inventory_system")

local BattleSimulation = {}

local WORLD_BOUNDS = {
    width = 1260,
    height = 546
}

local function addPartyUnits(simulation, party, team, isControlled, startX, direction)
    if not party or not party.actors then return end

    local startY = 120
    local spacingX = 72
    local spacingY = 78

    for i, actor in ipairs(party.actors) do
        local x = startX + direction * math.floor((i - 1) / 5) * spacingX
        local y = startY + ((i - 1) % 5) * spacingY
        local unit = BattleUnit.create(simulation.world, actor, x, y, team)
        BattleUnitSystem.snapToWorld(unit)
        simulation.context.addUnit(unit)

        if isControlled and i == 1 then
            simulation.context.data.selectedUnitId = unit.id
            simulation.context.data.playerUnit = unit
        end
    end
end

function BattleSimulation.new(partyA, partyB, controlPartyA)
    local simulation = setmetatable({
        partyA = partyA,
        partyB = partyB,
        context = BattleContext.new(WORLD_BOUNDS),
        world = EcsWorld.startBattle()
    }, {__index = BattleSimulation})

    simulation.world:addSystems(DecisionSystem, ExecutionSystem)

    addPartyUnits(simulation, partyA, "player", controlPartyA == true, 180, 1)
    addPartyUnits(simulation, partyB, "enemy", false, WORLD_BOUNDS.width - 180, -1)

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
