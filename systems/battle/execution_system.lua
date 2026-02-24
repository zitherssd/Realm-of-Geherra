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
            if unit.hp <= 0 then
                unit.currentCast = nil
            else
                unit.currentCast.remaining = unit.currentCast.remaining - 1
                if unit.currentCast.remaining <= 0 then
                    ExecutionSystem._completeCast(unit, context)
                end
            end
        end
    end

    -- 2. Resolve Intents
    for _, unit in ipairs(units) do
        if unit.intent then
            if unit.hp > 0 then
                local intent = unit.intent
                
                if intent.type == "MOVE" then
                    ExecutionSystem._executeMove(unit, intent, context)
                elseif intent.type == "SKILL" then
                    ExecutionSystem._initiateSkill(unit, intent, context)
                end
            end
            
            -- Clear intent after processing
            unit.intent = nil
        end
    end
    
    -- 3. Update Projectiles
    ExecutionSystem._updateProjectiles(context)
end

function ExecutionSystem._executeMove(unit, intent, context)
    local tx, ty = intent.target.x, intent.target.y
    local grid = context.data.grid
    
    -- Validate move
    if grid:inBounds(tx, ty) and grid:hasCapacity(tx, ty, unit, context) then
        -- Update facing
        if tx > unit.x then
            unit.facing = -1 -- Face Right
        elseif tx < unit.x then
            unit.facing = 1 -- Face Left
        end

        -- Update Grid Occupancy
        grid:removeUnit(unit.x, unit.y, unit.id)
        grid:addUnit(tx, ty, unit.id)
        
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
    
    -- Update facing towards target
    if intent.targetUnitId then
        local target = context.data.units[intent.targetUnitId]
        if target then
            if target.x > unit.x then
                unit.facing = -1 -- Face Right
            elseif target.x < unit.x then
                unit.facing = 1 -- Face Left
            end
        end
    end
    
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
    if not skillData then return end
    local grid = context.data.grid

    local targetUnit = context.data.units[targetUnitId]
    -- 1. Validate Target (Alive and in Range)
    local isValid = false
    local range = skillData.range or 1.5
    local rangeSq = range * range
    
    if targetUnit and targetUnit.hp > 0 then
        local dx = targetUnit.x - unit.x
        local dy = targetUnit.y - unit.y
        local distSq = dx*dx + dy*dy
        if distSq <= rangeSq + 0.01 then
            isValid = true
        end
    end
    
    -- 2. Retarget if invalid
    if not isValid then
        targetUnit = context.findNearestHostile(unit, range)
    end
    
    if targetUnit then
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

        -- 1. Handle Projectile vs Instant Hit
        if skillData.projectile then
            -- Spawn Projectile
            local startX, startY = grid:gridToWorld(unit.x, unit.y)
            
            local proj = {
                x = startX,
                y = startY,
                visualX = startX,
                visualY = startY,
                startX = startX,
                startY = startY,
                targetGridX = targetUnit.x,
                targetGridY = targetUnit.y,
                attackerUnit = unit,
                skillId = skillId,
                speed = skillData.projectile.speed or 10,
                sprite = skillData.projectile.sprite,
                arc = skillData.projectile.arc or 0,
                progress = 0 -- 0.0 to 1.0 (approximate for arc)
            }
            
            context.addProjectile(proj)
        else
            -- Instant Hit
            local result = CombatSystem.resolveAttack(unit, targetUnit, skillData)
            ExecutionSystem.applyAttackResult(result, targetUnit, context)
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

-- Applies the contextual side-effects of a combat result
function ExecutionSystem.applyAttackResult(result, target, context)
    if result.hit then
        -- HIT: Apply Damage & Visuals
        if result.defeated then
            context.data.grid:removeUnit(target.x, target.y, target.id)
        end
        
        if context.addFloatingText then
            context.addFloatingText(target.visualX, target.visualY, tostring(result.damage), {1, 0.2, 0.2, 1})
        end
    else
        -- BLOCK/MISS
        if context.addFloatingText then
            context.addFloatingText(target.visualX, target.visualY, "BLOCK", {0.8, 0.8, 0.8, 1})
        end
    end
end

function ExecutionSystem._updateProjectiles(context)
    local projectiles = context.data.projectiles
    if not projectiles then return end
    
    local grid = context.data.grid
    
    for i = #projectiles, 1, -1 do
        local proj = projectiles[i]
        
        local tx, ty = grid:gridToWorld(proj.targetGridX, proj.targetGridY)
        
        local dx = tx - proj.x
        local dy = ty - proj.y
        local dist = math.sqrt(dx*dx + dy*dy)
        
        if dist <= proj.speed then
            -- Impact!
            local occupants = grid:getOccupants(proj.targetGridX, proj.targetGridY)
            if #occupants > 0 then
                for _, occupantId in ipairs(occupants) do
                    local targetUnit = context.data.units[occupantId]
                    if targetUnit and targetUnit.team ~= proj.attackerUnit.team then
                        local result = CombatSystem.resolveAttack(proj.attackerUnit, targetUnit, Skills[proj.skillId])
                        ExecutionSystem.applyAttackResult(result, targetUnit, context)
                    end
                end
            end
            table.remove(projectiles, i)
        else
            -- Move
            local moveX = (dx / dist) * proj.speed
            local moveY = (dy / dist) * proj.speed
            proj.x = proj.x + moveX
            proj.y = proj.y + moveY
            
            -- Update progress for Arc calculation (simple approximation based on distance)
            local totalDist = math.sqrt((tx - proj.startX)^2 + (ty - proj.startY)^2)
            if totalDist > 0 then
                proj.progress = 1.0 - (dist / totalDist)
            end
        end
    end
end

return ExecutionSystem