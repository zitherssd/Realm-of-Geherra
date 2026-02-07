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

local function heuristic(a, b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

local function getPath(unit, targetCell)
    local startNode = unit.currentCell
    local goalNode = targetCell
    
    if not startNode or not goalNode then return nil end

    local openSet = { startNode }
    local cameFrom = {}
    local gScore = {}
    gScore[startNode] = 0
    local fScore = {}
    fScore[startNode] = heuristic(startNode, goalNode)
    local visited = {} 
    
    while #openSet > 0 do
        local current = nil
        local minF = math.huge
        local currentIndex = -1
        
        for i, node in ipairs(openSet) do
            local f = fScore[node] or math.huge
            if f < minF then
                minF = f
                current = node
                currentIndex = i
            end
        end
        
        if not current then break end
        if current == goalNode then
            local path = {}
            while current do
                table.insert(path, 1, current)
                current = cameFrom[current]
            end
            return path
        end
        
        table.remove(openSet, currentIndex)
        visited[current] = true
        
        local dirs = {{1,0}, {-1,0}, {0,1}, {0,-1}}
        for _, dir in ipairs(dirs) do
            local nx, ny = current.x + dir[1], current.y + dir[2]
            if grid:isValidPosition(nx, ny) then
                local neighbor = grid.cells[nx][ny]
                if not visited[neighbor] then
                    local isWalkable = true
                    if neighbor ~= goalNode then
                        if neighbor.total_size + unit.size > neighbor.max_size then isWalkable = false end
                        local cellParty = grid:getCellPartyNumber(neighbor)
                        if cellParty and cellParty ~= unit.battle_party then isWalkable = false end
                    end
                    
                    if isWalkable then
                        local tentative_gScore = (gScore[current] or math.huge) + 1
                        if tentative_gScore < (gScore[neighbor] or math.huge) then
                            cameFrom[neighbor] = current
                            gScore[neighbor] = tentative_gScore
                            fScore[neighbor] = tentative_gScore + heuristic(neighbor, goalNode)
                            
                            local inOpen = false
                            for _, n in ipairs(openSet) do if n == neighbor then inOpen = true break end end
                            if not inOpen then table.insert(openSet, neighbor) end
                        end
                    end
                end
            end
        end
    end
    return nil
end

function BattleGridActions:moveTowardsUnit(unit, target)
    if not unit or not target then return false end
    if not unit.currentCell or not target.currentCell then return false end
    
    local path = getPath(unit, target.currentCell)
    if path and #path >= 2 then
        local nextCell = path[2]
        return self:moveUnitToCell(unit, nextCell)
    end
    
    return false
end

function BattleGridActions:tryUseAction(unit, action, battleState)
    if not action or not action.try then return false, "invalid_action" end

    local result = action:try(unit, battleState)
    if result.valid then
        unit.pending_action = result.action
        unit.pending_action.target = result.target
        unit.action_cooldown = action.cooldownStart or 0
        action.last_used_tick = battleState.currentTick
        action.executed_tick = nil -- Clear previous execution time so windup shows
        return true, "executed"
    elseif result.reason == "not_in_range" then
        if self:moveTowardsUnit(unit, unit.battle_target) then
            return false, "moved"
        else
            return false, "not_in_range"
        end
    else
        return false, result.reason
    end
end

return BattleGridActions