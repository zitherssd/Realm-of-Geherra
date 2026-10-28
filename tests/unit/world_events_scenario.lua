local World = require("src.ecs.world")
local Events = require("src.systems.campaign.world_events")
local Party = require("src.ecs.assemblages.party")
local Unit = require("src.ecs.assemblages.unit")
local Parties = require("src.systems.parties.party_system")
local Encounters = require("src.systems.campaign.world_encounter_system")
local Map = require("src.world.map")
local Context = require("src.game.game_context")
local Bus = require("src.core.event_bus")
local Viewer = require("src.ui.screens.world_event_viewer")
local WorldState = require("src.game.states.world_state")
local Input = require("src.core.input")
local Text = require("src.ui.world_event_text")
local Scenario = {}

local function party(world, map, name)
    local p = Party.create(world, name)
    p.x, p.y = 100, 120
    for _ = 1, 2 do Parties.addActor(p, Unit.create(world, "soldier")) end
    map:addParty(p)
    return p
end

function Scenario.run()
    Bus.init()
    Context.init()
    local world = World.init()
    local data = {time = {day = 2, hour = 8}, subjectIds = {"location_7"}, details = {value = 1}}
    local first = Events.record(world, "party_arrived", data, "arrival:1")
    data.details.value = 8
    first.details.value = 9
    assert(Events.get(world, first.id).details.value == 1)
    assert(Events.record(world, "party_arrived", data, "arrival:1").id == first.id)
    local older = Events.record(world, "party_departed", {time = {day = 1, hour = 6}})
    assert(first.id ~= older.id and Events.count(world) == 2)
    assert(Events.getAll(world)[1].id == older.id)
    assert(#Events.getByType(world, "party_arrived") == 1)
    assert(#Events.getBySubject(world, "location_7") == 1)
    local snapshot = Events.serialize(world)
    snapshot.events[1].type = "corrupted"
    assert(Events.get(world, older.id).type == "party_departed")
    assert(not pcall(Events.record, world, "bad", {time = data.time, bad = function() end}))
    assert(not pcall(Events.record, world, "bad", {time = data.time, bad = setmetatable({}, {})}))
    local another = World.init()
    assert(Events.count(another) == 0 and Events.count(world) == 2)

    for _, outcome in ipairs({"victory", "draw", "timeout"}) do
        world = World.init()
        local map = Map.new("events-" .. outcome)
        local a, b = party(world, map, "Patrol"), party(world, map, "Caravan")
        local bId, actorId = b.id, b.actors[1].id
        local _, encounter = Encounters.start(map, a, b, {maxTicks = 2, ticksPerWorldHour = 1})
        Encounters.update(0.5, map)
        assert(Events.count(world) == 0, "active encounter recorded history")
        -- Exercise real runner outcome resolution and campaign finalization without
        -- depending on the known combat targeting/timeout failure.
        for index, unit in ipairs(encounter.runner.simulation.context.data.unitList) do
            if outcome == "draw" or (outcome == "victory" and unit.team == "enemy") or
                (outcome == "timeout" and index == 1) then unit.hp = 0 end
        end
        Context.data.time = {day = 3, hour = 14.5}
        Encounters.update(2, map)
        local event = Events.get(world, encounter.eventId)
        assert(event and event.outcome == outcome and event.time.day == 3 and event.time.hour == 14.5)
        assert(event.participants[2].name == "Caravan")
        assert(#Events.getBySubject(world, actorId) == 1)
        assert(event.battlefieldId and #map.battlefieldRemains[1].corpses > 0)
        map.battlefieldRemains[1].corpses = {}
        map.battlefieldRemains[1].loot.gold = 0
        assert(Events.get(world, event.id).participants[2].name == "Caravan")
        assert(Events.get(world, event.id).participants[1].casualties == event.participants[1].casualties)
        if outcome == "victory" then
            assert(event.winnerPartyId == a.id and event.defeatedPartyIds[1] == bId)
            assert(event.eliminatedPartyIds[1] == bId)
            b:destroy()
            assert(Events.get(world, event.id).participants[2].name == "Caravan")
            assert(Text.describe(event) == "Patrol defeated Caravan")
        else assert(event.winnerPartyId == nil) end
        Encounters.update(2, map)
        Bus.emit("party_encounter_finished", {encounterId = encounter.id})
        assert(Events.count(world) == 1 and encounter.runner == nil)
        assert(Events.record(world, "battle_ended", {}, "battle_ended:" .. encounter.id).id == event.id)
    end

    world = World.init()
    local map = Map.new("no-remains")
    local a, b = party(world, map, "A"), party(world, map, "B")
    local _, encounter = Encounters.start(map, a, b, {maxTicks = 0})
    Encounters.update(0, map)
    assert(Events.get(world, encounter.eventId).battlefieldId == nil)

    local viewer = Viewer.new(world)
    viewer:draw()
    for i = 1, 100 do Events.record(world, "example", {time = {day = 4, hour = 0}, description = "Event " .. i}) end
    viewer:draw()
    local left = viewer:layout()
    viewer:mousepressed(left.x + 10, left.y + 10, 1)
    assert(viewer.selectedId == Events.getAt(world, 101).id)
    viewer.scroll = 100000
    viewer:draw()
    assert(viewer.scroll < 100000)
    local count = Events.count(world)
    Input.keypressed("w")
    WorldState.keypressed("f2")
    assert(WorldState.eventViewer and not Input.isKeyDown("w"))
    WorldState.keypressed("f2", true)
    assert(WorldState.eventViewer)
    assert(WorldState.keypressed("i") and not Input.isKeyDown("i"))
    WorldState.keypressed("escape")
    assert(not WorldState.eventViewer)
    WorldState.keypressed("f2")
    WorldState.keypressed("f2")
    assert(not WorldState.eventViewer and Events.count(world) == count)
    Viewer.new(World.init()):draw()
end

return Scenario
