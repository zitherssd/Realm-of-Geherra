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
    floatingTexts = {}
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
    BattleContext.data.camera = {x = 0, y = 0, zoom = 1.3}
    BattleContext.data.floatingTexts = {}
end

function BattleContext.addUnit(battleUnit)
    if not battleUnit then return end
    BattleContext.data.units[battleUnit.id] = battleUnit
    table.insert(BattleContext.data.unitList, battleUnit)
    
    -- Register initial position on grid
    if BattleContext.data.grid then
        BattleContext.data.grid:setOccupant(battleUnit.x, battleUnit.y, battleUnit.id)
    end
end

function BattleContext.removeDeadUnits()
    local units = BattleContext.data.unitList
    local grid = BattleContext.data.grid
    
    for i = #units, 1, -1 do
        local unit = units[i]
        if unit.hp <= 0 then
            if grid then
                grid:setOccupant(unit.x, unit.y, nil)
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

return BattleContext