local BattleGridActions = {
    ATTACK_COOLDOWN = 50, --ticks
    MOVE_COOLDOWN_BASE = 120
}
local grid = require("src.game.battle.BattleGrid")
local animations = require("src.game.battle.BattleAnimations")
local ui = require("src.game.battle.BattleUI")
local CombatFormulas = require("src.game.util.CombatFormulas")
local PartyModule = require('src.game.modules.PartyModule')

function BattleGridActions:placeUnitInCell(unit, cell)
    if not grid:isValidPosition(cell.x, cell.y) then
        print("Invalid cell position")
        return false
    end

    if cell.total_size + unit.size > cell.max_size then
        print("Cell is full")
        return false
    end

    if unit.currentCell then
        grid:removeUnitFromCell(unit, unit.currentCell)
    end
    
    grid:addUnitToCell(unit,cell)
    animations:updateUnitPositionsInCell(cell)
    return true
end

function BattleGridActions:placeUnitInCellByXY(unit, cellX, cellY)

    local cell = grid.cells[cellX][cellY]

    return self:placeUnitInCell(unit, cell);
end

function BattleGridActions:moveUnitToCell(unit, targetCell)
    if grid:getCellPartyNumber(targetCell) and unit.battle_party ~= grid:getCellPartyNumber(targetCell) then
        print("Cannot move to enemy cell")
        return false
    end

    local moveCooldown = math.floor((self.MOVE_COOLDOWN_BASE * (1 + (math.random() - 0.5) * 0.2)) / (unit.speed or 30))
    unit.action_cooldown = moveCooldown

    if targetCell.x < unit.currentCell.x then
        unit.facing_right = false
    elseif targetCell.x > unit.currentCell.x then
        unit.facing_right = true
    end

    self:placeUnitInCell(unit, targetCell)
    animations:updateUnitPositionsInCell(targetCell)
    return true
end

function BattleGridActions:moveUnitToCellByXY(unit, cellX, cellY)

    local targetCell = grid.cells[cellX][cellY]

    return BattleGridActions:moveUnitToCell(unit, targetCell)
end

function BattleGridActions:attack(attacker, defender)
    if defender.currentCell.x > attacker.currentCell.x then
        attacker.facing_right = true
    elseif defender.currentCell.x < attacker.currentCell.x then
        attacker.facing_right = false
    end

    attacker:flash({1,1,1},0.1)
    attacker.action_cooldown = self.ATTACK_COOLDOWN
    local roll = love.math.random(1,100)
    local hit = roll <= CombatFormulas:calculateHitChance(attacker,defender) 
    
    if hit then
        defender.target = attacker
        local damage =CombatFormulas:calculateDamage(attacker,defender)
        ui:createDamagePopup(defender.battle_x,defender.battle_y,damage)
        -- Trigger red flash on hit
        defender:flash({1,0,0},0.25)
        defender.health = defender.health - damage
    else
         defender:shake(0.2,1) 
    end

    if defender.health <= 0 then
        grid:removeUnitFromCell(defender, defender.currentCell)
        --defender:destroy()
    end
end

-- Pick a decent adjacent/melee target for the unit
function BattleGridActions:_pickMeleeTarget(unit)
    if not unit or not unit.currentCell then return nil end
    local enemies = unit.battle_party == 1 and ((PartyModule.parties[2] or {}).units) or ((PartyModule.parties[1] or {}).units)
    local best, bestPriority = nil, -math.huge
    for _, enemy in ipairs(enemies or {}) do
        if enemy.health > 0 and enemy.currentCell then
            local dx = enemy.currentCell.x - unit.currentCell.x
            local dy = enemy.currentCell.y - unit.currentCell.y
            local dist = math.abs(dx) + math.abs(dy)
            if dist <= 2 then
                local p = 0
                if unit.facing_right and dx > 0 then p = p + 10
                elseif (not unit.facing_right) and dx < 0 then p = p + 10 end
                if dy == 0 then p = p + 5 end
                if math.abs(dy) == 1 then p = p + 2 end
                p = p + (2 - dist)
                if p > bestPriority then bestPriority = p; best = enemy end
            end
        end
    end
    return best
end

-- Use an action: if it has a windup (cooldownStart), block for that many ticks,
-- then perform an attack identical to :attack, then set cooldownEnd.
-- If no windup, perform immediately and go on cooldown.
function BattleGridActions:useAction(unit, action, currentTick)
    if not unit or not action then return false end
    if unit.action_cooldown and unit.action_cooldown > 0 then return false end

    -- For now only support melee actions (no range). Require a nearby target to start.
    local requiresMelee = (action.range == nil)
    local hasTarget = true
    if requiresMelee then
        hasTarget = (self:_pickMeleeTarget(unit) ~= nil)
        if not hasTarget then
            return false
        end
    end

    local windup = math.max(0, action.cooldownStart or 0)
    if windup > 0 then
        unit.pending_action = action
        unit.action_cooldown = windup
        action.last_used_tick = currentTick or 0
        action.executed_tick = nil
        return true
    end

    -- No windup: execute now as melee (range handling later)
    local target = requiresMelee and self:_pickMeleeTarget(unit) or nil
    if requiresMelee and not target then return false end
    if target then self:attack(unit, target) end
    local recovery = math.max(0, action.cooldownEnd or self.ATTACK_COOLDOWN)
    unit.action_cooldown = recovery
    action.last_used_tick = currentTick or 0
    action.executed_tick = currentTick or 0
    return true
end

function BattleGridActions:executePending(unit, currentTick)
    if not unit or not unit.pending_action then return false end
    local action = unit.pending_action
    unit.pending_action = nil
    -- Perform melee attack for now
    local target = self:_pickMeleeTarget(unit)
    if target then
        self:attack(unit, target)
    end
    local recovery = math.max(0, action.cooldownEnd or self.ATTACK_COOLDOWN)
    unit.action_cooldown = recovery
    action.executed_tick = currentTick or 0
    return true
end

function BattleGridActions:moveTowardsUnit(unit, target)
    if not unit or not target then return false end
    
    -- Move towards target
    local dx = target.currentCell.x - unit.currentCell.x
    local dy = target.currentCell.y - unit.currentCell.y
    
    -- Determine move direction (prioritize X or Y based on larger distance)
    local moveX, moveY = 0, 0
    if math.abs(dx) > math.abs(dy) then
        moveX = dx > 0 and 1 or -1
    else
        moveY = dy > 0 and 1 or -1
    end
    
    -- Try to move in the chosen direction
    local newX = unit.currentCell.x + moveX
    local newY = unit.currentCell.y + moveY
    
    -- Prefer validated movement using moveUnit (handles cooldown/animation/stacking)
    if self:moveUnitToCellByXY(unit, newX, newY) then
        return true
    end
    
    -- If preferred axis is blocked, try the alternate axis step
    local altX, altY = unit.currentCell.x, unit.currentCell.y
    if moveX ~= 0 then
        altY = unit.currentCell.y + (dy > 0 and 1 or -1)
    else
        altX = unit.currentCell.x + (dx > 0 and 1 or -1)
    end
    
    if (altX ~= unit.currentCell.x or altY ~= unit.currentCell.y) then
        if self:moveUnitToCellByXY(unit, altX, altY) then
            return true
        end
    end
    
    return false
end

return BattleGridActions