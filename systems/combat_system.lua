-- systems/combat_system.lua
-- Handle combat mechanics, damage, and attack resolution

local CombatSystem = {}
local DEFAULT_TARGET_SIZE_BASELINE = 3
local DEFAULT_PROJECTILE_HIT_CHANCE = 70
local PROJECTILE_SIZE_ABOVE_BASE_BONUS = 5
local PROJECTILE_SIZE_BELOW_BASE_MALUS = 15

-- Break down a defender's total defense into base stats, armor, and shield components.
-- The total returned always matches defender.stats.defense (which already includes
-- equipment bonuses for BattleUnits). Returns: baseDefense, armorDefense, shieldDefense, totalDefense.
function CombatSystem._getDefenseBreakdown(defender)
    local totalDefense = 0
    local armorDefense = 0
    local shieldDefense = 0

    if not defender then
        return 0, 0, 0, 0
    end

    -- Total defense from the unit's derived stats (already includes equipment for BattleUnits)
    local defStats = defender.stats or {}
    totalDefense = defStats.defense or 0

    -- Sum equipment defense contributions so we can split them out
    if defender.equipment then
        local Items = require("data.items")
        for slot, itemId in pairs(defender.equipment) do
            if itemId then
                local item = Items[itemId]
                if item and item.type == "armor" and item.stats and item.stats.defense then
                    if slot == "offHand" then
                        shieldDefense = shieldDefense + item.stats.defense
                    else
                        armorDefense = armorDefense + item.stats.defense
                    end
                end
            end
        end
    end

    -- Base defense is what's left after removing equipment contributions
    local baseDefense = math.max(0, totalDefense - armorDefense - shieldDefense)

    return baseDefense, armorDefense, shieldDefense, totalDefense
end

function CombatSystem.rollAttack(attacker, defender, skill)
    local attStats = attacker.stats or {}
    
    local attack = attStats.attack or 10
    local baseDefense, armorDefense, shieldDefense, totalDefense = CombatSystem._getDefenseBreakdown(defender)
    
    local rawOffense = math.random(20)
    local rawDefense = math.random(20)
    local offenseTotal = rawOffense + attack
    local defenseTotal = math.max(0, rawDefense + totalDefense)
    
    local margin = offenseTotal - defenseTotal
    local isHit = margin > 0  -- Ties go to the defender
    
    return isHit, false, false, offenseTotal, defenseTotal, margin, baseDefense, armorDefense, shieldDefense
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

-- Determine the type of defensive action based on how badly the attacker missed
-- Returns: "dodge", "evade", "parry", or "block" with randomness
-- closeThreshold/mediumThreshold define margin bands (varies by d20 vs d100 scale)
function CombatSystem._determineDefenseAction(hasShield, margin, closeThreshold, mediumThreshold)
    closeThreshold = closeThreshold or -7
    mediumThreshold = mediumThreshold or -15
    
    local actionRoll = math.random(0, 100)
    
    if hasShield then
        -- With shield equipped
        if margin > closeThreshold then
            -- Close miss: 50% dodge, 20% evade, 30% block, 0% parry
            if actionRoll < 50 then return "dodge"
            elseif actionRoll < 70 then return "evade"
            else return "block" end
        elseif margin > mediumThreshold then
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
        if margin > closeThreshold then
            -- Close miss: 60% dodge, 20% evade, 20% block, 0% parry
            if actionRoll < 60 then return "dodge"
            elseif actionRoll < 80 then return "evade"
            else return "block" end
        elseif margin > mediumThreshold then
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
    local isHit, isCrit, isFumble, offenseTotal, defenseTotal, margin, baseDefense, armorDefense, shieldDefense = CombatSystem.rollAttack(attacker, defender, skill)
    
    if isHit then
        local damage = CombatSystem.calculateDamage(attacker, defender, skill)
        local defeated = CombatSystem._applyBattleDamage(defender, damage)
        
        -- Visual: Damage Flash (Red)
        if defender.visualEffects then
            defender.visualEffects.flashTime = 0.3
            defender.visualEffects.flashDuration = 0.3
            defender.visualEffects.flashColor = {0.5, 0, 0}
            defender.visualEffects.flashIntensity = 0.8
        end
        
        return {hit = true, damage = damage, defeated = defeated}
    end
    
    -- MISS: Determine defense action
    local action
    local hasShield = shieldDefense > 0
    
    -- Check if shield was the deciding factor:
    -- "would the attacker have hit without the shield's defense bonus?"
    -- offenseTotal - (defenseTotal - shieldDefense) > 0  ⇔  margin + shieldDefense > 0
    local isShieldBlock = hasShield and (margin + shieldDefense) > 0
    
    if isShieldBlock then
        action = "block"
        CombatSystem.applyBlockDurabilityLoss(defender)
    else
        action = CombatSystem._determineDefenseAction(hasShield, margin)
    end
    
    if defender.visualEffects then
        defender.visualEffects.shakeTime = 0.5
    end
    
    return {hit = false, damage = 0, defeated = false, action = action}
end

function CombatSystem.resolveProjectileAttack(attacker, defender, skill)
    local hitChance = CombatSystem.rollProjectileHitChance(attacker, defender, skill)
    local roll = math.random(100)
    local isHit = roll <= hitChance
    local baseDefense, armorDefense, shieldDefense = CombatSystem._getDefenseBreakdown(defender)

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

    local hasShield = shieldDefense > 0
    local action = CombatSystem._determineDefenseAction(hasShield, roll - hitChance, -20, -40)

    if defender.visualEffects then
        defender.visualEffects.shakeTime = 0.5
    end

    return {hit = false, damage = 0, defeated = false, action = action}
end

return CombatSystem
