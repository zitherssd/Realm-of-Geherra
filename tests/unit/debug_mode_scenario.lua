local EcsWorld = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Location = require("src.ecs.assemblages.location")
local PartySystem = require("src.systems.parties.party_system")
local GoalSystem = require("src.systems.goals.goal_system")
local Activities = require("src.systems.world_activities.world_activity_system")
local TimeSystem = require("src.systems.campaign.time_system")
local Map = require("src.world.map")
local Camera = require("src.world.camera")
local GameContext = require("src.game.game_context")
local StateManager = require("src.core.state_manager")
local WorldState = require("src.game.states.world_state")
local Mode = require("src.debug.mode")
local Tools = require("src.debug.campaign_tools")
local Inspector = require("src.debug.inspector")
local Overlay = require("src.ui.screens.debug_overlay")
local Definitions = require("src.systems.goals.goal_definitions")

local Scenario = {}

function Scenario.run()
    local world = EcsWorld.init()
    local map = Map.new("debug-map")
    local actor = Unit.create(world, "soldier")
    local party = Party.create(world, "Test patrol")
    PartySystem.addActor(party, actor)
    party.x, party.y, party.hostile = 100, 100, true
    assert(map:addParty(party))
    local origin = Location.create(world, nil, "Origin")
    local destination = Location.create(world, nil, "Destination")
    origin.x, origin.y, origin.siteId = 100, 100, "a"
    destination.x, destination.y, destination.siteId = 500, 100, "b"
    map:addLocation(origin)
    map:addLocation(destination)
    map.worldGen = {roads = {{from = "a", to = "b", points = {{x = 100, y = 100}, {x = 500, y = 100}}}}}
    GameContext.data.currentMap, GameContext.data.playerParty = map, nil
    local camera = Camera.new(800, 600)
    camera.x, camera.y = 100, 100
    camera:setZoom(2)

    Mode.enabled = false
    assert(#Tools.hitTest(map, camera, 400, 300) == 0)
    assert(not Tools.configureGoal(map, party.id, actor.id, {type = "acquire_gold", amount = "100", priority = "0"}))
    assert(not actor.npc_goals)
    assert(StateManager.keypressed("f1") and Mode.enabled)
    StateManager.keypressed("f1", true)
    assert(Mode.enabled, "key repeat toggled debug mode a second time")
    local hits = Tools.hitTest(map, camera, 400, 300)
    assert(#hits == 2, "overlapping location/party could not both be selected")
    assert(#Tools.hitTest(map, camera, 426, 300) == 0, "hit radius did not match screen-space markers")
    local overlay = Overlay.new()
    assert(overlay:mousepressed(map, camera, 400, 300, 2))
    assert(overlay.view == "menu" and overlay:blocksWorldInput())
    local function control(key)
        for _, row in ipairs(overlay:rows(map)) do if row.key == key then return row end end
    end
    local function cancel()
        for _, row in ipairs(overlay:rows(map)) do
            if row.kind == "button" and row.text == "Cancel" then row.action(); return end
        end
        error("Missing cancel action")
    end
    for _, row in ipairs(overlay:rows(map)) do
        assert(not row.text:find("Configure", 1, true), "party menu bypassed NPC inspection")
    end
    local follower = Unit.create(world, "soldier")
    follower:give("memory")
    PartySystem.addActor(party, follower)
    local resident = Unit.create(world, "soldier")
    resident:give("memory")
    origin.npcs[#origin.npcs + 1] = resident
    local troop = Unit.create(world, "soldier")
    troop.name = "Regular troop display name"
    GoalSystem.addGoal(troop, {type = "rest_and_recover"})
    PartySystem.addActor(party, troop)
    local regularResident = Unit.create(world, "soldier")
    origin.npcs[#origin.npcs + 1] = regularResident
    overlay:inspect("party", party.id)
    assert(not control("configure_goal"), "party inspector still offers direct goal editing")
    assert(control("inspect_npc:" .. actor.id), "leader without personal memory was missing")
    assert(control("inspect_npc:" .. follower.id), "party NPC was missing")
    assert(not control("inspect_npc:" .. troop.id), "ordinary troop with a name/goals exposed NPC inspection")
    control("inspect_npc:" .. actor.id).action()
    assert(overlay.target.kind == "unit" and overlay.target.id == actor.id)
    assert(control("configure_goal") and control("grant_knowledge"))
    assert(table.concat(Inspector.lines(map, "unit", actor.id), "\n"):find("HP:", 1, true))
    control("configure_goal").action()
    assert(overlay.view == "editor" and overlay.target.kind == "unit")
    party.leaderId = follower.id
    local saved, reason = Tools.configureActorGoals(map, actor.id, overlay.goalForms,
        overlay.capabilities, overlay.commandPartyId)
    assert(not saved and reason:find("leader changed", 1, true))
    party.leaderId = actor.id
    cancel()
    assert(overlay.view == "inspect" and overlay.target.id == actor.id)

    overlay:inspect("location", origin.id)
    assert(not control("inspect_npc:" .. regularResident.id), "ordinary location unit exposed NPC inspection")
    control("inspect_npc:" .. resident.id).action()
    assert(overlay.target.kind == "unit" and overlay.target.id == resident.id)
    control("grant_knowledge").action()
    assert(overlay.view == "memory" and overlay.target.id == resident.id)
    cancel()
    control("configure_goal").action()
    assert(#overlay.goalForms == 0, "resident inherited party leader default goals")
    overlay:newGoal(map, "provide_service")
    overlay.capabilities.heal = true
    control("apply").action()
    assert(overlay.view == "inspect" and overlay.target.kind == "unit" and overlay.target.id == resident.id)
    assert(resident.npc_goals.goals[1].type == "provide_service" and resident.npc_goals.capabilities.heal)
    assert(not actor.npc_goals, "resident editing changed the leader")

    assert(Activities.start(party, "travel", {destinationLocationId = destination.id}, map))
    local sequence = party.world_activity.sequence
    overlay:inspect("party", party.id)
    control("inspect_npc:" .. follower.id).action()
    control("configure_goal").action()
    overlay:newGoal(map, "rest_and_recover")
    control("apply").action()
    assert(follower.npc_goals.goals[1].type == "rest_and_recover")
    assert(party.world_activity.status == "active" and party.world_activity.sequence == sequence,
        "editing a follower cancelled the leader's activity")
    party.activeEncounterId = "reserved"
    assert(not Tools.configureActorGoals(map, follower.id, {}, {}))
    party.activeEncounterId = nil
    GameContext.data.playerParty = party
    assert(not Tools.configureActorGoals(map, follower.id, {}, {}))
    GameContext.data.playerParty = nil
    Activities.cancel(party, "test_cleanup")
    Activities.update(0, map)
    Activities.update(Activities.terminalRetryCooldownSeconds, map)
    PartySystem.removeActor(party, follower)
    follower:destroy()
    PartySystem.removeActor(party, troop)
    troop:destroy()
    table.remove(origin.npcs)
    regularResident:destroy()
    table.remove(origin.npcs)
    resident:destroy()

    overlay:edit(map, party.id)
    assert(overlay.view == "editor")
    overlay:layout(map)
    for _, row in ipairs(overlay.controls) do
        if row.key == "amount" then
            overlay:mousepressed(map, camera, row.x + 10, row.y + 10, 1)
            break
        end
    end
    assert(overlay.focus == "amount" and overlay.selectAll)
    overlay:textinput("250")
    assert(overlay.form.amount == "250" and overlay:keypressed("w"), "form leaked gameplay input")
    overlay:textinput("oops")
    assert(overlay.form.amount == "250")
    assert(Tools.configureGoals(map, party.id, actor.id, overlay.goalForms, overlay.capabilities))
    assert(actor.npc_goals.goals[1].amount == 250 and actor.npc_goals.capabilities.raid)
    overlay.form.roam = true
    overlay.capabilities.roam = true
    overlay.form.radius = "-1"
    assert(not Tools.configureGoals(map, party.id, actor.id, overlay.goalForms, overlay.capabilities))
    overlay.form.radius, overlay.form.durationSeconds = "300", "30"
    assert(Tools.configureGoals(map, party.id, actor.id, overlay.goalForms, overlay.capabilities))
    assert(actor.npc_goals.capabilities.roam and actor.npc_goals.goals[1].roam.originX == 100)
    assert(actor.npc_goals.goals[1].roam.durationSeconds == 30)

    -- The registry drives runtime construction and UI fields, including future types.
    local catalog = {}
    overlay.view = "goal_catalog"
    for _, row in ipairs(overlay:rows(map)) do catalog[#catalog + 1] = row.text end
    local listing = table.concat(catalog, "\n")
    for _, spec in ipairs(Definitions.list(Definitions.goals)) do
        assert(listing:find(spec.id, 1, true), "implemented goal missing from catalog")
    end
    Definitions.registerGoal("debug_fixture", {label = "Fixture", priority = 7,
        fields = {{key = "threshold", label = "Threshold", kind = "number", default = 12}}})
    Definitions.registerCapability("fixture", "Fixture")
    overlay:newGoal(map, "debug_fixture")
    assert(overlay.form.threshold == "12" and overlay.form.priority == "7")
    local foundField, foundCapability
    for _, row in ipairs(overlay:rows(map)) do
        if row.key == "threshold" then foundField = true end
        if row.key == "capability:fixture" then foundCapability = true; row.action() end
    end
    assert(foundField and foundCapability, "new registrations required editor changes")
    assert(Tools.configureGoals(map, party.id, actor.id, overlay.goalForms, overlay.capabilities))
    assert(#actor.npc_goals.goals == 2 and actor.npc_goals.goals[2].threshold == 12)
    assert(actor.npc_goals.capabilities.fixture)
    local unchanged = actor.npc_goals.goals
    overlay.form.threshold = "invalid"
    assert(not Tools.configureGoals(map, party.id, actor.id, overlay.goalForms, overlay.capabilities))
    assert(actor.npc_goals.goals == unchanged, "invalid later goal partially applied")
    Definitions.goals.debug_fixture, Definitions.capabilities.fixture = nil, nil
    table.remove(overlay.goalForms)
    overlay.form = overlay.goalForms[1]
    overlay.capabilities.fixture = nil
    assert(Tools.configureGoals(map, party.id, actor.id, overlay.goalForms, overlay.capabilities))
    -- Service and recovery goals are editable alongside ordinary goals; custom flags survive reopening.
    local goldForm = overlay.form
    overlay:newGoal(map, "provide_service")
    overlay:newGoal(map, "rest_and_recover")
    overlay.capabilities.heal, overlay.capabilities.custom_service = true, true
    assert(Tools.configureGoals(map, party.id, actor.id, overlay.goalForms, overlay.capabilities))
    overlay:edit(map, party.id)
    assert(#overlay.goalForms == 3 and overlay.capabilities.heal and overlay.capabilities.custom_service)
    assert(overlay.goalForms[2].priority == "20" and overlay.goalForms[3].priority == "1000")
    assert(not Tools.configureGoals(map, party.id, actor.id,
        {{type = "fulfill_obligation", serviceId = "invented", priority = "80"}}, {}))
    assert(#actor.npc_goals.goals == 3)
    assert(Tools.configureGoals(map, party.id, actor.id, {}, {heal = true}))
    assert(#actor.npc_goals.goals == 0 and actor.npc_goals.capabilities.heal)
    overlay.goalForms, overlay.form = {goldForm}, goldForm
    assert(Tools.configureGoals(map, party.id, actor.id, overlay.goalForms, overlay.capabilities))

    local oldState = actor.npc_goals.goals
    assert(not Tools.configureGoal(map, party.id, actor.id, {type = "acquire_gold", amount = "-1", priority = "0"}))
    assert(actor.npc_goals.goals == oldState, "invalid form mutated existing goals")
    party.activeEncounterId = "reserved"
    assert(not Tools.configureGoals(map, party.id, actor.id, overlay.goalForms, overlay.capabilities))
    assert(actor.npc_goals.goals == oldState, "editor replaced goals in an encounter")
    party.activeEncounterId = nil
    assert(not Tools.configureGoal(map, party.id, "different-leader", overlay.form))

    assert(map:stationParty(origin, party))
    local form = {type = "reach_location", destinationLocationId = destination.id, priority = "5", travel = true}
    assert(Tools.configureGoal(map, party.id, actor.id, form))
    GoalSystem.update(1, map)
    local previousGoal = actor.npc_goals.goals[1]
    assert(previousGoal.activity and party.world_activity.type == "travel")
    local invalid = {type = "reach_location", destinationLocationId = "missing", priority = "0"}
    assert(not Tools.configureGoal(map, party.id, actor.id, invalid))
    assert(party.world_activity.status == "active", "invalid edit stopped the running activity")
    assert(Tools.configureGoals(map, party.id, actor.id, overlay.goalForms, overlay.capabilities))
    assert(party.world_activity.status == "cancelled" and previousGoal.activity == nil)
    assert(previousGoal.lastOutcome.reason == "debug_goal_replaced", "replacement lost the original goal outcome")
    Activities.update(0, map)
    assert(party.world_activity.lastActivity.reason == "debug_goal_replaced")
    overlay:inspect("party", party.id)
    assert(not overlay:blocksWorldInput() and not overlay:keypressed("space"), "live inspector blocked world time")
    local description = table.concat(Inspector.lines(map, "party", party.id), "\n")
    assert(description:find("LEADER GOALS", 1, true) and description:find("debug_goal_replaced", 1, true))

    -- Render the actual overlay with the real LÖVE graphics context at the current resolution.
    overlay:draw(map)
    overlay:edit(map, party.id)
    overlay:draw(map)
    overlay:layout(map)
    local apply
    for _, row in ipairs(overlay.controls) do if row.key == "apply" then apply = row end end
    assert(apply and overlay.maxScroll >= 0)
    overlay:keypressed("escape")
    assert(not overlay.view)

    -- World input is frozen by the menu even if a movement key is held.
    GameContext.data.playerParty = party
    local previousMap, previousCamera, previousOverlay = WorldState.currentMap, WorldState.camera, WorldState.debugOverlay
    WorldState.currentMap, WorldState.camera, WorldState.debugOverlay = map, camera, overlay
    local previousFont = WorldState.font
    WorldState.font = love.graphics.newFont(14)
    overlay:mousepressed(map, camera, 400, 300, 2)
    GameContext.data.time = {day = 1, hour = 0}
    local x = party.x
    WorldState.update(1)
    assert(TimeSystem.isPaused() and party.x == x and TimeSystem.getHour() == 0)
    WorldState.draw()
    WorldState.debugModeChanged()
    assert(not overlay.view)
    assert(not Tools.configureGoal(map, party.id, actor.id, form), "editor controlled the player party")
    GameContext.data.playerParty = nil
    WorldState.currentMap, WorldState.camera, WorldState.debugOverlay = previousMap, previousCamera, previousOverlay
    WorldState.font = previousFont

    party:destroy()
    assert(not Tools.configureGoal(map, party.id, actor.id, form))
    assert(Inspector.lines(map, "party", party.id)[1]:find("removed"))
    StateManager.keypressed("f1")
    assert(not Mode.enabled)
    GameContext.data.currentMap = nil
end

return Scenario
