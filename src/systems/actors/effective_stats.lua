local Conditions = require("src.systems.actors.conditions")
local Items = require("src.data.items")
local Stats = {}

function Stats.get(actor, stat, fallback)
    local base = (actor.stats or {})[stat] or (stat == "sight" and actor.sight) or fallback or 0
    -- Battle wrappers already contain equipment bonuses.
    if not actor.actor then
        for _, id in pairs(actor.equipment or {}) do base = base + (((Items[id] or {}).stats or {})[stat] or 0) end
    end
    return Conditions.modify(actor, stat, base)
end

function Stats.protection(actor, kind)
    local base = (actor.protections or actor.innateProtections or {})[kind] or 0
    if not actor.protections then
        for _, id in pairs(actor.equipment or {}) do base = base + (((Items[id] or {}).protections or {})[kind] or 0) end
    end
    return Conditions.modify(actor, "protection_" .. kind, base)
end
return Stats

