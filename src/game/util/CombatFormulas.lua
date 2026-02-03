local CombatFormulas = {
    
}

function CombatFormulas:calculateHitChance(attacker, defender)
    if defender.defense <= 0 then return 95 end
    local ratio = attacker.attack / defender.defense
    local hitChance = 50 + (ratio - 1) * 35
    return math.max(5, math.min(hitChance,95))
end

function CombatFormulas:calculateDamage(attacker, defender)
    local raw = attacker.strength
    local prot = defender.protection or 0

    -- base damage from ratio formula
    local multiplier = raw / (raw + prot)
    local damage = raw * multiplier

    -- apply ±20% random variance
    local variance = 0.2 -- 20%
    local minVar = 1 - variance
    local maxVar = 1 + variance
    local roll = love.math.random() * (maxVar - minVar) + minVar
    damage = damage * roll

    -- round and clamp to at least 1
    damage = math.max(1, math.floor(damage + 0.5))

    return damage
end

return CombatFormulas