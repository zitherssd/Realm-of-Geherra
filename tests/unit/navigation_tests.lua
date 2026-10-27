local EcsWorld = require("src.ecs.world")
local Navigation = require("src.systems.world_navigation")
local Map = require("src.world.map")

local Tests = {}

local function makeMap(id, walkable)
    EcsWorld.init()
    local map = Map.new(id)
    map.width, map.height = 640, 640
    local grid = {cellSize = 64, cols = 10, rows = 10, cells = {}}
    for y = 1, grid.rows do
        grid.cells[y] = {}
        for x = 1, grid.cols do
            grid.cells[y][x] = {walkable = not walkable or walkable(x, y)}
        end
    end
    map.worldGen = {navigationGrid = grid}
    return map
end

function Tests.testSameStartAndGoal()
    local path, reason = Navigation.findPath(makeMap("same"), 100, 100, 100, 100)
    assert(path and #path == 1 and path[1].x == 100 and path[1].y == 100, tostring(reason))
end

function Tests.testBlockedDestination()
    local map = makeMap("blocked-destination", function(x, y) return x ~= 9 or y ~= 1 end)
    local path, reason = Navigation.findPath(map, 50, 50, 544, 50)
    assert(not path and reason == "destination_blocked", tostring(reason))
end

function Tests.testUnreachableGoal()
    local map = makeMap("unreachable", function(x) return x ~= 6 end)
    local path, reason = Navigation.findPath(map, 100, 100, 550, 100)
    assert(not path and reason == "destination_unreachable", tostring(reason))
end

function Tests.testBlockedStart()
    local map = makeMap("blocked-start", function(x, y) return x ~= 1 or y ~= 1 end)
    local path, reason = Navigation.findPath(map, 50, 50, 544, 50)
    assert(not path and reason == "start_blocked", tostring(reason))
    path, reason = Navigation.findPath(map, 50, 50, 50, 50)
    assert(not path and reason == "start_blocked", "A same-point route must still reject blocked ground")
end

function Tests.testMissingMap()
    local path, reason = Navigation.findPath(nil, 100, 100, 200, 200)
    assert(not path and reason == "map_unavailable", tostring(reason))
end

function Tests.testOutOfBoundsStart()
    local path, reason = Navigation.findPath(makeMap("start-bounds"), 9999, 9999, 100, 100)
    assert(not path and reason == "start_out_of_bounds", tostring(reason))
end

function Tests.testOutOfBoundsGoal()
    local path, reason = Navigation.findPath(makeMap("goal-bounds"), 100, 100, 9999, 9999)
    assert(not path and reason == "destination_out_of_bounds", tostring(reason))
end

function Tests.testNoNavigationGrid()
    local map = makeMap("no-grid")
    map.worldGen = nil
    local path, reason = Navigation.findPath(map, 100, 100, 500, 500)
    assert(path and #path == 1 and path[1].x == 500 and path[1].y == 500, tostring(reason))
end

function Tests.testEmptyResult()
    local path, reason = Navigation.findPath(makeMap("empty"), 100, 100, 200000, 50)
    assert(not path and reason == "destination_out_of_bounds", tostring(reason))
end

function Tests.testDiagonalMovement()
    local path, reason = Navigation.findPath(makeMap("diagonal"), 32, 32, 608, 608)
    assert(path and #path == 11, "Expected a direct diagonal route: " .. tostring(reason))
    for _, point in ipairs(path) do assert(point.x == point.y, "Route detoured off the diagonal") end
    local map = makeMap("blocked-corner", function(x, y)
        return (x == 1 and y == 1) or (x == 2 and y == 2)
    end)
    path, reason = Navigation.findPath(map, 32, 32, 96, 96)
    assert(not path and reason == "destination_unreachable", "Route cut through a blocked corner")
end

function Tests.run()
    Tests.testSameStartAndGoal()
    Tests.testBlockedDestination()
    Tests.testUnreachableGoal()
    Tests.testBlockedStart()
    Tests.testMissingMap()
    Tests.testOutOfBoundsStart()
    Tests.testOutOfBoundsGoal()
    Tests.testNoNavigationGrid()
    Tests.testEmptyResult()
    Tests.testDiagonalMovement()
    print("All navigation tests passed")
end

return Tests
