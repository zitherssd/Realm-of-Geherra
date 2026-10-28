local World = require("src.ecs.world")
local Events = require("src.systems.campaign.world_events")
local Knowledge = require("src.systems.knowledge.knowledge_system")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Parties = require("src.systems.parties.party_system")
local Map = require("src.world.map")
local Location = require("src.ecs.assemblages.location")
local Locations = require("src.systems.locations.location_system")
local Mode = require("src.debug.mode")
local Tools = require("src.debug.campaign_tools")
local Inspector = require("src.debug.inspector")
local Overlay = require("src.ui.screens.debug_overlay")
local Scenario = {}

local function battle(world, a, b)
    return Events.record(world, "battle_ended", {
        time = {day = 2, hour = 8}, x = 850, y = 310, battlefieldId = "battlefield_1",
        encounterId = "hidden_encounter", mapId = "hidden_map", subjectIds = {a.id, b.id},
        description = "Hidden full summary", ticks = 300, outcome = "victory", winnerPartyId = a.id,
        defeatedPartyIds = {b.id}, eliminatedPartyIds = {b.id},
        participants = {
            {partyId = a.id, name = "Secret victors", actorIds = {a.actors[1].id}, casualties = 1,
                technical = {hidden = true}},
            {partyId = b.id, name = "Secret defeated", actorIds = {b.actors[1].id}, casualties = 5}
        }
    })
end

function Scenario.run()
    local world = World.init()
    local map = Map.new("knowledge-map")
    local actor, companion = Unit.create(world, "player"), Unit.create(world, "companion")
    local troop = Unit.create(world, "soldier")
    local a, b = Party.create(world, "A"), Party.create(world, "B")
    Parties.addActor(a, actor)
    Parties.addActor(b, troop)
    map:addParty(a)
    map:addParty(b)
    local event = battle(world, a, b)
    assert(actor.memory and companion.memory and a.memory and b.memory)
    assert(not troop.memory, "Generic troops acquired personal memory")
    assert(Parties.getLeader(b) == troop and not troop.memory, "Leadership granted personal memory")
    assert(not Knowledge.learn(troop, event.id, {"location"}, world))
    assert(not Knowledge.knows(actor, event.id, world), "Recording an event granted knowledge")
    assert(not Knowledge.getKnownEvent(actor, event.id, world))
    assert(not Knowledge.getKnownEvent(actor, "event_missing", world))
    assert(not Knowledge.learn(actor, "event_missing", {}, world))
    assert(not Knowledge.learn(actor, event.id, {location = true, subjectIds = true}, world))
    assert(not Knowledge.knows(actor, event.id, world), "Invalid categories partially learned an event")

    -- Existence and partial location knowledge, on actors and on parties.
    assert(Knowledge.learn(actor, event.id, nil, world))
    local view = Knowledge.getKnownEvent(actor, event.id, world)
    assert(view.id == event.id and view.type == "battle_ended")
    local count = 0
    for _ in pairs(view) do count = count + 1 end
    assert(count == 2, "Existence knowledge revealed facts")
    assert(Knowledge.learn(actor, event.id, {"location"}, world))
    view = Knowledge.getKnownEvent(actor, event.id, world)
    assert(view.x == 850 and view.y == 310 and view.battlefieldId == "battlefield_1")
    assert(not view.time and not view.participants and not view.outcome and not view.winnerPartyId)
    assert(not view.encounterId and not view.mapId and not view.subjectIds and not view.description and not view.ticks)
    view.x = 0
    assert(Knowledge.getKnownEvent(actor, event.id, world).x == 850)
    assert(Knowledge.learn(a, event.id, {participants = true}, world))
    view = Knowledge.getKnownEvent(a, event.id, world)
    assert(view.participants[1].name == "Secret victors" and not view.participants[1].casualties)
    assert(not view.participants[1].technical and not view.casualties and not view.outcome and not view.x)
    assert(not Knowledge.knows(companion, event.id, world) and not Knowledge.knows(b, event.id, world))

    -- Directional sharing takes the union; repeats do not duplicate entries.
    assert(Knowledge.share(actor, a, event.id, world))
    assert(Knowledge.share(actor, a, event.id, world))
    view = Knowledge.getKnownEvent(a, event.id, world)
    assert(view.x and view.participants and not view.outcome)
    assert(not Knowledge.getKnownEvent(actor, event.id, world).participants, "Sharing was bidirectional")
    assert(not Knowledge.share(companion, actor, event.id, world))
    assert(#Knowledge.getKnownEvents(a, world, "battle_ended") == 1)
    assert(#Knowledge.getKnownEvents(a, world, "party_arrived") == 0)
    assert(Knowledge.learn(actor, event.id, {outcome = true, time = true}, world))
    view = Knowledge.getKnownEvent(actor, event.id, world)
    assert(view.x == 850 and view.time.day == 2 and view.outcome == "victory")
    assert(view.winnerPartyId == a.id and view.casualties[b.id] == 5 and not view.participants)
    assert(not Knowledge.getKnownEvent(a, event.id, world).outcome, "Source expansion propagated automatically")
    assert(Knowledge.share(a, actor, event.id, world))
    view = Knowledge.getKnownEvent(actor, event.id, world)
    view.participants[1].actorIds[1] = "changed"
    view.defeatedPartyIds[1], view.time.day, view.casualties[b.id] = "changed", 99, 0
    local details = Knowledge.getKnownDetails(actor, event.id, world)
    details.location, details.subjectIds = false, true
    local all = Knowledge.getKnownEvents(actor, world)
    all[1].participants[1].name = "changed"
    assert(Knowledge.getKnownEvent(actor, event.id, world).participants[1].name == "Secret victors")
    assert(Knowledge.getKnownDetails(actor, event.id, world).location)
    assert(Events.get(world, event.id).participants[1].actorIds[1] == actor.id)
    assert(Events.get(world, event.id).defeatedPartyIds[1] == b.id)
    assert(Events.get(world, event.id).time.day == 2 and Events.get(world, event.id).participants[2].casualties == 5)
    assert(not Knowledge.learn(actor, event.id, {location = false}, world))
    actor.memory.knownEvents[event.id].details.subjectIds = true
    assert(not Knowledge.getKnownEvent(actor, event.id, world).subjectIds)
    assert(Knowledge.share(actor, companion, event.id, world))
    assert(not companion.memory.knownEvents[event.id].details.subjectIds)
    actor.memory.knownEvents[event.id].details.subjectIds = nil
    -- Normal Concord snapshots contain no provenance pointers or event tables.
    local snapshot = actor.memory:serialize()
    assert(snapshot.knownEvents[event.id].details.location and not snapshot.world)
    assert(not snapshot.knownEvents[event.id].participants and not snapshot.__entity)

    -- Names/casualties remain historical after participant removal and membership changes.
    Parties.removeActor(a, actor)
    Parties.addActor(b, actor)
    Parties.setLeader(b, actor.id)
    assert(Knowledge.knows(actor, event.id, world) and Knowledge.knows(a, event.id, world))
    assert(not Knowledge.knows(b, event.id, world), "Membership synchronized memory")
    troop:destroy()
    a:destroy()
    assert(Knowledge.getKnownEvent(actor, event.id, world).participants[1].name == "Secret victors")
    assert(not Knowledge.getKnownEvent(a, event.id, world), "Destroyed owner still readable")

    -- F1 uses the filtered projection, offers actor navigation and a small grant form.
    local location = Location.create(world, nil, "Test village")
    -- Use another personal owner so its inspector starts with partial knowledge.
    companion = Unit.create(world, "companion")
    Locations.addNPC(location, companion)
    map:addLocation(location)
    Mode.enabled = false
    assert(not Tools.grantKnowledge(map, "unit", companion.id, event.id, {location = true}))
    Mode.enabled = true
    local overlay = Overlay.new()
    overlay:inspect("location", location.id)
    local foundActorLink = false
    for _, row in ipairs(overlay:rows(map)) do
        if row.text:find("Inspect NPC:", 1, true) then row.action(); foundActorLink = true; break end
    end
    assert(foundActorLink and overlay.target.id == companion.id)
    overlay:editMemory("unit", companion.id)
    assert(overlay:blocksWorldInput() and overlay:keypressed("tab"))
    overlay:textinput(event.id)
    assert(overlay.form.eventId == event.id)
    for _, row in ipairs(overlay:rows(map)) do if row.key == "location" then row.action() end end
    overlay:draw(map)
    for _, row in ipairs(overlay:rows(map)) do if row.key == "grant" then row.action(); break end end
    assert(overlay.view == "inspect" and not overlay:blocksWorldInput())
    local text = table.concat(Inspector.lines(map, "unit", companion.id), "\n")
    assert(text:find("Memory: personal", 1, true) and text:find(event.id, 1, true))
    assert(text:find("Details: location", 1, true) and text:find("850.0, 310.0", 1, true))
    assert(not text:find("Secret", 1, true) and not text:find("victory", 1, true))
    assert(not text:find("hidden_", 1, true) and not text:find("Hidden full summary", 1, true))
    assert(table.concat(Inspector.lines(map, "party", b.id), "\n"):find("Memory: party | Known events: 0", 1, true))
    overlay:draw(map)
    assert(overlay:keypressed("escape") and not overlay.view)
    Mode.enabled = false

    -- Unknown types cannot expose arbitrary payload fields. Campaign ID collisions
    -- never make an owner know a different campaign's event_1.
    local future = Events.record(world, "future_type", {time = {day = 3, hour = 4}, secret = "hidden"})
    assert(Knowledge.learn(actor, future.id, {}, world))
    assert(not Knowledge.learn(actor, future.id, {"secret"}, world))
    assert(not Knowledge.getKnownEvent(actor, future.id, world).secret)
    local malformed = Events.record(world, "battle_ended", {
        time = {day = 3, hour = 5}, x = {secret = "hidden"},
        battlefieldId = {secret = "hidden"}, winnerPartyId = {secret = "hidden"},
        participants = {{name = {secret = "hidden"}, actorIds = {{secret = "hidden"}}}}
    })
    assert(Knowledge.learn(actor, malformed.id, {"location", "participants", "outcome"}, world))
    view = Knowledge.getKnownEvent(actor, malformed.id, world)
    assert(not view.x and not view.battlefieldId and not view.winnerPartyId)
    assert(not view.participants[1].name and #view.participants[1].actorIds == 0)
    local otherWorld = World.init()
    local other = Unit.create(otherWorld, "player")
    local otherEvent = Events.record(otherWorld, "battle_ended", {time = {day = 1, hour = 0}, x = 999})
    assert(otherEvent.id == event.id)
    assert(not Knowledge.getKnownEvent(actor, event.id, otherWorld))
    assert(not Knowledge.learn(actor, event.id, {"location"}, otherWorld))
    assert(not Knowledge.share(actor, other, event.id, world))
    assert(not Knowledge.share(actor, other, event.id, otherWorld))
    assert(not Knowledge.knows(other, event.id, otherWorld))
    -- Component provenance rejects accidentally reusing memory in another world.
    other.memory = actor.memory
    assert(not Knowledge.getKnownEvent(other, event.id, otherWorld))
    assert(not Knowledge.learn(other, event.id, {}, otherWorld))
end

return Scenario
