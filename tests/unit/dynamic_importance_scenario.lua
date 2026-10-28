local Ecs = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Location = require("src.ecs.assemblages.location")
local Locations = require("src.systems.locations.location_system")
local Parties = require("src.systems.parties.party_system")
local Map = require("src.world.map")
local Goals = require("src.systems.goals.goal_system")
local Definitions = require("src.systems.goals.goal_definitions")
local Importance = require("src.systems.goals.goal_importance")
local Activities = require("src.systems.world_activities.world_activity_system")
local Services = require("src.systems.services.service_system")
local Knowledge = require("src.systems.knowledge.knowledge_system")
local Events = require("src.systems.campaign.world_events")
local Time = require("src.systems.campaign.time_system")
local Game = require("src.game.game_context")
local Bus = require("src.core.event_bus")
local Inspector = require("src.debug.inspector")

local function setup(withParty)
    Bus.init(); Game.init(); Time.reset()
    local world, map = Ecs.init(), Map.new("dynamic-importance")
    Game.data.currentMap = map
    Activities.init()
    local home = Location.create(world, "importance-home", "Home")
    local far = Location.create(world, "importance-far", "Far")
    home.x, home.y, far.x, far.y = 100, 100, 900, 100
    map:addLocation(home); map:addLocation(far)
    local actor = Unit.create(world, "soldier", "motivated")
    actor:ensure("memory")
    actor.hp, actor.maxHp, actor.treasury = 100, 100, 0
    local party
    if withParty then
        party = Party.create(world, "Motivated party", actor.id)
        Parties.addActor(party, actor)
        party.x, party.y = 100, 100
        map:addParty(party); map:stationParty(home, party)
    else Locations.addNPC(home, actor) end
    return world, map, actor, party, home, far
end
local function tick(map, dt)
    Goals.update(dt, map)
    Activities.update(dt, map)
end
local function score(goal, actor, party) return Goals.getImportance(goal, actor, party) end

local function scoresAndPartyHealth()
    local world, map, actor, party = setup(true)
    local state = Goals.configure(actor, {{type = "rest_and_recover"}, {type = "acquire_gold", amount = 1000}}, {})
    local rest, wealth = unpack(state.goals)
    assert(score(rest, actor, party) == 0)
    assert(score(nil, actor, party) == 0)
    assert(score({type = "acquire_gold", amount = "invalid"}, actor, party) == 0)
    actor.hp = 80; local minor = score(rest, actor, party)
    actor.hp = 50; local serious = score(rest, actor, party)
    actor.hp = 20; local critical = score(rest, actor, party)
    assert(minor > 0 and serious > minor and critical > serious and critical >= 90)
    assert((serious - minor) / 30 > minor / 20, "health urgency is not nonlinear")
    actor.hp = 100
    local members = {}
    for i = 1, 10 do
        local member = Unit.create(world, "soldier")
        member.hp, member.maxHp = 100, 100
        Parties.addActor(party, member); members[i] = member
    end
    assert(score(rest, actor, party) == 0, "party size created urgency")
    members[1].hp = 80
    assert(score(rest, actor, party) < 5, "one minor wound stopped a large party")
    members[1].hp = 1
    local oneCritical = score(rest, actor, party)
    assert(oneCritical > 25, "critical member received no extra attention")
    for _, member in ipairs(members) do member.hp = 30 end
    assert(score(rest, actor, party) > oneCritical and score(rest, actor, party) > 70)
    assert(score(rest, actor, nil) == 0)
    assert(Importance.recovery(rest, members[1], party) == Importance.health(0.3), "follower used group health")
    for _, member in ipairs(members) do member.hp = 0 end
    assert(score(rest, actor, party) == 0, "dead members contributed urgency")
    party.treasury = 0; assert(score(wealth, actor, party) == 100)
    party.treasury = 800; assert(math.abs(score(wealth, actor, party) - 100 * 0.2 ^ 1.125) < 0.001)
    party.treasury = 1000; assert(score(wealth, actor, party) == 0)
    party.treasury = 2000; assert(score(wealth, actor, party) == 0)
    party.treasury = 100; assert(math.abs(score(wealth, actor, party) - 100 * 0.9 ^ 1.125) < 0.001)
    for _, value in ipairs({-100, 0, 50, 100, 10000, math.huge, -math.huge, 0/0}) do
        local n = Importance.clamp(value); assert(n >= 0 and n <= 100)
    end
    local count, gold, hp = Events.count(world), party.treasury, actor.hp
    for _ = 1, 20 do for _, goal in ipairs(state.goals) do score(goal, actor, party) end end
    assert(Events.count(world) == count and party.treasury == gold and actor.hp == hp
        and party.world_activity.status == "idle" and not actor.caravan_formation, "importance read executed gameplay")
end

local function switchingAndOwnership()
    local world, map, actor, party, home, far = setup(true)
    local state = Goals.configure(actor, {
        {type = "reach_location", destinationLocationId = far.id, importance = 70},
        {type = "provide_service", importance = 70}, {type = "rest_and_recover"}
    }, {travel = true})
    local travel, service, rest = unpack(state.goals)
    tick(map, 0.1)
    assert(state.selectedGoalIndex == 1 and travel.activity, "equal scores did not preserve configured order")
    local sequence = party.world_activity.sequence
    service.priority = 74
    for _ = 1, 3 do tick(map, 0.1) end
    assert(state.selectedGoalIndex == 1 and party.world_activity.sequence == sequence)
    service.priority = 75 -- Exactly five points is enough.
    Goals.update(0.1, map)
    assert(state.selectedGoalIndex == 2 and party.world_activity.status == "cancelled")
    assert(travel.destinationLocationId == far.id and travel.lastOutcome.reason == "goal_interrupted")
    Activities.update(0, map)
    actor.hp = 20
    tick(map, 5)
    assert(state.selectedGoalIndex == 3, "non-dominant injury failed to interrupt")
    assert(score(rest, actor, party) >= 90)
    actor.hp = 100; service.priority = 0; travel.retrySeconds = 0
    tick(map, 5); tick(map, 1)
    assert(state.selectedGoalIndex == 1 and travel.attempts == 2)
    local actualX, actualY = party.x, party.y
    assert(travel.activity and party.world_activity.params.destinationLocationId == far.id)
    assert(actualX >= home.x and actualY == home.y)
    travel.priority = 0
    Goals.update(0.1, map)
    assert(not state.selectedGoalIndex and #state.goals == 3 and not travel.activity)
    Activities.update(0, map); Activities.update(5, map)
    assert(Activities.start(party, "travel", {destinationLocationId = home.id}, map))
    local manual = party.world_activity.sequence
    tick(map, 0.1)
    assert(party.world_activity.sequence == manual and party.world_activity.status == "active",
        "zero goals cancelled an external activity")
    service.priority = 100
    tick(map, 0.1)
    assert(party.world_activity.sequence == manual and not service.activity, "goal stole manual travel")
end

local function recreatedTravelUsesCurrentPosition()
    local _, map, actor, party, _, far = setup(true)
    local state = Goals.configure(actor, {{type = "reach_location", destinationLocationId = far.id, importance = 40},
        {type = "rest_and_recover"}}, {travel = true})
    tick(map, 3)
    local travel = state.goals[1]
    local oldWaypoints = party.world_activity.waypoints
    assert(party.x > 200)
    actor.hp = 20
    tick(map, 0.1); tick(map, 5)
    -- Recovery has traveled away from the former route position using real movement.
    local currentX, currentY = party.x, party.y
    actor.hp = 100
    local Navigation = require("src.world.world_navigation")
    local findPath, starts = Navigation.findPath, {}
    Navigation.findPath = function(m, ax, ay, bx, by)
        starts[#starts + 1] = {x = ax, y = ay}
        return findPath(m, ax, ay, bx, by)
    end
    local ok, err = pcall(function()
        Goals.update(5, map); Activities.update(5, map)
        Goals.update(5, map)
        assert(travel.activity and travel.attempts == 2)
        assert(#starts >= 1 and starts[#starts].x == currentX and starts[#starts].y == currentY,
            "resumed travel reused an obsolete origin")
        assert(party.world_activity.waypoints ~= oldWaypoints and travel.destinationLocationId == far.id)
        assert(currentX >= 100 and currentY == 100)
    end)
    Navigation.findPath = findPath
    assert(ok, err)
end

local function invalidationAndReservations()
    local world, map, actor, party, home, far = setup(true)
    local state = Goals.configure(actor, {
        {type = "reach_location", destinationLocationId = far.id, importance = 70},
        {type = "provide_service", importance = 69}
    }, {travel = true})
    tick(map, 0.1)
    local travel = state.goals[1]
    party.activeEncounterId = "reserved"
    state.goals[2].priority = 100
    Goals.update(1, map)
    assert(party.world_activity.status == "active" and state.selectedGoalIndex == 1)
    party.activeEncounterId = nil
    Goals.update(1, map)
    assert(party.world_activity.status == "cancelled" and state.selectedGoalIndex == 2)
    Activities.update(5, map)
    state.goals[2].status = "invalid"
    travel.retrySeconds = 0
    tick(map, 1)
    assert(state.selectedGoalIndex == 1, "invalid incumbent retained control")
    state.goals[2].priority, state.goals[2].status = 69, "pending"
    travel.status = "cancelled"
    Goals.update(1, map)
    assert(state.selectedGoalIndex == 2, "cancelled incumbent required threshold")
    assert(travel.status == "cancelled")
end

local function accumulatedAndKnowledge()
    local world, map, actor, party, home = setup(false)
    Definitions.registerGoal("importance_test_clock", {
        priority = 0,
        advanceImportance = function(goal, _, _, dt)
            goal.accumulatedImportance = (goal.accumulatedImportance or 0) + dt * 2
            goal.intervals = (goal.intervals or 0) + 1
        end
    })
    local event = Events.record(world, "battle_ended", {time = {day = 1, hour = 6}, outcome = "victory"})
    local state = Goals.configure(actor, {{type = "provide_service", importance = 100},
        {type = "importance_test_clock", accumulatedImportance = 0},
        {type = "acquire_knowledge", eventId = event.id, requiredDetails = {outcome = true}}}, {})
    local clock, knowledge = state.goals[2], state.goals[3]
    assert(score(knowledge, actor) == 90, "hidden event revealed its answer")
    home.npcs[#home.npcs + 1] = actor -- Deliberate duplicate reference.
    tick(map, 1)
    assert(clock.accumulatedImportance == 2 and clock.intervals == 1 and state.selectedGoalIndex == 1)
    Time.setPaused(true)
    tick(map, Time.worldHoursToSeconds(Time.update(10)))
    assert(clock.accumulatedImportance == 2 and clock.intervals == 1)
    for _ = 1, 10 do score(clock, actor) end
    assert(clock.intervals == 1, "read interface advanced accumulated state")
    Time.setPaused(false)
    tick(map, Time.worldHoursToSeconds(Time.update(1)))
    assert(clock.accumulatedImportance == 4 and clock.intervals == 2)
    assert(Knowledge.learn(actor, event.id, {"outcome"}, world))
    assert(score(knowledge, actor) == 0)
    tick(map, 1000000)
    assert(clock.accumulatedImportance == 100 and clock.intervals == 3 and #state.goals == 3)
    assert(knowledge.status == "satisfied" and state.selectedGoalIndex == 1)
    local text = table.concat(Inspector.lines(map, "unit", actor.id), "\n")
    assert(text:find("importance") and text:find("dominant") and text:find("Accumulated importance"))
    Definitions.goals.importance_test_clock = nil
end

local function nonDominantServiceCannotTravel()
    local world, map, actor, party, home, far = setup(true)
    local employer = Unit.create(world, "soldier")
    employer:ensure("memory"); employer.hp = employer.maxHp
    Locations.addNPC(far, employer)
    local context = {world = world, map = map}
    local offer = assert(Services.createRequest(employer, {type = "fixture", requiredCapability = "heal"}, context))
    assert(Knowledge.learn(actor, offer.offerEventId, {"service", "employer", "location"}, world))
    local state = Goals.configure(actor, {{type = "provide_service"}, {type = "rest_and_recover"}}, {heal = true, travel = true})
    actor.hp = 20
    tick(map, 1)
    assert(state.selectedGoalIndex == 2 and party.world_activity.type == "rest")
    assert(not state.goals[1].activity and not state.goals[1].pursuedServiceId,
        "non-dominant service goal pursued a known employment opportunity")
    assert(not Services.isProviding(actor, context), "occupied party rest exposed local healing")
    assert(party.x == home.x and Services.getRequest(offer.id, context).status == "open")
    actor.hp = 100
    Goals.cancelActivities(actor)
    Activities.update(5, map)
    state.goals[1].priority = 0
    tick(map, 1)
    assert(not state.selectedGoalIndex and #state.goals == 2 and party.world_activity.status == "idle",
        "all-zero goals invented a primary activity")
end

local function responsibilityAndLocalServices()
    local world, map, actor, _, home = setup(false)
    local customer = Unit.create(world, "soldier")
    customer:ensure("memory"); customer.hp, customer.maxHp, customer.treasury = 30, 100, 100
    Locations.addNPC(home, customer)
    local context = {world = world, map = map}
    local state = Goals.configure(actor, {{type = "provide_service", importance = 20}, {type = "rest_and_recover"}}, {heal = true})
    actor.hp = 20
    tick(map, 1)
    assert(state.selectedGoalIndex == 2 and Services.isProviding(actor, context))
    assert(Services.perform(actor, customer, "heal", context) and customer.hp == 70 and actor.treasury == 10)
    actor.activeEncounterId = "battle"
    assert(not Services.isProviding(actor, context))
    actor.activeEncounterId = nil
    local request = assert(Services.createRequest(customer, {type = "fixture", requiredCapability = "heal", data = {}}, context))
    assert(Services.assign(request.id, actor, context))
    local obligation = state.goals[#state.goals]
    actor.personality.responsibility = 0; assert(score(obligation, actor) == 50)
    actor.personality.responsibility = 0.5; assert(score(obligation, actor) == 70)
    actor.personality.responsibility = 1; assert(score(obligation, actor) == 90)
    actor.personality.responsibility = nil; assert(score(obligation, actor) == 70)
    tick(map, 1)
    assert(Services.hasObligation(actor, context) == request.id and state.selectedGoalIndex == 2)
    actor.hp = 100
    tick(map, 1)
    assert(Services.selectedGoal(actor) == obligation and score(obligation, actor) == 70)
    tick(map, 100)
    assert(Services.selectedGoal(actor) == obligation and score(obligation, actor) == 70)
    assert(Services.complete(request.id, context))
    tick(map, 1)
    assert(score(obligation, actor) == 0 and obligation.resolvedStatus == "completed" and #state.goals == 3)
end

local Scenario = {}
function Scenario.run()
    scoresAndPartyHealth()
    switchingAndOwnership()
    recreatedTravelUsesCurrentPosition()
    invalidationAndReservations()
    accumulatedAndKnowledge()
    nonDominantServiceCannotTravel()
    responsibilityAndLocalServices()
    Game.data.currentMap = nil
end
return Scenario
