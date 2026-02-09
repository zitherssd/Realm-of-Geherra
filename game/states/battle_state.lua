-- game/states/battle_state.lua
-- Battle/combat state
-- Manages the battle loop with a fixed timestep (tick system)

local Input = require("core.input")
local BattleContext = require("game.battle.battle_context")
local BattleGrid = require("game.battle.battle_grid")
local BattleUnit = require("game.battle.battle_unit")
local BattleState = {}

-- Systems
local DecisionSystem = require("systems.battle.decision_system")
local ExecutionSystem = require("systems.battle.execution_system")
local RenderSystem = require("systems.battle.render_system")

local GameContext = require("game.game_context")
-- Constants
local TICK_RATE = 1 / 20 -- 20 ticks per second
local MAX_FRAME_SKIP = 5

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
    local playerUnit = BattleContext.data.units[BattleContext.data.selectedUnitId]
    
    -- Only accept input if the player unit is ready to act
    if playerUnit and playerUnit:canAct() then
        local dx, dy = 0, 0
        if Input.isKeyDown("w") or Input.isKeyDown("up") then dy = -1 end
        if Input.isKeyDown("s") or Input.isKeyDown("down") then dy = 1 end
        if Input.isKeyDown("a") or Input.isKeyDown("left") then dx = -1 end
        if Input.isKeyDown("d") or Input.isKeyDown("right") then dx = 1 end

        if (dx ~= 0 or dy ~= 0) then
            -- Calculate target grid position
            local tx, ty = playerUnit.x + dx, playerUnit.y + dy
            
            -- Issue Move Command
            BattleContext.data.playerCommand = {
                type = "MOVE",
                target = {x = tx, y = ty},
                unitId = playerUnit.id
            }
        end
    end

    -- 2. Tick Loop
    local waitingForInput = false
    
    -- Pause simulation if player can act but hasn't issued a command
    if playerUnit and playerUnit:canAct() and not BattleContext.data.playerCommand then
        waitingForInput = true
    end
    
    if not waitingForInput then
        BattleContext.data.accumulator = BattleContext.data.accumulator + dt
        local loops = 0
        while BattleContext.data.accumulator >= TICK_RATE and loops < MAX_FRAME_SKIP do
            BattleState._tick()
            BattleContext.data.accumulator = BattleContext.data.accumulator - TICK_RATE
            loops = loops + 1
        end
    end

    -- 3. Render System (Visual Interpolation)
    RenderSystem.update(dt, BattleContext)
end

function BattleState._tick()
    BattleContext.data.tick = BattleContext.data.tick + 1
    
    -- 1. Decision System: Every tick, units decide what they want to do
    DecisionSystem.update(BattleContext)
    
    -- 2. Execution System: Resolve intents and update state
    ExecutionSystem.update(BattleContext)
end

function BattleState.draw()
    love.graphics.clear(0.1, 0.1, 0.1)
    
    RenderSystem.draw(BattleContext)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Battle Tick: " .. tostring(BattleContext.data.tick), 10, 10)
    
    local playerUnit = BattleContext.data.units[BattleContext.data.selectedUnitId]
    if playerUnit and playerUnit:canAct() and not BattleContext.data.playerCommand then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Waiting for Input...", 10, 30)
    end
end

return BattleState
