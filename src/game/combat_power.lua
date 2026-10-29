local EffectiveStats = require("src.systems.actors.effective_stats")
-- Shared campaign/battle estimate; accepts ordinary actor tables without an ECS world.
local Items = require("src.data.items")
local Combat = require("src.systems.battle.combat_system")
local CombatPower = {}

function CombatPower.unit(actor)
    if not actor or actor.fleeing or actor.escaped then return 0 end
    local stats, skills = {}, {}
    for key, value in pairs(actor.stats or {}) do stats[key] = value end
    for id, value in pairs(actor.skills or {}) do skills[id] = value end
    -- Battle wrappers already include equipment stats and granted skills.
    if not actor.actor then
        for _, itemId in pairs(actor.equipment or {}) do
            local item = Items[itemId]
            if item then
                for key, value in pairs(item.stats or {}) do stats[key] = (stats[key] or 0) + value end
                if item.grantsSkill then skills[item.grantsSkill] = true end
            end
        end
    end
    local hp = actor.hp or actor.maxHp or stats.health or 100
    if hp <= 0 then return 0 end
    local best, alternative, seen = 0, 0, {}
    for id, enabled in pairs(skills) do
        local skill = enabled and Combat.getEffectiveSkill(actor, id)
        local damage = skill and skill.baseDamage or 0
        if damage > 0 and skill.type ~= "command" and not skill.healing and
            (not skill.maxCharges or (actor.charges and actor.charges[id] or skill.maxCharges) > 0) then
            -- Supply variants of the same attack count once; range/cooldown/AoE add no power.
            local key = table.concat({skill.type or "", skill.damageType or "blunt", damage}, ":")
            if not seen[key] then
                seen[key] = true
                if damage > best then alternative, best = best, damage
                elseif damage > alternative then alternative = damage end
            end
        end
    end
    if best == 0 then return 0 end
    local protection = 0
    -- Mean physical protection represents armor without adding damage-type values together.
    for _, kind in ipairs({"slashing", "piercing", "blunt"}) do
        protection = protection + (EffectiveStats.protection(actor, kind)) / 3
    end
    local attack = EffectiveStats.get(actor, "attack", 10)
    local defense = EffectiveStats.get(actor, "defense")
    return hp / 20 * (attack + defense + EffectiveStats.get(actor, "strength") / 2 +
        best + 0.25 * alternative + protection / 2) / 30
end

function CombatPower.party(party)
    local power = 0
    for _, actor in ipairs(party.actors or party.members or party) do
        power = power + CombatPower.unit(actor)
    end
    return power
end

return CombatPower
