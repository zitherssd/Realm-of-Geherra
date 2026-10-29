-- Pure reads: calculation never starts work or duplicates authoritative state.
local Recovery = require("src.systems.actors.recovery")
local Parties = require("src.systems.parties.party_system")
local Knowledge = require("src.systems.knowledge.knowledge_system")
local Personality = require("src.data.types.personality")
local Ecs = require("src.ecs.world")
local Injury = require("src.systems.actors.injury_system")
local Importance = {criticalWeight = 0.5, wealthExponentBase = 2, wealthExponentGreed = 1.75,
    homeAwayPerDay = 5, homeRecoveryPerDay = 12}

function Importance.home(actor, map)
    local home = actor.homeLocationId and Ecs.findLocationById(actor.homeLocationId, actor.__world)
    for _, location in ipairs(map and map:getLocations() or {}) do
        if location == home then
            local Services = require("src.systems.services.service_system")
            return home, Services.getLocation(actor, {world = actor.__world, map = map}) == home
        end
    end
    return nil, false
end

-- Rates are points per game day, converted using the existing world clock.
function Importance.homeRate(actor, map)
    local home, atHome = Importance.home(actor, map)
    if not home then return 0 end
    local daySeconds = require("src.systems.campaign.time_system").worldHoursToSeconds(24)
    return (atHome and -Importance.homeRecoveryPerDay
        or Importance.homeAwayPerDay * Personality.get(actor, "homesickness")) / daySeconds
end

function Importance.advanceHome(goal, actor, _, dt, map)
    goal.accumulatedImportance = Importance.clamp((goal.accumulatedImportance or 0) + Importance.homeRate(actor, map) * dt)
end

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
function Importance.recoveryHealth(goal, actor, party)
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
function Importance.recovery(goal, actor, party)
    local urgency = Recovery.isLiving(actor) and Injury.importance(actor) or 0
    if party and Parties.getLeader(party) == actor then
        local total, count = 0, 0
        for _, member in ipairs(party.actors or {}) do
            if Recovery.isLiving(member) then
                total, count = total + Injury.importance(member), count + 1
            end
        end
        if count > 0 then urgency = math.max(urgency, total / count) end
    end
    return Importance.clamp(Importance.recoveryHealth(goal, actor, party) + urgency)
end
function Importance.wealth(goal, actor, party)
    local target = goal.amount or 10000
    if type(target) ~= "number" or target ~= target or math.abs(target) == math.huge or target <= 0 then return 0 end
    local treasury = party and Parties.getLeader(party) == actor and Parties.getTreasury(party) or actor.treasury or 0
    local remaining = math.max(0, 1 - treasury / target)
    return Importance.clamp(100 * remaining ^ (Importance.wealthExponentBase
        - Importance.wealthExponentGreed * Personality.get(actor, "greed")))
end
function Importance.knowledge(goal, actor)
    if Knowledge.findKnownInformation(actor, goal) then return 0 end
    return goal.priority
end
function Importance.obligation(goal, actor)
    local request = actor.__world and actor.__world.serviceRequests and actor.__world.serviceRequests[goal.serviceId]
    if goal.resolvedStatus or not request or request.status ~= "assigned"
        or request.assignedActorId ~= actor.id then return 0 end
    return 50 + 40 * Personality.get(actor, "responsibility")
end
return Importance
