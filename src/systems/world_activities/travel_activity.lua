-- Generic party travel along the map's road network.
local EcsWorld = require("src.ecs.world")
local PartyAiSystem = require("src.systems.party_ai_system")
local PartyInteractionSystem = require("src.systems.party_interaction_system")

local TravelActivity = {}

TravelActivity.initialPhase = "travel"
TravelActivity.speed = 70
TravelActivity.maxStallSeconds = 15

local function sameEntity(left, right)
    return left == right or (left and right and left.id ~= nil and left.id == right.id)
end

local function findParty(map, partyId)
    for _, party in ipairs(map:getParties() or {}) do
        if party.id == partyId then return party end
    end
    return nil
end

local function findMapLocation(map, locationId)
    local location = map.getLocationById and map:getLocationById(locationId)
    if not location or not location.__world then return nil end

    local campaignLocation = EcsWorld.findLocationById(locationId, location.__world)
    if campaignLocation == location then return location end
    return nil
end

local function buildRoadGraph(map)
    local graph = {}
    for _, road in ipairs((map.worldGen and map.worldGen.roads) or {}) do
        graph[road.from] = graph[road.from] or {}
        table.insert(graph[road.from], {
            to = road.to,
            points = road.points,
            forward = true
        })

        graph[road.to] = graph[road.to] or {}
        table.insert(graph[road.to], {
            to = road.from,
            points = road.points,
            forward = false
        })
    end
    return graph
end

local function roadGraph(map)
    if not map.worldGen then return {} end
    if not map.worldGen._roadGraph then
        map.worldGen._roadGraph = buildRoadGraph(map)
    end
    return map.worldGen._roadGraph
end

local function findRoadPath(map, fromLocation, toLocation)
    local graph = roadGraph(map)
    local startId, goalId = fromLocation.siteId, toLocation.siteId
    if not startId or not goalId then return nil end
    if startId == goalId then return {} end

    local visited = {[startId] = true}
    local queue = {{id = startId, edges = {}}}
    local head = 1

    while head <= #queue do
        local current = queue[head]
        head = head + 1

        if current.id == goalId then
            local waypoints = {}
            for _, edge in ipairs(current.edges) do
                if edge.forward then
                    for _, point in ipairs(edge.points) do
                        table.insert(waypoints, {x = point.x, y = point.y})
                    end
                else
                    for index = #edge.points, 1, -1 do
                        local point = edge.points[index]
                        table.insert(waypoints, {x = point.x, y = point.y})
                    end
                end
            end
            return waypoints
        end

        for _, edge in ipairs(graph[current.id] or {}) do
            if not visited[edge.to] then
                visited[edge.to] = true
                local edges = {}
                for _, previous in ipairs(current.edges) do
                    table.insert(edges, previous)
                end
                table.insert(edges, edge)
                table.insert(queue, {id = edge.to, edges = edges})
            end
        end
    end

    return nil
end

local function distanceBetween(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    return math.sqrt(dx * dx + dy * dy)
end

local function findOriginLocation(map, party)
    for _, location in ipairs(map:getLocations() or {}) do
        for _, stationedParty in ipairs(location.stationedParties or {}) do
            if sameEntity(stationedParty, party) then
                return location
            end
        end
    end

    local nearestLocation, nearestDistance
    for _, location in ipairs(map:getLocations() or {}) do
        if location.siteId then
            local distance = distanceBetween(party.x, party.y, location.x, location.y)
            if not nearestDistance or distance < nearestDistance then
                nearestLocation, nearestDistance = location, distance
            end
        end
    end
    return nearestLocation
end

local function appendWaypoint(waypoints, x, y)
    local last = waypoints[#waypoints]
    if not last or distanceBetween(last.x, last.y, x, y) > 1 then
        table.insert(waypoints, {x = x, y = y})
    end
end

function TravelActivity.prepare(party, params, map)
    if EcsWorld.findPartyById(party.id, party.__world) ~= party then
        return nil, "party_missing"
    end
    if type(params.destinationLocationId) ~= "string"
        and type(params.destinationLocationId) ~= "number" then
        return nil, "invalid_destination_id"
    end
    if not map or type(map.getLocations) ~= "function"
        or type(map.getParties) ~= "function" then
        return nil, "map_unavailable"
    end

    local destination = findMapLocation(map, params.destinationLocationId)
    if not destination then
        return nil, "destination_missing"
    end
    if destination.__world ~= party.__world then
        return nil, "campaign_mismatch"
    end
    if not map.worldGen or type(map.worldGen.roads) ~= "table" then
        return nil, "route_unavailable"
    end

    local origin = findOriginLocation(map, party)
    if not origin then return nil, "origin_missing" end
    if origin.__world ~= party.__world then
        return nil, "campaign_mismatch"
    end
    local roadWaypoints = findRoadPath(map, origin, destination)
    if not roadWaypoints then return nil, "route_unavailable" end

    local waypoints = {}
    if origin ~= destination then
        appendWaypoint(waypoints, origin.x, origin.y)
        for _, point in ipairs(roadWaypoints) do
            appendWaypoint(waypoints, point.x, point.y)
        end
    end
    appendWaypoint(waypoints, destination.x, destination.y)

    return {
        destinationLocationId = destination.id,
        waypoints = waypoints
    }
end

function TravelActivity.onStart(party, activity, prepared, map)
    if not findParty(map, party.id) and not map:addParty(party) then
        return false, "party_cannot_depart"
    end

    activity.waypoints = prepared.waypoints
    activity.waypointIndex = 1
    activity.stalledSeconds = 0
    activity.lastDistance = nil
    activity.previousPartyState = party.state
    party.state = "travel"
    return true
end

function TravelActivity.update(party, activity, dt, map)
    local destination = findMapLocation(map, activity.params.destinationLocationId)
    if not destination then
        return "failed", "destination_missing"
    end
    if EcsWorld.findPartyById(party.id, party.__world) ~= party then
        map:removeParty(party.id)
        return "failed", "party_removed"
    end
    if findParty(map, party.id) ~= party then
        return "failed", "party_missing"
    end
    if not activity.waypoints or #activity.waypoints == 0 then
        return "failed", "route_unavailable"
    end

    local distance = distanceBetween(party.x, party.y, destination.x, destination.y)
    if distance <= PartyInteractionSystem.interactionRadius then
        if not map:stationParty(destination, party) then
            return "failed", "arrival_stationing_failed"
        end
        return "completed", "arrived"
    end

    local previousX, previousY = party.x, party.y
    activity.waypointIndex = PartyAiSystem.followWaypoints(
        party,
        activity.waypoints,
        activity.waypointIndex,
        TravelActivity.speed,
        dt,
        map
    )

    local moved = distanceBetween(previousX, previousY, party.x, party.y)
    if moved <= 0.1 then
        activity.stalledSeconds = (activity.stalledSeconds or 0) + math.max(0, dt)
    else
        activity.stalledSeconds = 0
    end
    if activity.stalledSeconds >= TravelActivity.maxStallSeconds then
        return "failed", "route_stalled"
    end

    return nil
end

function TravelActivity.onTerminal(party, activity, status)
    if status == "completed" then
        party.state = "idle"
    else
        party.state = activity.previousPartyState or "idle"
    end
    activity.waypoints = nil
    activity.waypointIndex = nil
    activity.previousPartyState = nil
    activity.stalledSeconds = 0
    activity.lastDistance = nil
end

return TravelActivity
