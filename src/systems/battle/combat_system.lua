local Conditions = require("src.systems.actors.conditions")
local EffectiveStats = require("src.systems.actors.effective_stats")
-- systems/battle/combat_system.lua
-- Handle combat mechanics, damage, and attack resolution

local CombatSystem = {}
local Injury = require("src.systems.actors.injury_system")
-- Defense contributed by the equipped shield (offHand armor slot).
function CombatSystem._getShieldDefense(defender)
    if not defender or not defender.equipment or not defender.equipment.offHand then
        return 0
    end

    local Items = require("src.data.items")
    local item = Items[defender.equipment.offHand]
    if item and item.type == "armor" and item.slot == "offHand" and item.stats and item.stats.defense
        and (not defender.itemDurability or (defender.itemDurability[defender.equipment.offHand] or item.maxDurability or 1) > 0) then
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

    local attack = EffectiveStats.get(attacker, "attack", 10)
    local defense = EffectiveStats.get(defender, "defense")
    local shieldDefense = CombatSystem._getShieldDefense(defender)

    -- Attack side: two exploding d8s
    local attackRoll = attack + MATH.rollExploding(8) + MATH.rollExploding(8)
    -- Defense side: defense stat plus shield bonus, two exploding d8s
    local defenseRoll = defense + MATH.rollExploding(8) + MATH.rollExploding(8)
    local margin = attackRoll - defenseRoll

    return margin > 0, margin, shieldDefense
end

function CombatSystem.rollProjectileDefense(attacker, defender)
    local MATH = require("src.utils.math")
    local precision = EffectiveStats.get(attacker, "precision", 10)
    local shield = CombatSystem._getShieldDefense(defender)
    local attack = precision / 8 + MATH.rollExploding(8) + MATH.rollExploding(8)
    local defense = MATH.rollExploding(8) + MATH.rollExploding(8) + 2 * shield + EffectiveStats.get(defender, "projectileDefense")
    return attack > defense, attack - defense, shield
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
    local strength = EffectiveStats.get(attacker, "strength")
    local strengthContribution = math.floor(strength / 2)

    -- Get total protection (from battle unit and equipment)
    local totalProtection = EffectiveStats.protection(defender, damageType)

    -- Calculate raw damage with two exploding d6s: one for attack variance, one for AC mitigation
    local rollToAttack = MATH.rollExploding(6)  -- Attacker's chance to wound
    local rollForAC = MATH.rollExploding(6)     -- Defender's armor class/DR die (damage mitigation)

    local damage = math.max(0, weaponDamage + strengthContribution + rollToAttack - totalProtection - rollForAC)

    return CombatSystem.modifyDamage(attacker, defender, damage, damageType)
end

-- Ordinary calculation/protection -> outgoing -> incoming/typed resistance -> caps -> floor.
function CombatSystem.modifyDamage(attacker, defender, damage, kind)
    local outgoing = attacker and Conditions.effects(attacker) or {}
    local incoming = Conditions.effects(defender)
    damage = math.max(0, damage + (outgoing.outgoingDamage or 0)) * (outgoing.outgoingDamageMultiplier or 1)
    damage = math.max(0, damage + (incoming.incomingDamage or 0)) * (incoming.incomingDamageMultiplier or 1)
        * (incoming["incomingDamage_"..kind.."Multiplier"] or 1)
    local outMin,outMax = Conditions.damageLimits(attacker or {}, "outgoing")
    local inMin,inMax = Conditions.damageLimits(defender, "incoming")
    -- Upper caps win when independently authored minimum/maximum constraints conflict.
    return math.max(0, math.floor(math.min(math.max(damage,outMin,inMin),outMax,inMax)))
end

function CombatSystem.typedDamage(attacker, defender, amount, kind)
    return CombatSystem.modifyDamage(attacker,defender,
        math.max(0,amount-EffectiveStats.protection(defender,kind)),kind)
end

local function trigger(actor, event, other, skill, delivery)
    local context = actor.battleContext or (other and other.battleContext)
    local rng = context and context.data.conditionRng or math.random
    Conditions.trigger(actor,event,delivery,rng,function(reaction)
        local target = reaction.target == "self" and actor or other
        if not target or target.hp <= 0 then return end
        if (reaction.damage or 0) > 0 then
            local damage = CombatSystem.typedDamage(actor,target,reaction.damage,reaction.damageType or "blunt")
            CombatSystem._applyBattleDamage(target,damage,true,{reactive=true})
        end
        local ids = {}
        for id in pairs(reaction.apply or {}) do ids[#ids+1]=id end
        table.sort(ids)
        for _, id in ipairs(ids) do Conditions.apply(target,id,reaction.apply[id],skill and skill.id) end
    end)
end

local function finishAttack(attacker,defender,skill,result,hpLost,delivery)
    trigger(defender,"onAttackReceived",attacker,skill,delivery)
    if result.hit then
        trigger(defender,"onHitReceived",attacker,skill,delivery)
        if hpLost > 0 then trigger(defender,"onDamageReceived",attacker,skill,delivery) end
        trigger(attacker,"onHitDealt",defender,skill,delivery)
    end
    result.defeated = defender.hp <= 0
    return result
end

-- Calculate total protection for a damage type (innate + equipment)
function CombatSystem.getTotalProtection(defender, damageType)
    return defender and EffectiveStats.protection(defender, damageType or "blunt") or 0
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
            effectiveSkill[k] = v  -- Override with the item's modifier
        end
    end

    local troopType = unit and (unit.troopType or (unit.actor and unit.actor.troopType))
    local troopModifiers = troopType and require("src.data.troops")[troopType]
    troopModifiers = troopModifiers and troopModifiers.skillModifiers and troopModifiers.skillModifiers[skillId]
    if troopModifiers then
        for k, v in pairs(troopModifiers) do effectiveSkill[k] = v end
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
function CombatSystem._applyBattleDamage(unit, damage, isStatusDamage, options)
    options = options or {}
    -- BattleUnit uses .hp, not .stats.health
    if unit.escaped and not isStatusDamage then return false end
    local previousHp = unit.hp
    local morale = require("src.game.battle.morale")
    local powers = unit.battleContext and damage > 0 and morale.powers(unit.battleContext)
    unit.hp = math.max(0, unit.hp - damage)
    -- Status ticks are not individual damaging hits.
    if not isStatusDamage then Injury.fromDamage(unit, previousHp - unit.hp) end
    if unit.battleContext then
        morale.damage(unit.battleContext, unit, previousHp - unit.hp, powers)
    end
    if previousHp > unit.hp and not options.reactive and not options.deferEvents then
        trigger(unit,"onDamageReceived",options.attacker,options.skill,"periodic")
    end
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
        
        if defender.equipmentItems then defender.equipmentItems.offHand = nil end
    end
end

function CombatSystem.resolveAttack(attacker, defender, skill)
    if skill.healing then return CombatSystem.resolveAreaEffect(attacker, defender, skill) end
    local previousHp = defender.hp
    local isHit, margin, shieldDefense = CombatSystem.rollAttack(attacker, defender, skill)

    if isHit then
        local damage = CombatSystem.calculateDamage(attacker, defender, skill)
        local defeated = CombatSystem._applyBattleDamage(defender, damage, false, {deferEvents=true})

        -- Visual: Damage Flash (Red)
        if defender.visualEffects then
            defender.visualEffects.flashTime = 0.3
            defender.visualEffects.flashDuration = 0.3
            defender.visualEffects.flashColor = {0.5, 0, 0}
            defender.visualEffects.flashIntensity = 0.8
        end

        if skill.type == "melee" and not skill.aoe and not skill.projectile then Conditions.apply(defender, "harassed") end
        return finishAttack(attacker,defender,skill,{hit=true,damage=damage,defeated=defeated},previousHp-defender.hp,skill.type or "melee")
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

    if skill.type == "melee" and not skill.aoe and not skill.projectile then Conditions.apply(defender, "harassed") end
    return finishAttack(attacker,defender,skill,{hit=false,damage=0,defeated=false,action=action},0,skill.type or "melee")
end

-- Physical contact can be defended without delivering a projectile's area payload.
function CombatSystem.resolveProjectileContact(attacker, defender, skill, deferAttempt)
    local mode = skill and skill.projectile and skill.projectile.defenseMode or "opposed"
    assert(mode == "none" or mode == "opposed", "Unknown projectile defense mode: "..tostring(mode))
    if mode == "none" then return {hit = true} end
    local hit, margin, shield = CombatSystem.rollProjectileDefense(attacker, defender)
    if hit then return {hit = true} end

    local action = CombatSystem._determineMissAction(shield > 0, margin + 2 * shield > 0)
    if action == "block" then CombatSystem.applyBlockDurabilityLoss(defender) end
    if defender.visualEffects then defender.visualEffects.shakeTime = 0.5 end
    local result = {hit=false,damage=0,defeated=false,action=action}
    if not deferAttempt then return finishAttack(attacker,defender,skill,result,0,"projectile") end
    return result
end

function CombatSystem.resolveProjectileAttack(attacker, defender, skill)
    local previousHp = defender.hp
    local result = CombatSystem.resolveProjectileContact(attacker, defender, skill, true)
    if result.hit then
        local damage = CombatSystem.calculateDamage(attacker, defender, skill)
        local defeated = CombatSystem._applyBattleDamage(defender, damage, false, {deferEvents=true})

        if defender.visualEffects then
            defender.visualEffects.flashTime = 0.3
            defender.visualEffects.flashDuration = 0.3
            defender.visualEffects.flashColor = {0.5, 0, 0}
            defender.visualEffects.flashIntensity = 0.8
        end

        return finishAttack(attacker,defender,skill,{hit=true,damage=damage,defeated=defeated},previousHp-defender.hp,"projectile")
    end

    return finishAttack(attacker,defender,skill,result,0,"projectile")
end

-- Area contact is guaranteed; protection, injuries and morale use normal damage.
function CombatSystem.resolveAreaEffect(attacker, defender, skill)
    local previousHp = defender.hp
    local damage, defeated, hpLost = 0, false, 0
    if skill.baseDamage then
        damage = CombatSystem.calculateDamage(attacker, defender, skill)
        defeated = CombatSystem._applyBattleDamage(defender, damage, false, {deferEvents=true})
        hpLost = previousHp-defender.hp
        if defender.visualEffects then
            defender.visualEffects.flashTime = 0.3
            defender.visualEffects.flashDuration = 0.3
            defender.visualEffects.flashColor = {0.5, 0, 0}
            defender.visualEffects.flashIntensity = 0.8
        end
    end
    local healed = 0
    if skill.healing and not defeated then
        healed = math.max(0, math.min(skill.healing, defender.maxHp-defender.hp))
        defender.hp = defender.hp+healed
    end
    local result = {hit=true,damage=damage,healed=healed,defeated=defeated}
    if skill.baseDamage or not skill.healing then return finishAttack(attacker,defender,skill,result,hpLost,"aoe") end
    return result
end

return CombatSystem
