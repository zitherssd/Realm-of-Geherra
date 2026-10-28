-- Sites become persistent locations, then shared population rules create their actors.
local Location = require("src.ecs.assemblages.location")
local Ecs = require("src.ecs.world")
local Settings = require("src.data.population.settings")
local Catalog = require("src.data.population.catalog")
local Registry = require("src.data.definition_registry")
local Population = require("src.systems.population.npc_population_system")
local Inventory = require("src.systems.items.inventory_system")
local Random = require("src.core.seeded_random")
local MapGenerator = require("src.world.generation.map_generator")
local System = {}

local function includes(list, value)
    for _, entry in ipairs(list or {}) do if entry == value then return true end end
    return false
end

local function selectDefinition(site, rng)
    local choices, total = {}, 0
    for _, id in ipairs(Registry.keys(Catalog.locations)) do
        local definition = Catalog.locations[id]
        local placement = definition.placement
        if includes(placement.siteSizes, site.siteSize or "major") then
            local bias = (placement.biomeWeights or {})[site.biomeId]
            if bias == nil then bias = 1 end
            local weight = placement.weight * bias
            if weight > 0 then
                total = total + weight
                choices[#choices + 1] = {id = id, threshold = total}
            end
        end
    end
    assert(total > 0, "No location definition eligible for site " .. tostring(site.id))
    local pick = rng() * total
    for _, entry in ipairs(choices) do if pick < entry.threshold then return entry.id end end
    return choices[#choices].id
end

local function locationName(definition, rng, used, index)
    for _ = 1, #definition.names * 2 do
        local name = definition.names[rng(1, #definition.names)]
        if not used[name] then used[name] = true; return name end
    end
    local name = definition.names[rng(1, #definition.names)] .. " " .. index
    used[name] = true
    return name
end

function System.populate(map, data, options)
    if map.locationsInitialized then return map:getLocations() end
    options = options or {}
    Catalog.validate()
    local factions = options.factions or Settings.defaultFactions
    assert(#factions > 0, "Location faction list must not be empty")
    for _, id in ipairs(factions) do assert(Catalog.factions[id], "Unknown faction " .. tostring(id)) end
    local seen, plans, usedNames = {}, {}, {}
    -- Validate the full site plan before creating any entities.
    for index, source in ipairs(data.sites or {}) do
        assert(type(source.id) == "string" and not seen[source.id], "Missing/duplicate site ID")
        seen[source.id] = true
        local site = Inventory.deepClone(source)
        local override = (options.siteOverrides or {})[site.id] or {}
        Registry.fields(override, {definition = true, locationType = true, culture = true, faction = true,
            populationProfile = true, name = true, prosperity = true, population = true, tags = true}, "Site override " .. site.id)
        for key, value in pairs(override) do site[key] = Inventory.deepClone(value) end
        assert(type(site.x) == "number" and type(site.y) == "number" and site.x == site.x and site.y == site.y
            and site.x >= 0 and site.y >= 0 and site.x < map.width and site.y < map.height
            and map:isWalkable(site.x, site.y), "Site must have a valid walkable map position: " .. site.id)
        if site.siteSize then assert(site.siteSize == "major" or site.siteSize == "minor", "Unknown site size") end
        if site.name then assert(type(site.name) == "string" and site.name ~= "", "Invalid site name") end
        if site.tags then
            assert(type(site.tags) == "table", "Site tags must be a flag table")
            for tag, enabled in pairs(site.tags) do
                assert(type(tag) == "string" and type(enabled) == "boolean", "Invalid site tag")
            end
        end
        local rng = Random.new(data.seed, site.id .. ":location")
        local definitionId = override.definition or override.locationType or site.definition or site.definitionId or site.locationType
            or selectDefinition(site, rng)
        local definition = assert(Catalog.locations[definitionId], "Unknown location definition " .. tostring(definitionId))
        local factionId = site.faction or factions[((index - 1) % #factions) + 1]
        local faction = assert(Catalog.factions[factionId], "Unknown site faction " .. tostring(factionId))
        local cultureId = site.culture or faction.defaultCulture
        assert(Catalog.cultures[cultureId], "Unknown site culture " .. tostring(cultureId))
        local profileId = site.populationProfile or definition.populationProfile
        assert(Catalog.profiles[profileId], "Unknown site population profile " .. tostring(profileId))
        local population = site.population or Registry.roll(definition.population, rng)
        local prosperity = site.prosperity or Registry.roll(definition.prosperity, rng)
        Registry.range(population, site.id .. " population")
        Registry.range(prosperity, site.id .. " prosperity")
        plans[#plans + 1] = {site = site, definition = definition, faction = factionId, culture = cultureId,
            profile = profileId, population = population, prosperity = prosperity,
            visibility = Registry.roll(definition.visibility, rng),
            name = site.name or locationName(definition, rng, usedNames, index)}
    end
    for id in pairs(options.siteOverrides or {}) do assert(seen[id], "Override refers to unknown site " .. id) end
    local locations = {}
    for index, plan in ipairs(plans) do
        local site, definition = plan.site, plan.definition
        local location = Location.create(Ecs.campaign, nil, plan.name)
        location.x, location.y = site.x, site.y
        location.definitionId, location.type = definition.id, definition.id
        location.faction, location.culture, location.populationProfile = plan.faction, plan.culture, plan.profile
        location.population, location.prosperity, location.profile = plan.population, plan.prosperity, plan.visibility
        location.tags = Inventory.deepClone(site.tags or {})
        location.discovered = options.debugCampaign and true or not definition.hidden
        location.biomeId, location.siteId = site.biomeId, site.id
        data.sites[index].locationType = definition.id
        data.sites[index].definitionId = definition.id
        map:addLocation(location)
        Population.populate(map, location, data.seed)
        locations[#locations + 1] = location
    end
    -- Keep the existing road tracing algorithm, using definition eligibility.
    if data.world then
        local roadWorthy = {}
        for index, location in ipairs(locations) do
            local site = data.sites[index]
            if Catalog.locations[location.definitionId].roadWorthy and site.px and site.py then
                roadWorthy[#roadWorthy + 1] = site
            end
        end
        data.roads = #roadWorthy >= 2 and MapGenerator.traceRoads(roadWorthy, data.world) or {}
    end
    map.locationsInitialized = true
    return locations
end

return System
