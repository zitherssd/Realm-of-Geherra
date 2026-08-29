local Location = require("src.world.location")
local EcsWorld = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local WorldGenerationConfig = require("src.data.world_generation")
local LocationNpcSpawnRules = require("src.data.location_npc_spawn_rules")
local NpcNamePools = require("src.data.npc_name_pools")
local MapGenerator = require("src.systems.map_generator")

local LocationPopulationSystem = {}

--- Pick a random given name for an NPC based on their troopType.
-- Returns "GivenName the RoleName" or falls back to the role name alone.
local function generateNpcName(troopType, rng)
    local pools = NpcNamePools[troopType] or NpcNamePools.default
    local givenName = pools[rng(1, #pools)]
    -- Capitalise the role for the title
    local roleTitle = troopType:gsub("^%l", string.upper):gsub("_", " ")
    return givenName .. " the " .. roleTitle
end

-- Keep this for deterministic RNG usage in other contexts
local function makeRng(seed)
    local state = math.max(1, math.floor(seed or WorldGenerationConfig.defaultSeed))
    return function(min, max)
        state = (1664525 * state + 1013904223) % 4294967296
        local ratio = state / 4294967296
        if not min then
            return ratio
        end
        if not max then
            return math.floor(ratio * min) + 1
        end
        return math.floor(min + ratio * (max - min + 1))
    end
end

local function weightedChoice(weights, rng)
    local total = 0
    for _, value in pairs(weights) do
        total = total + value
    end

    local pick = rng() * total
    local cursor = 0

    for key, value in pairs(weights) do
        cursor = cursor + value
        if pick <= cursor then
            return key
        end
    end

    local fallback = next(weights)
    return fallback
end

local function randomRange(rng, bounds)
    if not bounds then
        return 0
    end
    return rng(bounds.min, bounds.max)
end

local function makeLocationName(index, locationType, namePools, rng, usedNames)
    local pool = namePools and namePools[locationType]

    if pool and #pool > 0 then
        local attempts = math.min(#pool * 2, 64)
        for _ = 1, attempts do
            local candidate = pool[rng(1, #pool)]
            if candidate and not usedNames[candidate] then
                usedNames[candidate] = true
                return candidate
            end
        end

        local candidate = pool[rng(1, #pool)]
        return string.format("%s %d", candidate, index)
    end

    return string.format("%s %d", locationType or "settlement", index)
end

local function spawnLocationNpcs(location, locationType, rng, spawnRules)
    local rules = spawnRules and spawnRules[locationType]
    if not rules then
        return
    end

    for _, rule in ipairs(rules.npcs or rules) do
        local chance = rule.chance or 1.0
        local count = math.max(0, rule.count or 1)

        for _ = 1, count do
            if rng() <= chance then
                local npc = Unit.create(EcsWorld.campaign, rule.troopType)
                npc:give("npc")
                -- Assign a given-name + title (e.g. "Ion the Elder")
                npc.name = generateNpcName(rule.troopType, rng)
                location:addNPC(npc)
            end
        end
    end
end

function LocationPopulationSystem.populate(map, generationData, options)
    options = options or {}
    local populationConfig = WorldGenerationConfig.locationPopulation
    local rng = makeRng((generationData.seed or WorldGenerationConfig.defaultSeed) + 71)
    local usedNames = {}

    local factions = options.factions or populationConfig.defaultFactions
    local locations = {}

    for index, site in ipairs(generationData.sites or {}) do
        local biomeConfig = generationData.biomeById[site.biomeId]
        local typeWeights = {}

        for locationType, baseWeight in pairs(populationConfig.typeWeights) do
            local biomeBias = 1
            if biomeConfig and biomeConfig.locationBias and biomeConfig.locationBias[locationType] then
                biomeBias = biomeConfig.locationBias[locationType]
            end
            typeWeights[locationType] = baseWeight * biomeBias
        end

        local locationType = weightedChoice(typeWeights, rng)
        local locationId = string.format("settlement_%02d", index)
        local location = Location.new(
            locationId,
            makeLocationName(index, locationType, populationConfig.namePools, rng, usedNames)
        )

        location:setPosition(site.x, site.y)
        location.type = locationType
        location.faction = factions[((index - 1) % #factions) + 1]
        location.population = randomRange(rng, populationConfig.populationByType[locationType])
        location.prosperity = randomRange(rng, populationConfig.prosperityByType[locationType])
        location.biomeId = site.biomeId
        location.siteId = site.id
        site.locationType = locationType

        spawnLocationNpcs(location, locationType, rng, LocationNpcSpawnRules)

        map:addLocation(location)
        table.insert(locations, location)
    end

    -- Roads are traced over ALL sites before types are known, so rebuild the
    -- network now to connect ONLY the road-worthy locations to each other
    -- (configurable via locationPopulation.roadWorthyTypes; default keeps
    -- village/town/castle linked). Other types get no roads at all.
    local roadTypes = populationConfig.roadWorthyTypes or { "village", "town", "castle" }
    local roadSet = {}
    for _, t in ipairs(roadTypes) do
        roadSet[t] = true
    end
    local world = generationData.world
    if world then
        local roadWorthy = {}
        for _, site in ipairs(generationData.sites or {}) do
            if roadSet[site.locationType] and site.px and site.py then
                table.insert(roadWorthy, site)
            end
        end
        if #roadWorthy >= 2 then
            generationData.roads = MapGenerator.traceRoads(roadWorthy, world)
        else
            generationData.roads = {}
        end
    end

    return locations
end

return LocationPopulationSystem
