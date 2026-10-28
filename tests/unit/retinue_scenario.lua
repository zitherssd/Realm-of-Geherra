local Ecs = require("src.ecs.world")
local Game = require("src.game.game_context")
local Map = require("src.world.map")
local Catalog = require("src.data.population.catalog")
local Inventory = require("src.systems.items.inventory_system")
local Locations = require("src.systems.population.location_population_system")
local Parties = require("src.systems.parties.party_system")
local Services = require("src.systems.services.service_system")
local Goals = require("src.systems.goals.goal_system")
local Activities = require("src.systems.world_activities.world_activity_system")
local Time = require("src.systems.campaign.time_system")
local Scenario = {}

local function fails(fn, fragment)
    local ok, err = pcall(fn)
    assert(not ok and tostring(err):find(fragment, 1, true), "Expected " .. fragment .. ", got " .. tostring(err))
end

local function setup(profile, options)
    Ecs.init(); Game.init(); Time.reset()
    local map = Map.new("retinue-test")
    local data = {seed = 73421, sites = {
        {id = "court", x = 100, y = 100, definition = "fort", culture = "minotaur",
            faction = "minotaur_clan", populationProfile = profile or "chieftain_court"},
        {id = "destination", x = 700, y = 100, definition = "village"},
    }}
    map:setWorldGenerationData(data)
    Game.data.currentMap = map
    Locations.populate(map, data, options)
    return map, map.locations[1], data
end

local function assertParty(map, location, party, placement)
    local leader = assert(Parties.getLeader(party))
    assert(leader.archetypeId == "minotaur_chieftain" and leader.memory and not leader.player)
    assert(Services.getParty(leader, Ecs.campaign) == party)
    assert(party.faction == "minotaur_clan" and not party.hostile)
    local inline = type(leader.defaultPartyTemplate) == "table" and not party.templateId
    assert(#party.actors >= (inline and 6 or 5) and #party.actors <= (inline and 10 or 9))
    assert(party.treasury >= 100 and party.treasury <= 250)
    assert(party.supplies == 100 and party.originLocationId == location.id)
    local seen = {}
    for _, member in ipairs(party.actors) do
        assert(not seen[member.id]); seen[member.id] = true
        assert(Ecs.findActorById(member.id) == member and member.treasury == 0)
        assert(member.culture == "minotaur" and member.faction == "minotaur_clan")
        if member ~= leader then
            assert(not member.memory)
            if inline then assert(not member.archetypeId and member.troopType:find("gaia_minotaur_", 1, true))
            else assert(member.archetypeId == "minotaur_guard") end
        end
        for _, resident in ipairs(location.npcs) do assert(member ~= resident) end
    end
    if placement == "stationed" then
        assert(location.stationedParties[1] == party and #map:getParties() == 0)
        assert(Services.getLocation(leader, {world = Ecs.campaign, map = map}) == location)
    else
        assert(#location.stationedParties == 0 and map:getParties()[1] == party)
        assert(not Services.getLocation(leader, {world = Ecs.campaign, map = map}))
        assert(map:isWalkable(party.x, party.y))
    end
    return leader
end

local function snapshot(party)
    local rows = {party.id, tostring(party.treasury)}
    for _, member in ipairs(party.actors) do rows[#rows + 1] = member.id .. member.name .. member.sprite end
    return table.concat(rows, "|")
end

function Scenario.run()
    local map, location, data = setup()
    local party = assert(Ecs.findPartyById(location.initialPartyIds[1]))
    local leader = assertParty(map, location, party, "stationed")
    assert(not location.garrisonPartyId, "personal retinue was incorrectly classified as a garrison")
    assert(leader.npc_goals.goals[1].type == "rest_and_recover", "party spawn replaced its leader's goals")
    local initial = snapshot(party)
    Locations.populate(map, data)
    assert(#location.initialPartyIds == 1 and snapshot(party) == initial)
    for _ = 1, 50 do math.random() end
    local again, home = setup()
    assert(snapshot(Ecs.findPartyById(home.initialPartyIds[1])) == initial)

    -- Stationed retinues use real travel and retain the same leader, troops and money.
    party = Ecs.findPartyById(home.initialPartyIds[1]); leader = Parties.getLeader(party)
    local identity, treasury, members = leader.id, party.treasury, #party.actors
    Goals.configure(leader, {{type = "reach_location", destinationLocationId = again.locations[2].id}}, {travel = true})
    for _ = 1, 300 do
        local elapsed = Time.worldHoursToSeconds(Time.update(0.1))
        Goals.update(elapsed, again)
        Activities.update(elapsed, again)
        if again.locations[2].stationedParties[1] == party then break end
    end
    assert(again.locations[2].stationedParties[1] == party and #home.stationedParties == 0)
    assert(Parties.getLeader(party).id == identity and #party.actors == members and party.treasury == treasury)

    local profile = Inventory.deepClone(Catalog.profiles.chieftain_court)
    profile.id = "retinue_test"
    Catalog.profiles.retinue_test = profile
    profile.residents[1].party = "traveling_retinue"
    map, location = setup("retinue_test")
    assertParty(map, location, Ecs.findPartyById(location.initialPartyIds[1]), "world")

    profile.residents[1].party = false
    map, location = setup("retinue_test")
    assert(#location.stationedParties == 0 and #map:getParties() == 0 and not location.initialPartyIds)
    assert(location.npcs[1].archetypeId == "minotaur_chieftain")

    profile.residents[1].party, profile.residents[1].count = "warrior_retinue", 2
    map, location = setup("retinue_test")
    assert(#location.initialPartyIds == 2 and #location.stationedParties == 2)
    local identities = {}
    for _, p in ipairs(location.stationedParties) do
        for _, member in ipairs(p.actors) do assert(not identities[member.id]); identities[member.id] = true end
    end
    assert(location.stationedParties[1].leaderId ~= location.stationedParties[2].leaderId)

    local mixed = Inventory.deepClone(Catalog.parties.warrior_retinue)
    mixed.id = "mixed_retinue"
    mixed.members = {{id = "warriors", role = "retinue_warrior", count = 2},
        {id = "healer", role = "healer", count = 1},
        {id = "absent", role = "retinue_warrior", count = 3, chance = 0}}
    Catalog.parties.mixed_retinue = mixed
    profile.residents[1].party, profile.residents[1].count = "mixed_retinue", 1
    map, location = setup("retinue_test")
    party = location.stationedParties[1]
    assert(#party.actors == 4 and party.actors[4].archetypeId == "minotaur_shaman")
    assert(party.actors[4].memory and party.actors[4].npc_goals.capabilities.heal)
    assert(party.treasury >= 150 and party.actors[4].treasury == 0)
    for _, member in ipairs(party.actors) do assert(Services.getParty(member, Ecs.campaign) == party) end
    mixed.members[1].party = "warrior_retinue"
    fails(function() Catalog.validate() end, "unknown field party")
    mixed.members[1].party = nil
    Catalog.parties.mixed_retinue = nil
    profile.residents[1].party = "warrior_retinue"

    -- Faction overrides can disable an archetype default without duplicating its slot.
    Catalog.factions.minotaur_clan.residentOverrides = {chieftain_court = {chieftain = {party = false}}}
    map, location = setup()
    assert(not location.initialPartyIds and location.npcs[1].archetypeId == "minotaur_chieftain")
    Catalog.factions.minotaur_clan.residentOverrides = nil

    -- A fort's garrison takes precedence over the archetype default: one leader, one party.
    map, location = setup("fort")
    assert(#location.stationedParties == 1 and #location.initialPartyIds == 1)
    assert(location.garrisonPartyId == location.initialPartyIds[1])
    assert(not location.stationedParties[1].templateId)

    fails(function() Catalog.validateRule({id = "bad", role = "fort_commander", party = "missing"}, "test") end, "unknown party")
    fails(function() Catalog.validateRule({id = "bad", role = "fort_guard", party = "warrior_retinue"}, "test") end, "important NPCs")
    local bad = Inventory.deepClone(Catalog.archetypes.minotaur_chieftain)
    bad.party = "missing"
    fails(function() Catalog.validateArchetype(bad) end, "Unknown archetype party")
    local old = Catalog.parties.warrior_retinue.placement
    Catalog.parties.warrior_retinue.placement = "teleport"
    fails(function() Catalog.validate() end, "Unknown party placement")
    Catalog.parties.warrior_retinue.placement = old
    local rule = Catalog.profiles.fort.residents[1]
    rule.party = "warrior_retinue"
    fails(function() Catalog.validate() end, "Garrison commander cannot")
    rule.party = nil
    Catalog.profiles.retinue_test = nil
    assert(Catalog.validate())
end

return Scenario
