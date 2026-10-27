local LocationDefinition = require("src.data.types.location_definition")
local PopulationProfile = require("src.data.types.population_profile")
local NpcArchetype = require("src.data.types.npc_archetype")
local PartyTemplate = require("src.data.types.party_template")
local Catalog = require("src.data.population.catalog")
local Actions = require("src.systems.location_action_registry")
local Rules = require("src.systems.location_rules")
local Inventory = require("src.systems.inventory_system")
local Ecs = require("src.ecs.world")
local Game = require("src.game.game_context")
local Map = require("src.world.map")
local Populate = require("src.systems.location_population_system")
local Locations = require("src.systems.location_system")
local Goals = require("src.systems.goal_system")
local Factory = require("src.systems.npc_factory")
local Services = require("src.systems.service_system")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Parties = require("src.systems.party_system")
local Time = require("src.systems.time_system")
local Scenario = {}

local function fails(fn, fragment)
    local ok, err = pcall(fn)
    assert(not ok and tostring(err):find(fragment, 1, true), "Expected " .. fragment .. ", got " .. tostring(err))
end

function Scenario.run()
    assert(LocationDefinition.is(Catalog.locations.wizard_tower))
    assert(not LocationDefinition.is({id = "incomplete"}))
    for _, field in ipairs({"gameplayType", "facilities"}) do
        local bad = Inventory.deepClone(Catalog.locations.fort)
        bad[field] = field == "facilities" and {} or "castle"
        fails(function() LocationDefinition.new(bad) end, "unknown field " .. field)
    end
    local bad = Inventory.deepClone(Catalog.locations.fort)
    bad.rules.caravanStop = "true"
    fails(function() LocationDefinition.new(bad) end, "rules.caravanStop: expected boolean")
    bad = Inventory.deepClone(Catalog.locations.fort); bad.placement.siteSizes = {"huge"}
    fails(function() LocationDefinition.new(bad) end, "placement.siteSizes[1]")
    bad = Inventory.deepClone(Catalog.locations.fort); bad.actions = {[2] = {label = "Bad", action = "pray"}}
    fails(function() LocationDefinition.new(bad) end, "dense array")
    fails(function() PopulationProfile.new({id = "bad", residents = {}, actions = {}}) end, "unknown field actions")
    fails(function() NpcArchetype.new({id = "bad", troopType = "bandit", title = "Bandit", important = true,
        treasury = "300"}) end, ".treasury")
    bad = Inventory.deepClone(Catalog.parties.warrior_retinue); bad.placement = "teleport"
    fails(function() PartyTemplate.new(bad) end, ".placement")
    assert(Actions.validateHandlers())
    local handlerModule = require("src.systems.location_actions.examine_wizard_tower")
    local previousHandler = handlerModule.execute
    handlerModule.execute = false
    fails(function() Actions.validateHandlers() end, "Missing location action handler")
    handlerModule.execute = previousHandler
    fails(function() Actions.resolve("missing_action") end, "Unknown location action")
    local action = Catalog.locations.wizard_tower.actions[1]
    local originalAction = action.action
    action.action = "missing_action"
    fails(function() Catalog.validate() end, "Unknown location action")
    action.action = originalAction
    assert(Catalog.validate())

    Ecs.init(); Game.init(); Time.reset()
    local map = Map.new("typed-locations")
    local data = {seed = 1234, sites = {
        {id = "tower", x = 100, y = 100, definition = "wizard_tower"},
        {id = "fort", x = 700, y = 100, definition = "fort"},
        {id = "other_fort", x = 100, y = 700, definition = "fort", populationProfile = "wizard_tower"},
    }}
    map:setWorldGenerationData(data)
    Game.data.currentMap = map
    Populate.populate(map, data)
    local tower, fort, other = unpack(map.locations)
    assert(tower.type == "wizard_tower" and tower.definitionId == tower.type and not tower.discovered)
    assert(fort.type == "fort" and fort.definitionId == "fort")
    assert(not tower.facilities and not fort.facilities)
    assert(#tower.npcs == 1 and tower.npcs[1].archetypeId == "tower_wizard")
    assert(not Rules.canHostCaravan(tower) and not Rules.canRecover(tower))
    assert(Rules.canHostCaravan(fort) and Rules.canRecover(fort) and Rules.recruitmentPool(fort) == "castle")
    local previousRandom, oldFaction = math.random, fort.faction
    math.random = function(low) return low and 1 or 0.6 end
    fort.faction = "neutral"
    local recruited
    local recruitmentOk, recruitmentError = pcall(function()
        local _, _, choices = require("src.systems.recruitment_system").roll(fort)
        recruited = choices
    end)
    math.random, fort.faction = previousRandom, oldFaction
    assert(recruitmentOk, recruitmentError)
    assert(#recruited == 2 and recruited[1] == "knight", "fort recruitment ignored its explicit pool")

    -- A population override changes inhabitants; the fort keeps its own action list.
    local Screen = require("src.ui.screens.location_screen")
    local towerScreen = Screen.new(tower, function() end)
    local button
    for _, candidate in ipairs(towerScreen.buttons) do
        if candidate.text == "Examine the tower" then button = candidate end
    end
    assert(button and not button.disabled)
    local fortScreen = Screen.new(other, function() end)
    local audience = false
    for _, candidate in ipairs(fortScreen.buttons) do
        assert(candidate.text ~= "Examine the tower")
        if candidate.text == "Request Audience" then audience = true end
    end
    assert(audience and other.npcs[1].archetypeId == "tower_wizard")
    local States = require("src.core.state_manager")
    local oldPush, target, params = States.push, nil, nil
    States.push = function(name, arguments) target, params = name, arguments end
    local ok, err = pcall(button.callback)
    States.push = oldPush
    assert(ok, err)
    assert(target == "dialogue" and params.location == tower and params.dialogueTree.speaker == tower.name)
    towerScreen:draw(); fortScreen:draw()

    -- Both service recovery and goal destination selection read the explicit rule.
    local healer = Factory.create(Ecs.campaign, "healer")
    assert(Locations.addNPC(tower, healer))
    local patient = Factory.create(Ecs.campaign, "traveler", {}, {stats = {health = 100}, hp = 30, treasury = 100})
    assert(Locations.addNPC(tower, patient))
    Goals.update(0.1, map)
    assert(Services.isProviding(healer, {world = Ecs.campaign, map = map}))
    local goal = patient.npc_goals.goals[1]
    Services.tryRecoveryHealing(patient, goal, {world = Ecs.campaign, map = map})
    assert(patient.hp == 30 and patient.treasury == 100)
    Catalog.locations.wizard_tower.rules.recoveryStop = true
    Services.tryRecoveryHealing(patient, goal, {world = Ecs.campaign, map = map})
    assert(patient.hp == 70 and patient.treasury == 90)
    Catalog.locations.wizard_tower.rules.recoveryStop = false

    local traveler = Factory.create(Ecs.campaign, "traveler", {}, {stats = {health = 100}, hp = 30})
    local party = Party.create(Ecs.campaign, "Injured travelers", traveler.id)
    Parties.addActor(party, traveler); party.x, party.y = 150, 100
    assert(map:addParty(party))
    Goals.update(1.1, map)
    assert(party.world_activity.params.destinationLocationId == fort.id, "recovery chose a tower with recoveryStop=false")

    -- Real caravan evaluation accepts a true fort ID; no castle alias is necessary.
    local sponsor = Factory.create(Ecs.campaign, "wealthy_merchant")
    assert(Locations.addNPC(fort, sponsor))
    Goals.update(1.1, map)
    local preparation = assert(sponsor.caravan_formation.preparation)
    assert(preparation.destinationLocationId == other.id, "caravan ignored explicit location rules")
    local player = Unit.create(Ecs.campaign, "player"); player:ensure("player")
    local playerParty = Party.create(Ecs.campaign, "Player", player.id)
    Parties.addActor(playerParty, player); playerParty.x, playerParty.y = tower.x, tower.y
    assert(map:addParty(playerParty))
    require("src.systems.visibility_system").update(playerParty, map)
    assert(tower.discovered, "hidden typed location could not be discovered")
    assert(Catalog.validate())
end

return Scenario
