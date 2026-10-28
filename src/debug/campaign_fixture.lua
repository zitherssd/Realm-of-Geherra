-- Initial conditions only. Goals, services, navigation and encounters own all later behavior.
local Ecs = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local NpcFactory = require("src.systems.population.npc_factory")
local Random = require("src.core.seeded_random")
local Party = require("src.ecs.assemblages.party")
local Parties = require("src.systems.parties.party_system")
local Locations = require("src.systems.locations.location_system")
local Navigation = require("src.world.world_navigation")
local Game = require("src.game.game_context")
local LocationRules = require("src.systems.locations.location_rules")
local Fixture = {seed = 73421, profiles = {normal = true, no_leader = true, healing = true, bandit_risk = true}}

function Fixture.validate(profile)
    assert(Fixture.profiles[profile], "Unknown debug campaign profile: " .. tostring(profile))
    return profile
end

local function settlement(location)
    return LocationRules.canHostCaravan(location)
end

-- Stable map order is also the caravan system's destination preference.
local function selectSettlements(map)
    for _, home in ipairs(map:getLocations()) do
        if settlement(home) then
            for _, far in ipairs(map:getLocations()) do
                if far ~= home and settlement(far) then
                    local path = Navigation.findPath(map, home.x, home.y, far.x, far.y)
                    if path and Navigation.findPath(map, far.x, far.y, home.x, home.y) then
                        return home, far, path
                    end
                end
            end
        end
    end
    error("Debug campaign requires two reachable generated settlements")
end

-- Derive positions from the real route; never create coordinates or location IDs.
local function outsidePosition(map, home, path)
    local radius = require("src.systems.parties.party_interaction_system").interactionRadius
    for _, point in ipairs(path) do
        local nearest, distance
        for _, location in ipairs(map:getLocations()) do
            if settlement(location) then
                local d = (point.x - location.x)^2 + (point.y - location.y)^2
                if not distance or d < distance then nearest, distance = location, d end
            end
        end
        if nearest == home and distance > (radius + 16)^2 and map:isWalkable(point.x, point.y) then
            return point.x, point.y
        end
    end
    error("Debug campaign requires an outdoor route position near the merchant settlement")
end

function Fixture.populate(map, profile)
    Fixture.validate(profile)
    if Game.data.debugCampaign then
        assert(Game.data.debugCampaign.map == map and Game.data.debugCampaign.profile == profile,
            "Debug fixture already initialized for another map/profile")
        return Game.data.debugCampaign
    end
    local home, far, path = selectSettlements(map)
    local x, y = outsidePosition(map, home, path)
    local world = Ecs.campaign
    local summary = {map = map, profile = profile, homeId = home.id, farId = far.id, actors = {}, parties = {}}
    local archetypes = {bel_naram = "wealthy_merchant", ashur = "caravan_leader", ninsun = "healer",
        enlil = "caravan_leader", ur_salim = "traveler", zakur = "bandit_leader"}
    local function actor(key, name, location, definitions, capabilities, gold)
        local a = NpcFactory.create(world, archetypes[key], {rng = Random.new(Fixture.seed, key),
            homeLocationId = location and location.id,
            culture = location and location.culture or "generic",
            faction = key == "zakur" and "bandits" or (location and location.faction or "neutral")},
            {id = "debug_" .. key, name = name, stats = {health = 100}, treasury = gold or 0,
                goals = definitions, capabilities = capabilities})
        if location then assert(Locations.addNPC(location, a)) end
        summary.actors[#summary.actors + 1] = a.id
        return a
    end
    actor("bel_naram", "Bel-Naram", home, {{type = "acquire_gold", amount = 10000}}, {caravanFormation = true}, 2000)
    actor("ashur", "Ashur", profile == "no_leader" and far or home,
        {{type = "provide_service"}}, {leadCaravan = true, travel = true}, 50)
    actor("ninsun", "Ninsun", home, {{type = "provide_service"}}, {heal = true}, 100)
    actor("enlil", "Enlil", far, {{type = "provide_service"}}, {leadCaravan = true, travel = true}, 50)
    local traveler = actor("ur_salim", "Ur-Salim", nil, {{type = "rest_and_recover"}}, {travel = true})
    traveler.hp = 30
    local party = Party.create(world, "Ur-Salim's travelers", traveler.id, "debug_travelers")
    Parties.addActor(party, traveler)
    Parties.setPosition(party, x, y)
    party.treasury, party.hostile, party.faction = 100, false, "neutral"
    assert(map:addParty(party))
    summary.parties[#summary.parties + 1] = party.id
    if profile == "bandit_risk" then
        local point = path[math.max(1, math.floor(#path / 2))]
        local leader = actor("zakur", "Zakur", nil,
            {{type = "acquire_gold", amount = 10000, roam = {originX = point.x, originY = point.y,
                radius = 180, durationSeconds = 30}}}, {raid = true, roam = true})
        local bandits = Party.create(world, "Zakur's bandits", leader.id, "debug_bandits")
        Parties.addActor(bandits, leader)
        for _ = 1, 5 do Parties.addActor(bandits, Unit.create(world, "bandit")) end
        Parties.setPosition(bandits, point.x, point.y)
        bandits.hostile, bandits.faction, bandits.treasury = true, "bandits", 75
        assert(map:addParty(bandits))
        summary.parties[#summary.parties + 1] = bandits.id
    end
    local playerParty = Game.data.playerParty
    Parties.setPosition(playerParty, map:nearestWalkable(home.x, home.y))
    -- A real initial injury permits the player to try Ninsun's ordinary transaction.
    Game.data.player.hp = math.max(1, math.floor(Game.data.player.maxHp * 0.6))
    home.discovered, far.discovered = true, true
    Game.data.debugCampaign = summary
    require("src.debug.mode").enabled = true
    print(string.format("Debug Campaign [%s]: A = %s [%s]; B = %s [%s]", profile, home.name, home.id, far.name, far.id))
    for _, id in ipairs(summary.actors) do
        local a = Ecs.findActorById(id)
        local services = require("src.systems.services.service_system")
        local location = services.getLocation(a, {world = world, map = map})
        local owner = services.getParty(a, world) or a
        print(string.format("%s [%s]: %s; HP %d/%d; gold %d", a.name, id,
            location and location.name or string.format("party %s at %.1f, %.1f", owner.id, owner.x, owner.y),
            a.hp, a.maxHp, owner.treasury))
    end
    return summary
end

return Fixture
