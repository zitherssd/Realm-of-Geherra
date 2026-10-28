-- Hydrates a permanent actor from shared data. Never creates work or advances goals.
local Catalog = require("src.data.population.catalog")
local Registry = require("src.data.definition_registry")
local Unit = require("src.ecs.assemblages.unit")
local Troops = require("src.data.troops")
local Inventory = require("src.systems.items.inventory_system")
local Trader = require("src.systems.items.trader_system")
local Goals = require("src.systems.goals.goal_system")
local Random = require("src.core.seeded_random")
local Personality = require("src.data.types.personality")
local Factory = {}

local function choice(value, rng)
    if type(value) == "table" then return value[rng(1, #value)] end
    return value
end

local function hydrate(world, archetypeId, definition, context, overrides)
    context, overrides = context or {}, overrides or {}
    for field, value in pairs(overrides) do
        if field ~= "name" and field ~= "id" and field ~= "hp" then definition[field] = Inventory.deepClone(value) end
    end
    Catalog.validateArchetype(definition)
    local culture = assert(Catalog.cultures[context.culture or "generic"], "Unknown NPC culture")
    assert(Catalog.factions[context.faction or "neutral"], "Unknown NPC faction")
    local rng = context.rng or Random.new(context.seed, archetypeId or definition.troopType)
    local troop = Troops[definition.troopType]
    local npc = Unit.create(world, definition.troopType, overrides.id)
    npc.archetypeId, npc.culture, npc.faction = archetypeId, culture.id, context.faction or "neutral"
    npc.defaultPartyTemplate = definition.party
    npc.factions[npc.faction] = true
    -- Unit hydration also supports random sprites/equipment. Resolve them again using
    -- this actor's own seeded stream so unrelated global RNG draws cannot change it.
    npc.sprite = choice(troop.sprite or npc.sprite, rng)
    npc.equipment = {}
    for _, slot in ipairs(Registry.keys(troop.equipment or {})) do npc.equipment[slot] = choice(troop.equipment[slot], rng) end
    for _, slot in ipairs(Registry.keys(definition.equipment or {})) do npc.equipment[slot] = choice(definition.equipment[slot], rng) end
    for _, group in ipairs({"stats", "attributes"}) do
        for _, key in ipairs(Registry.keys(definition[group] or {})) do
            npc[group][key] = Registry.roll(definition[group][key], rng)
        end
    end
    npc.maxHp = npc.stats.health
    npc.hp = overrides.hp or npc.maxHp
    assert(npc.maxHp > 0 and npc.hp > 0 and npc.hp <= npc.maxHp, "Invalid NPC health")
    npc.treasury = Registry.roll(definition.treasury or 0, rng)
    if definition.important then
        npc:ensure("npc"); npc:ensure("memory")
        npc.homeLocationId = context.homeLocationId
        local pools = Catalog.names[definition.namePool or culture.namePool].pools
        local names = pools[archetypeId] or pools[definition.troopType] or pools.default
        npc.name = overrides.name or (names[rng(1, #names)] .. " the " .. definition.title)
        npc.personality = Personality.roll(definition.personality, rng)
        Goals.configure(npc, Inventory.deepClone(definition.goals or {}), Inventory.deepClone(definition.capabilities or {}))
    else
        if npc.memory then npc:remove("memory") end
        npc.name = overrides.name or definition.title
    end
    if definition.dialogueId then npc.dialogueId = definition.dialogueId end
    if troop.stock then
        npc.inventory, npc.inventoryFormat = Trader.buildStockInventory(troop), "list"
        npc.buysFromPlayers, npc.sellPriceFactor = troop.buysFromPlayers, troop.sellPriceFactor
        npc.restockIntervalDays = troop.restockIntervalDays
        if npc.restockIntervalDays then npc.lastStockRefreshDay = 0 end
    end
    return npc
end

function Factory.create(world, archetypeId, context, overrides)
    local definition = Inventory.deepClone(assert(Catalog.archetypes[archetypeId], "Unknown NPC archetype " .. tostring(archetypeId)))
    return hydrate(world, archetypeId, definition, context, overrides)
end

function Factory.createTroop(world, troopType, context)
    local troop = assert(Troops[troopType], "Unknown troop template " .. tostring(troopType))
    return hydrate(world, nil, {id = troopType, troopType = troopType, title = troop.name or troopType,
        important = false, treasury = 0, goals = {}, capabilities = {}}, context)
end

return Factory
