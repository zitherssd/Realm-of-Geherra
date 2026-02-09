-- game/states/battle_state.lua
-- Battle/combat state

local Input = require("core.input")
local BattleContext = require("game.battle.battle_context")
local BattleGrid = require("game.battle.battle_grid")
local BattleUnit = require("game.battle.battle_unit")

local DecisionSystem = require("systems.battle.decision_system")
local ExecutionSystem = require("systems.battle.execution_system")
local RenderSystem = require("systems.battle.render_system")

local GameContext = require("game.game_context")

local BattleState = {}

function BattleState.enter(params)
    params = params or {}
    local enemyParty = params.enemyParty
    
    -- Initialize battle with 30x13 grid, 42px cells
    local grid = BattleGrid.new(30, 13, 42)
    BattleContext.init(grid)
    
    -- Convert Player Party to BattleUnits
    local playerParty = GameContext.data.playerParty
    if playerParty and playerParty.actors then
        local startX = 3
        local startY = 3
        
        for i, actor in ipairs(playerParty.actors) do
            -- Simple formation logic: stack vertically
            local x = startX + math.floor((i-1)/5)
            local y = startY + ((i-1) % 5) * 2
            
            local unit = BattleUnit.new(actor, x, y, "player")
            unit:snapToGrid(grid.cellSize)
            BattleContext.addUnit(unit)
            
            -- Auto-select the first player unit (usually leader)
            if i == 1 then
                BattleContext.data.selectedUnitId = unit.id
            end
        end
    end
    
    -- Convert Enemy Party to BattleUnits
    if enemyParty and enemyParty.actors then
        local startX = 26
        local startY = 3
        
        for i, actor in ipairs(enemyParty.actors) do
            local x = startX - math.floor((i-1)/5)
            local y = startY + ((i-1) % 5) * 2
            
            local unit = BattleUnit.new(actor, x, y, "enemy")
            unit:snapToGrid(grid.cellSize)
            BattleContext.addUnit(unit)
        end
    end
end

function BattleState.exit()
    -- Cleanup battle state
end

function BattleState.update(dt)
    if BattleContext.data.paused then return end
    
    -- 1. Input Handling
    if Input.isMousePressed() then
        local mx, my = Input.getMousePosition()
        local grid = BattleContext.data.grid
        local gx, gy = grid:worldToGrid(mx, my)
        
        if grid:inBounds(gx, gy) and BattleContext.data.selectedUnitId then
            -- Issue Move Command
            BattleContext.data.playerCommand = {
                type = "MOVE",
                target = {x = gx, y = gy},
                unitId = BattleContext.data.selectedUnitId
            }
        end
    end

    -- 2. Systems Loop
    DecisionSystem.update(dt, BattleContext)
    ExecutionSystem.update(dt, BattleContext)
    RenderSystem.update(dt, BattleContext)
end

function BattleState.draw()
    love.graphics.clear(0.1, 0.1, 0.1)
    
    RenderSystem.draw(BattleContext)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Battle State - Click to Move", 10, 10)
end

return BattleState
