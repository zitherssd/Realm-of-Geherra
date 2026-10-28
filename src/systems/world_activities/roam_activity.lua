local PartySystem = require("src.systems.parties.party_system")
-- Generic bounded wandering. All retained state is primitive data or waypoints.
local EcsWorld = require("src.ecs.world")
local Navigation = require("src.world.world_navigation")
local Movement = require("src.systems.parties.party_ai_system")

local Roam = {initialPhase = "roam", speed = PartySystem.worldSpeed, maxAttempts = 12, maxStallSeconds = 15}

local function finite(n)
    return type(n) == "number" and n == n and math.abs(n) < math.huge
end

local function inside(x, y, ox, oy, radius)
    return (x - ox)^2 + (y - oy)^2 <= radius^2 + 0.000001
end

local function originLocation(map, id, world)
    local location = map:getLocationById(id)
    if location and location.__world == world and EcsWorld.findLocationById(id, world) == location then
        return location
    end
end

local function selectPath(party, map, ox, oy, radius)
    local minimumDistance = math.min(16, radius / 4)
    for _ = 1, Roam.maxAttempts do
        local angle, distance = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
        local x, y = ox + math.cos(angle) * distance, oy + math.sin(angle) * distance
        if (x - party.x)^2 + (y - party.y)^2 >= minimumDistance^2 then
            local path = Navigation.findPath(map, party.x, party.y, x, y)
            if path then
                local contained = true
                -- A circle is convex: segments between contained waypoints stay inside.
                -- Reject terrain detours outside the area without changing generic A*.
                for _, point in ipairs(path) do
                    if not inside(point.x, point.y, ox, oy, radius) then contained = false; break end
                end
                if contained then return path end
            end
        end
    end
    return nil, "no_roaming_destination"
end

function Roam.prepare(party, params, map)
    if EcsWorld.findPartyById(party.id, party.__world) ~= party then return nil, "party_missing" end
    if not map then return nil, "map_unavailable" end
    if not finite(params.radius) or params.radius <= 0 then return nil, "invalid_radius" end
    if params.durationSeconds ~= nil and (not finite(params.durationSeconds) or params.durationSeconds <= 0) then
        return nil, "invalid_duration"
    end
    local ox, oy = params.originX, params.originY
    if params.originLocationId ~= nil then
        if ox ~= nil or oy ~= nil then return nil, "ambiguous_origin" end
        local location = originLocation(map, params.originLocationId, party.__world)
        if not location then return nil, "origin_missing" end
        ox, oy = location.x, location.y
    end
    if not finite(ox) or not finite(oy) then return nil, "invalid_origin" end
    if not inside(party.x, party.y, ox, oy, params.radius) then return nil, "party_outside_roaming_area" end
    local path, reason = selectPath(party, map, ox, oy, params.radius)
    if not path then return nil, reason end
    return {originX = ox, originY = oy, waypoints = path}
end

function Roam.onStart(party, activity, prepared, map)
    local present = false
    for _, existing in ipairs(map:getParties()) do
        if existing == party then present = true; break end
    end
    if not present and not map:addParty(party) then return false, "party_cannot_depart" end
    activity.roamOriginX, activity.roamOriginY = prepared.originX, prepared.originY
    activity.elapsedSeconds = 0
    activity.waypoints, activity.waypointIndex = prepared.waypoints, 1
    activity.previousPartyState = party.state
    party.state = "roam"
    return true
end

function Roam.update(party, activity, dt, map)
    if EcsWorld.findPartyById(party.id, party.__world) ~= party then
        map:removeParty(party.id)
        return "failed", "party_removed"
    end
    local params = activity.params
    if params.originLocationId ~= nil then
        local location = originLocation(map, params.originLocationId, party.__world)
        if not location then return "failed", "origin_missing" end
        if location.x ~= activity.roamOriginX or location.y ~= activity.roamOriginY then
            return "failed", "origin_moved"
        end
    end
    if not inside(party.x, party.y, activity.roamOriginX, activity.roamOriginY, params.radius) then
        return "failed", "party_outside_roaming_area"
    end
    local step = math.max(0, dt)
    if params.durationSeconds then step = math.min(step, params.durationSeconds - activity.elapsedSeconds) end
    if activity.waypointIndex > #activity.waypoints then
        local path, reason = selectPath(party, map, activity.roamOriginX, activity.roamOriginY, params.radius)
        if not path then return "failed", reason end
        activity.waypoints, activity.waypointIndex = path, 1
    end
    local x, y = party.x, party.y
    activity.waypointIndex = Movement.followWaypoints(party, activity.waypoints,
        activity.waypointIndex, Roam.speed, step, map)
    activity.elapsedSeconds = activity.elapsedSeconds + step
    if params.durationSeconds and activity.elapsedSeconds >= params.durationSeconds then
        return "completed", "duration_elapsed"
    end
    if activity.waypointIndex <= #activity.waypoints and (party.x - x)^2 + (party.y - y)^2 < 0.000000000001 then
        activity.stalledSeconds = activity.stalledSeconds + step
    else
        activity.stalledSeconds = 0
    end
    if activity.stalledSeconds >= Roam.maxStallSeconds then return "failed", "route_stalled" end
end

function Roam.onTerminal(party, activity)
    party.state = activity.previousPartyState or "idle"
    activity.roamOriginX, activity.roamOriginY, activity.elapsedSeconds = nil, nil, nil
    activity.waypoints, activity.waypointIndex, activity.previousPartyState = nil, nil, nil
    activity.stalledSeconds = 0
end

return Roam
