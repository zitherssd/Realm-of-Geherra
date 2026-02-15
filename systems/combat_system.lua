-- systems/combat_system.lua
-- Handle combat mechanics, damage, and attack resolution

local CombatSystem = {}

function CombatSystem.rollAttack(attacker, defender, skill)
    local attStats = attacker.stats or {}
    local defStats = defender.stats or {}
    
    local attack = attStats.attack or 10
    local defense = defStats.defense or 10
    
    if defense <= 0 then return 95 end
    
    local ratio = attack / defense
    local hitChance = 50 + (ratio - 1) * 35 -- Base 50%, adjusted by ratio
    return math.max(5, math.min(hitChance, 95))
end

function CombatSystem.calculateDamage(attacker, defender, skill)
    local attStats = attacker.stats or {}
    local defStats = defender.stats or {}
    
    local strength = attStats.strength or 10
    local multiplier = skill.damageMultiplier or 1.0
    
    -- Damage Formula: (Strength * Multiplier) - (Defense / 2)
    local rawDamage = strength * multiplier
    local defense = defStats.defense or 0
    local damage = math.max(1, rawDamage - (defense * 0.5))
    
    return math.floor(damage)
end

-- Private function for battle context
function CombatSystem._applyBattleDamage(unit, damage)
    -- BattleUnit uses .hp, not .stats.health
    unit.hp = math.max(0, unit.hp - damage)
    return unit.hp <= 0
end

-- Check if a unit is alive. Works on Actors and BattleUnits.
function CombatSystem.isAlive(target)
    if not target then return false end
    if target.hp then
        return target.hp > 0
    elseif target.stats and target.stats.health then
        return target.stats.health > 0
    end
    return true -- Default to alive if no health is found
end

-- Deals damage to a target. Works on Actors and BattleUnits.
function CombatSystem.dealDamage(target, amount)
    if not target then return false end
    
    local isDefeated = false
    if target.hp then
        target.hp = math.max(0, target.hp - amount)
        isDefeated = target.hp <= 0
    elseif target.stats and target.stats.health then
        target.stats.health = math.max(0, target.stats.health - amount)
        isDefeated = target.stats.health <= 0
    end
    
    return isDefeated
end

-- Heals a target. Works on Actors and BattleUnits.
function CombatSystem.heal(target, amount)
    if not target then return end
    
    if target.hp and target.maxHp then
        target.hp = math.min(target.maxHp, target.hp + amount)
    elseif target.stats and target.stats.health then
        local maxHealth = target.stats.maxHealth or 100
        target.stats.health = math.min(maxHealth, target.stats.health + amount)
    end
end

function CombatSystem.resolveAttack(attacker, defender, skill, context)
    -- 1. Check for Hit
    local hitChance = CombatSystem.rollAttack(attacker, defender, skill)
    local isHit = math.random(100) <= hitChance
    
    if isHit then
        -- HIT
        local damage = CombatSystem.calculateDamage(attacker, defender, skill)
        local defeated = CombatSystem._applyBattleDamage(defender, damage)
        
        -- Visual: Damage Flash (Red)
        if defender.visualEffects then
            defender.visualEffects.flashTime = 0.3
            defender.visualEffects.flashDuration = 0.3
            defender.visualEffects.flashColor = {0.5, 0, 0}
            defender.visualEffects.flashIntensity = 0.8
        end
        
        -- Contextual Side Effects (from old _resolveHit)
        if defeated then
            context.data.grid:setOccupant(defender.x, defender.y, nil)
        end
        
        if context.addFloatingText then
            context.addFloatingText(defender.visualX, defender.visualY, tostring(damage), {1, 0.2, 0.2, 1})
        end
        
        return {hit = true, damage = damage, defeated = defeated}
    else
        -- MISS/BLOCK
        -- Visual: Shake
        if defender.visualEffects then
            defender.visualEffects.shakeTime = 0.5
        end
        
        -- Contextual Side Effects (from old _resolveHit)
        if context.addFloatingText then
            context.addFloatingText(defender.visualX, defender.visualY, "BLOCK", {0.8, 0.8, 0.8, 1})
        end
        
        return {hit = false, damage = 0, defeated = false}
    end
end

return CombatSystem
