-- systems/faction_system.lua
-- Handle faction relationships and allegiances

local FactionSystem = {}

function FactionSystem.setReputation(actor, factionId, reputation)
    if not actor.factions then
        actor.factions = {}
    end
    actor.factions[factionId] = reputation
end

function FactionSystem.modifyReputation(actor, factionId, delta)
    if not actor.factions then
        actor.factions = {}
    end
    actor.factions[factionId] = (actor.factions[factionId] or 0) + delta
end

function FactionSystem.getReputation(actor, factionId)
    if not actor.factions then return 0 end
    return actor.factions[factionId] or 0
end

function FactionSystem.getFactionStanding(actor, factionId)
    local rep = FactionSystem.getReputation(actor, factionId)
    if rep >= 100 then return "ally"
    elseif rep >= 50 then return "friend"
    elseif rep >= 0 then return "neutral"
    elseif rep >= -50 then return "rival"
    else return "enemy" end
end

return FactionSystem
