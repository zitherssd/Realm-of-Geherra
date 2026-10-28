-- Acquisition and bounded communication at completed TravelActivity arrivals.
local EcsWorld = require("src.ecs.world")
local Events = require("src.systems.campaign.world_events")
local Knowledge = require("src.systems.knowledge.knowledge_system")
local LocationSystem = require("src.systems.locations.location_system")
local TimeSystem = require("src.systems.campaign.time_system")
local TravelKnowledge = {exchangeProbability = 0.5}

-- Injectable for deterministic scenarios; normal gameplay uses LÖVE's RNG.
function TravelKnowledge.random()
    return love.math.random()
end

local function livingActor(actor, world)
    return actor and actor.memory and (actor.hp or 0) > 0
        and EcsWorld.findActorById(actor.id, world) == actor
        and actor.__world == world
end

local function members(party)
    local result = {}
    for _, actor in ipairs(party.actors or {}) do
        if livingActor(actor, party.__world) then result[#result + 1] = actor end
    end
    return result
end

local function learnJourney(party, event)
    local details = Knowledge.getDetailCategories(event.id, party.__world)
    Knowledge.learn(party, event.id, details)
    for _, actor in ipairs(members(party)) do Knowledge.learn(actor, event.id, details) end
end

-- Counts only successful additions, including existence-only knowledge separately.
local function shareNew(source, target, stats)
    for _, event in ipairs(Knowledge.getKnownEvents(source)) do
        local known = Knowledge.getKnownDetails(target, event.id)
        local details = Knowledge.getKnownDetails(source, event.id)
        local added = 0
        for category in pairs(details) do
            if not known or not known[category] then added = added + 1 end
        end
        if (not known or added > 0) and Knowledge.share(source, target, event.id) then
            stats.eventsTransferred = stats.eventsTransferred + 1
            stats.detailsTransferred = stats.detailsTransferred + added
        end
    end
end

local function eventData(party, journey, map)
    return {
        time = {day = TimeSystem.getDay(), hour = TimeSystem.getHour()},
        mapId = map.id, x = party.x, y = party.y,
        partyId = party.id, partyName = party.name,
        originLocationId = journey.originLocationId,
        originLocationName = journey.originLocationName,
        destinationLocationId = journey.destinationLocationId,
        destinationLocationName = journey.destinationLocationName,
        subjectIds = {party.id, journey.destinationLocationId, journey.originLocationId}
    }
end

-- Capture before Map:addParty unstations the party; record only after it succeeds.
function TravelKnowledge.captureJourney(party, destination, map)
    local journey = {
        destinationLocationId = destination.id, destinationLocationName = destination.name
    }
    for _, location in ipairs(map:getLocations()) do
        for _, stationed in ipairs(location.stationedParties or {}) do
            if stationed == party then
                journey.originLocationId, journey.originLocationName = location.id, location.name
            end
        end
    end
    journey.meaningful = journey.originLocationId ~= destination.id
    return journey
end

function TravelKnowledge.depart(party, journey, map)
    if not journey.meaningful or not journey.originLocationId or journey.departureEventId then return end
    local data = eventData(party, journey, map)
    for key, value in pairs(party.caravanDeparture or {}) do data[key] = value end
    if data.sponsorId then
        data.subjectIds[#data.subjectIds + 1] = data.sponsorId
        data.subjectIds[#data.subjectIds + 1] = data.preparationId
    end
    local event = Events.record(party.__world, "party_departed", data)
    journey.departureEventId = event.id
    learnJourney(party, event)
    local sponsor = data.sponsorId and EcsWorld.findActorById(data.sponsorId, party.__world)
    if sponsor and sponsor.memory then
        Knowledge.learn(sponsor, event.id, Knowledge.getDetailCategories(event.id, party.__world), party.__world)
    end
end

local function exchange(party, destination, arrivalId)
    local stats = {arrivalEventId = arrivalId, locationId = destination.id,
        eligible = 0, participants = 0, eventsTransferred = 0, detailsTransferred = 0}
    local travelers, ownIds, unavailable = members(party), {}, {}
    for _, actor in ipairs(party.actors or {}) do ownIds[actor.id] = true end
    for _, other in ipairs(destination.stationedParties or {}) do
        if other.activeEncounterId then
            for _, actor in ipairs(other.actors or {}) do unavailable[actor.id] = true end
        end
    end
    -- A member may carry knowledge retained from a previous party.
    for _, actor in ipairs(travelers) do shareNew(actor, party, stats) end
    for _, npc in ipairs(LocationSystem.getAvailableNpcs(destination)) do
        if not ownIds[npc.id] and not unavailable[npc.id] and not npc.activeEncounterId
            and livingActor(npc, party.__world) then
            stats.eligible = stats.eligible + 1
            if TravelKnowledge.random() < TravelKnowledge.exchangeProbability then
                stats.participants = stats.participants + 1
                shareNew(party, npc, stats)
                shareNew(npc, party, stats)
            end
        end
    end
    for _, actor in ipairs(travelers) do shareNew(party, actor, stats) end
    party.lastArrivalExchange = stats
end

-- Only called after successful authoritative stationing. The journey guard also
-- prevents a repeated callback from rerolling conversation partners.
function TravelKnowledge.arrive(party, journey, destination, map)
    if not journey or not journey.meaningful or journey.arrivalEventId then return end
    if EcsWorld.findPartyById(party.id, party.__world) ~= party then return end
    local activity = party.world_activity
    if not activity or activity.status ~= "active" or activity.travelJourney ~= journey
        or activity.params.destinationLocationId ~= destination.id or party.activeEncounterId then return end
    local stationed = false
    for _, candidate in ipairs(destination.stationedParties or {}) do
        if candidate == party then stationed = true end
    end
    if not stationed then return end
    local data = eventData(party, journey, map)
    data.destinationLocationId, data.destinationLocationName = destination.id, destination.name
    local event = Events.record(party.__world, "party_arrived", data)
    journey.arrivalEventId = event.id
    learnJourney(party, event)
    exchange(party, destination, event.id)
end

return TravelKnowledge
