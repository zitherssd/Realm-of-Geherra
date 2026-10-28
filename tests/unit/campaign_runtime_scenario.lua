local Runtime = require("src.game.campaign.campaign_runtime")
local Ecs = require("src.ecs.world")
local Game = require("src.game.game_context")
local Bus = require("src.core.event_bus")
local Time = require("src.systems.campaign.time_system")
local Encounters = require("src.systems.campaign.encounter_system")
local Battles = require("src.systems.campaign.world_encounter_system")
local Activities = require("src.systems.world_activities.world_activity_system")
local Goals = require("src.systems.goals.goal_system")
local Services = require("src.systems.services.service_system")
local Caravans = require("src.systems.services.caravan_system")
local Recovery = require("src.systems.actors.recovery")
local AI = require("src.systems.parties.party_ai_system")
local Quests = require("src.systems.quests.quest_system")
local Party = require("src.ecs.assemblages.party")
local Map = require("src.world.map")
local WorldState = require("src.game.states.world_state")
local Input = require("src.core.input")
local Visibility = require("src.systems.parties.visibility_system")

local Scenario = {}

function Scenario.run()
    local originals = {}
    local function replace(owner, key, value)
        originals[#originals + 1] = {owner, key, owner[key]}
        owner[key] = value
    end
    local ok, err = xpcall(function()
        local world = Runtime.beginNewGame({debugCampaign = "normal"})
        local map = Map.new("runtime-test")
        map.width, map.height = 1000, 1000
        local player = Party.create(world, "Player")
        player.x, player.y = 100, 100
        map:addParty(player)
        Game.setPlayerParty(player)
        Game.data.currentMap = map
        local calls, reserved = {}, {}
        local function record(name) calls[#calls + 1] = name end
        local function expect(sequence)
            assert(table.concat(calls, ",") == sequence, table.concat(calls, ","))
            calls = {}
        end
        replace(Encounters, "update", function(seconds, distance)
            assert(math.abs(seconds - 0.2) < 1e-7 and distance == 8)
            record("random")
        end)
        replace(Recovery, "encounterReservations", function(m, p)
            assert(m == map and p == player)
            record("reservations")
            return reserved
        end)
        replace(Battles, "update", function(hours, m)
            assert(math.abs(hours - 0.3) < 1e-7 and m == map)
            record("battles")
        end)
        replace(world, "__flush", function() record("flush") end)
        replace(Services, "update", function(context)
            assert(context.world == world and context.map == map)
            record("services")
        end)
        replace(Caravans, "update", function(context)
            assert(context.world == world and context.map == map)
            record("caravans")
        end)
        replace(Caravans, "updateWork", function(context)
            assert(context.world == world and context.map == map)
            record("caravan_work")
        end)
        replace(Goals, "evaluate", function(seconds, m, p)
            assert(math.abs(seconds - 0.2) < 1e-7 and m == map and p == player)
            record("goals")
        end)
        replace(Recovery, "update", function(seconds, m, p, resting, snapshot)
            assert(math.abs(seconds - 0.2) < 1e-7 and m == map and p == player)
            assert(resting and snapshot == reserved)
            record("recovery")
        end)
        replace(Activities, "ensureDefaultActivities", function() record("defaults") end)
        replace(AI, "update", function(seconds)
            assert(math.abs(seconds - 0.2) < 1e-7)
            record("ai")
        end)
        local originalActivityUpdate = Activities.update
        replace(Activities, "update", function(seconds)
            assert(math.abs(seconds - 0.2) < 1e-7 or seconds == 0)
            record("activities")
        end)

        Time.setTimeScale(2)
        local hours, seconds = Runtime.advanceTime(0.1)
        assert(math.abs(hours - 0.3) < 1e-7 and math.abs(seconds - 0.2) < 1e-7)
        local snapshot = Runtime.updateEncounters(hours, seconds, map, player, 8)
        Runtime.update(seconds, map, player, true, snapshot)
        expect("random,reservations,battles,flush,services,caravans,goals,caravan_work,recovery,defaults,ai,activities")
        Runtime.updateEncounters(hours, seconds, map, player)
        expect("reservations,battles") -- Waiting/resting do not roll random encounters.
        Goals.update(seconds, map, player)
        expect("flush,goals") -- Standalone goal evaluation no longer schedules other systems.

        Time.setPaused(true)
        hours, seconds = Runtime.advanceTime(0.1)
        assert(hours == 0 and seconds == 0)
        Runtime.updateEncounters(hours, seconds, map, player, 8)
        Runtime.update(seconds, map, player, false)
        expect("activities")
        Time.setPaused(false)
        Time.setTimeScale(0)
        hours, seconds = Runtime.advanceTime(0.1)
        assert(hours == 0 and seconds == 0)
        Runtime.update(seconds, map, player, false)
        expect("activities")

        -- Actual terminal cleanup at zero time, with retry timers frozen afterward.
        local npc = Party.create(world, "Cancelled traveler")
        map:addParty(npc)
        npc.world_activity.type = "travel"
        npc.world_activity.status = "cancelled"
        npc.world_activity.reason = "test_cancel"
        npc.world_activity.sequence = 7
        Activities.update = originalActivityUpdate
        Runtime.update(0, map, player, false)
        assert(npc.world_activity.status == "idle" and npc.world_activity.type == nil)
        assert(npc.world_activity.lastActivity.sequence == 7)
        assert(npc.world_activity.lastActivity.reason == "test_cancel")
        local cooldown = npc.world_activity.retryCooldownSeconds
        assert(cooldown > 0)
        Runtime.update(0, map, player, false)
        assert(npc.world_activity.retryCooldownSeconds == cooldown)
        expect("")
        Activities.update = function() record("activities") end

        -- WorldState admits idle cleanup, but a modal skips the entire tick.
        WorldState.currentMap = map
        WorldState.camera = {update = function() end,
            screenToWorld = function() return 0, 0 end, getZoom = function() return 1 end}
        WorldState.isResting, WorldState.restInputLock = false, 0
        WorldState.interactionCooldowns = {}
        WorldState.pendingRaidBattle = nil
        WorldState.eventViewer, WorldState.serviceViewer = nil, nil
        WorldState.debugOverlay:close()
        replace(Input, "isKeyDown", function() return false end)
        replace(Visibility, "update", function() record("visibility") end)
        WorldState.update(0.1)
        expect("activities,visibility")
        WorldState.eventViewer = {}
        WorldState.update(0.1)
        assert(Time.isPaused())
        expect("")
        WorldState.eventViewer = nil
        Time.setTimeScale(2)
        WorldState.isResting, WorldState.restInputLock = true, 1
        WorldState.update(0.1)
        expect("reservations,battles,flush,services,caravans,goals,caravan_work,recovery,defaults,ai,activities,visibility")
        WorldState.isResting = false

        -- Repeated setup and bus replacement must leave exactly one of each listener.
        local killed, contacts, started = 0, 0, 0
        replace(Quests, "onPartyKilled", function() killed = killed + 1 end)
        replace(Encounters, "_onPartyKilled", function() killed = killed + 1 end)
        replace(Battles, "_onPartyContact", function() contacts = contacts + 1 end)
        replace(Activities, "_onEncounterStarted", function() started = started + 1 end)
        local resets = 0
        replace(Encounters, "reset", function() resets = resets + 1 end)
        for _ = 1, 2 do
            Bus.init()
            Runtime.init(); Runtime.init()
            Runtime.enterWorld(); Runtime.enterWorld()
            Runtime.resumeWorld()
            WorldState.exit() -- Campaign subscribers survive presentation exit into battle.
            Bus.emit("party_killed", "missing")
            Bus.emit("party_contact", {})
            Bus.emit("party_encounter_started", {})
        end
        assert(killed == 4 and contacts == 2 and started == 2)
        assert(resets == 10)

        -- Ordinary campaigns historically retain transient scale/pause/accumulator.
        Time.reset()
        Time.update(0.005)
        Time.setTimeScale(3)
        Time.setPaused(true)
        local oldWorld = Ecs.campaign
        local newWorld = Runtime.beginNewGame({})
        assert(newWorld ~= oldWorld and Game.data.currentMap == nil)
        assert(Time.getTimeScale() == 3 and Time.isPaused())
        Time.setPaused(false)
        Time.update(0.003)
        assert(Time.getHour() > 6, "ordinary begin discarded the fractional clock accumulator")
        Runtime.beginNewGame({debugCampaign = "normal"})
        assert(Time.getTimeScale() == 1 and not Time.isPaused())
        assert(Time.getDay() == 1 and Time.getHour() == 6)
        Time.update(0.001)
        assert(Time.getHour() == 6, "debug begin retained the fractional clock accumulator")
    end, debug.traceback)
    for index = #originals, 1, -1 do
        local entry = originals[index]
        entry[1][entry[2]] = entry[3]
    end
    WorldState.exit()
    Bus.init()
    Runtime.init()
    Time.reset()
    if not ok then error(err, 0) end
end

return Scenario
