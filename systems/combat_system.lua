-- systems/combat_system.lua
-- Handle combat mechanics, damage, and attack resolution

local CombatSystem = {}

function CombatSystem.calculateDamage(attacker, defender, skill)
    -- Calculate damage based on attacker stats, defender armor, and skill
    local baseDamage = (attacker.stats.strength or 10) * (skill.damageMultiplier or 1.0)
    local defense = (defender.stats.defense or 5)
    local finalDamage = math.max(1, baseDamage - defense / 2)
    return finalDamage
end

function CombatSystem.applyDamage(actor, damage)
    actor.stats.health = (actor.stats.health or 100) - damage
    if actor.stats.health <= 0 then
        -- Actor is defeated
        return true
    end
    return false
end

function CombatSystem.resolveAttack(attacker, defender, skill)
    local damage = CombatSystem.calculateDamage(attacker, defender, skill)
    local defeated = CombatSystem.applyDamage(defender, damage)
    return {damage = damage, defeated = defeated}
end

return CombatSystem
