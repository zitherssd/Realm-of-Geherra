local Init = require("src.game.game_initializer")
local Ecs = require("src.ecs.world")
local Game = require("src.game.game_context")
local Fixture = require("src.debug.campaign_fixture")
local Loader = require("src.systems.painted_map_loader")
local Goals = require("src.systems.goal_system")
local Services = require("src.systems.service_system")
local Events = require("src.systems.world_events")
local Knowledge = require("src.systems.knowledge_system")
local Activities = require("src.systems.world_activity_system")
local Parties = require("src.systems.party_system")
local Time = require("src.systems.time_system")
local Scenario = {}

function Scenario.run()
    assert(Init.getMapLoader({}) == Loader, "normal campaigns changed map loader")
    local DebugMap = require("src.debug.campaign_map")
    local stepper = DebugMap.createGeneration()
    assert(stepper:advance() and stepper:progress() == 1)
    local result = stepper.result
    assert(stepper:advance() and stepper.result == result, "debug splash rebuilt its map")
    local function launch(profile)
        if profile == "bandit_risk" then
            -- Exercise the main-menu/CLI splash path as well as synchronous startup.
            local generation = require("src.game.states.world_generation_state")
            local states = require("src.core.state_manager")
            local previousSwap, destination = states.swap, nil
            states.swap = function(name) destination = name end
            local ok, err = pcall(function()
                generation.enter({options = {debugCampaign = profile}})
                generation.update(0)
            end)
            states.swap = previousSwap
            assert(ok, err)
            assert(destination == "world" and generation.finished)
        else
            Init.initNewGame({debugCampaign = profile})
        end
        local map = Game.data.currentMap
        local context = {world = Ecs.campaign, map = map}
        assert(#Services.listRequests(context) == 0 and Events.count(Ecs.campaign) == 0)
        return map, context
    end
    local function actor(key) return assert(Ecs.findActorById("debug_" .. key)) end
    local firstIds
    for _, profile in ipairs({"normal", "no_leader", "healing", "bandit_risk", "normal"}) do
        local map, context = launch(profile)
        assert(map.width == 1536 and map.height == map.width and map.worldGen.debugLayout)
        assert(#map:getLocations() == 9 and #map.worldGen.roads == 12)
        assert(map:getBiomeAt(511, 100) == "plains" and map:getBiomeAt(512, 100) == "forest")
        assert(map:getTravelSpeedMod(100, 100) > map:getTravelSpeedMod(600, 100))
        local Navigation = require("src.systems.world_navigation")
        for index, location in ipairs(map:getLocations()) do
            assert(location.discovered and map:isWalkable(location.x, location.y))
            assert(location.x == ((index - 1) % 3 + 0.5) * 512 + 8)
            assert(location.y == (math.floor((index - 1) / 3) + 0.5) * 512 + 8)
            assert(Navigation.findPath(map, map.locations[1].x, map.locations[1].y, location.x, location.y))
        end
        local fixture = Game.data.debugCampaign
        assert(#fixture.actors == (profile == "bandit_risk" and 6 or 5))
        local home, far = Ecs.findLocationById(fixture.homeId), Ecs.findLocationById(fixture.farId)
        local sponsor, worker, healer, distant, traveler = actor("bel_naram"), actor("ashur"), actor("ninsun"), actor("enlil"), actor("ur_salim")
        assert(Services.getLocation(sponsor, context) == home and sponsor.treasury == 2000)
        assert(Services.getLocation(worker, context) == (profile == "no_leader" and far or home))
        assert(Services.getLocation(healer, context) == home and healer.treasury == 100)
        assert(Services.getLocation(distant, context) == far)
        assert(sponsor.npc_goals.capabilities.caravanFormation and worker.npc_goals.capabilities.leadCaravan)
        assert(healer.npc_goals.capabilities.heal and distant.npc_goals.capabilities.leadCaravan)
        assert(traveler.npc_goals.goals[1].type == "rest_and_recover" and traveler.hp == 30)
        local travelers = Ecs.findPartyById("debug_travelers")
        assert(Parties.getLeader(travelers) == traveler and travelers.treasury == 100)
        assert(not Services.getLocation(traveler, context) and map:isWalkable(travelers.x, travelers.y))
        local seen, membership = {}, {}
        for _, location in ipairs(map:getLocations()) do
            for _, a in ipairs(location.npcs) do
                assert(not membership[a.id]); membership[a.id] = true
            end
            for _, p in ipairs(location.stationedParties) do
                assert(Parties.getLeader(p))
                for _, a in ipairs(p.actors) do
                    assert(not membership[a.id]); membership[a.id] = true
                    assert(Ecs.findActorById(a.id) == a)
                end
            end
        end
        for _, p in ipairs(map:getParties()) do
            assert(Parties.getLeader(p))
            for _, a in ipairs(p.actors) do
                assert(not membership[a.id]); membership[a.id] = true
                assert(not seen[a.id]); seen[a.id] = true
                assert(Ecs.findActorById(a.id) == a)
            end
        end
        for _, id in ipairs(fixture.actors) do
            assert(membership[id] and Ecs.findActorById(id).memory)
        end
        local ids = table.concat(fixture.actors, ",") .. home.id .. far.id
        if profile == "normal" then
            if firstIds then assert(ids == firstIds, "fresh launch changed identities/settlements") end
            firstIds = ids
        end
        local playerParty, player = Game.data.playerParty, Game.data.player
        assert(Parties.getLeader(playerParty) == player and player.player and playerParty.treasury == 50)
        assert(not sponsor.caravan_formation and not worker.caravan_work)
        if profile == "bandit_risk" then
            local bandits = assert(Ecs.findPartyById("debug_bandits"))
            assert(Parties.getLeader(bandits) == actor("zakur") and #bandits.actors == 6)
            assert(bandits.hostile and bandits.faction == "bandits" and bandits.treasury == 75)
            assert(map:isWalkable(bandits.x, bandits.y) and actor("zakur").npc_goals.capabilities.raid)
            for _, a in ipairs(bandits.actors) do assert(a.equipment.mainHand and a.hp > 0) end
        end
        assert(Fixture.populate(map, profile) == fixture)
        Init.finalizeNewGame(map, map:getLocations())
        assert(sponsor.treasury == 2000 and #fixture.actors == (profile == "bandit_risk" and 6 or 5))
        Goals.update(0.1, map, playerParty)
        local preparation = assert(sponsor.caravan_formation.preparation)
        local request = assert(Services.getRequest(preparation.leaderServiceId, context))
        assert(#Services.listRequests(context) == 1 and not worker.caravan_work and sponsor.treasury == 2000)
        assert(not Knowledge.knows(distant, request.offerEventId))
        assert(Services.isProviding(healer, context))
        assert(Services.perform(healer, player, "heal", context))
        assert(playerParty.treasury == 40 and healer.treasury == 110)
        assert(travelers.world_activity.type == "travel")
        if profile == "no_leader" then
            for _ = 1, 4 do Goals.update(2.1, map, playerParty) end
            assert(not Services.getRequest(request.id, context).assignedActorId)
            assert(not Knowledge.knows(distant, request.offerEventId))
            -- Explicit debug knowledge is the sole exceptional control in this test.
            assert(Knowledge.learn(distant, request.offerEventId, {"service", "employer", "location"}, Ecs.campaign))
            Goals.update(2.1, map, playerParty)
            assert(not Services.getRequest(request.id, context).assignedActorId)
            assert(distant.npc_goals.goals[1].reason == "independent_resident_cannot_travel")
            assert(not Services.getParty(distant, Ecs.campaign))
        else
            Goals.update(2.1, map, playerParty)
            assert(Services.getRequest(request.id, context).assignedActorId == worker.id)
        end
        if profile == "healing" then
            local paid = false
            for _ = 1, 600 do
                local elapsed = Time.worldHoursToSeconds(Time.update(0.1))
                Goals.update(elapsed, map, playerParty)
                Activities.update(elapsed, map, playerParty)
                if travelers.treasury < 100 then paid = true; break end
            end
            assert(paid and traveler.hp > 30 and Services.getLocation(traveler, context) == home,
                "traveler did not navigate and buy local healing autonomously")
        end
        if profile == "normal" then
            -- Real presentation and input lifecycle, including the startup F1 summary.
            local World = require("src.game.states.world_state")
            World.enter()
            assert(World.debugOverlay.target.id == home.id)
            World.draw()
            World.update(0)
            assert(Game.data.playerParty == playerParty and Game.data.player == player)
            local screen = require("src.ui.screens.location_screen").new(home, function() end)
            local accessible = {}
            for _, button in ipairs(screen.buttons) do
                if button.npc then
                    assert(button.x >= 0 and button.x + button.w <= screen.width)
                    assert(button.y + button.h < screen.leaveBtn.y)
                    accessible[button.npc.id] = true
                end
            end
            assert(accessible[sponsor.id] and accessible[worker.id] and accessible[healer.id])
            screen:draw()
            local previewPath = os.getenv("GEHERRA_DEBUG_MAP_PREVIEW")
            if previewPath then
                local canvas = love.graphics.newCanvas(900, 900)
                love.graphics.push("all")
                love.graphics.setCanvas(canvas)
                love.graphics.origin()
                love.graphics.clear(0.06, 0.07, 0.06, 1)
                love.graphics.scale(900 / map.width)
                map:drawMap()
                love.graphics.setFont(love.graphics.newFont(15))
                map:drawLocations(map.width / 900)
                love.graphics.pop()
                local file = assert(io.open(previewPath, "wb"))
                file:write(canvas:newImageData():encode("png"):getString())
                file:close()
            end
        end
    end
    local map = launch(nil)
    assert(not Game.data.debugCampaign and not Game.data.debugCampaignProfile)
    assert(not Ecs.findActorById("debug_bel_naram"))
    assert(not map.worldGen.debugLayout and map.width ~= map.height)
    assert(#map:getParties() == 3 and Game.data.playerParty.treasury == 50)
    require("src.debug.mode").enabled = false
end

return Scenario
