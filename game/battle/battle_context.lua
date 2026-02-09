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
    outcome = nil        -- nil, "win", "loss", "flee"
}

function BattleContext.init(grid)
    BattleContext.data.grid = grid
    BattleContext.data.units = {}
    BattleContext.data.unitList = {}
    BattleContext.data.paused = false
    BattleContext.data.playerCommand = nil
    BattleContext.data.selectedUnitId = nil
    BattleContext.data.outcome = nil
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

return BattleContext