-- game/battle/battle_context.lua
-- Shared blackboard for the current battle instance
-- Manages the grid, unit lists, and command state

local BattleContext = {}

BattleContext.data = {
    grid = nil,
    units = {},          -- Map of ID -> BattleUnit
    unitList = {},       -- Ordered list for iteration
    
    -- Time management
    paused = false,
    
    -- Input / Command
    -- Example: { type="MOVE", target={x=10, y=5}, unitId="player_1" }
    playerCommand = nil, 
    
    -- Selection
    selectedUnitId = nil,
    
    -- State
    outcome = nil,       -- nil, "win", "loss", "flee"

    -- Tick System
    tick = 0,
    accumulator = 0,
    
    -- Camera
    camera = {x = 0, y = 0, zoom = 1.3},
    floatingTexts = {},
    projectiles = {},
    casualties = {}    -- List of BattleUnit
}

function BattleContext.init(grid)
    BattleContext.data.grid = grid
    BattleContext.data.units = {}
    BattleContext.data.unitList = {}
    BattleContext.data.paused = false
    BattleContext.data.playerCommand = nil
    BattleContext.data.selectedUnitId = nil
    BattleContext.data.outcome = nil
    BattleContext.data.tick = 0
    BattleContext.data.accumulator = 0
    BattleContext.data.selectedSkillIndex = 1
    BattleContext.data.inputCooldown = 0
    BattleContext.data.targetingMode = false
    BattleContext.data.targetingSkillId = nil
    BattleContext.data.targetingCell = nil
    BattleContext.data.camera = {x = 0, y = 0, zoom = 1.3}
    BattleContext.data.floatingTexts = {}
    BattleContext.data.projectiles = {}
    BattleContext.data.casualties = {}
end

function BattleContext.addUnit(battleUnit)
    if not battleUnit then return end
    BattleContext.data.units[battleUnit.id] = battleUnit
    table.insert(BattleContext.data.unitList, battleUnit)
    
    -- Register initial position on grid
    if BattleContext.data.grid then
        BattleContext.data.grid:addUnit(battleUnit.x, battleUnit.y, battleUnit.id)
    end
end

function BattleContext.removeDeadUnits()
    local units = BattleContext.data.unitList
    local grid = BattleContext.data.grid
    
    for i = #units, 1, -1 do
        local unit = units[i]
        if unit.hp <= 0 then
            table.insert(BattleContext.data.casualties, unit)
            if grid then
                grid:removeUnit(unit.x, unit.y, unit.id)
            end
            BattleContext.data.units[unit.id] = nil
            table.remove(units, i)
        end
    end
end

function BattleContext.addFloatingText(x, y, text, color)
    table.insert(BattleContext.data.floatingTexts, {
        x = x,
        y = y,
        text = text,
        color = color or {1, 1, 1, 1},
        time = 0,
        duration = 1.0,
        offsetY = 0
    })
end

function BattleContext.addProjectile(proj)
    table.insert(BattleContext.data.projectiles, proj)
end

function BattleContext.findNearestHostile(unit, maxRange)
    local nearestTarget = nil
    local minDist = math.huge
    local maxRangeSq = maxRange and (maxRange * maxRange) or math.huge

    for _, other in ipairs(BattleContext.data.unitList) do
        if other.team ~= unit.team and other.hp > 0 then
            local dx = unit.x - other.x
            local dy = unit.y - other.y
            local distSq = dx*dx + dy*dy
            
            if distSq <= maxRangeSq + 0.01 and distSq < minDist then
                minDist = distSq
                nearestTarget = other
            end
        end
    end
    return nearestTarget, minDist
end

return BattleContext