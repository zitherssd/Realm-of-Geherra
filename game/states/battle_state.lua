-- game/states/battle_state.lua
-- Battle/combat state
-- Manages the battle loop with a fixed timestep (tick system)

local Input = require("core.input")
local BattleContext = require("game.battle.battle_context")
local BattleGrid = require("game.battle.battle_grid")
local BattleUnit = require("game.battle.battle_unit")
local Skills = require("data.skills")
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
    
    -- Update Input Cooldown
    if BattleContext.data.inputCooldown > 0 then
        BattleContext.data.inputCooldown = BattleContext.data.inputCooldown - dt
    end

    -- 1. Input Handling
    local playerUnit = BattleContext.data.units[BattleContext.data.selectedUnitId]
    
    -- Tab: Cycle Skills
    if Input.isKeyDown("tab") and BattleContext.data.inputCooldown <= 0 then
        BattleContext.data.selectedSkillIndex = BattleContext.data.selectedSkillIndex + 1
        if playerUnit and playerUnit.skillList then
            if BattleContext.data.selectedSkillIndex > #playerUnit.skillList then
                BattleContext.data.selectedSkillIndex = 1
            end
        else
            BattleContext.data.selectedSkillIndex = 1
        end
        BattleContext.data.inputCooldown = 0.2
    end

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

        -- Space: Use Selected Skill
        if Input.isKeyDown("space") and BattleContext.data.inputCooldown <= 0 then
            if playerUnit.skillList and #playerUnit.skillList > 0 then
                local skillId = playerUnit.skillList[BattleContext.data.selectedSkillIndex]
                local skillData = Skills[skillId]
                
                if skillData then
                    -- Find best target (nearest enemy in range)
                    local bestTarget = nil
                    local minDist = math.huge
                    local rangeSq = (skillData.range or 1.5) * (skillData.range or 1.5)
                    
                    for _, other in ipairs(BattleContext.data.unitList) do
                        if other.team ~= playerUnit.team and other.hp > 0 then
                            local tdx = playerUnit.x - other.x
                            local tdy = playerUnit.y - other.y
                            local dist = tdx*tdx + tdy*tdy
                            
                            if dist <= rangeSq and dist < minDist then
                                minDist = dist
                                bestTarget = other
                            end
                        end
                    end
                    
                    if bestTarget then
                        BattleContext.data.playerCommand = {
                            type = "SKILL",
                            skillId = skillId,
                            targetUnitId = bestTarget.id,
                            unitId = playerUnit.id
                        }
                        BattleContext.data.inputCooldown = 0.2
                    end
                end
            end
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

    -- Draw Player Skills UI
    if playerUnit and playerUnit.skillList then
        local screenW = love.graphics.getWidth()
        local uiX = screenW - 220
        local uiY = 20
        
        -- Background
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", uiX, uiY, 200, #playerUnit.skillList * 40 + 10)
        
        for i, skillId in ipairs(playerUnit.skillList) do
            local skill = Skills[skillId]
            if skill then
                local y = uiY + 10 + (i-1)*40
                
                -- Highlight selected
                if i == BattleContext.data.selectedSkillIndex then
                    love.graphics.setColor(1, 1, 0, 0.3)
                    love.graphics.rectangle("fill", uiX + 5, y, 190, 35)
                end
                
                -- Windup Progress (Filling Up)
                if playerUnit.currentCast and playerUnit.currentCast.skillId == skillId then
                    local total = skill.windup or 1
                    local current = playerUnit.currentCast.remaining
                    local progress = math.max(0, math.min(1, 1.0 - (current / total)))
                    
                    love.graphics.setColor(0.2, 0.8, 1, 0.5) -- Cyan fill
                    love.graphics.rectangle("fill", uiX + 5, y, 190 * progress, 35)
                -- Cooldown Progress (Decreasing)
                elseif (playerUnit.cooldowns[skillId] or 0) > 0 then
                    local total = skill.cooldown or 20
                    local current = playerUnit.cooldowns[skillId]
                    local progress = math.max(0, math.min(1, current / total))
                    
                    love.graphics.setColor(1, 0.5, 0, 0.3) -- Orange/Red tint for cooldown
                    love.graphics.rectangle("fill", uiX + 5, y, 190 * progress, 35)
                end
                
                -- Text
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(skill.name, uiX + 10, y + 5)
                
                -- Cooldown / Charges
                local cd = playerUnit.cooldowns[skillId] or 0
                if cd > 0 then
                    love.graphics.setColor(1, 0, 0, 1)
                    love.graphics.print(string.format("%.1fs", cd/20), uiX + 150, y + 5)
                elseif playerUnit.charges[skillId] then
                    love.graphics.setColor(0, 1, 1, 1)
                    local max = skill.maxCharges or "?"
                    love.graphics.print(string.format("%s/%s", tostring(playerUnit.charges[skillId]), tostring(max)), uiX + 150, y + 5)
                end
            end
        end
    end
end

return BattleState
