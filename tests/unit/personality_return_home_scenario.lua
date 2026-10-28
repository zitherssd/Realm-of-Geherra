local Ecs = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Location = require("src.ecs.assemblages.location")
local Locations = require("src.systems.locations.location_system")
local Parties = require("src.systems.parties.party_system")
local Factory = require("src.systems.population.npc_factory")
local Catalog = require("src.data.population.catalog")
local Personality = require("src.data.types.personality")
local Goals = require("src.systems.goals.goal_system")
local Definitions = require("src.systems.goals.goal_definitions")
local Importance = require("src.systems.goals.goal_importance")
local Activities = require("src.systems.world_activities.world_activity_system")
local Services = require("src.systems.services.service_system")
local Knowledge = require("src.systems.knowledge.knowledge_system")
local Events = require("src.systems.campaign.world_events")
local Runtime = require("src.game.campaign.campaign_runtime")
local Time = require("src.systems.campaign.time_system")
local Random = require("src.core.seeded_random")
local Game = require("src.game.game_context")
local Bus = require("src.core.event_bus")
local Map = require("src.world.map")
local Inspector = require("src.debug.inspector")

local function near(actual, expected)
    assert(math.abs(actual - expected) < 0.00001, tostring(actual) .. " ~= " .. tostring(expected))
end
local function setup(withParty)
    Bus.init(); Game.init(); Time.reset(); Activities.init()
    local world, map = Ecs.init(), Map.new("personality-home")
    Game.data.currentMap = map
    local home = Location.create(world, "home", "Home")
    local far = Location.create(world, "far", "Far")
    home.x, home.y, far.x, far.y = 100, 100, 900, 100
    map:addLocation(home); map:addLocation(far)
    local actor = Unit.create(world, "soldier", "homesick")
    actor:ensure("memory")
    actor.homeLocationId, actor.hp, actor.maxHp, actor.treasury = home.id, 100, 100, 0
    local party
    if withParty then
        party = Party.create(world, "Home party", actor.id)
        Parties.addActor(party, actor)
        party.x, party.y = far.x, far.y
        map:addParty(party); map:stationParty(far, party)
    else Locations.addNPC(home, actor) end
    return world, map, actor, party, home, far
end
local function tick(map, dt)
    Goals.update(dt, map)
    Activities.update(dt, map)
end

local function generation()
    local world, map, _, _, home = setup(false)
    local rng = Random.new(123, "personalities")
    local first = Factory.create(world, "healer", {rng = rng, homeLocationId = home.id})
    local second = Factory.create(world, "healer", {rng = rng})
    for _, name in ipairs(Personality.traits) do
        local range = Catalog.archetypes.healer.personality[name]
        assert(first.personality[name] >= range[1] and first.personality[name] <= range[2])
        assert(first.personality[name] ~= second.personality[name])
    end
    local again = Factory.create(world, "healer", {rng = Random.new(123, "personalities")})
    for _, name in ipairs(Personality.traits) do near(first.personality[name], again.personality[name]) end
    assert(first.homeLocationId == home.id and second.homeLocationId == nil)
    local plain = Factory.create(world, "elder", {seed = 2})
    for _, name in ipairs(Personality.traits) do assert(plain.personality[name] == 0.5) end
    assert(not Factory.createTroop(world, "soldier").personality)
    local named = Factory.create(world, "healer", {}, {name = "Named", personality = {greed = 1, homesickness = 0.2}})
    assert(named.personality.greed == 1 and named.personality.homesickness == 0.2 and named.personality.responsibility == 0.5)
    for _, bad in ipairs({{invented = 0.5}, {greed = {-0.1, 0.5}}, {greed = {0.8, 0.2}},
        {greed = {0, 1.1}}, {greed = {0}}, {greed = "bad"}, {greed = 0/0}, {greed = math.huge}, {greed = {0, 1, 1}}}) do
        assert(not pcall(Personality.validate, bad), "invalid personality accepted")
        assert(not pcall(Factory.create, world, "healer", {}, {personality = bad}))
    end
    assert(Catalog.validate())
    local before = first.personality
    Locations.addNPC(home, first)
    tick(map, 1)
    Goals.configure(first, {{type = "return_home"}}, {travel = true})
    assert(first.personality.homesickness == before.homesickness)
    local party = Party.create(world, "Named party", first.id)
    Locations.removeNPC(home, first)
    Parties.addActor(party, first); party.x, party.y = home.x, home.y
    map:addParty(party)
    assert(Activities.start(party, "travel", {destinationLocationId = "far"}, map))
    for _ = 1, 6 do tick(map, 1) end
    assert(first.homeLocationId == home.id and first.personality.greed == before.greed)
end

local function accumulation()
    assert(Definitions.create({type = "return_home", importance = 7}).accumulatedImportance == 7)
    local _, map, actor, party, home, far = setup(true)
    actor.personality = {homesickness = 1}
    local state = Goals.configure(actor, {{type = "provide_service", importance = 100}, {type = "return_home"}}, {})
    local goal = state.goals[2]
    assert(goal.accumulatedImportance == 0)
    home.npcs[#home.npcs + 1] = actor -- Stale resident reference must not imply home or double advancement.
    assert(not select(2, Importance.home(actor, map)))
    tick(map, 16)
    near(goal.accumulatedImportance, 12)
    assert(state.selectedGoalIndex == 1)
    Time.setPaused(true)
    tick(map, Time.worldHoursToSeconds(Time.update(5)))
    near(goal.accumulatedImportance, 12)
    Time.setPaused(false)
    local original = actor.personality.homesickness
    actor.personality.homesickness = 0
    tick(map, 16); near(goal.accumulatedImportance, 12)
    actor.personality.homesickness = 0.5
    tick(map, 16); near(goal.accumulatedImportance, 18)
    Locations.removeNPC(home, actor)
    map:addParty(party); map:stationParty(home, party)
    local arrival = goal.accumulatedImportance
    assert(arrival == 18 and select(2, Importance.home(actor, map)))
    tick(map, 8); near(goal.accumulatedImportance, 9)
    actor.personality.homesickness = original
    tick(map, 8); near(goal.accumulatedImportance, 0)
    assert(#state.goals == 2 and state.selectedGoalIndex == 1)
    map:addParty(party); map:stationParty(far, party)
    tick(map, 1000000); assert(goal.accumulatedImportance == 100)
    map:addParty(party); map:stationParty(home, party)
    tick(map, 1000000); assert(goal.accumulatedImportance == 0)
    actor.homeLocationId = "missing"
    goal.accumulatedImportance = 50
    tick(map, 100); assert(goal.accumulatedImportance == 50 and goal.reason == "home_missing")
    actor.homeLocationId = nil
    tick(map, 100); assert(goal.accumulatedImportance == 50)
end

local function behavior()
    local _, map, actor, party, home = setup(true)
    actor.personality = {homesickness = 0}
    local state = Goals.configure(actor, {{type = "return_home", accumulatedImportance = 85},
        {type = "provide_service", importance = 40}}, {travel = true})
    local goal = state.goals[1]
    tick(map, 1)
    assert(goal.activity and party.world_activity.type == "travel" and party.world_activity.params.destinationLocationId == home.id)
    local firstRoute = party.world_activity.waypoints
    state.goals[2].priority = 90
    Goals.update(1, map)
    assert(state.selectedGoalIndex == 2 and not goal.activity and goal.accumulatedImportance == 85)
    Activities.update(0, map); Activities.update(5, map)
    local Navigation = require("src.world.world_navigation")
    local findPath, startX = Navigation.findPath, party.x
    local routed = false
    Navigation.findPath = function(m, x, y, bx, by)
        assert(x == startX and y == party.y); routed = true
        return findPath(m, x, y, bx, by)
    end
    state.goals[2].priority = 40
    local ok, err = pcall(function() Goals.update(10, map) end)
    Navigation.findPath = findPath
    assert(ok, err)
    assert(routed and goal.activity and party.world_activity.waypoints ~= firstRoute)
    for _ = 1, 20 do tick(map, 1) end
    assert(select(2, Importance.home(actor, map)))
    assert(goal.accumulatedImportance > 0 and not goal.activity and party.world_activity.status == "idle")
    assert(state.selectedGoalIndex == 1 and party.world_activity.type == nil, "home created fake local work")
    goal.accumulatedImportance = 36
    Goals.update(0.01, map); assert(state.selectedGoalIndex == 1)
    goal.accumulatedImportance = 35
    Goals.update(0.01, map); assert(state.selectedGoalIndex == 2)
    local score = goal.accumulatedImportance
    Goals.update(1, map); assert(goal.accumulatedImportance < score)
    goal.accumulatedImportance, state.goals[2].priority = 0, 0
    Goals.update(1, map); assert(not state.selectedGoalIndex and #state.goals == 2)

    local _, residentMap, resident = setup(false)
    local residentState = Goals.configure(resident, {{type = "return_home", accumulatedImportance = 85},
        {type = "provide_service", importance = 40}}, {heal = true})
    tick(residentMap, 1)
    assert(residentState.selectedGoalIndex == 1 and residentState.goals[1].status == "active")
    assert(Services.getParty(resident) == nil)
    assert(Services.isProviding(resident, {world = Ecs.campaign, map = residentMap}))
    resident.homeLocationId = "far"
    tick(residentMap, 1)
    assert(residentState.goals[1].reason == "no_commanded_party")
end

local function passengersAndReservations()
    local world, map, actor, party, home = setup(true)
    local passenger = Unit.create(world, "soldier", "passenger")
    passenger:ensure("memory"); passenger.homeLocationId = home.id
    passenger.personality = {homesickness = 1}
    Parties.addActor(party, passenger)
    local passengerState = Goals.configure(passenger, {{type = "return_home"}}, {travel = true})
    assert(Activities.start(party, "travel", {destinationLocationId = home.id}, map))
    local sequence = party.world_activity.sequence
    Goals.update(16, map)
    near(passengerState.goals[1].accumulatedImportance, 12)
    assert(party.world_activity.sequence == sequence and not passengerState.goals[1].activity)
    assert(Services.getParty(passenger) == party and #party.actors == 2)
    Activities.update(20, map); Activities.update(1, map)
    assert(select(2, Importance.home(passenger, map)))
    Goals.update(1, map)
    assert(passengerState.goals[1].accumulatedImportance < 12 and #party.actors == 2)

    map:addParty(party)
    party.x, party.y = 500, 100
    local state = Goals.configure(actor, {{type = "return_home", accumulatedImportance = 85},
        {type = "provide_service", importance = 40}}, {travel = true})
    Activities.update(5, map); Goals.update(1, map)
    assert(state.goals[1].activity)
    party.activeEncounterId = "reserved"
    state.goals[2].priority = 100
    Goals.update(1, map)
    assert(state.selectedGoalIndex == 1 and party.world_activity.status == "active")
    party.activeEncounterId = nil
    Goals.update(1, map)
    assert(state.selectedGoalIndex == 2 and party.world_activity.status == "cancelled")

    local _, externalMap, externalActor, externalParty, externalHome = setup(true)
    local externalState = Goals.configure(externalActor, {{type = "return_home", accumulatedImportance = 85}}, {travel = true})
    assert(Activities.start(externalParty, "travel", {destinationLocationId = externalHome.id}, externalMap))
    local externalSequence = externalParty.world_activity.sequence
    Goals.update(1, externalMap)
    assert(externalParty.world_activity.sequence == externalSequence and not externalState.goals[1].activity,
        "ReturnHome stole an external travel activity")
end

local function wealthAndResponsibility()
    local _, map, actor, party, home = setup(true)
    local goal = Definitions.create({type = "acquire_gold", amount = 10000})
    party.treasury = 9000
    for _, case in ipairs({{0, 1}, {0.5, 100 * 0.1 ^ 1.125}, {1, 100 * 0.1 ^ 0.25}}) do
        actor.personality = {greed = case[1]}
        near(Goals.getImportance(goal, actor, party), case[2]); assert(goal.amount == 10000)
    end
    party.treasury = 10000; assert(Goals.getImportance(goal, actor, party) == 0)
    party.treasury = 11000; assert(Goals.getImportance(goal, actor, party) == 0)
    party.treasury = 1000; assert(Goals.getImportance(goal, actor, party) > 90)
    actor.personality = nil; actor.treasury = 9000
    near(Goals.getImportance(goal, actor), 100 * 0.1 ^ 1.125)
    assert(Goals.getImportance({type = "acquire_gold", amount = 0}, actor) == 0)
    assert(Goals.getImportance({type = "acquire_gold", amount = math.huge}, actor) == 0)
    assert(Goals.getImportance({type = "acquire_gold", amount = 0/0}, actor) == 0)
    local worker = Unit.create(Ecs.campaign, "soldier")
    worker:ensure("memory"); worker.responsibility = 0.9
    Goals.configure(worker, {{type = "provide_service"}}, {heal = true})
    assert(worker.personality.responsibility == 0.9 and worker.responsibility == nil)
    Goals.configure(worker, {{type = "provide_service"}}, {heal = true})
    assert(worker.personality.responsibility == 0.9)
    map:addParty(party); map:stationParty(home, party); Locations.addNPC(home, worker)
    local request = assert(Services.createRequest(actor, {type = "fixture", requiredCapability = "heal"}, {world = Ecs.campaign, map = map}))
    assert(Services.assign(request.id, worker, {world = Ecs.campaign, map = map}))
    local obligation = worker.npc_goals.goals[2]
    near(Goals.getImportance(obligation, worker), 86)
    worker.responsibility = 0 -- A late legacy field cannot contradict fixed personality.
    tick(map, 1)
    assert(worker.responsibility == nil and worker.personality.responsibility == 0.9)
    local initial = Goals.getImportance(obligation, worker)
    tick(map, 100); near(Goals.getImportance(obligation, worker), initial)
    assert(Services.complete(request.id, {world = Ecs.campaign}))
    local events = Events.count(Ecs.campaign)
    assert(Services.complete(request.id, {world = Ecs.campaign}) and Events.count(Ecs.campaign) == events)
end

local function arrival(mode)
    local world, map, healer, party, home, far = setup(true)
    map:addParty(party); map:stationParty(home, party)
    healer.personality = {homesickness = 1}
    local state = Goals.configure(healer, {{type = "provide_service", importance = 40}, {type = "return_home"}}, {heal = true, travel = true})
    local customer = Unit.create(world, "soldier", "patient")
    customer:ensure("memory"); customer.hp, customer.maxHp, customer.treasury = 30, 100, 100
    Locations.addNPC(far, customer)
    local context = {world = world, map = map}
    local request = assert(Services.createRequest(customer, {type = "heal", requiredCapability = "heal"}, context))
    Knowledge.learn(healer, request.offerEventId, {"service", "employer", "location"}, world)
    Goals.update(0.1, map)
    assert(state.goals[1].activity and state.goals[1].pursuedServiceId == request.id)
    assert(not Services.assign(request.id, healer, context), "remote acceptance")
    state.goals[2].accumulatedImportance = 95
    if mode == "cancelled" then Services.cancel(request.id, context, "cancelled_before_arrival") end
    if mode == "unavailable" then customer.activeEncounterId = "reserved" end
    if mode == "capability" then state.capabilities.heal = false end
    if mode == "remote" then Locations.removeNPC(far, customer); Locations.addNPC(home, customer) end
    -- Finish real travel before the next goal decision; homesickness is already dominant.
    Activities.update(20, map); Activities.update(1, map)
    assert(Services.getLocation(healer, context) == far)
    if mode == "busy" then
        Activities.update(5, map)
        assert(Activities.start(party, "rest", {actorId = healer.id}, map))
    end
    if mode == "encounter" then party.activeEncounterId = "reserved" end
    local money, events = party.treasury, Events.count(world)
    Runtime.updateGoals(0.1, map)
    if mode then
        assert(customer.hp == 30 and party.treasury == money)
        assert(Services.getRequest(request.id, context).status ~= "completed")
    else
        assert(customer.hp == 70 and customer.treasury == 90 and party.treasury == money + 10)
        assert(Services.getRequest(request.id, context).status == "completed")
        assert(Events.count(world) == events + 2, "assignment/completion events duplicated")
        assert(Services.selectedGoal(healer).type == "return_home")
        for _ = 1, 7 do Runtime.updateGoals(1, map); Activities.update(1, map) end
        assert(state.goals[2].activity and party.world_activity.params.destinationLocationId == home.id)
        assert(customer.hp == 70 and customer.treasury == 90 and party.treasury == money + 10)
        assert(not Services.assign(request.id, healer, context))
        local text = table.concat(Inspector.lines(map, "unit", healer.id), "\n")
        assert(text:find("Personality homesickness") and text:find("At home:") and text:find("ReturnHome rate:"))
    end
end

local function passengerArrivalBeforeLeaderDeparture()
    local world, map, leader, party, home, far = setup(true)
    local leaderState = Goals.configure(leader, {{type = "return_home", accumulatedImportance = 100}}, {travel = true})
    leader.personality.homesickness = 0
    local healer = Unit.create(world, "soldier", "passenger-healer")
    healer:ensure("memory"); healer.homeLocationId = home.id
    local state = Goals.configure(healer, {{type = "provide_service", importance = 40},
        {type = "return_home", accumulatedImportance = 95}}, {heal = true, travel = true})
    Parties.addActor(party, healer)
    local patient = Unit.create(world, "soldier", "passenger-patient")
    patient:ensure("memory"); patient.hp, patient.maxHp, patient.treasury = 30, 100, 100
    Locations.addNPC(far, patient)
    local context = {world = world, map = map}
    local request = assert(Services.createRequest(patient, {type = "heal", requiredCapability = "heal"}, context))
    Knowledge.learn(healer, request.offerEventId, {"service", "employer", "location"}, world)
    -- Retained opportunity from before boarding; no new passenger movement authority.
    state.goals[1].pursuedServiceId, state.goals[1].retrySeconds = request.id, 10
    assert(map:addParty(party))
    party.x, party.y = 850, 100
    assert(Activities.start(party, "travel", {destinationLocationId = far.id}, map))
    local sequence = party.world_activity.sequence
    Runtime.updateGoals(0.1, map)
    assert(patient.hp == 30 and Services.getRequest(request.id, context).status == "open")
    assert(party.world_activity.sequence == sequence and not state.goals[2].activity)
    Activities.update(1, map); Activities.update(1, map)
    assert(Services.getLocation(healer, context) == far)
    Activities.update(0, map); Activities.update(5, map)
    Runtime.updateGoals(0.1, map)
    assert(patient.hp == 70 and Services.getRequest(request.id, context).status == "completed")
    assert(leaderState.goals[1].activity and party.world_activity.params.destinationLocationId == home.id,
        "leader departure must follow passenger's arrival work")
    assert(Services.getParty(healer) == party and #party.actors == 2 and not state.goals[2].activity)
end

local Scenario = {}
function Scenario.run()
    generation(); accumulation(); behavior(); passengersAndReservations(); wealthAndResponsibility()
    arrival()
    for _, mode in ipairs({"cancelled", "unavailable", "capability", "remote", "busy", "encounter"}) do arrival(mode) end
    passengerArrivalBeforeLeaderDeparture()
    Game.data.currentMap = nil
end
return Scenario
