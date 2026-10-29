local Conditions = require("src.systems.actors.conditions")
-- Owns the transient ECS world and context for one battle.

local BattleContext = require("src.game.battle.battle_context")
local BattleUnit = require("src.ecs.assemblages.battle_unit")
local BattleUnitSystem = require("src.systems.battle.battle_unit_system")
local EcsWorld = require("src.ecs.world")
local DecisionSystem = require("src.systems.battle.decision_system")
local ExecutionSystem = require("src.systems.battle.execution_system")

local InventorySystem = require("src.systems.items.inventory_system")

local Morale = require("src.game.battle.morale")
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
    local members = {}
    for _, actor in ipairs(party.actors) do
        local unit = byId[actor.id]
        unit.escapeEdge = team == "player" and 0 or WORLD_BOUNDS.width
        members[#members+1] = unit
    end
    simulation.context.data.battleParties[team] = {members=members, leader=leader, routed=false}
    if isControlled then
        local player = leader
        for _, member in ipairs(members) do
            if member.moraleExempt then player = member; break end
        end
        player.moraleExempt = true
        simulation.context.data.selectedUnitId = player.id
        simulation.context.data.playerUnit = player
        for _, id in ipairs({"on_me", "charge"}) do
            player.skills[id] = {level = 1}
            table.insert(player.skillList, id)
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

function BattleSimulation.new(partyA, partyB, controlPartyA, options)
    local simulation = setmetatable({
        partyA = partyA,
        partyB = partyB,
        context = BattleContext.new(WORLD_BOUNDS),
        world = EcsWorld.startBattle()
    }, {__index = BattleSimulation})

    simulation.world:addSystems(DecisionSystem, ExecutionSystem)

    simulation.context.data.projectileRng = options and options.projectileRng
    simulation.context.data.moraleRng = options and options.moraleRng
    simulation.context.data.squads = {}
    addPartyUnits(simulation, partyA, "player", controlPartyA == true)
    addPartyUnits(simulation, partyB, "enemy", false)

    return simulation
end

function BattleSimulation:tick()
    if self.settled then return end
    self.context.data.tick = self.context.data.tick + 1
    self.world:emit("update", self.context)
    self.context.removeDeadUnits()
    Morale.process(self.context)
    Morale.updateEscapes(self.context)
end

local function getLivingCounts(context)
    local livingByTeam = {player = 0, enemy = 0}
    for _, unit in ipairs(context.data.unitList) do
        if unit.hp > 0 and not unit.fleeing and not unit.escaped then
            livingByTeam[unit.team] = (livingByTeam[unit.team] or 0) + 1
        end
    end
    return livingByTeam.player, livingByTeam.enemy
end

function BattleSimulation:getOutcome()
    if self.settled then return self.tacticalOutcome, self.tacticalWinner end
    local context, partyA, partyB = self.context, self.partyA, self.partyB
    local partyAAlive, partyBAlive = getLivingCounts(context)
    self.resolving = partyAAlive == 0 or partyBAlive == 0
    for _, unit in ipairs(context.data.unitList) do
        if unit.hp > 0 and unit.fleeing and not unit.escaped then return nil, nil end
    end
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
    for _, unit in ipairs(context.data.escaped) do unitsByActorId[unit.id] = unit end
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
            tacticalHp = battleUnit and battleUnit.tacticalHp,
            tacticalEscaped = battleUnit and battleUnit.tacticalEscaped,
            maxHp = battleUnit and battleUnit.maxHp or maxHp,
            statusEffects = InventorySystem.deepClone(battleUnit and battleUnit.statusEffects or actor.statusEffects or {}),
            defeated = finalHp <= 0,
            escaped = battleUnit and battleUnit.escaped or false,
            state = finalHp <= 0 and "defeated" or
                (battleUnit and battleUnit.escaped and "escaped") or
                (battleUnit and battleUnit.fleeing and "fleeing") or "active",
            injuries = InventorySystem.deepClone(battleUnit and battleUnit.injuries or actor.injuries or {}),
            equipment = InventorySystem.deepClone(battleUnit and battleUnit.equipment or actor.equipment or {}),
            itemDurability = InventorySystem.deepClone(battleUnit and battleUnit.itemDurability or actor.itemDurability or {})
        }
    end
end

-- A bounded, synchronous status-only tail; tactical time and the winner stay fixed.
BattleSimulation.SETTLEMENT_LIMIT = 10000
function BattleSimulation:settle(outcome, winnerPartyId)
    if self.settled then return end
    self.settled, self.tacticalOutcome, self.tacticalWinner = true, outcome, winnerPartyId
    self.settlementTicks = 0
    local units = collectBattleUnits(self.context)
    for _, unit in pairs(units) do
        unit.tacticalHp, unit.tacticalEscaped = unit.hp, unit.escaped == true
        unit.intent, unit.currentCast = nil, nil
    end
    local function pending()
        for _, unit in pairs(units) do
            if unit.hp > 0 then
                for id, entry in pairs(unit.statusEffects or {}) do
                    if Conditions.finitePeriodic(entry, id) then return true end
                end
            end
        end
        return false
    end
    while self.settlementTicks < self.SETTLEMENT_LIMIT and pending() do
        self.settlementTicks = self.settlementTicks + 1
        for _, unit in pairs(units) do
            if unit.hp > 0 then ExecutionSystem.tickStatuses(unit, self.context, true) end
        end
        Morale.process(self.context)
        self.context.removeDeadUnits()
    end
    self.settlementTruncated = pending()
    for _, unit in pairs(units) do
        unit.statusEffects = Conditions.persistentStatuses(unit)
    end
    for index = #self.context.data.escaped, 1, -1 do
        local unit = self.context.data.escaped[index]
        if unit.hp <= 0 then
            unit.escaped = false
            table.remove(self.context.data.escaped, index)
            self.context.data.casualties[#self.context.data.casualties+1] = unit
        end
    end
end

function BattleSimulation:buildResult(outcome, winnerPartyId)
    self:settle(outcome, winnerPartyId)
    outcome, winnerPartyId = self.tacticalOutcome, self.tacticalWinner
    local partyA, partyB = self.partyA, self.partyB
    local result = {
        partyAId = partyA.id,
        partyBId = partyB.id,
        outcome = outcome,
        winnerPartyId = winnerPartyId,
        loserPartyId = nil,
        routedPartyIds = {},
        actors = {},
        ticks = self.context.data.tick,
        settlementTicks = self.settlementTicks,
        settlementTruncated = self.settlementTruncated
    }

    for _, side in ipairs({{team="player", id=partyA.id}, {team="enemy", id=partyB.id}}) do
        local party = self.context.data.battleParties[side.team]
        if party and party.routed then result.routedPartyIds[#result.routedPartyIds+1] = side.id end
    end

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
