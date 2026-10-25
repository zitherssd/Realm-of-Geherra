-- Builds and stores serializable battlefield aftermath on the owning map.

local BattlefieldRemainsSystem = {}

local function ensureMapState(map)
    map.battlefieldRemains = map.battlefieldRemains or {}
    map.nextBattlefieldRemainsSequence = map.nextBattlefieldRemainsSequence or 1
end

local function copySerializable(value, path, ancestors)
    local valueType = type(value)
    if valueType == "nil" or valueType == "string" or valueType == "boolean" then
        return value
    elseif valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            error(path .. " contains a non-finite number", 3)
        end
        return value
    elseif valueType ~= "table" then
        error(path .. " contains a non-serializable " .. valueType, 3)
    end

    ancestors = ancestors or {}
    if ancestors[value] then error(path .. " contains a cycle", 3) end
    ancestors[value] = true
    local copy = {}
    for key, child in pairs(value) do
        if type(key) ~= "string" and type(key) ~= "number" then
            error(path .. " contains a non-primitive key", 3)
        end
        copy[key] = copySerializable(child, path .. "." .. tostring(key), ancestors)
    end
    ancestors[value] = nil
    return copy
end

local function requireStableId(value, label)
    local valueType = type(value)
    if valueType ~= "string" and valueType ~= "number" then
        error(label .. " must be a string or number ID", 3)
    end
    if valueType == "number" and
        (value ~= value or value == math.huge or value == -math.huge) then
        error(label .. " must be a finite number", 3)
    end
end

local function optionalIdentity(value)
    local valueType = type(value)
    if valueType == "string" or valueType == "number" or valueType == "boolean" then
        return value
    end
    return nil
end

local function getPartyActors(encounter)
    local partiesByActorId = {}
    for _, party in ipairs({encounter.partyA, encounter.partyB}) do
        if type(party) ~= "table" or type(party.actors) ~= "table" then
            error("Encounter must retain both campaign party references", 3)
        end
        for _, actor in ipairs(party.actors) do
            if partiesByActorId[actor.id] then
                error("Encounter actor IDs must be unique", 3)
            end
            partiesByActorId[actor.id] = {actor = actor, party = party}
        end
    end
    return partiesByActorId
end

local function copyFaction(actor, party)
    local affiliation = actor.faction or party.faction
    if type(affiliation) == "string" or type(affiliation) == "number" then
        return affiliation
    end
    return nil
end

local function factionList(actor)
    local factions = {}
    for faction, active in pairs(actor.factions or {}) do
        if active then
            local value = type(faction) == "number" and active or faction
            if type(value) == "string" or type(value) == "number" then
                factions[#factions + 1] = value
            end
        end
    end
    table.sort(factions, function(a, b) return tostring(a) < tostring(b) end)
    return #factions > 0 and factions or nil
end

local function buildCorpses(encounter, battleResult, worldTime)
    local actorsById = getPartyActors(encounter)
    local corpses = {}
    for actorId, actorResult in pairs(battleResult.actors) do
        if actorResult.defeated then
            local entry = actorsById[actorId]
            if not entry then
                error("Casualty actor " .. tostring(actorId) .. " is not in the encounter", 3)
            end
            local actor, party = entry.actor, entry.party
            corpses[#corpses + 1] = {
                actorId = actor.id,
                name = type(actor.name) == "string" and actor.name or tostring(actor.id),
                unitTypeId = optionalIdentity(actor.troopType or actor.type) or "unknown",
                species = optionalIdentity(actor.species),
                race = optionalIdentity(actor.race),
                faction = copyFaction(actor, party),
                factions = factionList(actor),
                deathTime = copySerializable(worldTime, "World timestamp")
            }
        end
    end
    table.sort(corpses, function(a, b) return tostring(a.actorId) < tostring(b.actorId) end)
    return corpses
end

function BattlefieldRemainsSystem.prepare(map, encounter, battleResult, worldTime, retainedItems, retainedGold)
    if type(map) ~= "table" then error("Battlefield remains require a map", 2) end
    if type(encounter) ~= "table" then error("Battlefield remains require an encounter", 2) end
    requireStableId(encounter.id, "Encounter")
    if encounter.remainsCreated then
        error("Battlefield remains were already created for this encounter", 2)
    end
    if type(battleResult) ~= "table" or type(battleResult.actors) ~= "table" then
        error("Battlefield remains require an encounter actor result", 2)
    end
    if type(worldTime) ~= "table" or type(worldTime.day) ~= "number" or
        type(worldTime.hour) ~= "number" then
        error("Battlefield remains require a world day/hour timestamp", 2)
    end

    local corpses = buildCorpses(encounter, battleResult, worldTime)
    retainedItems = retainedItems or {}
    retainedGold = retainedGold or {}
    local lootItems, goldTotal = {}, 0
    for _, resource in ipairs(retainedItems) do
        lootItems[#lootItems + 1] = copySerializable(resource, "Retained loot")
    end
    for _, resource in ipairs(retainedGold) do
        if type(resource.amount) ~= "number" or resource.amount < 0 then
            error("Retained gold must be a non-negative amount", 2)
        end
        goldTotal = goldTotal + resource.amount
    end
    if #corpses == 0 and #lootItems == 0 and goldTotal == 0 then
        return nil
    end

    local x = encounter.x
    local y = encounter.y
    if type(x) ~= "number" or type(y) ~= "number" then
        x = ((encounter.partyA.x or 0) + (encounter.partyB.x or 0)) / 2
        y = ((encounter.partyA.y or 0) + (encounter.partyB.y or 0)) / 2
    end
    local victorPartyId = battleResult.winnerPartyId
    local participants = {
        {partyId = encounter.partyAId, name = encounter.partyA.name or tostring(encounter.partyAId)},
        {partyId = encounter.partyBId, name = encounter.partyB.name or tostring(encounter.partyBId)}
    }
    local site = {
        id = nil,
        discovered = false,
        currentlyVisible = false,
        loot = {
            items = lootItems,
            gold = goldTotal
        },
        corpses = corpses,
        history = {
            encounterId = encounter.id,
            position = {x = x, y = y},
            participants = participants,
            victorPartyId = victorPartyId,
            worldTime = copySerializable(worldTime, "World timestamp")
        }
    }
    return copySerializable(site, "Battlefield remains site")
end

function BattlefieldRemainsSystem.apply(map, encounter, site)
    ensureMapState(map)
    if encounter.remainsCreated then
        error("Battlefield remains were already created for this encounter", 2)
    end
    encounter.remainsCreated = true
    if not site then return nil end

    local sequence = map.nextBattlefieldRemainsSequence
    map.nextBattlefieldRemainsSequence = sequence + 1
    site.id = tostring(map.id or "map") .. ":remains:" .. tostring(sequence)
    site.discovered = site.discovered == true
    site.currentlyVisible = false
    if type(map.addBattlefieldRemains) == "function" then
        map:addBattlefieldRemains(site)
    else
        map.battlefieldRemains[#map.battlefieldRemains + 1] = site
    end
    return site
end

function BattlefieldRemainsSystem.serialize(map)
    ensureMapState(map)
    local sites = copySerializable(map.battlefieldRemains, "Battlefield remains")
    for _, site in ipairs(sites) do
        site.currentlyVisible = false
    end
    return {
        schemaVersion = 1,
        nextSequence = map.nextBattlefieldRemainsSequence,
        sites = sites
    }
end

function BattlefieldRemainsSystem.restore(map, data)
    if type(map) ~= "table" or type(data) ~= "table" or data.schemaVersion ~= 1 or
        type(data.sites) ~= "table" or type(data.nextSequence) ~= "number" or
        data.nextSequence < 1 or data.nextSequence % 1 ~= 0 then
        error("Invalid serialized battlefield remains data", 2)
    end
    local sites = copySerializable(data.sites, "Serialized battlefield remains")
    for _, site in ipairs(sites) do
        requireStableId(site.id, "Battlefield remains site")
        site.discovered = site.discovered == true
        site.currentlyVisible = false
    end
    map.battlefieldRemains = sites
    map.nextBattlefieldRemainsSequence = data.nextSequence
end

function BattlefieldRemainsSystem.getAll(map)
    ensureMapState(map)
    return map.battlefieldRemains
end

return BattlefieldRemainsSystem
