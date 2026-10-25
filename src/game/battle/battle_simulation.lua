-- Owns the transient ECS world and context for one battle.

local BattleContext = require("src.game.battle.battle_context")
local BattleUnit = require("src.ecs.assemblages.battle_unit")
local BattleUnitSystem = require("src.systems.battle.battle_unit_system")
local EcsWorld = require("src.ecs.world")
local DecisionSystem = require("src.ecs.systems.decision_system")
local ExecutionSystem = require("src.ecs.systems.execution_system")

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

function BattleSimulation:destroy()
    if self.world then
        EcsWorld.endBattle(self.world)
        self.world = nil
    end
end

return BattleSimulation
