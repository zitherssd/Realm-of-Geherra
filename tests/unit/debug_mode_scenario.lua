local EcsWorld = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Location = require("src.ecs.assemblages.location")
local PartySystem = require("src.systems.party_system")
local GoalSystem = require("src.systems.goal_system")
local Activities = require("src.systems.world_activity_system")
local TimeSystem = require("src.systems.time_system")
local Map = require("src.world.map")
local Camera = require("src.world.camera")
local GameContext = require("src.game.game_context")
local StateManager = require("src.core.state_manager")
local WorldState = require("src.game.states.world_state")
local Mode = require("src.debug.mode")
local Tools = require("src.debug.campaign_tools")
local Inspector = require("src.debug.inspector")
local Overlay = require("src.ui.screens.debug_overlay")

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
    assert(Tools.configureGoal(map, party.id, actor.id, overlay.form))
    assert(actor.npc_goals.goals[1].amount == 250 and actor.npc_goals.capabilities.raid)
    overlay.form.roam = true
    overlay.form.radius = "-1"
    assert(not Tools.configureGoal(map, party.id, actor.id, overlay.form))
    overlay.form.radius, overlay.form.durationSeconds = "300", "30"
    assert(Tools.configureGoal(map, party.id, actor.id, overlay.form))
    assert(actor.npc_goals.capabilities.roam and actor.npc_goals.goals[1].roam.originX == 100)
    assert(actor.npc_goals.goals[1].roam.durationSeconds == 30)

    local oldState = actor.npc_goals.goals
    assert(not Tools.configureGoal(map, party.id, actor.id, {type = "acquire_gold", amount = "-1", priority = "0"}))
    assert(actor.npc_goals.goals == oldState, "invalid form mutated existing goals")
    party.activeEncounterId = "reserved"
    assert(not Tools.configureGoal(map, party.id, actor.id, overlay.form))
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
    assert(Tools.configureGoal(map, party.id, actor.id, overlay.form))
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
