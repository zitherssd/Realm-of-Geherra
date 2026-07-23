-- systems/combat_system.lua
-- Handle combat mechanics, damage, and attack resolution

local CombatSystem = {}
local DEFAULT_TARGET_SIZE_BASELINE = 3
local DEFAULT_PROJECTILE_HIT_CHANCE = 70
local PROJECTILE_SIZE_ABOVE_BASE_BONUS = 5
local PROJECTILE_SIZE_BELOW_BASE_MALUS = 15

function CombatSystem.rollAttack(attacker, defender, skill)
    local attStats = attacker.stats or {}
    local defStats = defender.stats or {}
    
    local attack = attStats.attack or 10
    local defense = defStats.defense or 10
    
    if defense <= 0 then return 95 end
    
    local difference = attack - defense
    local hitChance = CombatSystem._interpolateHitChance(difference)
    return hitChance
end

function CombatSystem._interpolateHitChance(difference)
    local hitCurve = {
        {-100, 3},
        {-80, 7},
        {-60, 10},
        {-40, 15},
        {-20, 20},
        {-10, 32},
        {0, 45},
        {10, 70},
        {20, 80},
        {40, 88},
        {60, 93},
        {80, 97},
        {100, 100},
    }
    
    -- If difference is outside the curve, return the boundary value
    if difference <= hitCurve[1][1] then
        return hitCurve[1][2]
    end
    if difference >= hitCurve[#hitCurve][1] then
        return hitCurve[#hitCurve][2]
    end
    
    -- Find the two points to interpolate between
    for i = 1, #hitCurve - 1 do
        if difference >= hitCurve[i][1] and difference <= hitCurve[i + 1][1] then
            local x0, y0 = hitCurve[i][1], hitCurve[i][2]
            local x1, y1 = hitCurve[i + 1][1], hitCurve[i + 1][2]
            
            -- Linear interpolation between control points
            local t = (difference - x0) / (x1 - x0)
            return y0 + t * (y1 - y0)
        end
    end
    
    -- Fallback (shouldn't reach here)
    return 50
end

function CombatSystem.rollProjectileHitChance(attacker, defender, skill)
    local targetSize = DEFAULT_TARGET_SIZE_BASELINE
    if defender then
        if defender.size then
            targetSize = defender.size
        elseif defender.actor and defender.actor.size then
            targetSize = defender.actor.size
        end
    end

    local hitChance = DEFAULT_PROJECTILE_HIT_CHANCE
    if targetSize > DEFAULT_TARGET_SIZE_BASELINE then
        hitChance = hitChance + ((targetSize - DEFAULT_TARGET_SIZE_BASELINE) * PROJECTILE_SIZE_ABOVE_BASE_BONUS)
    elseif targetSize < DEFAULT_TARGET_SIZE_BASELINE then
        hitChance = hitChance - ((DEFAULT_TARGET_SIZE_BASELINE - targetSize) * PROJECTILE_SIZE_BELOW_BASE_MALUS)
    end

    return math.max(5, math.min(hitChance, 95))
end

function CombatSystem.calculateDamage(attacker, defender, skill)
    local attStats = attacker.stats or {}
    local damageType = skill.damageType or "blunt"
    
    local baseDamage = skill.baseDamage or 0
    local strength = attStats.strength or 10
    
    -- Get total protection (prefer pre-calculated BattleUnit protections, fallback to getTotalProtection)
    local totalProtection = 0
    if defender.protections and defender.protections[damageType] then
        totalProtection = defender.protections[damageType]
    else
        totalProtection = CombatSystem.getTotalProtection(defender, damageType)
    end
    
    -- Damage Formula: BaseDamage - TotalProtection
    -- Minimum 0 damage (no guarantee of damage)
    local damage = math.max(0, baseDamage - totalProtection)
    
    -- Apply 20% variance (±20%, range 0.8 to 1.2)
    local variance = 0.8 + math.random() * 0.4
    damage = damage * variance
    
    return math.floor(damage)
end

-- Calculate total protection for a damage type (innate + equipment)
function CombatSystem.getTotalProtection(defender, damageType)
    if not defender then return 0 end
    
    local damageType = damageType or "blunt"
    local totalProtection = 0
    
    -- Add innate protections
    if defender.innateProtections and defender.innateProtections[damageType] then
        totalProtection = totalProtection + defender.innateProtections[damageType]
    end
    
    -- Add equipment protections
    if defender.equipment then
        local Items = require("data.items")
        for slot, itemId in pairs(defender.equipment) do
            if itemId then
                local item = Items[itemId]
                if item and item.protections and item.protections[damageType] then
                    totalProtection = totalProtection + item.protections[damageType]
                end
            end
        end
    end
    
    return totalProtection
end

-- Get effective skill by merging base skill with equipment modifiers
function CombatSystem.getEffectiveSkill(unit, skillId)
    local Skills = require("data.skills")
    local Items = require("data.items")
    
    local baseSkill = Skills[skillId]
    if not baseSkill then return nil end
    
    -- Shallow copy the base skill
    local effectiveSkill = {}
    for k, v in pairs(baseSkill) do
        effectiveSkill[k] = v
    end
    
    -- Apply modifiers from equipped items that grant this skill
    if unit.equipment then
        for slot, itemId in pairs(unit.equipment) do
            if itemId then
                local item = Items[itemId]
                if item and item.grantsSkill == skillId and item.skillModifiers then
                    for k, v in pairs(item.skillModifiers) do
                        effectiveSkill[k] = v  -- Override with weapon's modifier
                    end
                end
            end
        end
    end
    
    return effectiveSkill
end

-- Determine the type of defensive action based on roll margin and defender state
-- Returns: "dodge", "evade", "parry", or "block" with randomness
-- Prioritizes BLOCK if shield prevented the hit
function CombatSystem._determineDefenseAction(attacker, defender, hitChance, roll)
    local margin = roll - hitChance  -- Negative = missed by this amount
    
    -- Check if defender has a shield equipped
    local hasShield = false
    local shieldDefense = 0
    if defender.equipment and defender.equipment.offHand then
        local Items = require("data.items")
        local shieldItem = Items[defender.equipment.offHand]
        if shieldItem and shieldItem.type == "armor" and shieldItem.slot == "offHand" then
            hasShield = true
            shieldDefense = shieldItem.stats.defense or 0
        end
    end
    
    -- Check if shield was the deciding factor (prevented the hit)
    if hasShield and shieldDefense > 0 then
        -- Calculate hit chance without shield defense
        local defenderDefense = defender.stats.defense or 0
        local defenderDefenseWithoutShield = defenderDefense - shieldDefense
        local differenceWithoutShield = (attacker.stats.attack or 0) - defenderDefenseWithoutShield
        local hitChanceWithoutShield = CombatSystem._interpolateHitChance(differenceWithoutShield)
        
        -- If it would have hit without shield but misses with shield, it's a BLOCK
        if hitChanceWithoutShield > roll and hitChance <= roll then
            return "block"  -- Shield successfully blocked the attack
        end
    end
    
    -- For regular misses, randomly determine action based on margin
    local actionRoll = math.random(0, 100)
    
    if hasShield then
        -- With shield equipped
        if margin > -20 then
            -- Close miss: 50% dodge, 20% evade, 30% block, 0% parry
            if actionRoll < 50 then return "dodge"
            elseif actionRoll < 70 then return "evade"
            else return "block" end
        elseif margin > -40 then
            -- Medium miss: 10% dodge, 25% evade, 40% block, 20% parry
            if actionRoll < 10 then return "dodge"
            elseif actionRoll < 35 then return "evade"
            elseif actionRoll < 75 then return "block"
            else return "parry" end
        else
            -- Wide miss: 1% dodge, 18% evade, 21% block, 60% parry
            if actionRoll < 1 then return "dodge"
            elseif actionRoll < 19 then return "evade"
            elseif actionRoll < 40 then return "block"
            else return "parry" end
        end
    else
        -- Without shield (weapon block only)
        if margin > -20 then
            -- Close miss: 60% dodge, 20% evade, 20% block, 0% parry
            if actionRoll < 60 then return "dodge"
            elseif actionRoll < 80 then return "evade"
            else return "block" end
        elseif margin > -40 then
            -- Medium miss: 15% dodge, 30% evade, 30% block, 20% parry
            if actionRoll < 15 then return "dodge"
            elseif actionRoll < 45 then return "evade"
            elseif actionRoll < 75 then return "block"
            else return "parry" end
        else
            -- Wide miss: 3% dodge, 18% evade, 19% block, 60% parry
            if actionRoll < 3 then return "dodge"
            elseif actionRoll < 21 then return "evade"
            elseif actionRoll < 40 then return "block"
            else return "parry" end
        end
    end
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
        target.maxHp = target.maxHp or target.stats.health
        target.hp = math.max(0, (target.hp or target.maxHp) - amount)
        isDefeated = target.hp <= 0
    end
    
    return isDefeated
end

-- Heals a target. Works on Actors and BattleUnits.
function CombatSystem.heal(target, amount)
    if not target then return end
    
    if target.hp and target.maxHp then
        target.hp = math.min(target.maxHp, target.hp + amount)
    elseif target.stats and target.stats.health then
        target.maxHp = target.maxHp or target.stats.health
        target.hp = math.min(target.maxHp, (target.hp or target.maxHp) + amount)
    end
end

-- Apply durability loss when shield blocks an attack
function CombatSystem.applyBlockDurabilityLoss(defender)
    if not defender or not defender.equipment or not defender.equipment.offHand then
        return
    end
    
    local Items = require("data.items")
    local shieldId = defender.equipment.offHand
    local shieldItem = Items[shieldId]
    
    -- Only shields lose durability (type = "armor" and slot = "offHand")
    if not shieldItem or shieldItem.type ~= "armor" or shieldItem.slot ~= "offHand" then
        return
    end
    
    -- Reduce shield durability by 1
    if not defender.itemDurability then
        defender.itemDurability = {}
    end
    
    defender.itemDurability[shieldId] = (defender.itemDurability[shieldId] or shieldItem.maxDurability) - 1
    
    -- If shield is destroyed, unequip it and remove from inventory
    if defender.itemDurability[shieldId] <= 0 then
        defender.equipment.offHand = nil
        defender.itemDurability[shieldId] = nil
        
        -- Remove the item from inventory if it exists there
        if defender.inventory then
            for i = #defender.inventory, 1, -1 do
                if defender.inventory[i] == shieldId then
                    table.remove(defender.inventory, i)
                end
            end
        end
    end
end

function CombatSystem.resolveAttack(attacker, defender, skill)
    -- 1. Check for Hit
    local hitChance = CombatSystem.rollAttack(attacker, defender, skill)
    local roll = math.random(100)
    local isHit = roll <= hitChance
    
    if isHit then
        local damage = CombatSystem.calculateDamage(attacker, defender, skill)
        local defeated = CombatSystem._applyBattleDamage(defender, damage)
        
        -- Visual: Damage Flash (Red)
        if defender.visualEffects then
            defender.visualEffects.flashTime = 0.3 -- 0.3 seconds
            defender.visualEffects.flashDuration = 0.3
            defender.visualEffects.flashColor = {0.5, 0, 0}
            defender.visualEffects.flashIntensity = 0.8
        end
        
        return {hit = true, damage = damage, defeated = defeated}
    end
    
    -- MISS: Determine defense action and apply visual effects
    local action = CombatSystem._determineDefenseAction(attacker, defender, hitChance, roll)
    
    if defender.visualEffects then
        defender.visualEffects.shakeTime = 0.5 -- 0.5 seconds
    end
    
    return {hit = false, damage = 0, defeated = false, action = action}
end

function CombatSystem.resolveProjectileAttack(attacker, defender, skill)
    local hitChance = CombatSystem.rollProjectileHitChance(attacker, defender, skill)
    local roll = math.random(100)
    local isHit = roll <= hitChance

    if isHit then
        local damage = CombatSystem.calculateDamage(attacker, defender, skill)
        local defeated = CombatSystem._applyBattleDamage(defender, damage)

        if defender.visualEffects then
            defender.visualEffects.flashTime = 0.3
            defender.visualEffects.flashDuration = 0.3
            defender.visualEffects.flashColor = {0.5, 0, 0}
            defender.visualEffects.flashIntensity = 0.8
        end

        return {hit = true, damage = damage, defeated = defeated}
    end

    local action = CombatSystem._determineDefenseAction(attacker, defender, hitChance, roll)

    if defender.visualEffects then
        defender.visualEffects.shakeTime = 0.5
    end

    return {hit = false, damage = 0, defeated = false, action = action}
end

return CombatSystem
