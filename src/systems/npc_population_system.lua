local Catalog = require("src.data.population.catalog")
local Registry = require("src.data.definition_registry")
local Factory = require("src.systems.npc_factory")
local Inventory = require("src.systems.inventory_system")
local Locations = require("src.systems.location_system")
local PartyFactory = require("src.systems.npc_party_factory")
local Random = require("src.core.seeded_random")
local Population = {}

local function contains(list, value)
    for _, item in ipairs(list) do if item == value then return true end end
    return false
end

function Population.matches(rule, location)
    if rule.enabled == false then return false end
    local condition = rule.when or {}
    if condition.minProsperity and location.prosperity < condition.minProsperity then return false end
    if condition.maxProsperity and location.prosperity > condition.maxProsperity then return false end
    if condition.minPopulation and location.population < condition.minPopulation then return false end
    if condition.maxPopulation and location.population > condition.maxPopulation then return false end
    if condition.culture and location.culture ~= condition.culture then return false end
    if condition.faction and location.faction ~= condition.faction then return false end
    if condition.biomes and not contains(condition.biomes, location.biomeId) then return false end
    for _, tag in ipairs(condition.tags or {}) do if not (location.tags or {})[tag] then return false end end
    return true
end

-- Once per location, never on visits. Changing ownership does not respawn residents.
function Population.populate(map, location, seed)
    if location.populationInitialized then return false end
    local profile = assert(Catalog.profiles[location.populationProfile], "Unknown population profile")
    local faction = assert(Catalog.factions[location.faction], "Unknown location faction")
    local overrides = (faction.residentOverrides or {})[profile.id] or {}
    local slots = {}
    for _, base in ipairs(profile.residents) do
        local rule = Inventory.deepClone(base)
        for key, value in pairs(overrides[base.id] or {}) do rule[key] = Inventory.deepClone(value) end
        local rng = Random.new(seed, location.siteId .. ":" .. rule.id)
        if Population.matches(rule, location) then
            local archetypeId = rule.archetype or Catalog.resolveRole(location.culture, rule.role, location.faction, false)
            for index = 1, Registry.roll(rule.count or 1, rng) do
                if rng() < (rule.chance or 1) then
                    local npc = Factory.create(location.__world, archetypeId,
                        {rng = rng, culture = location.culture, faction = location.faction})
                    npc.populationSlot = rule.id
                    npc.x, npc.y = location.x, location.y
                    assert(Locations.addNPC(location, npc))
                    slots[rule.id] = slots[rule.id] or {}
                    slots[rule.id][#slots[rule.id] + 1] = npc
                    local partyDefinition = rule.party
                    if partyDefinition == nil then partyDefinition = npc.defaultPartyTemplate end
                    -- The garrison already supplies this leader's party, replacing defaults.
                    if partyDefinition and not (profile.garrison and profile.garrison.leaderSlot == rule.id) then
                        local spec, templateId = Catalog.resolveParty(partyDefinition)
                        PartyFactory.create(map, location, npc, spec, seed,
                            location.siteId .. ":" .. rule.id .. ":" .. index .. ":party",
                            {templateId = templateId, matches = Population.matches})
                    end
                end
            end
        end
    end
    if profile.garrison then
        local g = profile.garrison
        local leader = assert(slots[g.leaderSlot] and slots[g.leaderSlot][1], "Missing garrison commander")
        local party = PartyFactory.create(map, location, leader,
            {placement = "stationed", treasury = g.treasury,
                members = {{id = "guards", role = g.role, count = g.count}}}, seed,
            location.siteId .. ":garrison", {name = location.name .. " Garrison", garrison = true, matches = Population.matches})
        location.garrisonPartyId = party.id
    end
    location.populationInitialized = true
    return true
end

return Population
