-- Generic party travel over the map's walkable terrain.
local EcsWorld = require("src.ecs.world")
local PartyAiSystem = require("src.systems.party_ai_system")
local PartyInteractionSystem = require("src.systems.party_interaction_system")

local Navigation = require("src.systems.world_navigation")
local TravelKnowledge = require("src.systems.travel_knowledge_system")

local TravelActivity = {}

TravelActivity.initialPhase = "travel"
TravelActivity.speed = 70
TravelActivity.maxStallSeconds = 15

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

local function distanceBetween(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    return math.sqrt(dx * dx + dy * dy)
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
    local waypoints, reason = Navigation.findPath(map, party.x, party.y, destination.x, destination.y)
    if not waypoints then return nil, reason end

    return {
        destinationLocationId = destination.id,
        journey = TravelKnowledge.captureJourney(party, destination, map),
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
    activity.travelJourney = prepared.journey
    party.state = "travel"
    TravelKnowledge.depart(party, activity.travelJourney, map)
    return true
end

function TravelActivity.update(party, activity, dt, map)
    if activity.status ~= "active" or dt <= 0 then return nil end
    if activity.travelJourney and activity.travelJourney.arrivalEventId then return "completed", "arrived" end
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
    if activity.waypointIndex >= #activity.waypoints
        and distance <= PartyInteractionSystem.interactionRadius then
        if not map:stationParty(destination, party) then
            return "failed", "arrival_stationing_failed"
        end
        TravelKnowledge.arrive(party, activity.travelJourney, destination, map)
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
    activity.travelJourney = nil
end

return TravelActivity
