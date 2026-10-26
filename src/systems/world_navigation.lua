-- Static terrain navigation. Uses the same grid and speed data as Map movement.
local Navigation = {}

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function inBounds(map, x, y)
    return finite(x) and finite(y) and x >= (map.minX or 0) and y >= (map.minY or 0)
        and x < (map.maxX or map.width) and y < (map.maxY or map.height)
end

-- Binary min-heap: duplicate entries are cheap; stale entries are skipped on pop.
local function push(heap, node)
    local i = #heap + 1
    while i > 1 do
        local parent = math.floor(i / 2)
        if heap[parent].f <= node.f then break end
        heap[i] = heap[parent]
        i = parent
    end
    heap[i] = node
end

local function pop(heap)
    local first, last = heap[1], table.remove(heap)
    if #heap > 0 then
        local i = 1
        while i * 2 <= #heap do
            local child = i * 2
            if child < #heap and heap[child + 1].f < heap[child].f then child = child + 1 end
            if last.f <= heap[child].f then break end
            heap[i] = heap[child]
            i = child
        end
        heap[i] = last
    end
    return first
end

-- Returns world-space waypoints, or nil plus an explicit reason. No entity mutation.
-- Call once when issuing travel, not every update. A path includes the start-cell
-- centre so arbitrary endpoints cannot cut across a blocked neighbouring cell.
function Navigation.findPath(map, startX, startY, goalX, goalY)
    if not map then return nil, "map_unavailable" end
    if not inBounds(map, startX, startY) then return nil, "start_out_of_bounds" end
    if not inBounds(map, goalX, goalY) then return nil, "destination_out_of_bounds" end
    if not map:isWalkable(startX, startY) then return nil, "start_blocked" end
    if not map:isWalkable(goalX, goalY) then return nil, "destination_blocked" end
    local grid = map.worldGen and map.worldGen.navigationGrid
    -- Map explicitly treats maps without terrain data as open ground.
    if not grid then return {{x = goalX, y = goalY}} end

    local size, cols = grid.cellSize, grid.cols
    local sx, sy = math.floor(startX / size) + 1, math.floor(startY / size) + 1
    local gx, gy = math.floor(goalX / size) + 1, math.floor(goalY / size) + 1
    if sx == gx and sy == gy then return {{x = goalX, y = goalY}} end
    local function key(x, y) return (y - 1) * cols + x end
    local function center(x, y) return (x - 0.5) * size, (y - 0.5) * size end
    local function walkable(x, y)
        local row = grid.cells[y]
        local cell = row and row[x]
        local wx, wy = center(x, y)
        return cell and cell.walkable and inBounds(map, wx, wy)
    end
    -- Existing terrain/road modifiers never exceed 1: Euclidean distance is
    -- an admissible lower bound for estimated travel time at base speed 1.
    local function heuristic(x, y)
        return math.sqrt((gx - x)^2 + (gy - y)^2) * size
    end
    local costs = {}
    local function cost(x, y)
        local id = key(x, y)
        if not costs[id] then
            local wx, wy = center(x, y)
            costs[id] = 1 / math.max(0.01, math.min(1, map:getTravelSpeedMod(wx, wy)))
        end
        return costs[id]
    end
    local startId, goalId = key(sx, sy), key(gx, gy)
    local scores, parents, closed, open = {[startId] = 0}, {}, {}, {}
    push(open, {x = sx, y = sy, id = startId, g = 0, f = heuristic(sx, sy)})
    while #open > 0 do
        local current = pop(open)
        if not closed[current.id] and current.g == scores[current.id] then
            if current.id == goalId then
                local reverse, id = {}, goalId
                while id do
                    local x, y = (id - 1) % cols + 1, math.floor((id - 1) / cols) + 1
                    local wx, wy = center(x, y)
                    reverse[#reverse + 1] = {x = wx, y = wy}
                    id = parents[id]
                end
                local path = {}
                for i = #reverse, 1, -1 do path[#path + 1] = reverse[i] end
                path[#path + 1] = {x = goalX, y = goalY}
                return path
            end
            closed[current.id] = true
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local x, y = current.x + dx, current.y + dy
                    if (dx ~= 0 or dy ~= 0) and walkable(x, y)
                        and (dx == 0 or dy == 0 or
                            (walkable(current.x + dx, current.y) and walkable(current.x, current.y + dy))) then
                        local id = key(x, y)
                        local stepCost = size * math.sqrt(dx * dx + dy * dy)
                            * (cost(current.x, current.y) + cost(x, y)) / 2
                        local score = current.g + stepCost
                        if not closed[id] and score < (scores[id] or math.huge) then
                            scores[id], parents[id] = score, current.id
                            push(open, {x = x, y = y, id = id, g = score, f = score + heuristic(x, y)})
                        end
                    end
                end
            end
        end
    end
    return nil, "destination_unreachable"
end

return Navigation
