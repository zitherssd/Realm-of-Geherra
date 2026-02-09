-- systems/reputation_system.lua
-- Handle reputation tracking and effects

local ReputationSystem = {}

function ReputationSystem.addReputation(actor, source, amount)
    if not actor.reputation then
        actor.reputation = {}
    end
    actor.reputation[source] = (actor.reputation[source] or 0) + amount
end

function ReputationSystem.getReputation(actor, source)
    if not actor.reputation then return 0 end
    return actor.reputation[source] or 0
end

function ReputationSystem.getOverallReputation(actor)
    if not actor.reputation then return 0 end
    
    local total = 0
    for _, rep in pairs(actor.reputation) do
        total = total + rep
    end
    
    return total
end

return ReputationSystem
