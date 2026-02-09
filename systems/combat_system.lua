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

function CombatSystem.applyDamage(unit, damage)
    -- BattleUnit uses .hp, not .stats.health
    unit.hp = math.max(0, unit.hp - damage)
    return unit.hp <= 0
end

function CombatSystem.resolveAttack(attacker, defender, skill)
    -- 1. Check for Hit
    local hitChance = CombatSystem.rollAttack(attacker, defender, skill)
    local isHit = math.random(100) <= hitChance
    
    if isHit then
        local damage = CombatSystem.calculateDamage(attacker, defender, skill)
        local defeated = CombatSystem.applyDamage(defender, damage)
        
        -- Visual: Damage Flash (Red)
        if defender.visualEffects then
            defender.visualEffects.flashTime = 0.3 -- 0.3 seconds
            defender.visualEffects.flashDuration = 0.3
            defender.visualEffects.flashColor = {0.5, 0, 0}
            defender.visualEffects.flashIntensity = 0.8
        end
        
        return {hit = true, damage = damage, defeated = defeated}
    end
    
    -- MISS/BLOCK: Visual Shake
    if defender.visualEffects then
        defender.visualEffects.shakeTime = 0.5 -- 0.5 seconds
    end
    
    return {hit = false, damage = 0, defeated = false}
end

return CombatSystem
