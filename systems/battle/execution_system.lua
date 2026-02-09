-- systems/battle/execution_system.lua
-- Resolves intents, updates logical positions, applies damage

local ExecutionSystem = {}

function ExecutionSystem.update(dt, context)
    local units = context.data.unitList
    local grid = context.data.grid

    -- 1. Decrement Cooldowns
    for _, unit in ipairs(units) do
        if unit.globalCooldown > 0 then
            unit.globalCooldown = unit.globalCooldown - dt
        end
        for skillId, cd in pairs(unit.cooldowns) do
            if cd > 0 then
                unit.cooldowns[skillId] = cd - dt
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
                ExecutionSystem._executeSkill(unit, intent, context)
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
        
        -- Set moving flag (Render system will handle visual lerp)
        unit.isMoving = true
        
        -- Small GCD to prevent instant teleporting across map
        unit.globalCooldown = 0.2
    end
end

function ExecutionSystem._executeSkill(unit, intent, context)
    local targetUnit = context.data.units[intent.targetUnitId]
    
    if targetUnit then
        -- Calculate Damage (Placeholder)
        local damage = 10
        if unit.actor.stats and unit.actor.stats.strength then
            damage = unit.actor.stats.strength
        end
        
        targetUnit.hp = math.max(0, targetUnit.hp - damage)
        
        -- Set Cooldown
        unit.globalCooldown = 1.0
        
        print(unit.id .. " hit " .. targetUnit.id .. " for " .. damage .. " damage.")
    end
end

return ExecutionSystem