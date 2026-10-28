local Ecs = require("src.ecs.world")
local Game = require("src.game.game_context")
local Runtime = require("src.game.campaign.campaign_runtime")
local Time = require("src.systems.campaign.time_system")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Location = require("src.ecs.assemblages.location")
local Map = require("src.world.map")
local Parties = require("src.systems.parties.party_system")
local Locations = require("src.systems.locations.location_system")
local Goals = require("src.systems.goals.goal_system")
local Services = require("src.systems.services.service_system")
local Investigations = require("src.systems.services.investigation_system")
local Activities = require("src.systems.world_activities.world_activity_system")
local Knowledge = require("src.systems.knowledge.knowledge_system")
local TravelKnowledge = require("src.systems.knowledge.travel_knowledge_system")
local Events = require("src.systems.campaign.world_events")
local Encounters = require("src.systems.campaign.world_encounter_system")
local Visibility = require("src.systems.parties.visibility_system")
local Bus = require("src.core.event_bus")
local Scenario = {}

local function objective(actor)
    for _, goal in ipairs(actor.npc_goals.goals) do if goal.caravanFate then return goal end end
end

-- Controlled battle HP uses the same real encounter finalization as battle knowledge fixtures.
local function destroyCaravan(f, empty)
    local caravan = f.caravan
    if caravan.world_activity.status == "active" then Activities.cancel(caravan, "fixture_detour") end
    Activities.update(0, f.map)
    caravan.world_activity.retryCooldownSeconds = 0
    assert(Activities.start(caravan, "travel", {destinationX = 450, destinationY = empty and 1500 or 100}, f.map))
    for _ = 1, 400 do
        f.tick(0.1)
        if caravan.world_activity.status == "idle" then break end
    end
    local raider = Party.create(f.world, "Battle survivors")
    Parties.addActor(raider, Unit.create(f.world, "soldier"))
    raider.x, raider.y = caravan.x, caravan.y
    f.map:addParty(raider)
    local ok, encounter = Encounters.start(f.map, raider, caravan, {maxTicks = 1})
    assert(ok)
    for _, unit in ipairs(encounter.runner.simulation.context.data.unitList) do
        if unit.team == "enemy" then unit.hp = 0 end
    end
    Encounters.update(0, f.map)
    f.battleId = assert(encounter.eventId)
    f.site = assert(f.map:getBattlefieldRemains()[1])
    assert(not Knowledge.knows(f.sponsor, f.battleId))
end

function Scenario.fixture(empty, living)
    Bus.init(); Game.init()
    local f = {world = Ecs.init(), map = Map.new("investigation-fixture")}
    Time.reset(); Runtime.init(); Runtime.enterWorld()
    Game.data.currentMap = f.map
    f.home, f.far = Location.create(f.world, nil, "Sponsor Town"), Location.create(f.world, nil, "Trade Town")
    f.home.x, f.home.y, f.far.x, f.far.y = 100, 100, 800, 100
    f.map:addLocation(f.home); f.map:addLocation(f.far)
    function f.actor(name, location)
        local a = Unit.create(f.world, "soldier")
        a:ensure("memory")
        a.name, a.hp, a.maxHp, a.sight = name, 100, 100, 240
        if location then Locations.addNPC(location, a) end
        return a
    end
    f.sponsor, f.leader = f.actor("Merchant", f.home), f.actor("Caravan leader", f.home)
    f.sponsor.treasury = 2000
    Goals.configure(f.sponsor, {{type = "acquire_gold", amount = 10000}, {type = "rest_and_recover"}}, {caravanFormation = true})
    Goals.configure(f.leader, {{type = "provide_service"}, {type = "rest_and_recover"}}, {leadCaravan = true, travel = true})
    f.context = {world = f.world, map = f.map}
    function f.tick(dt)
        local seconds = Time.worldHoursToSeconds(Time.update(dt))
        Runtime.updateGoals(seconds, f.map, Game.data.playerParty)
        Activities.update(seconds, f.map, Game.data.playerParty)
        if Game.data.playerParty then Visibility.update(Game.data.playerParty, f.map) end
    end
    f.tick(0.1); f.tick(2.1); f.tick(49)
    f.caravan = assert(Ecs.findPartyById(f.leader.caravan_work.partyId, f.world))
    f.departure = assert(Knowledge.getKnownEvents(f.sponsor, nil, "party_departed")[1])
    f.serviceId = f.leader.caravan_work.serviceId
    -- Distant observer enables ordinary NPC visibility without revealing the evidence to the player.
    local player = f.actor("Player")
    player:ensure("player")
    local playerParty = Party.create(f.world, "Player", player.id)
    Parties.addActor(playerParty, player)
    playerParty.x, playerParty.y = 2000, 2000
    f.map:addParty(playerParty)
    Game.data.player, Game.data.playerParty = player, playerParty
    if not living then destroyCaravan(f, empty) end
    f.worker = f.actor("Investigator", f.home)
    Goals.configure(f.worker, {{type = "provide_service"}, {type = "rest_and_recover"}}, {investigate = true, travel = true})
    return f
end

local function waitOffer(f)
    for _ = 1, 1000 do
        f.tick(0.1)
        local goal = objective(f.sponsor)
        if goal and goal.investigation.serviceId then return Services.getRequest(goal.investigation.serviceId, f.context) end
    end
    error("Investigation offer missing")
end

local function visit(f)
    local random = TravelKnowledge.random
    TravelKnowledge.random = function() return 0 end
    -- Actual arrival exchange, rather than a direct offer/evidence grant.
    local visitor = f.actor("Visitor")
    local party = Party.create(f.world, "Visiting travelers", visitor.id)
    Parties.addActor(party, visitor)
    party.x, party.y = f.home.x, 800
    f.map:addParty(party)
    assert(Activities.start(party, "travel", {destinationLocationId = f.home.id}, f.map))
    for _ = 1, 400 do
        f.tick(0.1)
        if f.worker.investigation_work then TravelKnowledge.random = random; return f.worker.investigation_work end
    end
    TravelKnowledge.random = random
    error("Known offer was not accepted")
end

local function runToReport(f)
    local sawSearch, sawReturn = false, false
    for _ = 1, 2200 do
        f.tick(0.1)
        local work = f.worker.investigation_work
        if not work then return sawSearch, sawReturn end
        local party = assert(Ecs.findPartyById(work.partyId, f.world))
        sawSearch = sawSearch or party.world_activity.type == "search"
        sawReturn = sawReturn or work.phase == "returning"
        assert(work.centerIndex <= #work.centers + 1)
        assert(not Knowledge.knows(f.sponsor, f.battleId), "Knowledge leaked before the intentional report")
        if Services.getLocation(f.worker, f.context) ~= f.home then assert(not work.reported) end
    end
    error("Investigation did not report: " .. tostring(f.worker.investigation_work.reason))
end

local function outcomes(empty)
    local f = Scenario.fixture(empty)
    local offer = waitOffer(f)
    assert(not Knowledge.knows(f.worker, offer.offerEventId))
    assert(not Investigations.assign(offer.id, f.worker, f.context))
    local inventory, equipment, memory, id = f.worker.inventory, f.worker.equipment, f.worker.memory, f.worker.id
    local work = visit(f)
    assert(work.targetPartyId == f.caravan.id and work.createdParty)
    assert(f.worker.id == id and f.worker.memory == memory and f.worker.inventory == inventory and f.worker.equipment == equipment)
    assert(not Services.getLocation(f.worker, f.context), tostring(work.phase) .. ": " .. tostring(work.reason))
    assert(Services.getRequest(offer.id, f.context).assignedActorId == id)
    assert(Services.hasObligation(f.worker, f.context) == offer.id)
    assert(not Knowledge.knows(f.sponsor, f.battleId))
    local count = #Services.listRequests(f.context)
    for _ = 1, 10 do f.tick(0.1) end
    assert(#Services.listRequests(f.context) == count, "Duplicate active investigation")
    local sawSearch, sawReturn = runToReport(f)
    assert(sawReturn and (sawSearch or not empty))
    assert(Services.getRequest(offer.id, f.context).status == "completed", require("src.ui.world_event_text").details(f.worker.lastInvestigationWork, true))
    assert(f.worker.lastInvestigationWork.reported and f.worker.lastInvestigationWork.returned)
    assert(not Services.hasObligation(f.worker, f.context) and Services.getLocation(f.worker, f.context) == f.home)
    assert(not Services.getParty(f.worker, f.world))
    local goal = objective(f.sponsor)
    assert((goal.status == "satisfied") == not empty)
    assert(Knowledge.knows(f.sponsor, f.battleId) == not empty)
    assert(Knowledge.knows(f.worker, f.battleId) == not empty)
    assert(not Knowledge.knows(Game.data.player, f.battleId))
    local closure = Services.getRequest(offer.id, f.context)
    assert(Events.get(f.world, closure.closureEventId).status == "completed")
    if empty then
        for _ = 1, 20 do f.tick(0.1) end
        assert(#Services.listRequests(f.context) == count)
        f.tick(Time.worldHoursToSeconds(Investigations.retryHours) + 11)
        assert(objective(f.sponsor).investigation.serviceId ~= offer.id, "No retry after honest empty report")
    end
    local inspector = require("src.debug.inspector")
    assert(table.concat(inspector.lines(f.map, "unit", f.sponsor.id), "\n"):find("Overdue caravan", 1, true))
    assert(table.concat(inspector.lines(f.map, "unit", f.worker.id), "\n"):find("Investigation:", 1, true))
    local viewer = require("src.ui.screens.service_viewer").new(f.world, f.map)
    viewer:draw()
    local overlay = require("src.ui.screens.debug_overlay").new()
    overlay:inspect("unit", f.worker.id); overlay:draw(f.map)
end

local function interruptionAndLoss()
    local f = Scenario.fixture(true)
    local offer = waitOffer(f)
    visit(f)
    local work, party = f.worker.investigation_work, Services.getParty(f.worker, f.world)
    local x, y, index = party.x, party.y, work.centerIndex
    Time.setPaused(true); f.tick(100)
    assert(party.x == x and party.y == y and work.centerIndex == index)
    Time.setPaused(false)
    party.activeEncounterId = "reserved"
    for _ = 1, 5 do f.tick(0.1) end
    assert(party.x == x and party.y == y and work.centerIndex == index)
    party.activeEncounterId = nil
    f.worker.hp = 30
    f.tick(1)
    assert(Services.selectedGoal(f.worker).type == "rest_and_recover")
    assert(f.worker.investigation_work == work and Services.hasObligation(f.worker, f.context) == offer.id)
    f.worker.hp = 100
    for _ = 1, 20 do f.tick(0.1) end
    assert(f.worker.investigation_work == work and work.centerIndex >= index)
    f.worker.hp = 0
    f.tick(0.1)
    assert(not f.worker.investigation_work and f.worker.lastInvestigationWork.phase == "failed")
    local cancelled = Services.getRequest(offer.id, f.context)
    assert(cancelled.status == "cancelled" and not Knowledge.knows(f.sponsor, cancelled.closureEventId))
    local goal = objective(f.sponsor)
    assert(goal.status ~= "satisfied" and goal.investigation.serviceId == offer.id)
    f.tick(11)
    assert(goal.investigation.serviceId == offer.id, "Remote death caused an early retry")
    f.tick(Time.worldHoursToSeconds(Investigations.assignmentHours) + 11)
    assert(not Knowledge.knows(f.sponsor, f.battleId))
    assert(not goal.investigation.serviceId)
    f.tick(Time.worldHoursToSeconds(Investigations.retryHours) + 11)
    assert(goal.investigation.serviceId and goal.investigation.serviceId ~= offer.id)
end

local function boundaries()
    local f = Scenario.fixture(false, true)
    assert(not objective(f.sponsor), "Early investigation")
    -- Freeze the real expedition; overdue does not imply destruction.
    f.caravan.activeEncounterId = "delayed"
    f.tick(15)
    local offer = waitOffer(f)
    assert(objective(f.sponsor).status ~= "satisfied" and offer.data.targetPartyId == f.caravan.id)
    local before = #Services.listRequests(f.context)
    for _ = 1, 20 do f.tick(1) end
    assert(#Services.listRequests(f.context) == before)
    -- Recognition must not look up the remote target, even if it still exists.
    local find = Ecs.findPartyById
    Ecs.findPartyById = function(id, world) assert(id ~= f.caravan.id, "Remote lookup in overdue recognition"); return find(id, world) end
    Investigations.recognize(f.sponsor, f.context)
    Ecs.findPartyById = find
    local attempt = objective(f.sponsor).investigation
    Goals.configure(f.sponsor, {{type = "acquire_gold", amount = 10000}, {type = "rest_and_recover"}}, {caravanFormation = true})
    Investigations.recognize(f.sponsor, f.context)
    assert(objective(f.sponsor).investigation == attempt)
    local other = Events.record(f.world, "party_departed", {time = {day = Time.getDay(), hour = Time.getHour()},
        partyId = "other_caravan", sponsorId = f.sponsor.id, expectedReturnAt = 0,
        originLocationId = f.home.id, destinationLocationId = f.far.id})
    Knowledge.learn(f.sponsor, other.id, {"party", "sponsorship", "location", "destination"})
    Investigations.recognize(f.sponsor, f.context)
    local targets = {}; for _, goal in ipairs(f.sponsor.npc_goals.goals) do if goal.caravanFate then targets[goal.subject.id] = true end end
    assert(targets[f.caravan.id] and targets.other_caravan)
    local unqualified = f.actor("Unqualified", f.home)
    Goals.configure(unqualified, {{type = "provide_service"}}, {})
    Goals.update(1, f.map)
    Knowledge.share(f.sponsor, unqualified, offer.offerEventId)
    assert(not Investigations.assign(offer.id, unqualified, f.context))
    -- Departure/destination arrival and nonterminal battles cannot answer fate.
    local query = objective(f.sponsor)
    assert(not Knowledge.findKnownInformation(f.sponsor, query))
    local battle = Events.record(f.world, "battle_ended", {time = {day = Time.getDay(), hour = Time.getHour()},
        participants = {{partyId = f.caravan.id}}, winnerPartyId = f.caravan.id, outcome = "victory"})
    Knowledge.learn(f.sponsor, battle.id, {"participants", "outcome"})
    assert(not Knowledge.findKnownInformation(f.sponsor, query))
    f.caravan.activeEncounterId = nil
    for _ = 1, 1400 do f.tick(0.1); if not f.leader.caravan_work then break end end
    assert(not f.leader.caravan_work and Knowledge.findKnownInformation(f.sponsor, query))
end

local function partialReportingAndMissingEmployer()
    local f = Scenario.fixture(true)
    local offer = waitOffer(f)
    visit(f)
    Knowledge.learn(f.worker, f.battleId, {"participants"}) -- Controlled partial-memory reporting boundary.
    Locations.removeNPC(f.home, f.sponsor); Locations.addNPC(f.far, f.sponsor)
    local work = f.worker.investigation_work
    local party = Services.getParty(f.worker, f.world)
    party.treasury = 7 -- Unexpected resources must keep the returned party alive.
    for _ = 1, 2400 do
        f.tick(0.1)
        if work.reason == "awaiting_employer_at_home" then break end
    end
    assert(work.phase == "reporting" and not work.reported)
    assert(f.worker.hp > 0 and Knowledge.knows(f.worker, f.battleId))
    assert(not Knowledge.knows(f.sponsor, f.battleId))
    Locations.removeNPC(f.far, f.sponsor); Locations.addNPC(f.home, f.sponsor)
    for _ = 1, 120 do f.tick(0.1); if not f.worker.investigation_work then break end end
    local known = assert(Knowledge.getKnownDetails(f.sponsor, f.battleId))
    assert(known.participants and not known.outcome and not known.location)
    assert(objective(f.sponsor).status ~= "satisfied")
    assert(Services.getRequest(offer.id, f.context).status == "completed")
    assert(Services.getParty(f.worker, f.world) == party and party.treasury == 7)
    assert(Services.getLocation(f.worker, f.context) == f.home)
end

local function liveContact()
    local f = Scenario.fixture(false, true)
    f.caravan.activeEncounterId = "delayed"
    local offer = waitOffer(f)
    local work = visit(f)
    local party = Services.getParty(f.worker, f.world)
    f.tick(0.1)
    assert(#Events.getByType(f.world, "party_encounter") == 0)
    -- Controlled positions test the contact boundary; no target lookup from a distance can teach its condition.
    f.caravan.x, f.caravan.y = party.x, party.y
    f.tick(0.1)
    assert(#Events.getByType(f.world, "party_encounter") == 0, "Reserved target was contacted")
    f.caravan.activeEncounterId = nil
    f.leader.hp = 0 -- A stale roster with no living participants cannot establish survival.
    f.tick(0.1)
    assert(#Events.getByType(f.world, "party_encounter") == 0)
    f.leader.hp = 100
    f.caravan.x, f.caravan.y = party.x, party.y
    f.tick(0.1)
    local encounter = assert(Events.getByType(f.world, "party_encounter")[1])
    assert(encounter.partyId == f.caravan.id and encounter.observerPartyId == party.id)
    assert(Knowledge.knows(f.worker, encounter.id) and not Knowledge.knows(f.sponsor, encounter.id))
    f.caravan.activeEncounterId = "still_delayed"
    for _ = 1, 800 do f.tick(0.1); if not f.worker.investigation_work then break end end
    assert(not f.worker.investigation_work and Knowledge.knows(f.sponsor, encounter.id))
    assert(objective(f.sponsor).status == "satisfied")
    assert(Services.getRequest(offer.id, f.context).status == "completed")
    assert(work.reported and #Events.getByType(f.world, "party_encounter") == 1)
end

local function knownFateAndRoute()
    local f = Scenario.fixture(true)
    Knowledge.learn(f.sponsor, f.battleId, {"outcome", "time"})
    local before = #Services.listRequests(f.context)
    f.tick(40)
    assert(not objective(f.sponsor) and #Services.listRequests(f.context) == before)
    local readSites = f.map.getBattlefieldRemains
    f.map.getBattlefieldRemains = function() error("Route read hidden evidence") end
    local route = Investigations.route(f.map, f.home, f.far)
    f.map.getBattlefieldRemains = readSites
    assert(#route <= Investigations.maxCenters and route[#route].x == f.far.x)
    for _, point in ipairs(route) do assert(point.y == f.home.y and f.map:isWalkable(point.x, point.y)) end
end

local function searchRecoveryAndLocalReturn()
    local f = Scenario.fixture(true)
    waitOffer(f); visit(f)
    local work, party = f.worker.investigation_work, Services.getParty(f.worker, f.world)
    for _ = 1, 500 do f.tick(0.1); if party.world_activity.type == "search" then break end end
    assert(party.world_activity.type == "search")
    f.tick(0.3)
    local index = work.centerIndex
    f.worker.hp = 30; f.tick(0.1)
    assert(Services.selectedGoal(f.worker).type == "rest_and_recover" and work.centerIndex == index)
    assert((work.searchElapsed or 0) > 0 and work.searchElapsed < work.searchSeconds)
    f.worker.hp = 100
    runToReport(f)
    assert(f.worker.lastInvestigationWork.reported and objective(f.sponsor).status ~= "satisfied")

    f = Scenario.fixture(false, true)
    f.caravan.activeEncounterId = "delayed"
    local offer = waitOffer(f)
    work = visit(f)
    party = Services.getParty(f.worker, f.world)
    party.activeEncounterId = "investigator_reserved"
    f.caravan.activeEncounterId = nil
    for _ = 1, 1200 do f.tick(0.1); if not f.leader.caravan_work then break end end
    f.tick(1) -- Goal evaluation follows the physical delivery callback.
    assert(not f.leader.caravan_work and objective(f.sponsor).status == "satisfied")
    assert(f.worker.investigation_work == work and not work.reported)
    assert(Services.getRequest(offer.id, f.context).status == "assigned", "Remote cancellation after caravan return")
    party.activeEncounterId = nil
    runToReport(f)
    assert(f.worker.lastInvestigationWork.reported and Services.getRequest(offer.id, f.context).status == "completed")
end

local function terminalCancellation()
    local f = Scenario.fixture(true)
    local offer = waitOffer(f)
    local work = visit(f)
    local party = Services.getParty(f.worker, f.world)
    local x, y, index = party.x, party.y, work.centerIndex
    party.activeEncounterId = "reserved"
    assert(Services.cancel(offer.id, f.context, "fixture_cancel"))
    local events = #Events.getByType(f.world, "service_cancelled")
    f.tick(0.1)
    assert(f.worker.investigation_work == work and party.x == x and party.y == y)
    party.activeEncounterId = nil
    f.tick(0.1)
    assert(not f.worker.investigation_work and f.worker.lastInvestigationWork.phase == "cancelled")
    assert(f.worker.lastInvestigationWork.centerIndex == index and party.x == x and party.y == y)
    assert(not Services.hasObligation(f.worker, f.context))
    assert(#Events.getByType(f.world, "service_cancelled") == events, "duplicate cancellation event")
end

function Scenario.run()
    local random = TravelKnowledge.random
    TravelKnowledge.random = function() return 1 end
    local ok, err = xpcall(function()
        boundaries()
        outcomes(false)
        outcomes(true)
        interruptionAndLoss()
        partialReportingAndMissingEmployer()
        liveContact()
        knownFateAndRoute()
        searchRecoveryAndLocalReturn()
        terminalCancellation()
    end, debug.traceback)
    TravelKnowledge.random = random
    Bus.init()
    assert(ok, err)
end

-- Same ordinary WorldState preview convention as caravan_scenario.
function Scenario.preview(empty, smoke)
    love.window.setMode(1100, 800, {resizable = true})
    love.window.setTitle("Geherra 7E investigation playtest" .. (empty and " (empty search)" or ""))
    local f = Scenario.fixture(empty)
    waitOffer(f)
    love.math.setRandomSeed(1)
    local visitor = f.actor("Visiting traveler")
    local visitorParty = Party.create(f.world, "Visiting travelers", visitor.id)
    Parties.addActor(visitorParty, visitor)
    visitorParty.x, visitorParty.y = 100, 800
    f.map:addParty(visitorParty)
    Goals.configure(visitor, {{type = "reach_location", destinationLocationId = f.home.id}}, {travel = true})
    Game.data.playerParty.x, Game.data.playerParty.y = 100, 400
    Game.data.debugCampaign = {map = f.map, profile = empty and "investigation_empty" or "investigation",
        homeId = f.home.id, farId = f.far.id, actors = {f.sponsor.id, f.worker.id, visitor.id}, parties = {visitorParty.id}}
    require("src.debug.mode").enabled = true
    local States, Input = require("src.core.state_manager"), require("src.core.input")
    States.init(); Input.init(); States.push("world")
    local WorldState = require("src.game.states.world_state")
    WorldState.camera.x, WorldState.camera.y = 500, 300
    WorldState.debugOverlay:inspect("unit", f.sponsor.id)
    local frame = 0
    love.update = function(dt)
        if smoke and frame == 0 then
            for _ = 1, 2800 do f.tick(0.1) end
            assert(f.worker.lastInvestigationWork and f.worker.lastInvestigationWork.reported,
                "Preview investigator did not report: " .. require("src.ui.world_event_text").details({
                    worker = Knowledge.getKnownEvents(f.worker), visitor = Knowledge.getKnownEvents(visitor),
                    requests = Services.listRequests(f.context)}, true))
            assert((objective(f.sponsor).status == "satisfied") == not empty)
        end
        Input.update(dt); States.update(dt)
        frame = frame + 1
        if smoke and frame >= 3 then love.event.quit(0) end
    end
    love.draw = function()
        States.draw()
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("7E: hold Space to advance | F1 inspector | F2 history | F3 services | H injure investigator", 15, 70)
    end
    love.keypressed = function(key, _, repeated)
        if States.keypressed(key, repeated) then return end
        Input.keypressed(key)
        if key == "h" and not WorldState.blocksPointerInput() then f.worker.hp = 30 end
    end
    love.keyreleased = function(key) Input.keyreleased(key); States.keyreleased(key) end
    love.textinput = States.textinput
    love.mousepressed = function(x, y, button) Input.mousepressed(x, y, button); States.mousepressed(x, y, button) end
    love.mousereleased = function(x, y, button) Input.mousereleased(x, y, button); States.mousereleased(x, y, button) end
    love.mousemoved = function(x, y, dx, dy) Input.mousemoved(x, y, dx, dy) end
    love.wheelmoved = States.wheelmoved
end

return Scenario
