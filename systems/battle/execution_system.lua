-- systems/battle/execution_system.lua
-- Resolves intents, updates logical positions, applies damage

local ExecutionSystem = {}
local Skills = require("data.skills")
local CombatSystem = require("systems.combat_system")

function ExecutionSystem.update(context)
    local units = context.data.unitList
    local grid = context.data.grid

    -- 1. Decrement Cooldowns
    for _, unit in ipairs(units) do
        if unit.globalCooldown > 0 then
            unit.globalCooldown = unit.globalCooldown - 1
        end
        for skillId, cd in pairs(unit.cooldowns) do
            if cd > 0 then
                unit.cooldowns[skillId] = cd - 1
            end
        end
        
        -- Handle Casting / Windup
        if unit.currentCast then
            unit.currentCast.remaining = unit.currentCast.remaining - 1
            if unit.currentCast.remaining <= 0 then
                ExecutionSystem._completeCast(unit, context)
            end
        end
    end

    -- 2. Resolve Intents
    for _, unit in ipairs(units) do
        if unit.intent then
            local intent = unit.intent
            
            if intent.type == "MOVE" then
                ExecutionSystem._executeMove(unit, intent, grid)
            elseif intent.type == "SKILL" then
                ExecutionSystem._initiateSkill(unit, intent, context)
            end
            
            -- Clear intent after processing
            unit.intent = nil
        end
    end
end

function ExecutionSystem._executeMove(unit, intent, grid)
    local tx, ty = intent.target.x, intent.target.y
    
    -- Validate move
    if grid:inBounds(tx, ty) and grid:isFree(tx, ty) then
        -- Update Grid Occupancy
        grid:setOccupant(unit.x, unit.y, nil)
        grid:setOccupant(tx, ty, unit.id)
        
        -- Update Logical Position
        unit.x = tx
        unit.y = ty
        
        -- Calculate Cooldown
        -- Formula: 120 * (1 + random_variance) / battle_speed
        -- Result is in TICKS.
        local battleSpeed = unit.stats.battle_speed or 10
        local variance = (math.random() - 0.5) * 0.2 -- +/- 10%
        local cooldownTicks = (120 * (1 + variance)) / battleSpeed
        
        unit.globalCooldown = cooldownTicks
    end
end

function ExecutionSystem._initiateSkill(unit, intent, context)
    local skillId = intent.skillId
    local skillData = Skills[skillId]
    
    if skillData then
        local windup = skillData.windup or 0
        
        if windup > 0 then
            -- Start Windup
            unit.currentCast = {
                skillId = skillId,
                targetUnitId = intent.targetUnitId,
                remaining = windup
            }
            -- Unit is busy during windup
            unit.globalCooldown = windup
            
            -- Visual: Start Windup Flash (White/Yellow pulse)
            unit.visualEffects.flashTime = 0.2 -- Brief flash (0.2s)
            unit.visualEffects.flashDuration = 0.2
            unit.visualEffects.flashColor = {1, 1, 0.8} -- Warm white
            unit.visualEffects.flashIntensity = 0.5 -- Subtle intensity
            
        else
            -- Instant Cast
            ExecutionSystem._executeSkillEffect(unit, skillId, intent.targetUnitId, context)
        end
    end
end

function ExecutionSystem._completeCast(unit, context)
    if not unit.currentCast then return end
    
    ExecutionSystem._executeSkillEffect(unit, unit.currentCast.skillId, unit.currentCast.targetUnitId, context)
    unit.currentCast = nil
end

function ExecutionSystem._executeSkillEffect(unit, skillId, targetUnitId, context)
    local skillData = Skills[skillId]
    local targetUnit = context.data.units[targetUnitId]
    
    if targetUnit and skillData then
        -- Visual: Lunge Animation
        -- Calculate direction vector
        local dx = targetUnit.x - unit.x
        local dy = targetUnit.y - unit.y
        local dist = math.sqrt(dx*dx + dy*dy)
        
        if dist > 0 then
            unit.visualEffects.lungeX = dx / dist
            unit.visualEffects.lungeY = dy / dist
            unit.visualEffects.lungeTime = 0.2 -- 200ms lunge
            unit.visualEffects.lungeDuration = 0.2
        end

        -- 1. Resolve Attack (Hit/Miss + Damage)
        local result = CombatSystem.resolveAttack(unit, targetUnit, skillData)
        
        if result.hit then
            -- HIT: Apply Damage & Visuals
            if result.defeated then
                context.data.grid:setOccupant(targetUnit.x, targetUnit.y, nil)
            end
            
            if context.addFloatingText then
                context.addFloatingText(targetUnit.visualX, targetUnit.visualY, tostring(result.damage), {1, 0.2, 0.2, 1})
            end
            
        else
        end
        
        -- 2. Set Cooldowns (Value is in ticks)
        local cdTicks = skillData.cooldown or 20
        unit.cooldowns[skillId] = cdTicks
        
        -- 3. Consume Charge (if applicable)
        if skillData.maxCharges then
            unit.charges[skillId] = (unit.charges[skillId] or 0) - 1
        end
        
        -- Apply a Global Cooldown (GCD) so they can't move immediately after attacking
        unit.globalCooldown = cdTicks
    end
end

return ExecutionSystem