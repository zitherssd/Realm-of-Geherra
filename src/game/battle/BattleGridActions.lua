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