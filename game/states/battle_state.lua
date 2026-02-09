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

function BattleState.enter()
    -- Initialize battle with 30x13 grid, 42px cells
    local grid = BattleGrid.new(30, 13, 42)
    BattleContext.init(grid)
    
    -- Convert Player Party to BattleUnits
    local playerParty = GameContext.data.playerParty
    if playerParty then
        -- For now, just add the leader as a test unit
        local leaderId = playerParty.leaderId
        -- In real impl, fetch actual Actor object from GameContext or Registry
        local mockActor = { id = leaderId, stats = { health = 100, strength = 15 } } 
        
        local pUnit = BattleUnit.new(mockActor, 5, 6, "player")
        pUnit:snapToGrid(grid.cellSize)
        BattleContext.addUnit(pUnit)
        
        -- Auto-select player unit
        BattleContext.data.selectedUnitId = pUnit.id
    end
    
    -- Add a dummy enemy
    local enemyActor = { id = "bandit_1", stats = { health = 50, strength = 8 } }
    local eUnit = BattleUnit.new(enemyActor, 15, 6, "enemy")
    eUnit:snapToGrid(grid.cellSize)
    BattleContext.addUnit(eUnit)
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
