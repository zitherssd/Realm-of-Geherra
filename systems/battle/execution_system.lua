-- systems/battle/execution_system.lua
-- Resolves intents, updates logical positions, applies damage

local ExecutionSystem = {}
local Skills = require("data.skills")

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
        
        -- Calculate Cooldown
        -- Formula: 120 * (1 + random_variance) / battle_speed
        -- Result is in TICKS.
        local battleSpeed = unit.actor.stats.battle_speed or 10
        local variance = (math.random() - 0.5) * 0.2 -- +/- 10%
        local cooldownTicks = (120 * (1 + variance)) / battleSpeed
        
        unit.globalCooldown = cooldownTicks
    end
end

function ExecutionSystem._executeSkill(unit, intent, context)
    local skillId = intent.skillId
    local skillData = Skills[skillId]
    local targetUnit = context.data.units[intent.targetUnitId]
    
    if targetUnit and skillData then
        -- 1. Calculate Damage
        -- Base damage comes from Strength (melee) or Intelligence (magic - placeholder)
        local baseStat = unit.actor.stats.strength or 10
        local multiplier = skillData.damageMultiplier or 1.0
        
        local damage = math.floor(baseStat * multiplier)
        
        -- Apply Damage
        targetUnit.hp = math.max(0, targetUnit.hp - damage)
        
        -- 2. Set Cooldowns (Convert seconds to ticks: 20 ticks/sec)
        local cdTicks = (skillData.cooldown or 1.0) * 20
        unit.cooldowns[skillId] = cdTicks

        -- 3. Consume Charge (if applicable)
        if skillData.maxCharges then
            unit.charges[skillId] = (unit.charges[skillId] or 0) - 1
        end
        
        -- Apply a Global Cooldown (GCD) so they can't move immediately after attacking
        unit.globalCooldown = 20 -- 1 second GCD
        
        print(string.format("%s used %s on %s for %d damage.", unit.id, skillData.name, targetUnit.id, damage))
    end
end

return ExecutionSystem