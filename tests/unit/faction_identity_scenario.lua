local Factions = require("src.data.factions")
local Catalog = require("src.data.population.catalog")
local Recruitment = require("src.data.recruitment")
local Recruits = require("src.systems.locations.recruitment_system")
local Ecs = require("src.ecs.world")
local Game = require("src.game.game_context")
local Map = require("src.world.map")
local Populate = require("src.systems.population.location_population_system")
local Factory = require("src.systems.population.npc_factory")
local Parties = require("src.systems.parties.party_system")
local Scenario = {}

local function fails(fn, fragment)
    local ok, err = pcall(fn)
    assert(not ok and tostring(err):find(fragment, 1, true), "Expected " .. fragment .. ", got " .. tostring(err))
end

local function invalidReference(target, key, value, fragment)
    local previous = target[key]
    target[key] = value
    local ok, err = pcall(Catalog.validate)
    target[key] = previous
    assert(not ok and tostring(err):find(fragment, 1, true), "Expected " .. fragment .. ", got " .. tostring(err))
end

local function identitiesAndReferences()
    assert(Factions == Catalog.factions and Factions == require("src.data.population.factions.index"),
        "Faction catalog entry points must share the same records")
    local count = 0
    for _ in pairs(Factions) do count = count + 1 end
    assert(count == 8 and not Factions.pelasgians and not Factions.pelasgian and not Factions.minotaur)
    for _, id in ipairs({"menari", "dacians", "hyperboreans", "neutral", "bandits", "undead",
        "pelasgian_clan", "minotaur_clan"}) do
        assert(Factions[id].id == id and Catalog.cultures[Factions[id].defaultCulture])
    end
    assert(Factions.undead.name == "Undead Forces" and Factions.undead.color.r == 0.3)
    assert(Factions.menari.description == "The widespread common people, fragmented into countless cultures.")
    assert(Factions.pelasgian_clan.defaultCulture == "pelasgian")
    assert(Factions.minotaur_clan.defaultCulture == "minotaur")
    assert(Catalog.validate())

    invalidReference(Factions.menari, "id", "dacians", "Invalid faction ID: menari")
    invalidReference(Factions.pelasgian_clan, "defaultCulture", "pelasgian_clan", "Unknown faction culture")
    invalidReference(Recruitment, "pelasgians", Recruitment.pelasgian_clan, "Unknown recruitment faction")
    invalidReference(Recruitment.pelasgian_clan.village, 1, "imaginary_troop", "Unknown recruitment troop")
    invalidReference(Recruitment.pelasgian_clan, "village", {}, "Empty recruitment pool")
    invalidReference(Recruitment.neutral, "default", nil, "Missing neutral recruitment fallback")
    invalidReference(require("src.data.population.settings").defaultFactions, 1, "pelasgian", "Unknown default faction")
    invalidReference(require("src.data.encounters").bands[1].pools[1], "faction", "pelasgians", "Unknown encounter faction")
    invalidReference(require("src.data.quests").hunt_dogs.onStart, "faction", "minotaur", "Unknown quest party faction")
    fails(function() Catalog.validateConditions({faction = "pelasgian"}, "fixture") end, "unknown faction")
    assert(Catalog.validate())
end

local function recruitmentPools()
    local cases = {
        {faction = "menari", type = "town", first = "soldier", last = "knight"},
        {faction = "dacians", type = "castle", first = "knight"},
        {faction = "hyperboreans", type = "town", first = "knight"},
        {faction = "pelasgian_clan", type = "village", first = "pelas_youth", last = "pelas_tribesman"},
        {faction = "pelasgian_clan", type = "town", first = "pelas_tribesman", last = "pelas_skirmisher"},
        {faction = "pelasgian_clan", type = "fort", first = "pelas_skirmisher"},
        {faction = "pelasgian_clan", type = "wizard_tower", first = "pelas_youth"},
        {faction = "minotaur_clan", type = "town", first = "soldier"},
        {faction = "bandits", type = "fort", first = "knight"},
        {faction = "undead", type = "wizard_tower", first = "soldier"},
        {type = "village", first = "soldier"},
    }
    local previousRandom = math.random
    local ok, err = pcall(function()
        for _, case in ipairs(cases) do
            for _, last in ipairs({false, true}) do
                math.random = function(upper) return upper and (last and upper or 1) or 0.6 end
                -- The same political roster applies even to a different local culture.
                for _, culture in ipairs({"generic", "pelasgian", "minotaur"}) do
                    local _, count, troops = Recruits.roll({faction = case.faction, type = case.type, culture = culture})
                    local expected = last and (case.last or case.first) or case.first
                    assert(count == 2 and troops[1] == expected and troops[2] == expected,
                        "Recruitment changed faction/pool semantics for " .. tostring(case.faction) .. "/" .. case.type)
                end
            end
        end
        for _, faction in ipairs({"pelasgians", "pelasgian", "minotaur", "unknown"}) do
            fails(function() Recruits.roll({faction = faction, type = "village"}) end, "Unknown recruitment faction")
        end
    end)
    math.random = previousRandom
    assert(ok, err)
end

local function populationAndCulture()
    local world = Ecs.init()
    Game.init()
    local map = Map.new("faction-identity")
    local data = {seed = 1234, sites = {
        {id = "clan", x = 100, y = 100, definition = "fort", faction = "pelasgian_clan"},
        {id = "minotaurs", x = 500, y = 100, definition = "fort", faction = "minotaur_clan"},
        {id = "occupied", x = 900, y = 100, definition = "fort", faction = "pelasgian_clan", culture = "minotaur"},
    }}
    map:setWorldGenerationData(data)
    Populate.populate(map, data)
    for index, location in ipairs(map:getLocations()) do
        local expectedCulture = index == 1 and "pelasgian" or "minotaur"
        assert(location.culture == expectedCulture and location.faction == data.sites[index].faction)
        local garrison = location.stationedParties[1]
        assert(garrison.faction == location.faction)
        local commander = Parties.getLeader(garrison)
        assert(commander.culture == expectedCulture and commander.faction == location.faction)
        assert(commander.archetypeId == (index == 1 and "pelasgian_officer" or "minotaur_chieftain"))
        for _, guard in ipairs(garrison.actors) do
            assert(guard.faction == location.faction and guard.factions[location.faction] == true)
            if guard ~= commander then
                assert(guard.archetypeId == (index == 2 and "minotaur_guard" or "pelasgian_veteran"))
                assert(guard.culture == (index == 2 and "minotaur" or "pelasgian"))
            end
        end
        local healers = 0
        for _, actor in ipairs(location.npcs) do
            assert(actor.culture == expectedCulture and actor.faction == location.faction)
            if actor.populationSlot == "healer" then healers = healers + 1 end
        end
        if location.faction == "pelasgian_clan" then assert(healers == 1, "Clan resident override was lost") end
    end
    local actor = Factory.create(world, "healer", {culture = "minotaur", faction = "pelasgian_clan", seed = 1})
    assert(actor.culture == "minotaur" and actor.faction == "pelasgian_clan")
    fails(function() Factory.create(world, "healer", {faction = "pelasgians"}) end, "Unknown NPC faction")

    local empty = Map.new("invalid-faction")
    fails(function() Populate.populate(empty, {seed = 1, sites = {
        {id = "valid", x = 100, y = 100, definition = "village", faction = "neutral"},
        {id = "invalid", x = 200, y = 100, definition = "village", faction = "pelasgian"},
    }}) end, "Unknown site faction")
    assert(#empty:getLocations() == 0, "Invalid faction partially populated the map")
end

function Scenario.run()
    identitiesAndReferences()
    recruitmentPools()
    populationAndCulture()
end

return Scenario
