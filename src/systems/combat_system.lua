-- systems/combat_system.lua
-- Handle combat mechanics, damage, and attack resolution

local CombatSystem = {}
local DEFAULT_TARGET_SIZE_BASELINE = 3
local DEFAULT_PROJECTILE_HIT_CHANCE = 70
local PROJECTILE_SIZE_ABOVE_BASE_BONUS = 5
local PROJECTILE_SIZE_BELOW_BASE_MALUS = 15

-- Defense contributed by the equipped shield (offHand armor slot).
function CombatSystem._getShieldDefense(defender)
    if not defender or not defender.equipment or not defender.equipment.offHand then
        return 0
    end

    local Items = require("src.data.items")
    local item = Items[defender.equipment.offHand]
    if item and item.type == "armor" and item.stats and item.stats.defense then
        return item.stats.defense
    end

    return 0
end

-- Melee accuracy: two exploding d8s each, with attack/defense modifiers.
-- Formula: attackRoll = attack + rollExploding(8) + rollExploding(8)
--          defenseRoll = defense + shieldBonus + rollExploding(8) + rollExploding(8)
-- Ties (margin == 0) are misses for the attacker.
-- Returns: isHit, margin, shieldDefense
function CombatSystem.rollAttack(attacker, defender, skill)
    local MATH = require("src.utils.math")
    local attStats = attacker.stats or {}
    local defStats = defender.stats or {}

    local attack = attStats.attack or 10
    local defense = defStats.defense or 0
    local shieldDefense = CombatSystem._getShieldDefense(defender)

    -- Attack side: two exploding d8s
    local attackRoll = attack + MATH.rollExploding(8) + MATH.rollExploding(8)
    -- Defense side: defense stat plus shield bonus, two exploding d8s
    local defenseRoll = defense + shieldDefense + MATH.rollExploding(8) + MATH.rollExploding(8)
    local margin = attackRoll - defenseRoll

    return margin > 0, margin, shieldDefense
end

function CombatSystem.rollProjectileHitChance(defender)
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

-- Damage formula: effective skill baseDamage + strength/2 + rollExploding(6) - totalProtection - rollExploding(6)
-- Returns clamped to [0, math.inf), floored to integer.
function CombatSystem.calculateDamage(attacker, defender, skill)
    local MATH = require("src.utils.math")
    skill = CombatSystem.getEffectiveSkill(attacker, skill.id) or skill
    local weaponDamage = skill.baseDamage or 0

    -- Get damageType from skill or weapon, default to "blunt"
    local damageType = skill.damageType or "blunt"

    -- Strength contributes half its value to damage
    local strength = attacker.stats.strength or 0
    local strengthContribution = math.floor(strength / 2)

    -- Get total protection (from battle unit and equipment)
    local totalProtection = 0
    if defender.protections and defender.protections[damageType] then
        totalProtection = defender.protections[damageType]
    else
        totalProtection = CombatSystem.getTotalProtection(defender, damageType)
    end

    -- Calculate raw damage with two exploding d6s: one for attack variance, one for AC mitigation
    local rollToAttack = MATH.rollExploding(6)  -- Attacker's chance to wound
    local rollForAC = MATH.rollExploding(6)     -- Defender's armor class/DR die (damage mitigation)

    local damage = math.max(0, weaponDamage + strengthContribution + rollToAttack - totalProtection - rollForAC)

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
        local Items = require("src.data.items")
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

-- Effective skill = base skill overridden by the equipped weapon's skillModifiers.
function CombatSystem.getEffectiveSkill(unit, skillId)
    local Skills = require("src.data.skills")

    local baseSkill = Skills[skillId]
    if not baseSkill then return nil end

    -- Shallow copy the base skill
    local effectiveSkill = {}
    for k, v in pairs(baseSkill) do
        effectiveSkill[k] = v
    end

    local modifiers = CombatSystem._getSkillModifiers(unit, skillId)
    if modifiers then
        for k, v in pairs(modifiers) do
            effectiveSkill[k] = v  -- Override with the weapon's modifier
        end
    end

    return effectiveSkill
end

-- Skill modifiers from the weapon that grants the skill. Prefers mainHand, then
-- rangedWeapon, then any other equipped slot.
function CombatSystem._getSkillModifiers(unit, skillId)
    if not unit or not unit.equipment then return nil end
    local Items = require("src.data.items")

    for _, slot in ipairs({"mainHand", "rangedWeapon"}) do
        local itemId = unit.equipment[slot]
        if itemId then
            local item = Items[itemId]
            if item and item.grantsSkill == skillId and item.skillModifiers then
                return item.skillModifiers
            end
        end
    end

    for _, itemId in pairs(unit.equipment) do
        local item = Items[itemId]
        if item and item.grantsSkill == skillId and item.skillModifiers then
            return item.skillModifiers
        end
    end

    return nil
end

-- A miss is a "block" only when the target's shield was the deciding factor
-- (the attack would have hit without the shield's defense bonus); otherwise it
-- is an "evade". These are the only two defensive outcomes.
function CombatSystem._determineMissAction(hasShield, wouldHitWithoutShield)
    if hasShield and wouldHitWithoutShield then
        return "block"
    end
    return "evade"
end

-- Private function for battle context
function CombatSystem._applyBattleDamage(unit, damage)
    -- BattleUnit uses .hp, not .stats.health
    unit.hp = math.max(0, unit.hp - damage)
    return unit.hp <= 0
end

-- Apply durability loss when shield blocks an attack
function CombatSystem.applyBlockDurabilityLoss(defender)
    if not defender or not defender.equipment or not defender.equipment.offHand then
        return
    end
    
    local Items = require("src.data.items")
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
    local isHit, margin, shieldDefense = CombatSystem.rollAttack(attacker, defender, skill)

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

    -- MISS: block only when the shield was the deciding factor, else evade.
    local hasShield = shieldDefense > 0
    local wouldHitWithoutShield = (margin + shieldDefense) > 0
    local action = CombatSystem._determineMissAction(hasShield, wouldHitWithoutShield)

    if action == "block" then
        CombatSystem.applyBlockDurabilityLoss(defender)
    end

    if defender.visualEffects then
        defender.visualEffects.shakeTime = 0.5
    end

    return {hit = false, damage = 0, defeated = false, action = action}
end

function CombatSystem.resolveProjectileAttack(attacker, defender, skill)
    local hitChance = CombatSystem.rollProjectileHitChance(defender)
    local roll = math.random(100)

    if roll <= hitChance then
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

    -- Projectile misses are evades: the size-based hit roll never involves the
    -- shield's defense, so the shield can't be the deciding factor.
    if defender.visualEffects then
        defender.visualEffects.shakeTime = 0.5
    end

    return {hit = false, damage = 0, defeated = false, action = "evade"}
end

return CombatSystem
