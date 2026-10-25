-- Shared target pursuit for world activities.
local PartyAiSystem = require("src.systems.party_ai_system")

local Pursuit = {}

local function distanceBetween(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    return math.sqrt(dx * dx + dy * dy)
end

function Pursuit.update(party, target, activity, dt, map, speed, contactRadius, maxStallSeconds, options)
    options = options or {}
    local targetX = options.targetX
    local targetY = options.targetY
    if targetX == nil then targetX = target.x end
    if targetY == nil then targetY = target.y end
    local canContact = options.canContact ~= false
    local distance = distanceBetween(party.x, party.y, targetX, targetY)
    if canContact and distance <= contactRadius then
        return "contact"
    end

    PartyAiSystem.moveToward(party, targetX, targetY, speed, dt, map)

    local newDistance = distanceBetween(party.x, party.y, targetX, targetY)
    if canContact and newDistance <= contactRadius then
        return "contact"
    end

    if activity.lastDistance and newDistance >= activity.lastDistance - 0.1 then
        activity.stalledSeconds = activity.stalledSeconds + math.max(0, dt)
    else
        activity.stalledSeconds = 0
    end
    activity.lastDistance = newDistance

    if activity.stalledSeconds >= maxStallSeconds then
        return "failed", "pursuit_stalled"
    end

    return "pursuing"
end

return Pursuit
