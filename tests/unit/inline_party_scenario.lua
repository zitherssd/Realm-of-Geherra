local Ecs = require("src.ecs.world")
local Game = require("src.game.game_context")
local Map = require("src.world.map")
local Populate = require("src.systems.location_population_system")
local Catalog = require("src.data.population.catalog")
local Composition = require("src.data.types.party_definition")
local Member = require("src.data.types.party_member")
local Inventory = require("src.systems.inventory_system")
local Parties = require("src.systems.party_system")
local Scenario = {}

local function fails(fn, fragment)
    local ok, err = pcall(fn)
    assert(not ok and tostring(err):find(fragment, 1, true), "Expected " .. fragment .. ", got " .. tostring(err))
end

local function setup(seed)
    Ecs.init(); Game.init()
    local map = Map.new("inline-party")
    local data = {seed = seed, sites = {{id = "court", x = 100, y = 100, definition = "fort",
        faction = "minotaur_clan", populationProfile = "chieftain_court"}}}
    map:setWorldGenerationData(data)
    Populate.populate(map, data)
    return map, map.locations[1], data
end

function Scenario.run()
    local definition = Catalog.archetypes.minotaur_chieftain
    assert(type(definition.party) == "table" and Composition.is(definition.party))
    assert(not definition.party.id and #definition.party.members == 3)
    local optionalSeen, optionalAbsent, firstSnapshot = false, false, nil
    for seed = 1, 32 do
        local map, home, data = setup(seed)
        local party = assert(home.stationedParties[1])
        local leader = assert(Parties.getLeader(party))
        assert(leader.archetypeId == "minotaur_chieftain" and leader.memory)
        assert(not party.templateId and party.supplies == 100)
        assert(party.treasury >= 100 and party.treasury <= 250)
        local groups, seen, snapshot = {}, {}, {party.id, tostring(party.treasury)}
        for _, actor in ipairs(party.actors) do
            assert(not seen[actor.id]); seen[actor.id] = true
            assert(Ecs.findActorById(actor.id) == actor and actor.treasury == 0)
            for _, resident in ipairs(home.npcs) do assert(resident ~= actor) end
            snapshot[#snapshot + 1] = actor.id .. actor.troopType .. actor.name .. actor.sprite
            if actor ~= leader then
                assert(not actor.memory and not actor.archetypeId)
                groups[actor.troopType] = (groups[actor.troopType] or 0) + 1
            end
        end
        assert(groups.gaia_minotaur_naked >= 3 and groups.gaia_minotaur_naked <= 4)
        assert(groups.gaia_minotaur_warhammer >= 2 and groups.gaia_minotaur_warhammer <= 4)
        local warrior = groups.gaia_minotaur_warrior_commander or 0
        assert(warrior == 0 or warrior == 1)
        optionalSeen, optionalAbsent = optionalSeen or warrior == 1, optionalAbsent or warrior == 0
        assert(#party.actors == 1 + groups.gaia_minotaur_naked + groups.gaia_minotaur_warhammer + warrior)
        local before = #party.actors
        Populate.populate(map, data)
        assert(#home.stationedParties == 1 and #party.actors == before)
        if seed == 1 then
            firstSnapshot = table.concat(snapshot, "|")
            leader.defaultPartyTemplate.members[1].count = 999
            assert(definition.party.members[1].count.min == 3, "runtime actor modified shared composition")
        end
        local screen = require("src.ui.screens.location_screen").new(home, function() end)
        for _, button in ipairs(screen.buttons) do if button.npc then assert(button.npc.memory) end end
    end
    assert(optionalSeen and optionalAbsent, "50% optional member never varied across campaign seeds")
    for _ = 1, 100 do math.random() end
    local map, home = setup(1)
    local party = home.stationedParties[1]
    local snapshot = {party.id, tostring(party.treasury)}
    for _, actor in ipairs(party.actors) do snapshot[#snapshot + 1] = actor.id .. actor.troopType .. actor.name .. actor.sprite end
    assert(table.concat(snapshot, "|") == firstSnapshot)

    local bad = Inventory.deepClone(definition.party)
    bad.members[1].troopType = "missing_minotaur"
    fails(function() Catalog.validatePartyDefinition(bad, "inline") end, "unknown troop template")
    bad = Inventory.deepClone(definition.party); bad.members[2].id = bad.members[1].id
    fails(function() Catalog.validatePartyDefinition(bad, "inline") end, "Duplicate party member slot")
    bad = Inventory.deepClone(definition.party); bad.members[1].role = "fort_guard"
    fails(function() Catalog.validatePartyDefinition(bad, "inline") end, "exactly one")
    bad = Inventory.deepClone(definition.party); bad.members[1].chance = 1.5
    fails(function() Catalog.validatePartyDefinition(bad, "inline") end, ".chance")
    bad = Inventory.deepClone(definition.party); bad.members[1].count = {min = 5, max = 2}
    fails(function() Catalog.validatePartyDefinition(bad, "inline") end, "inverted range")
    fails(function() Member.new({id = "bad", troopType = "gaia_minotaur_naked", party = "warrior_retinue"}) end,
        "unknown field party")

    local profile = Inventory.deepClone(Catalog.profiles.chieftain_court)
    profile.id = "inline_party_test"
    profile.residents[1].party = Inventory.deepClone(definition.party)
    profile.residents[1].party.members = {{id = "fixed", troopType = "gaia_minotaur_warhammer", count = 3, chance = 1},
        {id = "absent", troopType = "gaia_minotaur_naked", count = 4, chance = 0}}
    Catalog.profiles.inline_party_test = profile
    Ecs.init(); Game.init()
    local overrideMap = Map.new("inline-override")
    Populate.populate(overrideMap, {seed = 1, sites = {{id = "court", x = 100, y = 100,
        definition = "fort", faction = "minotaur_clan", populationProfile = "inline_party_test"}}})
    assert(#overrideMap.locations[1].stationedParties[1].actors == 4)
    Catalog.profiles.inline_party_test = nil
    assert(Catalog.validate())
end

return Scenario
