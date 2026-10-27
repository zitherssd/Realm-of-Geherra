local Ecs = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Location = require("src.ecs.assemblages.location")
local Map = require("src.world.map")
local Locations = require("src.systems.location_system")
local Parties = require("src.systems.party_system")
local Goals = require("src.systems.goal_system")
local Services = require("src.systems.service_system")
local Caravans = require("src.systems.caravan_system")
local Activities = require("src.systems.world_activity_system")
local Time = require("src.systems.time_system")
local Game = require("src.game.game_context")
local Events = require("src.systems.world_events")
local Knowledge = require("src.systems.knowledge_system")
local TravelKnowledge = require("src.systems.travel_knowledge_system")
local Scenario = {}

local function setup()
    local world, map = Ecs.init(), Map.new("caravan-fixture")
    Game.init()
    Game.data.time, Game.data.currentMap = {day = 1, hour = 6}, map
    Time.setPaused(false); Time.setTimeScale(1)
    local home, far = Location.create(world, nil, "Sponsor Town"), Location.create(world, nil, "Trade Town")
    home.x, home.y, far.x, far.y = 100, 100, 800, 100
    map:addLocation(home); map:addLocation(far)
    local function actor(name)
        local a = Unit.create(world, "soldier")
        a:ensure("memory")
        a.name, a.hp, a.maxHp, a.treasury = name, 100, 100, 0
        Locations.addNPC(home, a)
        return a
    end
    local sponsor, worker = actor("Merchant"), actor("Prospective leader")
    sponsor.treasury = 2000
    Goals.configure(sponsor, {{type = "acquire_gold", amount = 10000}, {type = "rest_and_recover"}}, {caravanFormation = true})
    Goals.configure(worker, {{type = "provide_service"}, {type = "rest_and_recover"}}, {leadCaravan = true, travel = true})
    local context = {world = world, map = map}
    local function tick(dt, playerParty)
        local elapsed = Time.worldHoursToSeconds(Time.update(dt))
        Goals.update(elapsed, map, playerParty)
        Activities.update(elapsed, map, playerParty)
    end
    return world, map, home, far, sponsor, worker, context, tick, actor
end

local function prepare()
    local world, map, home, far, sponsor, worker, context, tick, actor = setup()
    tick(0.1)
    local prep = assert(sponsor.caravan_formation.preparation)
    assert(#Services.listRequests(context) == 1 and #world:query({"party"}) == 0)
    assert(prep.readyAt - prep.startedAt == Time.worldHoursToSeconds(72))
    assert(sponsor.caravan_formation.nextSponsorshipAt - prep.startedAt == Time.worldHoursToSeconds(720))
    assert(sponsor.treasury == 2000)
    -- No leader; pause, goal replacement, and recovery cannot erase runtime.
    Locations.removeNPC(home, worker)
    local ready, cooldown = prep.readyAt, sponsor.caravan_formation.nextSponsorshipAt
    Time.setPaused(true); tick(100)
    assert(Caravans.now() < ready and not Services.getRequest(prep.leaderServiceId, context).assignedActorId)
    Time.setPaused(false)
    Goals.configure(sponsor, {{type = "rest_and_recover"}}, {})
    sponsor.hp = 30
    tick(50)
    assert(sponsor.caravan_formation.preparation == prep and Caravans.now() >= ready)
    assert(#world:query({"party"}) == 0 and sponsor.treasury == 2000)
    assert(sponsor.caravan_formation.nextSponsorshipAt == cooldown)
    -- Late recruitment starts the same immutable offer, then dispatches once.
    Locations.addNPC(home, worker); tick(2.1); tick(0.1)
    local request = Services.getRequest(prep.leaderServiceId, context)
    assert(request.status == "assigned" and request.assignedActorId == worker.id)
    assert(not Services.assign(request.id, worker, context))
    assert(worker.caravan_work and #world:query({"party"}) == 1)
    assert(sponsor.treasury == 1500)
    local party = Ecs.findPartyById(worker.caravan_work.partyId, world)
    assert(party.treasury == 500 and Parties.getLeader(party) == worker and #home.npcs == 1)
    assert(sponsor.caravan_formation.nextSponsorshipAt == cooldown)
    local departures = Events.getByType(world, "party_departed")
    assert(#departures == 1 and departures[1].sponsorId == sponsor.id)
    local event = departures[1]
    assert(event.originLocationId == home.id and event.destinationLocationId == far.id and event.partyId == party.id)
    local expected = Caravans.estimateTravel(map, home.x, home.y, far.x, far.y) * 2 * 1.2
        + Time.worldHoursToSeconds(Caravans.tradingHours)
    assert(math.abs(event.expectedReturnAt - event.departureAt - expected) < 1e-6)
    assert(Knowledge.getKnownEvent(sponsor, event.id).expectedReturnAt == event.expectedReturnAt)
    assert(Knowledge.knows(worker, event.id) and Ecs.findActorById(worker.id, world) == worker)
    assert(Events.get(world, request.offerEventId).status == "open")
    return world, map, home, far, sponsor, worker, context, tick, party, prep
end

local function journey()
    local world, map, home, far, sponsor, worker, context, tick, party, prep = prepare()
    -- Actual stolen capital is not recreated by trading or delivery.
    local thief = Party.create(world, "Thief")
    assert(require("src.systems.inventory_system").transferGold(party, thief, 100))
    local random = TravelKnowledge.random
    TravelKnowledge.random = function() return 1 end -- No optional arrival gossip.
    for _ = 1, 800 do tick(0.1); if not worker.caravan_work then break end end
    TravelKnowledge.random = random
    assert(not worker.caravan_work, "expedition did not finish")
    assert(sponsor.treasury == 2000 and thief.treasury == 100) -- 1500 + 400 + floor(400*.25)
    local trades = Events.getByType(world, "caravan_traded")
    assert(#trades == 1 and trades[1].profit == 100)
    assert(not Knowledge.knows(sponsor, trades[1].id), "remote trade leaked without communication")
    assert(#Events.getByType(world, "party_departed") == 2 and #Events.getByType(world, "party_arrived") == 2)
    assert(Services.getRequest(prep.leaderServiceId, context).status == "completed")
    assert(Services.getLocation(worker, context) == home and not Services.getParty(worker, world))
    assert(Ecs.findPartyById(party.id, world) == nil)
    local cooldown = sponsor.caravan_formation.nextSponsorshipAt
    Goals.configure(sponsor, {{type = "acquire_gold", amount = 10000}}, {caravanFormation = true})
    tick(1)
    assert(not sponsor.caravan_formation.preparation)
    Game.data.time.day, Game.data.time.hour = 32, 6
    tick(11) -- Existing goal retry interval also needs simulation time.
    assert(sponsor.caravan_formation.preparation and sponsor.caravan_formation.nextSponsorshipAt > cooldown)
end

local function proactiveAndFailedDispatch()
    local world, map, home, far, sponsor, worker, context, tick, actor = setup()
    tick(0.1)
    local prep = sponsor.caravan_formation.preparation
    local request = Services.getRequest(prep.leaderServiceId, context)
    -- Only learned offer details can motivate the proactive application.
    Knowledge.learn(worker, request.offerEventId, {"service", "employer", "location"}, world)
    tick(0.1)
    assert(Services.getRequest(request.id, context).assignedActorId == worker.id)
    local identity, inventory, memory = worker.id, worker.inventory, worker.memory
    sponsor.treasury = 20
    tick(49)
    assert(#world:query({"party"}) == 0 and sponsor.treasury == 20)
    assert(sponsor.caravan_formation.preparation.reason == "insufficient_or_shared_funds")
    assert(worker.id == identity and worker.inventory == inventory and worker.memory == memory)
    sponsor.treasury = 2000; tick(0.1)
    assert(worker.caravan_work and sponsor.treasury == 1500)
    assert(not Caravans.dispatch(sponsor, worker, context) and sponsor.treasury == 1500)
end

local function playerOverride(assigned)
    local world, map, home, far, sponsor, worker, context, tick, actor = setup()
    local player = actor("Player")
    player:ensure("player"); Locations.removeNPC(home, player)
    local party = Party.create(world, "Existing player party", player.id)
    Parties.addActor(party, player); party.x, party.y = home.x, home.y
    party.treasury = 50
    map:addParty(party)
    Game.data.player, Game.data.playerParty = player, party
    tick(0.1, party)
    local prep = sponsor.caravan_formation.preparation
    local originalId = prep.leaderServiceId
    if assigned then
        assert(Services.assign(originalId, worker, context))
        assert(Services.hasObligation(worker, context))
    end
    assert(Caravans.now() < prep.readyAt and Caravans.canVolunteer(sponsor, player, context))
    -- Use the real dialogue callback for volunteering and revalidation.
    local Dialogue = require("src.game.states.dialogue_state")
    local UI = require("src.ui.ui_manager")
    local States = require("src.core.state_manager")
    Dialogue.enter({target = sponsor, location = home, dialogueTree = {lines = {{text = "Greetings.", options = {{text = "Leave", next = "end"}}}}}})
    local screen, option = UI.getActiveScreen()
    for _, choice in ipairs(screen.lines[1].options) do if choice.action == "volunteer_caravan" then option = choice end end
    assert(option)
    local oldSwap = States.swap
    States.swap = function() end
    screen.onChoice(option)
    States.swap = oldSwap
    Dialogue.exit()
    assert(Game.data.playerParty == party and #world:query({"party"}) == 1)
    assert(party.treasury == 550 and sponsor.treasury == 1500 and player.caravan_work)
    assert(player.caravan_work.partyId == party.id and Parties.getLeader(party) == player)
    assert(Services.getRequest(originalId, context).status == "cancelled")
    assert(not Services.hasObligation(worker, context))
    assert(Services.getLocation(worker, context) == home)
    assert(not Caravans.canVolunteer(sponsor, player, context))
    for _ = 1, 900 do tick(0.1, party); if not player.caravan_work then break end end
    assert(not player.caravan_work and Game.data.playerParty == party)
    assert(party.treasury == 0 and sponsor.treasury == 2187) -- floor(550 * .25) + 550
    assert(Services.getRequest(prep.leaderServiceId, context).status == "completed")
    assert(#Events.getByType(world, "party_departed") == 2)
end

local function interruptions()
    local world, map, home, far, sponsor, worker, context, tick, party, prep = prepare()
    local position, phase = party.x, worker.caravan_work.phase
    party.activeEncounterId = "reserved"
    tick(2)
    assert(party.x == position and worker.caravan_work.phase == phase)
    party.activeEncounterId = nil
    worker.hp = 30; tick(0.1)
    assert(worker.npc_goals.goals[2].recovering and worker.caravan_work)
    worker.hp = 100
    for _ = 1, 1200 do tick(0.1); if not worker.caravan_work then break end end
    assert(not worker.caravan_work and Services.getRequest(prep.leaderServiceId, context).status == "completed")
    assert(#Events.getByType(world, "caravan_traded") == 1)
    -- A removed/dead/moved sponsor cannot receive a fabricated delivery.
    world, map, home, far, sponsor, worker, context, tick, party, prep = prepare()
    sponsor.hp = 0
    for _ = 1, 1000 do tick(0.1) end
    assert(worker.caravan_work.phase == "delivery" and party.treasury == 625)
    assert(Services.getRequest(prep.leaderServiceId, context).status == "assigned")
    assert(sponsor.treasury == 1500 and worker.caravan_work.reason == "awaiting_sponsor_at_origin")
    sponsor.hp = 100
    Locations.removeNPC(home, sponsor); Locations.addNPC(far, sponsor); tick(1)
    assert(worker.caravan_work.phase == "delivery" and party.treasury == 625 and sponsor.treasury == 1500)
    Locations.removeNPC(far, sponsor); Locations.addNPC(home, sponsor); tick(1)
    assert(not worker.caravan_work and sponsor.treasury == 2125)
end

local function loss()
    local world, map, home, far, sponsor, worker, context, tick, party, prep = prepare()
    local raider = Party.create(world, "Bandits")
    local bandit = Unit.create(world, "soldier")
    Parties.addActor(raider, bandit)
    raider.x, raider.y, raider.hostile = party.x + 10, party.y, true
    bandit.sight, worker.profile, party.visible = 1000, 1000, true
    map:addParty(raider)
    assert(require("src.systems.world_activities.raid_activity").visibleTarget(raider, map, nil, party.id) == party)
    -- Exercise the real generic loot resolver/application with a deterministic
    -- defeat. Combat balance and its existing timeout fixtures stay separate.
    local result = {partyAId = raider.id, partyBId = party.id, outcome = "victory", winnerPartyId = raider.id,
        actors = {[bandit.id] = {partyId = raider.id, finalHp = 100, defeated = false},
            [worker.id] = {partyId = party.id, finalHp = 0, defeated = true}}}
    local loot = require("src.systems.loot_resolver").resolve(raider, party, result,
        {plunderAllowed = true, stolenProportion = 1, destroyedProportion = 0}, function() return 0 end)
    local encounter = {id = "caravan-defeat", partyAId = raider.id, partyBId = party.id, x = party.x, y = party.y,
        time = {day = Time.getDay(), hour = Time.getHour()}}
    local application = require("src.systems.loot_application")
    application.apply(application.prepare(loot, {map = map, encounter = encounter, battleResult = result,
        worldTime = {day = Time.getDay(), hour = Time.getHour()}}))
    worker.hp = 0
    tick(0.1)
    assert(raider.treasury == 500 and sponsor.treasury == 1500)
    local request = Services.getRequest(prep.leaderServiceId, context)
    assert(request.status == "cancelled" and not Knowledge.knows(sponsor, request.closureEventId))
    assert(#Events.getByType(world, "party_arrived") == 0 and #Events.getByType(world, "caravan_traded") == 0)
    assert(sponsor.caravan_formation.nextSponsorshipAt == prep.startedAt + Time.worldHoursToSeconds(720))
end

local function rollbackAndOverlappingExpeditions()
    local world, map, home, far, sponsor, worker, context, tick = setup()
    tick(0.1); tick(2.1)
    local prep = sponsor.caravan_formation.preparation
    assert(Services.getRequest(prep.leaderServiceId, context).assignedActorId == worker.id)
    -- Inject a real Map departure failure after stationing/funding. No charge,
    -- actor duplication, departure history, or stranded party may survive it.
    local add = map.addParty
    map.addParty = function() return false end
    tick(49)
    map.addParty = add
    world:__flush()
    assert(#world:query({"party"}) == 0 and sponsor.treasury == 2000 and not worker.caravan_work)
    assert(Services.getLocation(worker, context) == home and #home.npcs == 2)
    assert(#Events.getByType(world, "party_departed") == 0)
    assert(Services.getRequest(prep.leaderServiceId, context).status == "assigned")
    tick(0.1)
    local firstParty = Ecs.findPartyById(worker.caravan_work.partyId, world)
    firstParty.activeEncounterId = "long-reservation"
    -- Preparation eligibility is independent of already traveling expeditions.
    Game.data.time.day, Game.data.time.hour = 32, 6
    tick(11)
    local second = assert(sponsor.caravan_formation.preparation)
    assert(second.id ~= prep.id and second.leaderServiceId ~= prep.leaderServiceId)
    assert(Services.getRequest(prep.leaderServiceId, context).status == "assigned")
    assert(firstParty.treasury == 500 and sponsor.treasury == 1500)
    local replacement = Unit.create(world, "soldier")
    replacement:ensure("memory"); replacement.hp, replacement.maxHp = 100, 100
    Locations.addNPC(home, replacement)
    Goals.configure(replacement, {{type = "provide_service"}}, {leadCaravan = true})
    tick(2.1); tick(2.1); tick(49)
    assert(replacement.caravan_work and replacement.caravan_work.partyId ~= firstParty.id)
    assert(firstParty.treasury == 500 and sponsor.treasury == 1000)
end

local function ownershipAndViews()
    local world, map, home, far, sponsor, worker, context, tick = setup()
    tick(0.1)
    local prep = sponsor.caravan_formation.preparation
    local unrelated = Party.create(world, "Unrelated party", worker.id)
    Locations.removeNPC(home, worker); Parties.addActor(unrelated, worker)
    unrelated.x, unrelated.y = home.x, home.y
    map:addParty(unrelated); map:stationParty(home, unrelated)
    assert(not Services.assign(prep.leaderServiceId, worker, context))
    assert(Parties.getLeader(unrelated) == worker and #unrelated.actors == 1)
    local Inspector = require("src.debug.inspector")
    local lines = table.concat(Inspector.lines(map, "unit", sponsor.id), "\n")
    assert(lines:find("Caravan preparation", 1, true) and lines:find(prep.leaderServiceId, 1, true))
    local Viewer = require("src.ui.screens.service_viewer")
    local viewer = Viewer.new(world, map)
    assert(#viewer.rows == 1 and viewer.rows[1].data.preparationId == prep.id)
    viewer:draw()
    local Mode = require("src.debug.mode")
    local old = Mode.enabled; Mode.enabled = true
    local overlay = require("src.ui.screens.debug_overlay").new()
    overlay:inspect("unit", sponsor.id); overlay:draw(map)
    local found = false
    for _, row in ipairs(overlay:rows(map)) do
        if row.key == "enable_caravan_sponsor" then row.action(); found = true end
    end
    assert(found)
    Mode.enabled = old
    local function plain(value)
        if type(value) == "table" then
            assert(not getmetatable(value))
            for key, child in pairs(value) do assert(type(key) == "string" or type(key) == "number"); plain(child) end
        else assert(type(value) == "number" or type(value) == "string" or type(value) == "boolean" or value == nil) end
    end
    plain(sponsor.caravan_formation:serialize())
end

function Scenario.run()
    journey()
    proactiveAndFailedDispatch()
    playerOverride(false)
    playerOverride(true)
    interruptions()
    loss()
    rollbackAndOverlappingExpeditions()
    ownershipAndViews()
end

-- An ordinary WorldState on a small deterministic map, using the real F1/F2/F3
-- and dialogue. These fixture keys do not add controls to the shipping game.
function Scenario.preview(smoke)
    love.window.setMode(1024, 768, {resizable = true})
    love.window.setTitle("Geherra 7C caravan playtest")
    local world, map, home, far, sponsor, worker, context, tick, actor = setup()
    local player = actor("Player")
    player:ensure("player"); Locations.removeNPC(home, player)
    local party = Party.create(world, "Player party", player.id)
    Parties.addActor(party, player); party.x, party.y, party.treasury = home.x, home.y, 100
    map:addParty(party)
    Game.data.player, Game.data.playerParty = player, party
    Goals.configure(sponsor, {}, {}); Goals.configure(worker, {}, {})
    local States = require("src.core.state_manager")
    local Input = require("src.core.input")
    local WorldState = require("src.game.states.world_state")
    require("src.core.event_bus").init()
    States.init(); Input.init(); States.push("world")
    local frame = 0
    love.update = function(dt)
        Input.update(dt); States.update(dt)
        frame = frame + 1
        if smoke and frame >= 3 then love.event.quit(0) end
    end
    love.draw = function()
        States.draw()
        if States.getCurrentState() == WorldState and not WorldState.blocksPointerInput() then
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("7C fixture: F1 debug | F2 history | F3 services | Space wait | C merchant dialogue", 15, 70)
            love.graphics.print("H injure sponsor | J injure worker | B spawn bandits near dispatched caravan", 15, 90)
        end
    end
    love.keypressed = function(key, _, repeated)
        if States.keypressed(key, repeated) then return end
        Input.keypressed(key)
        if States.getCurrentState() ~= WorldState or WorldState.blocksPointerInput() then return end
        if key == "c" then
            States.push("dialogue", {target = sponsor, location = home, dialogueTree = {
                speaker = sponsor.name, lines = {{text = "Can you lead my caravan?", options = {{text = "Leave", next = "end"}}}}
            }})
        elseif key == "h" then sponsor.hp = 30
        elseif key == "j" then worker.hp = 30
        elseif key == "b" then
            local work = worker.caravan_work or player.caravan_work
            local caravan = work and Ecs.findPartyById(work.partyId, world)
            if caravan and not caravan.activeEncounterId then
                local bandits = Party.create(world, "Fixture bandits")
                bandits.x, bandits.y, bandits.hostile, bandits.faction = caravan.x + 10, caravan.y, true, "bandits"
                for _ = 1, 2 do
                    local bandit = Unit.create(world, "soldier")
                    bandit.hp, bandit.maxHp, bandit.sight = 500, 500, 1000
                    bandit.stats.health, bandit.stats.attack, bandit.stats.defense, bandit.stats.battle_speed = 500, 500, 100, 120
                    bandit.skills = {javelin_throw = {learned = true}}
                    Parties.addActor(bandits, bandit)
                end
                map:addParty(bandits)
            end
        end
    end
    love.keyreleased = function(key) Input.keyreleased(key); States.keyreleased(key) end
    love.textinput = States.textinput
    love.mousepressed = function(x, y, button) Input.mousepressed(x, y, button); States.mousepressed(x, y, button) end
    love.mousereleased = function(x, y, button) Input.mousereleased(x, y, button); States.mousereleased(x, y, button) end
    love.mousemoved = function(x, y, dx, dy) Input.mousemoved(x, y, dx, dy) end
    love.wheelmoved = States.wheelmoved
end
return Scenario
