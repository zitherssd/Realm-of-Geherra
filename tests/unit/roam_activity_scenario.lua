local EcsWorld = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local Location = require("src.ecs.assemblages.location")
local Map = require("src.world.map")
local Activities = require("src.systems.world_activity_system")
local Movement = require("src.systems.party_ai_system")
local Time = require("src.systems.time_system")

local function fixture()
    local world = EcsWorld.init()
    local map = Map.new("roam-map")
    map.width, map.height = 400, 400
    local grid = {cellSize = 20, cols = 20, rows = 20, cells = {}}
    for y = 1, 20 do
        grid.cells[y] = {}
        for x = 1, 20 do
            grid.cells[y][x] = {walkable = not (x == 12 and y >= 8 and y <= 12), biomeId = "forest"}
        end
    end
    map.worldGen = {navigationGrid = grid, roads = {}}
    local party = Party.create(world, "Roamer", nil, "roamer")
    party.x, party.y, party.state = 210, 210, "wander"
    assert(map:addParty(party))
    return world, map, party
end

local function testMovementAndLifecycle()
    local _, map, party = fixture()
    local params = {originX = 200, originY = 200, radius = 150, durationSeconds = 30}
    assert(Activities.start(party, "roam", params, map))
    local activity = party.world_activity
    assert(not Activities.start(party, "roam", params, map), "roam replaced active movement")
    local x, y = party.x, party.y
    Movement.update(1, map, {})
    Activities.update(0, map)
    assert(party.x == x and party.y == y and activity.elapsedSeconds == 0)
    Time.setPaused(true)
    Activities.update(Time.worldHoursToSeconds(Time.update(5)), map)
    assert(party.x == x and party.y == y and activity.elapsedSeconds == 0)
    Time.setPaused(false)
    party.activeEncounterId = "reserved"
    Activities.update(10, map)
    assert(party.x == x and party.y == y and activity.elapsedSeconds == 0)
    party.activeEncounterId = nil
    local moved, destinations = false, {}
    for _ = 1, 120 do
        local endpoint = activity.waypoints[#activity.waypoints]
        destinations[tostring(endpoint.x) .. ":" .. tostring(endpoint.y)] = true
        x, y = party.x, party.y
        -- Passing this party as player also verifies generic explicit activity support.
        Activities.update(0.25, map, party)
        local distance = math.sqrt((party.x - x)^2 + (party.y - y)^2)
        moved = moved or distance > 0
        assert(distance <= 70 * 0.25 + 0.00001, "roaming teleported")
        assert(map:isWalkable(party.x, party.y), "roaming crossed blocked terrain")
        assert((party.x - 200)^2 + (party.y - 200)^2 <= 150^2 + 0.00001, "roaming left its area")
    end
    local count = 0
    for _ in pairs(destinations) do count = count + 1 end
    assert(moved and count > 1, "roaming failed to select successive destinations")
    assert(activity.status == "idle" and activity.lastActivity.reason == "duration_elapsed")
    assert(activity.lastActivity.status == "completed" and not activity.waypoints and not activity.elapsedSeconds)
    assert(party.state == "wander")
end

local function testOriginsCancellationAndFailure()
    local world, map, party = fixture()
    local location = Location.create(world, "roam-origin", "Origin")
    location.x, location.y = 210, 210
    map:addLocation(location)
    assert(map:stationParty(location, party))
    local params = {originLocationId = location.id, radius = 150}
    assert(Activities.start(party, "roam", params, map))
    assert(#location.stationedParties == 0 and map:getParties()[1] == party)
    assert(party.world_activity:serialize().params.originLocationId == location.id)
    Activities.update(1, map)
    assert(Activities.cancel(party, "manual_stop"))
    Activities.update(0, map)
    assert(party.world_activity.lastActivity.reason == "manual_stop" and not party.world_activity.waypoints)
    Activities.update(5, map)
    assert(Activities.start(party, "roam", params, map))
    map.locations = {}
    Activities.update(1, map)
    assert(party.world_activity.reason == "origin_missing")
    Activities.update(0, map)
    Activities.update(5, map)
    params = {originX = 200, originY = 200, radius = 150}
    assert(Activities.start(party, "roam", params, map))
    assert(map:removeParty(party.id))
    assert(party.world_activity.reason == "party_removed")
    local x, y = party.x, party.y
    Activities.update(10, map)
    assert(party.x == x and party.y == y)

    _, map, party = fixture()
    for _, row in ipairs(map.worldGen.navigationGrid.cells) do
        for _, cell in ipairs(row) do cell.walkable = false end
    end
    local started, reason = Activities.start(party, "roam", params, map)
    assert(not started and reason == "no_roaming_destination")
    assert(party.world_activity.status == "idle", "failed selection partially started roaming")

    _, map, party = fixture()
    assert(Activities.start(party, "roam", params, map))
    map.isWalkable = function() return false end
    Activities.update(15, map)
    assert(party.world_activity.reason == "route_stalled")
    Activities.update(0, map)
    assert(not party.world_activity.waypoints)

    _, map, party = fixture()
    assert(Activities.start(party, "roam", params, map))
    party:destroy()
    Activities.update(1, map)
    assert(party.world_activity.reason == "party_removed" and #map:getParties() == 0)
end

local Scenario = {}
function Scenario.run()
    -- Deterministic candidates without altering random state for other scenarios.
    local random, index = math.random, 0
    math.random = function()
        index = index + 1
        return ((index * 37) % 101) / 101
    end
    local ok, err = xpcall(function()
        testMovementAndLifecycle()
        testOriginsCancellationAndFailure()
    end, debug.traceback)
    math.random = random
    Time.setPaused(true)
    assert(ok, err)
end
return Scenario
