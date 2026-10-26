-- systems/location_system.lua
-- Plain functions for location entities (replaces the old Location:setPosition()/:addNPC() methods).

local LocationSystem = {}
local PartySystem = require("src.systems.party_system")
local EcsWorld = require("src.ecs.world")

local function isRemoved(entity)
    return entity.__isEntity and (not entity.__world
        or EcsWorld.findEntityById(entity.id, nil, entity.__world) ~= entity)
end

local function ensureNpcs(location)
    if not location.npcs then
        location.npcs = {}
    end
    return location.npcs
end

local function ensureStationedParties(location)
    location.stationedParties = location.stationedParties or {}
    return location.stationedParties
end

local function sameEntity(left, right)
    if left == nil or right == nil then
        return false
    end
    if left.id ~= nil and right.id ~= nil then
        return left.id == right.id
    end
    return left == right
end

function LocationSystem.setPosition(location, x, y)
    location.x = x
    location.y = y
end

function LocationSystem.addNPC(location, npc)
    if not location or not npc then return false end
    local npcs = ensureNpcs(location)
    for _, existing in ipairs(npcs) do
        if sameEntity(existing, npc) then
            return false
        end
    end
    for _, party in ipairs(location.stationedParties or {}) do
        for _, actor in ipairs(party.actors or {}) do
            if sameEntity(actor, npc) then return false end
        end
    end
    table.insert(npcs, npc)
    return true
end

function LocationSystem.removeNPC(location, npc)
    if not location or not location.npcs then return false end
    for index, existing in ipairs(location.npcs) do
        if sameEntity(existing, npc) then
            table.remove(location.npcs, index)
            return true
        end
    end
    return false
end

function LocationSystem.addStationedParty(map, location, party)
    if not map or not location or not party or type(map.getLocations) ~= "function" then
        return false
    end
    if isRemoved(party) then return false end

    local locationIsOnMap = false
    for _, candidate in ipairs(map:getLocations() or {}) do
        if candidate == location or sameEntity(candidate, location) then
            locationIsOnMap = true
            break
        end
    end
    if not locationIsOnMap then return false end

    local partiesOnMap = type(map.getParties) == "function" and map:getParties() or {}
    for _, activeParty in ipairs(partiesOnMap) do
        if sameEntity(activeParty, party) then
            return false
        end
    end

    local actorIds = {}
    for _, actor in ipairs(party.actors or {}) do
        local actorKey = actor.id or actor
        if actorIds[actorKey] then return false end
        actorIds[actorKey] = true
    end

    for _, otherLocation in ipairs(map:getLocations() or {}) do
        for _, resident in ipairs(otherLocation.npcs or {}) do
            if actorIds[resident.id or resident] then return false end
        end
        for _, stationedParty in ipairs(otherLocation.stationedParties or {}) do
            if sameEntity(stationedParty, party) then
                return false
            end
            if not sameEntity(stationedParty, party) then
                for _, actor in ipairs(stationedParty.actors or {}) do
                    if actorIds[actor.id or actor] then return false end
                end
            end
        end
    end
    for _, activeParty in ipairs(partiesOnMap) do
        for _, actor in ipairs(activeParty.actors or {}) do
            if actorIds[actor.id or actor] then return false end
        end
    end

    local parties = ensureStationedParties(location)
    for _, existing in ipairs(parties) do
        if sameEntity(existing, party) then
            return false
        end
    end
    table.insert(parties, party)
    return true
end

function LocationSystem.removeStationedParty(location, party)
    if not location then return false end
    local parties = ensureStationedParties(location)
    for index, existing in ipairs(parties) do
        if sameEntity(existing, party) then
            table.remove(parties, index)
            return true
        end
    end
    return false
end

function LocationSystem.getAvailableNpcs(location)
    if not location then return {} end

    local available = {}
    local seen = {}
    local function addActor(actor)
        if not actor then return end
        local key = actor.id or tostring(actor)
        if seen[key] then return end
        seen[key] = true
        table.insert(available, actor)
    end

    local residents = location.npcs or {}
    for index = #residents, 1, -1 do
        local npc = residents[index]
        if isRemoved(npc) then
            table.remove(residents, index)
        end
    end
    for _, npc in ipairs(residents) do
        addActor(npc)
    end

    local parties = ensureStationedParties(location)
    for index = #parties, 1, -1 do
        local party = parties[index]
        if isRemoved(party) then
            table.remove(parties, index)
        else
            local actors = party.actors
            if type(actors) == "table" then
                for actorIndex = #actors, 1, -1 do
                    local actor = actors[actorIndex]
                    if isRemoved(actor) then
                        PartySystem.removeActor(party, actor)
                    end
                end
            end
        end
    end

    for _, party in ipairs(parties) do
        if type(party.actors) == "table" then
            for _, actor in ipairs(party.actors) do
                addActor(actor)
            end
        end
    end

    return available
end

return LocationSystem
