-- Builds and stores serializable battlefield aftermath on the owning map.

local Inventory = require("src.systems.items.inventory_system")

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

local function findMapParty(map, partyId)
    for _, party in ipairs(map:getParties() or {}) do
        if party.id == partyId then return party end
    end
    return nil
end

local function getPartyActors(map, encounter)
    local partyA = findMapParty(map, encounter.partyAId)
    local partyB = findMapParty(map, encounter.partyBId)
    if not partyA or not partyB then
        error("Encounter party IDs do not resolve on the campaign map", 3)
    end

    local partiesByActorId = {}
    for _, party in ipairs({partyA, partyB}) do
        if type(party) ~= "table" or type(party.actors) ~= "table" then
            error("Encounter parties must have actor rosters", 3)
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

local function buildCorpses(map, encounter, battleResult, worldTime)
    local actorsById = getPartyActors(map, encounter)
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

    local partyA = findMapParty(map, encounter.partyAId)
    local partyB = findMapParty(map, encounter.partyBId)
    if not partyA or not partyB then
        error("Encounter party IDs do not resolve on the campaign map", 2)
    end
    local corpses = buildCorpses(map, encounter, battleResult, worldTime)
    retainedItems = retainedItems or {}
    retainedGold = retainedGold or {}
    local lootItems, goldTotal = {}, 0
    for _, resource in ipairs(retainedItems) do
        local item = copySerializable(resource.item, "Retained loot item")
        if resource.durabilityRemaining ~= nil then item.durabilityRemaining = resource.durabilityRemaining end
        assert(Inventory.addItem({inventory = lootItems}, item), "Invalid remains item")
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
        x = ((partyA.x or 0) + (partyB.x or 0)) / 2
        y = ((partyA.y or 0) + (partyB.y or 0)) / 2
    end
    local victorPartyId = battleResult.winnerPartyId
    local participants = {
        {partyId = encounter.partyAId, name = partyA.name or tostring(encounter.partyAId)},
        {partyId = encounter.partyBId, name = partyB.name or tostring(encounter.partyBId)}
    }
    local site = {
        id = nil,
        discovered = false,
        currentlyVisible = false,
        inventory = lootItems,
        loot = {gold = goldTotal},
        corpses = corpses,
        history = {
            resourceAllocations = copySerializable(retainedItems, "Retained resource history"),
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
        schemaVersion = 2,
        nextSequence = map.nextBattlefieldRemainsSequence,
        sites = sites
    }
end

function BattlefieldRemainsSystem.restore(map, data)
    if type(map) ~= "table" or type(data) ~= "table" or (data.schemaVersion ~= 1 and data.schemaVersion ~= 2) or
        type(data.sites) ~= "table" or type(data.nextSequence) ~= "number" or
        data.nextSequence < 1 or data.nextSequence % 1 ~= 0 then
        error("Invalid serialized battlefield remains data", 2)
    end
    local sites = copySerializable(data.sites, "Serialized battlefield remains")
    for _, site in ipairs(sites) do
        requireStableId(site.id, "Battlefield remains site")
        if data.schemaVersion == 1 then
            if site.inventory ~= nil or type(site.loot) ~= "table" or type(site.loot.items) ~= "table" then
                error("Invalid legacy battlefield inventory", 2)
            end
            for index, resource in pairs(site.loot.items) do
                if type(index) ~= "number" or index < 1 or index % 1 ~= 0 or
                    index > #site.loot.items or type(resource) ~= "table" then
                    error("Invalid legacy battlefield item list", 2)
                end
            end
            site.inventory = Inventory.new()
            site.history = site.history or {}
            site.history.resourceAllocations = copySerializable(site.loot.items, "Legacy resource history")
            for _, resource in ipairs(site.loot.items) do
                local item = copySerializable(resource.item or resource, "Legacy loot item")
                if resource.item and resource.durabilityRemaining ~= nil then
                    item.durabilityRemaining = resource.durabilityRemaining
                end
                assert(Inventory.addItem(site, item), "Invalid legacy remains item")
            end
            site.loot.items = nil
        end
        if not Inventory.isValid(site.inventory) then error("Invalid battlefield inventory", 2) end
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
