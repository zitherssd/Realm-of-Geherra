local CampaignRuntime = require("src.game.campaign.campaign_runtime")
local Ecs = require("src.ecs.world")
local Map = require("src.world.map")
local Game = require("src.game.game_context")
local Locations = require("src.systems.population.location_population_system")
local Npcs = require("src.systems.population.npc_population_system")
local Factory = require("src.systems.population.npc_factory")
local Catalog = require("src.data.population.catalog")
local Registry = require("src.data.definition_registry")
local Inventory = require("src.systems.items.inventory_system")
local Parties = require("src.systems.parties.party_system")
local Services = require("src.systems.services.service_system")
local Goals = require("src.systems.goals.goal_system")
local Random = require("src.core.seeded_random")
local Scenario = {}

local function fails(fn, fragment)
    local ok, err = pcall(fn)
    assert(not ok and tostring(err):find(fragment, 1, true), "Expected " .. fragment .. ", got " .. tostring(err))
end

local function setup(seed, options)
    Ecs.init(); Game.init()
    local map = Map.new("population-test")
    local data = {seed = seed or 1234, biomeById = {}, sites = {
        {id = "hornwatch", x = 100, y = 100, biomeId = "hills", definition = "fort", faction = "minotaur_clan"},
        {id = "bronzewall", x = 700, y = 100, biomeId = "forest", definition = "fort", faction = "pelasgian_clan"},
        {id = "occupied", x = 100, y = 700, biomeId = "plains", definition = "fort",
            faction = "pelasgian_clan", culture = "minotaur"},
        {id = "market", x = 700, y = 700, biomeId = "plains", definition = "trading_town", prosperity = 90},
    }}
    map:setWorldGenerationData(data)
    Game.data.currentMap = map
    Locations.populate(map, data, options)
    return map, data
end

local function snapshot(map)
    local values, seen = {}, {}
    local function actor(a)
        assert(not seen[a.id], "duplicate membership: " .. a.id)
        seen[a.id] = true
        assert(Ecs.findActorById(a.id) == a)
        values[#values + 1] = table.concat({a.id, a.archetypeId, a.name, a.hp, a.treasury, a.sprite, a.culture, a.faction}, "|")
        for _, slot in ipairs(Registry.keys(a.equipment)) do values[#values + 1] = slot .. "=" .. a.equipment[slot] end
    end
    for _, location in ipairs(map:getLocations()) do
        values[#values + 1] = table.concat({location.id, location.name, location.definitionId,
            location.faction, location.culture, location.population, location.prosperity}, "|")
        for _, a in ipairs(location.npcs) do actor(a) end
        for _, party in ipairs(location.stationedParties) do
            values[#values + 1] = party.id .. ":" .. party.treasury
            assert(Parties.getLeader(party) and party.x == location.x and party.y == location.y)
            assert(#party.actors >= 9 and #party.actors <= 17)
            for _, a in ipairs(party.actors) do actor(a) end
        end
    end
    return table.concat(values, "\n")
end

function Scenario.run()
    assert(Catalog.validate())
    fails(function() Registry.load("archetype", "src.data.npc_archetypes.", {"healer", "healer"}) end, "Duplicate")
    fails(function() Catalog.validateRule({id = "bad", role = "unknown"}, "test") end, "unknown role")
    fails(function() Catalog.validateRule({id = "bad", role = "healer", chance = 2}, "test") end, "test.chance")
    fails(function() Catalog.validateRule({id = "bad", role = "healer", count = {min = 2, max = 1}}, "test") end, "range")
    fails(function() Catalog.validateRule({id = "bad", role = "healer", when = {prosperitty = 5}}, "test") end, "unknown field")
    fails(function() Catalog.validateRule({id = "bad", role = "healer", when = {minProsperity = {min = 1, max = 5}}}, "test") end, "test.when.minProsperity")
    local bad = Inventory.deepClone(Catalog.archetypes.healer)
    bad.troopType = "does_not_exist"
    fails(function() Catalog.validateArchetype(bad) end, "Unknown troop")
    bad = Inventory.deepClone(Catalog.archetypes.healer); bad.equipment = {mainHand = "imaginary_item"}
    fails(function() Catalog.validateArchetype(bad) end, "Unknown equipment")
    bad = Inventory.deepClone(Catalog.archetypes.healer); bad.capabilities = {invented_healing = true}
    fails(function() Catalog.validateArchetype(bad) end, "capability")

    local map, data = setup()
    local first = snapshot(map)
    local a, b, occupied, market = unpack(map:getLocations())
    assert(a.definitionId == b.definitionId and a.type == "fort" and b.type == "fort")
    assert(a.culture == "minotaur" and b.culture == "pelasgian")
    assert(Parties.getLeader(a.stationedParties[1]).archetypeId == "minotaur_chieftain")
    assert(Parties.getLeader(b.stationedParties[1]).archetypeId == "pelasgian_officer")
    assert(Parties.getLeader(occupied.stationedParties[1]).archetypeId == "minotaur_chieftain")
    assert(occupied.culture == "minotaur" and occupied.faction == "pelasgian_clan")
    for _, guard in ipairs(b.stationedParties[1].actors) do
        if guard ~= Parties.getLeader(b.stationedParties[1]) then assert(guard.archetypeId == "pelasgian_veteran" and not guard.memory) end
    end
    for _, guard in ipairs(occupied.stationedParties[1].actors) do
        if guard ~= Parties.getLeader(occupied.stationedParties[1]) then assert(guard.culture == "pelasgian") end
    end
    local healerCount = 0
    for _, npc in ipairs(b.npcs) do if npc.populationSlot == "healer" then healerCount = healerCount + 1 end end
    assert(healerCount == 1, "faction override duplicated or omitted guaranteed healer")
    local commander = Parties.getLeader(a.stationedParties[1])
    assert(Services.getParty(commander, Ecs.campaign) == a.stationedParties[1] and commander.treasury == 0)
    assert(Services.getLocation(commander, {world = Ecs.campaign, map = map}) == a)
    local screen = require("src.ui.screens.location_screen").new(b, function() end)
    local commanderVisible = false
    for _, button in ipairs(screen.buttons) do
        if button.npc then
            assert(button.npc.memory, "ordinary garrison troops filled the dialogue screen")
            if button.npc == Parties.getLeader(b.stationedParties[1]) then commanderVisible = true end
        end
    end
    assert(commanderVisible, "stationed commander was unavailable for conversation")
    screen:draw()
    assert(not Npcs.populate(map, a, 456), "repeat population rerolled residents")
    assert(Locations.populate(map, data) == map:getLocations() and snapshot(map) == first)
    -- Ownership changes do not replace existing civilians, their names or memories.
    local oldName = a.npcs[1].name
    a.faction = "pelasgian_clan"
    assert(not Npcs.populate(map, a, 456) and a.culture == "minotaur" and a.npcs[1].name == oldName)
    a.faction = "minotaur_clan"

    local condition = {when = {minProsperity = 80, maxProsperity = 95, culture = "generic",
        faction = market.faction, biomes = {"plains"}, tags = {"trade"}}}
    market.tags.trade = true
    assert(Npcs.matches(condition, market))
    market.prosperity = 79; assert(not Npcs.matches(condition, market)); market.prosperity = 90
    market.tags.trade = nil; assert(not Npcs.matches(condition, market))
    assert(not Npcs.matches({enabled = false}, market))

    local sponsor
    for _, npc in ipairs(market.npcs) do
        if npc.archetypeId == "wealthy_merchant" then sponsor = sponsor or npc end
    end
    assert(sponsor and sponsor.treasury >= 1500 and not sponsor.caravan_formation)
    CampaignRuntime.updateGoals(0.1, map)
    local preparation = assert(sponsor.caravan_formation.preparation)
    assert(#Services.listProviders({world = Ecs.campaign, map = map}) >= 1)
    CampaignRuntime.updateGoals(2.1, map)
    local request = Services.getRequest(preparation.leaderServiceId, {world = Ecs.campaign})
    local worker = assert(Ecs.findActorById(request.assignedActorId))
    assert(worker.archetypeId == "caravan_leader" and Services.hasObligation(worker, {world = Ecs.campaign}))

    for _ = 1, 100 do math.random() end
    local fresh = setup()
    assert(snapshot(fresh) == first, "population changed with global RNG consumption or stale IDs")
    local different = setup(1235)
    assert(snapshot(different) ~= first, "seed did not vary generated population")
    local overridden = setup(1234, {siteOverrides = {hornwatch = {culture = "pelasgian", faction = "neutral", name = "Scenario Fort"}}})
    assert(overridden.locations[1].name == "Scenario Fort" and overridden.locations[1].culture == "pelasgian")
    assert(Parties.getLeader(overridden.locations[1].stationedParties[1]).archetypeId == "pelasgian_officer")
    assert(overridden.locations[1].stationedParties[1].actors[2].archetypeId == "pelasgian_guard")

    -- Independent actor copies and deterministic equipment selection.
    local actor1 = Factory.create(Ecs.campaign, "pelasgian_guard", {rng = Random.new(7), culture = "pelasgian"})
    local actor2 = Factory.create(Ecs.campaign, "pelasgian_guard", {rng = Random.new(7), culture = "pelasgian"})
    assert(actor1.id ~= actor2.id and actor1.equipment.mainHand == actor2.equipment.mainHand)
    actor1.equipment.mainHand = "changed"
    assert(actor2.equipment.mainHand ~= "changed" and not actor2.memory)

    -- Full plan validation rejects bad late-site input before mutating the map.
    Ecs.init()
    local empty = Map.new("bad-population")
    local malformed = {seed = 1, sites = {{id = "valid", x = 100, y = 100, definition = "village"},
        {id = "invalid", x = 200, y = 100, definition = "missing_fort"}}}
    fails(function() Locations.populate(empty, malformed) end, "Unknown location definition")
    assert(#empty.locations == 0 and not Ecs.findLocationById("location_1"))
    fails(function() Locations.populate(empty, {sites = {{id = "one", x = 100, y = 100, definition = "village"}}},
        {siteOverrides = {missing = {culture = "minotaur"}}}) end, "unknown site")
    assert(#empty.locations == 0)
    local minorData = {seed = 1234, sites = {}}
    for index = 1, 12 do minorData.sites[index] = {id = "minor_" .. index, x = index * 50, y = 100, siteSize = "minor"} end
    local minorMap = Map.new("minor-sites")
    Locations.populate(minorMap, minorData)
    for _, location in ipairs(minorMap.locations) do
        assert(location.definitionId ~= "town" and location.definitionId ~= "castle"
            and location.definitionId ~= "fort" and location.definitionId ~= "trading_town")
    end
    assert(Catalog.validate())
end

return Scenario
