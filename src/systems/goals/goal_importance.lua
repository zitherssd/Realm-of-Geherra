-- Pure reads: calculation never starts work or duplicates authoritative state.
local Recovery = require("src.systems.actors.recovery")
local Parties = require("src.systems.parties.party_system")
local Knowledge = require("src.systems.knowledge.knowledge_system")
local Importance = {criticalWeight = 0.5, responsibilityDefault = 0.5}

function Importance.clamp(value)
    if type(value) ~= "number" or value ~= value then return 0 end
    return math.max(0, math.min(100, value))
end

-- Remaining HP / urgency. Data points are balancing configuration.
Importance.healthCurve = {{0, 100}, {0.2, 95}, {0.4, 80}, {0.5, 60}, {0.8, 15}, {1, 0}}
function Importance.health(ratio)
    ratio = math.max(0, math.min(1, ratio))
    if ratio == 1 then return 0 end
    for index = 2, #Importance.healthCurve do
        local left, right = Importance.healthCurve[index - 1], Importance.healthCurve[index]
        if ratio <= right[1] then
            return left[2] + (right[2] - left[2]) * (ratio - left[1]) / (right[1] - left[1])
        end
    end
    return 0
end
local function healthRatio(actor)
    local maximum = Recovery.maxHealth(actor)
    return maximum > 0 and math.max(0, math.min(1, (actor.hp or maximum) / maximum)) or 1
end
function Importance.recovery(goal, actor, party)
    local personal = Importance.health(healthRatio(actor))
    if not party or Parties.getLeader(party) ~= actor then return personal end
    local total, count, worst = 0, 0, 1
    for _, member in ipairs(party.actors or {}) do
        if Recovery.isLiving(member) then
            local ratio = healthRatio(member)
            total, count, worst = total + ratio, count + 1, math.min(worst, ratio)
        end
    end
    if count == 0 then return personal end
    local average = Importance.health(total / count)
    -- Only HP below 30% adds critical urgency; party size never multiplies it.
    local critical = 100 * math.max(0, (0.3 - worst) / 0.3)
    return math.max(personal, average + (100 - average) * Importance.criticalWeight * critical / 100)
end
function Importance.wealth(goal, actor, party)
    local target = goal.amount or 10000
    if type(target) ~= "number" or target <= 0 then return 0 end
    return 100 * (1 - (party and Parties.getTreasury(party) or actor.treasury or 0) / target)
end
function Importance.knowledge(goal, actor)
    if Knowledge.findKnownInformation(actor, goal) then return 0 end
    return goal.priority
end
function Importance.obligation(goal, actor)
    local request = actor.__world and actor.__world.serviceRequests and actor.__world.serviceRequests[goal.serviceId]
    if goal.resolvedStatus or not request or request.status ~= "assigned"
        or request.assignedActorId ~= actor.id then return 0 end
    local responsibility = actor.responsibility
    if type(responsibility) ~= "number" or responsibility ~= responsibility then responsibility = Importance.responsibilityDefault end
    return 50 + 40 * math.max(0, math.min(1, responsibility))
end
return Importance
