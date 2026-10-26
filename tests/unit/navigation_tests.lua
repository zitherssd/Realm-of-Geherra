local EcsWorld = require("src.ecs.world")
local Location = require("src.ecs.assemblages.location")
local Unit = require("src.ecs.assemblages.unit")
local Navigation = require("src.systems.world_navigation")
local Map = require("src.world.map")

local Tests = {}

-- Test 1: Pathfinding to same coordinates
function Tests.testSameStartAndGoal()
    local world = EcsWorld.init()
    local map = Map.new("test-same-point")
    local origin = Location.create(world, "test-origin", "Origin")
    origin.siteId, origin.x, origin.y = "site-a", 100, 100
    
    local gridCol = math.floor(100 / 64) + 1
    local gridRow = math.floor(100 / 64) + 1
    
    map.worldGen = {
        navigationGrid = {
            cellSize = 64,
            cols = 50,
            rows = 50,
            cells = {}
        }
    }
    
    for y = 1, 50 do
        map.worldGen.navigationGrid.cells[y] = {}
        for x = 1, 50 do
            local cell = {walkable = true}
            if (x == gridCol and y == gridRow) then
                cell.blockedReason = "water"
                cell.walkable = false
            end
            map.worldGen.navigationGrid.cells[y][x] = cell
        end
    end
    
    local waypoints, reason = Navigation.findPath(map, 100, 100, 100, 100)
    assert(waypoints and #waypoints == 1 and waypoints[1].x == 100,
        "same-point path: " .. tostring(reason))
end

-- Test 2: Blocked destination
function Tests.testBlockedDestination()
    local world = EcsWorld.init()
    local map = Map.new("test-blocked-dest")
    
    local function makeGrid(walkableFn)
        return {
            cellSize = 64,
            cols = 10,
            rows = 10,
            cells = {}
        }
    end
    
    for y = 1, 10 do
        makeGrid.walkable = walkableFn
        map.worldGen.navigationGrid.cells[y] = {}
        for x = 1, 10 do
            local cell = {walkable = walkableFn(x * 64, y * 64)}
            map.worldGen.navigationGrid.cells[y][x] = cell
        end
    end
    
    local waypoints, reason = Navigation.findPath(map, 50, 50, 512, 50)
    assert(not waypoints and reason == "destination_blocked",
        "blocked-dest: " .. tostring(reason))
    
    map.worldGen = makeGrid(function() return true end)
end

-- Test 3: Unreachable destination (no path exists)
function Tests.testUnreachableGoal()
    local world = EcsWorld.init()
    local map = Map.new("test-unreachable")
    
    for y = 1, 10 do
        map.worldGen.navigationGrid.cells[y] = {}
        for x = 1, 10 do
            local cell = {walkable = true}
            if x == 6 and y <= 5 then
                cell.walkable = false
            end
            map.worldGen.navigationGrid.cells[y][x] = cell
        end
    end
    
    local waypoints, reason = Navigation.findPath(map, 100, 100, 550, 100)
    assert(not waypoints and reason == "destination_unreachable",
        "unreachable goal: " .. tostring(reason))
end

-- Test 4: Start position is blocked
function Tests.testBlockedStart()
    local world = EcsWorld.init()
    local map = Map.new("test-blocked-start")
    
    local function makeGrid()
        local grid = {
            cellSize = 64,
            cols = 10,
            rows = 10,
            cells = {}
        }
        for y = 1, 10 do
            grid.cells[y] = {}
            for x = 1, 10 do
                local cell = {walkable = true}
                if (x == math.floor(50 / 64) + 1 then
                    cell.walkable = false
                end
                grid.cells[y][x] = cell
            end
        end
        return grid
    end
    
    map.worldGen = makeGrid()
    
    local waypoints, reason = Navigation.findPath(map, 50, 50, 512, 50)
    assert(not waypoints and reason == "start_blocked",
        "blocked start: " .. tostring(reason))
end

-- Test 5: Missing map should return error
function Tests.testMissingMap()
    local waypoints, reason = Navigation.findPath(nil, 100, 100, 200, 200)
    assert(not waypoints and reason == "map_unavailable",
        "missing map: " .. tostring(reason))
end

-- Test 6: Out of bounds start
function Tests.testOutOfBoundsStart()
    local world = EcsWorld.init()
    local map = Map.new("test-outbounds-start")
    
    for y = 1, 5 do
        map.worldGen.navigationGrid.cells[y] = {}
        for x = 1, 5 do
            map.worldGen.navigationGrid.cells[y][x] = {walkable = true}
        end
    end
    
    local waypoints, reason = Navigation.findPath(map, 9999, 9999, 100, 100)
    assert(not waypoints and reason == "start_out_of_bounds",
        "out of bounds start: " .. tostring(reason))
end

-- Test 7: Out of bounds goal
function Tests.testOutOfBoundsGoal()
    local world = EcsWorld.init()
    local map = Map.new("test-outbounds-goal")
    
    for y = 1, 5 do
        map.worldGen.navigationGrid.cells[y] = {}
        for x = 1, 5 do
            map.worldGen.navigationGrid.cells[y][x] = {walkable = true}
        end
    end
    
    local waypoints, reason = Navigation.findPath(map, 100, 100, 9999, 9999)
    assert(not waypoints and reason == "destination_out_of_bounds",
        "out of bounds goal: " .. tostring(reason))
end

-- Test 8: No navigation grid (should return direct path)
function Tests.testNoNavigationGrid()
    local world = EcsWorld.init()
    local map = Map.new("test-no-grid")
    
    local origin = Location.create(world, "no-grid-origin", "Origin")
    origin.siteId, origin.x, origin.y = "site-a", 100, 100
    
    local destination = Location.create(world, "no-grid-dest", "Dest")
    destination.siteId, destination.x, destination.y = "site-b", 500, 500
    map:addLocation(destination)
    
    local waypoints, reason = Navigation.findPath(map, 100, 100, 500, 500)
    assert(waypoints and #waypoints > 0 and waypoints[2].x == 500,
        "no grid path: " .. tostring(reason))
end

-- Test 9: Empty waypoints list
function Tests.testEmptyResult()
    local world = EcsWorld.init()
    local map = Map.new("test-empty")
    
    for y = 1, 5 do
        map.worldGen.navigationGrid.cells[y] = {}
        for x = 1, 5 do
            map.worldGen.navigationGrid.cells[y][x] = {walkable = true}
        end
    end
    
    local waypoints, reason = Navigation.findPath(map, 100, 100, 200000, 50)
    assert(not waypoints and reason == "destination_unreachable",
        "empty result: " .. tostring(reason))
end

-- Test 10: Diagonal movement costs
function Tests.testDiagonalMovement()
    local world = EcsWorld.init()
    local map = Map.new("test-diagonal")
    
    for y = 1, 10 do
        map.worldGen.navigationGrid.cells[y] = {}
        for x = 1, 10 do
            map.worldGen.navigationGrid.cells[y][x] = {walkable = true}
        end
    end
    
    local waypoints, _ = Navigation.findPath(map, 50, 50, 64 * 9 + 32, 64 * 9 + 32)
    if waypoints then
        -- Verify path exists and moves diagonally
        assert(waypoints[1].x < waypoints[#waypoints - 1].x,
            "diagonal path: x should increase")
        assert(waypoints[1].y < waypoints[#waypoints - 1].y,
            "diagonal path: y should increase")
    end
end

Tests.run = function()
    print("Running navigation unit tests...")
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
    print("All navigation tests passed!")
end

return Tests
