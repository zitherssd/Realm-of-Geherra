local World = require("src.ecs.world")
local Context = require("src.game.game_context")
local Initializer = require("src.game.game_initializer")
local Events = require("src.systems.campaign.world_events")
local Knowledge = require("src.systems.knowledge.knowledge_system")
local Encounters = require("src.systems.campaign.world_encounter_system")
local Visibility = require("src.systems.parties.visibility_system")
local Remains = require("src.systems.battlefield.battlefield_remains_system")
local Parties = require("src.systems.parties.party_system")
local Bus = require("src.core.event_bus")
local Party = require("src.ecs.assemblages.party")
local Unit = require("src.ecs.assemblages.unit")
local Map = require("src.world.map")
local Scenario = {}

local function party(world, map, name, x)
    local p = Party.create(world, name)
    p.x, p.y = x or 5000, 0
    Parties.addActor(p, Unit.create(world, "companion"))
    Parties.addActor(p, Unit.create(world, "soldier"))
    map:addParty(p)
    return p, p.actors[1], p.actors[2]
end

local function fullyKnown(owner, eventId, world)
    local flags = assert(Knowledge.getKnownDetails(owner, eventId, world))
    for _, detail in ipairs({"time", "location", "participants", "outcome"}) do assert(flags[detail]) end
    assert(#Knowledge.getKnownEvents(owner, world, "battle_ended") == 1)
end

local function testStarterBattleAndDiscovery()
    Bus.init()
    Context.init()
    local world = World.init()
    local map = Map.new("battle-knowledge")
    Initializer._createStarterParties(map) -- Exercise the real Forest Bandits classification.
    local bandits, merchantParty = map:getParties()[1], map:getParties()[2]
    local leader, soldier, merchant = bandits.actors[1], bandits.actors[2], merchantParty.actors[1]
    assert(bandits.name == "Forest Bandits" and leader.troopType == "bandit" and leader.memory)
    assert(not soldier.memory, "Starter troops unexpectedly have personal memory")
    local player, playerActor = party(world, map, "Distant player")
    local observer, observerActor, observerTroop = party(world, map, "Later observer", 6000)
    local distant, distantActor = party(world, map, "Unrelated party", 9000)
    Context.data.playerParty, Context.data.currentMap = player, map
    -- Ensure cleanup can destroy identities before acquisition; history must use
    -- the captured roster and defeated owners must never acquire knowledge.
    Bus.subscribe("party_killed", function(id)
        if id == merchantParty.id then merchantParty:destroy(); merchant:destroy() end
    end)
    local ok, encounter = Encounters.start(map, bandits, merchantParty, {maxTicks = 1})
    assert(ok and Events.count(world) == 0 and #Knowledge.getKnownEvents(bandits, world) == 0)
    -- Controlled final HP exercises real result/loot/remains/finalization without
    -- depending on the separately tracked combat targeting/timeout failures.
    for _, unit in ipairs(encounter.runner.simulation.context.data.unitList) do
        if unit.team == "enemy" then unit.hp = 0 end
    end
    Encounters.update(0, map)
    local event = assert(Events.get(world, encounter.eventId))
    assert(event.outcome == "victory" and event.winnerPartyId == bandits.id)
    assert(event.participants[2].name == "Wandering Trader")
    assert(event.participants[2].actorIds[1] == merchant.id)
    fullyKnown(bandits, event.id, world)
    fullyKnown(leader, event.id, world)
    assert(not soldier.memory and not Knowledge.knows(merchantParty, event.id, world))
    assert(not Knowledge.knows(merchant, event.id, world))
    assert(not Knowledge.knows(distant, event.id, world) and not Knowledge.knows(distantActor, event.id, world))
    assert(not Knowledge.knows(observer, event.id, world) and not Knowledge.knows(player, event.id, world))
    Encounters.update(1, map)
    Encounters.update(1, map)
    assert(Events.count(world) == 1)
    fullyKnown(bandits, event.id, world)

    local site = assert(map:getBattlefieldRemains()[1])
    assert(site.id == event.battlefieldId and site.history.eventId == event.id)
    -- A second, unseen site's event must not leak when the first site is observed.
    local hiddenId, hiddenEncounter = "hidden-remains", "hidden-encounter"
    local hidden = Events.record(world, "battle_ended", {
        time = {day = 1, hour = 0}, mapId = map.id, encounterId = hiddenEncounter,
        battlefieldId = hiddenId, subjectIds = {hiddenId}, x = 20000, y = 20000, participants = {}
    })
    map:addBattlefieldRemains({id = hiddenId, history = {position = {x = 20000, y = 20000},
        encounterId = hiddenEncounter, eventId = hidden.id}, corpses = {}, inventory = {}, loot = {gold = 0}})
    observer.x, observer.y = site.history.position.x, site.history.position.y
    Visibility.update(player, map)
    fullyKnown(observer, event.id, world)
    fullyKnown(observerActor, event.id, world)
    assert(not observerTroop.memory)
    assert(not site.discovered and not site.currentlyVisible, "NPC sight exposed a player map marker")
    assert(not Knowledge.knows(player, event.id, world) and not Knowledge.knows(distant, event.id, world))
    assert(not Knowledge.knows(observer, hidden.id, world))

    player.x, player.y = observer.x, observer.y
    Visibility.update(player, map)
    fullyKnown(player, event.id, world)
    fullyKnown(playerActor, event.id, world)
    assert(site.discovered and site.currentlyVisible)
    assert(not Knowledge.knows(player, hidden.id, world))
    -- Link survives the existing remains snapshot/restore path. Legacy sites can
    -- also resolve the exact event by subject + encounter/map identity.
    Remains.restore(map, Remains.serialize(map))
    local restored = map:getBattlefieldRemains()[1]
    assert(restored.history.eventId == event.id)
    restored.history.eventId = nil
    distant.x, distant.y = observer.x, observer.y
    Visibility.update(player, map)
    fullyKnown(distant, event.id, world)
    fullyKnown(distantActor, event.id, world)
    -- Depleting resources never changes historical knowledge.
    restored.corpses, restored.inventory, restored.loot = {}, {}, {gold = 0}
    for _ = 1, 3 do Visibility.update(player, map) end
    assert(Events.count(world) == 2)
    fullyKnown(observer, event.id, world)
    assert(Knowledge.getKnownEvent(observer, event.id, world).casualties[merchantParty.id] == 2)

    -- A stale/destroyed observer in a map list and a site with no associated
    -- history are both harmless; an incorrect explicit association fails closed.
    observer:destroy()
    map:addBattlefieldRemains({id = "no-event", history = {position = {x = player.x, y = player.y}}})
    restored.history.eventId = hidden.id
    local newcomer, newcomerActor = party(world, map, "Newcomer", player.x)
    newcomer.y = player.y
    Visibility.update(player, map)
    assert(not Knowledge.knows(newcomer, event.id, world) and not Knowledge.knows(newcomerActor, hidden.id, world))
    assert(Events.count(world) == 2)
    Bus.init()
end

local function testSurvivalAndOptionalMemory()
    for _, outcome in ipairs({"timeout", "draw"}) do
        Bus.init()
        Context.init()
        local world, map = World.init(), Map.new("knowledge-" .. outcome)
        local a, fallen, troop = party(world, map, "A", 100)
        local b, survivor = party(world, map, "B", 100)
        b:remove("memory") -- Personal acquisition works independently of party memory.
        local _, encounter = Encounters.start(map, a, b, {maxTicks = 0})
        for _, unit in ipairs(encounter.runner.simulation.context.data.unitList) do
            if outcome == "draw" or unit.id == fallen.id then unit.hp = 0 end
        end
        Encounters.update(0, map)
        local event = Events.get(world, encounter.eventId)
        assert(event.outcome == outcome and not b.memory and not troop.memory)
        assert(not Knowledge.knows(fallen, event.id, world), "Defeated actor learned the battle")
        if outcome == "timeout" then
            fullyKnown(a, event.id, world)
            fullyKnown(survivor, event.id, world)
        else
            assert(not Knowledge.knows(a, event.id, world) and not Knowledge.knows(survivor, event.id, world))
        end
        Encounters.update(1, map)
        assert(Events.count(world) == 1)
    end
end

function Scenario.run()
    testStarterBattleAndDiscovery()
    testSurvivalAndOptionalMemory()
end

return Scenario
