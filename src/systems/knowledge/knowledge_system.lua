-- Explicit historical knowledge only. Never observes events or current resources.
local Events = require("src.systems.campaign.world_events")
local EcsWorld = require("src.ecs.world")
local Knowledge = {}

local function historicalId(value)
    if type(value) == "string" or type(value) == "number" then return value end
end

local function idList(values)
    local result = {}
    for _, value in ipairs(type(values) == "table" and values or {}) do
        local id = historicalId(value)
        if id ~= nil then result[#result + 1] = id end
    end
    return result
end

-- Small event-specific projections, deliberately allowlisting nested fields too.
-- Add future event types here; unknown types support existence knowledge only.
local projections = {
    battle_ended = {
        time = function(view, event)
            view.time = {day = event.time.day, hour = event.time.hour}
        end,
        location = function(view, event)
            if type(event.x) == "number" then view.x = event.x end
            if type(event.y) == "number" then view.y = event.y end
            view.battlefieldId = historicalId(event.battlefieldId)
        end,
        participants = function(view, event)
            view.participants = {}
            for _, participant in ipairs(event.participants or {}) do
                view.participants[#view.participants + 1] = {
                    partyId = historicalId(participant.partyId),
                    name = type(participant.name) == "string" and participant.name or nil,
                    actorIds = idList(participant.actorIds)
                }
            end
        end,
        outcome = function(view, event)
            view.outcome = type(event.outcome) == "string" and event.outcome or nil
            view.winnerPartyId = historicalId(event.winnerPartyId)
            view.defeatedPartyIds = idList(event.defeatedPartyIds)
            view.eliminatedPartyIds = idList(event.eliminatedPartyIds)
            view.casualties = {}
            -- Keep casualties separate so knowing identities alone reveals no losses.
            for _, participant in ipairs(event.participants or {}) do
                local id = historicalId(participant.partyId)
                if id ~= nil and type(participant.casualties) == "number" then
                    view.casualties[id] = participant.casualties
                end
            end
        end
    }
}

local function travelTime(view, event)
    view.time = {day = event.time.day, hour = event.time.hour}
end

local function travelParty(view, event)
    view.partyId = historicalId(event.partyId)
    view.partyName = type(event.partyName) == "string" and event.partyName or nil
end

local function travelLocation(view, event)
    if type(event.x) == "number" then view.x = event.x end
    if type(event.y) == "number" then view.y = event.y end
    view.originLocationId = historicalId(event.originLocationId)
    view.originLocationName = type(event.originLocationName) == "string" and event.originLocationName or nil
end

local function travelDestination(view, event)
    view.destinationLocationId = historicalId(event.destinationLocationId)
    view.destinationLocationName = type(event.destinationLocationName) == "string"
        and event.destinationLocationName or nil
end

projections.party_departed = {
    time = travelTime, party = travelParty, location = travelLocation, destination = travelDestination,
    sponsorship = function(view, event)
        view.sponsorId = historicalId(event.sponsorId)
        view.sponsorName = type(event.sponsorName) == "string" and event.sponsorName or nil
        view.expectedReturnAt = type(event.expectedReturnAt) == "number" and event.expectedReturnAt or nil
        view.departureAt = type(event.departureAt) == "number" and event.departureAt or nil
        view.preparationId = historicalId(event.preparationId)
    end
}
projections.caravan_traded = {
    time = travelTime, party = travelParty,
    trade = function(view, event) view.profit, view.locationId = event.profit, historicalId(event.locationId) end
}
projections.party_arrived = {
    time = travelTime, party = travelParty,
    location = function(view, event)
        travelLocation(view, event)
        travelDestination(view, event)
    end
}

-- Each category discloses only its own fields; existence alone cannot reveal a job.
for _, eventType in ipairs({"service_offered", "service_filled", "service_cancelled", "service_completed"}) do
    projections[eventType] = {
        time = travelTime,
        location = function(view, event)
            view.locationId = historicalId(event.locationId)
            view.locationName = type(event.locationName) == "string" and event.locationName or nil
        end,
        employer = function(view, event)
            view.employerId = historicalId(event.employerId)
            view.employerName = type(event.employerName) == "string" and event.employerName or nil
        end,
        service = function(view, event)
            view.serviceId = historicalId(event.serviceId)
            view.serviceType = type(event.serviceType) == "string" and event.serviceType or nil
            view.requiredCapability = type(event.requiredCapability) == "string" and event.requiredCapability or nil
        end,
        outcome = function(view, event)
            view.status = type(event.status) == "string" and event.status or nil
            view.assignedActorId = historicalId(event.assignedActorId)
            view.workerName = type(event.workerName) == "string" and event.workerName or nil
        end
    }
end

local function memoryFor(owner, world)
    world = world or (owner and owner.__world)
    if not owner or not world or owner.__world ~= world or not (owner.unit or owner.party)
        or EcsWorld.findEntityById(owner.id, nil, world) ~= owner then
        return nil, nil, "Owner is not a live member of this campaign."
    end
    if not owner.memory then return nil, nil, "Owner has no memory component." end
    if owner.memory.__entity ~= owner or not owner.memory:isForWorld(world) then
        return nil, nil, "Memory belongs to another owner or campaign."
    end
    return owner.memory, world
end

function Knowledge.getDetailCategories(eventId, world)
    local event = type(eventId) == "string" and Events.get(world, eventId)
    local result = {}
    for category in pairs(event and projections[event.type] or {}) do result[#result + 1] = category end
    table.sort(result)
    return result
end

function Knowledge.learn(owner, eventId, details, world)
    local memory, campaign, err = memoryFor(owner, world)
    if not memory then return false, err end
    local event = type(eventId) == "string" and Events.get(campaign, eventId)
    if not event then return false, "Unknown event in this campaign." end
    if details ~= nil and type(details) ~= "table" then return false, "Expected detail names or flags." end
    local allowed, learned = projections[event.type] or {}, {}
    for key, value in pairs(details or {}) do
        local category = type(key) == "number" and value or key
        if not allowed[category] or (type(key) ~= "number" and value ~= true) then
            return false, "Invalid detail category: " .. tostring(category)
        end
        learned[category] = true
    end
    -- Validate the entire request before adding or expanding an entry.
    local entry = memory.knownEvents[eventId] or {details = {}}
    for category in pairs(learned) do entry.details[category] = true end
    memory.knownEvents[eventId] = entry
    return true
end

function Knowledge.knows(owner, eventId, world)
    local memory, campaign = memoryFor(owner, world)
    return memory ~= nil and type(eventId) == "string" and memory.knownEvents[eventId] ~= nil
        and Events.get(campaign, eventId) ~= nil
end

function Knowledge.getKnownDetails(owner, eventId, world)
    local memory, campaign = memoryFor(owner, world)
    if not memory or type(eventId) ~= "string" then return nil end
    local entry, event = memory.knownEvents[eventId], Events.get(campaign, eventId)
    if not entry or not event then return nil end
    local result = {}
    for category, known in pairs(entry.details) do
        if known == true and (projections[event.type] or {})[category] then result[category] = true end
    end
    return result
end

function Knowledge.getKnownEvent(owner, eventId, world)
    local memory, campaign = memoryFor(owner, world)
    if not memory then return nil end
    local details = Knowledge.getKnownDetails(owner, eventId, campaign)
    if not details then return nil end
    local event = Events.get(campaign, eventId)
    local view = {id = event.id, type = event.type}
    for category in pairs(details) do projections[event.type][category](view, event) end
    return view
end

-- Deterministic ID order; does not consult global history to discover events.
function Knowledge.getKnownEvents(owner, world, eventType)
    local memory, campaign = memoryFor(owner, world)
    if not memory then return {} end
    local ids, result = {}, {}
    for id in pairs(memory.knownEvents) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local view = Knowledge.getKnownEvent(owner, id, campaign)
        if view and (not eventType or view.type == eventType) then result[#result + 1] = view end
    end
    return result
end

function Knowledge.share(source, target, eventId, world)
    world = world or (source and source.__world)
    local details = Knowledge.getKnownDetails(source, eventId, world)
    if not details then return false, "Source does not know this event in this campaign." end
    return Knowledge.learn(target, eventId, details, world)
end

return Knowledge
