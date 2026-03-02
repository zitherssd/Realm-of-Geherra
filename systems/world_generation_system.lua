local WorldGenerationConfig = require("data.world_generation")

local WorldGenerationSystem = {}

local function makeRng(seed)
    local state = math.max(1, math.floor(seed or WorldGenerationConfig.defaultSeed))
    return function(min, max)
        state = (1103515245 * state + 12345) % 2147483648
        local ratio = state / 2147483648
        if not min then
            return ratio
        end
        if not max then
            return math.floor(ratio * min) + 1
        end
        return math.floor(min + ratio * (max - min + 1))
    end
end

local function weightedChoice(list, rng)
    local total = 0
    for _, item in ipairs(list) do
        total = total + (item.weight or 1)
    end

    local pick = rng() * total
    local cursor = 0
    for _, item in ipairs(list) do
        cursor = cursor + (item.weight or 1)
        if pick <= cursor then
            return item
        end
    end

    return list[#list]
end

local function keyOf(x, y)
    return string.format("%d:%d", x, y)
end

local function inBounds(grid, x, y)
    return y >= 1 and y <= #grid and x >= 1 and x <= #grid[y]
end

local function loadImageData(path)
    if not love.filesystem.getInfo(path) then
        return nil
    end

    local ok, imageData = pcall(love.image.newImageData, path)
    if ok then
        return imageData
    end

    return nil
end

local function resolveTerrainMaskData(map, options, config)
    local maskPath = options.terrainMaskPath
        or (config.map and config.map.terrainMaskPath)

    if maskPath then
        return loadImageData(maskPath)
    end

    if map.visuals and map.visuals.image then
        local ok, imageData = pcall(function()
            return map.visuals.image:newImageData()
        end)

        if ok then
            return imageData
        end
    end

    return nil
end

local function buildWalkableGrid(map, navigationConfig, imageData)
    local cellSize = navigationConfig.cellSize
    local cols = math.max(1, math.floor(map.width / cellSize))
    local rows = math.max(1, math.floor(map.height / cellSize))
    local grid = {}
    local blackThreshold = navigationConfig.blackThreshold or 0.08

    for y = 1, rows do
        grid[y] = {}
        for x = 1, cols do
            local walkable = true

            if imageData then
                local sampleX = math.min(imageData:getWidth() - 1, math.floor((x - 0.5) * cellSize))
                local sampleY = math.min(imageData:getHeight() - 1, math.floor((y - 0.5) * cellSize))
                local r, g, b = imageData:getPixel(sampleX, sampleY)
                local luminance = (r + g + b) / 3
                walkable = luminance > blackThreshold
            end

            grid[y][x] = {
                x = x,
                y = y,
                worldX = (x - 0.5) * cellSize,
                worldY = (y - 0.5) * cellSize,
                walkable = walkable,
                blockedReason = walkable and nil or "terrain",
                biomeId = nil
            }
        end
    end

    return {
        cellSize = cellSize,
        cols = cols,
        rows = rows,
        cells = grid
    }
end

local function applyContinentWaterMask(navigationGrid, continentConfig, seed)
    if not continentConfig or continentConfig.enabled == false then
        return
    end

    local rows = navigationGrid.rows
    local cols = navigationGrid.cols
    local centerX = (cols + 1) / 2
    local centerY = (rows + 1) / 2
    local invHalfWidth = 2 / math.max(1, cols)
    local invHalfHeight = 2 / math.max(1, rows)
    local radius = continentConfig.radius or 0.9
    local edgeBand = continentConfig.edgeWaterBandCells or 0
    local noiseScale = continentConfig.noiseScale or 2.2
    local noiseStrength = continentConfig.noiseStrength or 0
    local seedOffset = (tonumber(seed) or 0) * 0.001

    for y = 1, rows do
        for x = 1, cols do
            local cell = navigationGrid.cells[y][x]

            local inEdgeBand = x <= edgeBand
                or y <= edgeBand
                or x > (cols - edgeBand)
                or y > (rows - edgeBand)

            local nx = (x - centerX) * invHalfWidth
            local ny = (y - centerY) * invHalfHeight
            local radial = math.sqrt(nx * nx + ny * ny)

            local noise = 0
            if noiseStrength > 0 and love.math and love.math.noise then
                noise = (love.math.noise((x / cols) * noiseScale + seedOffset, (y / rows) * noiseScale + seedOffset) - 0.5) * 2
            end

            local waterByShape = radial > (radius + noise * noiseStrength)

            if inEdgeBand or waterByShape then
                cell.walkable = false
                cell.biomeId = nil
                cell.blockedReason = "water"
            end
        end
    end
end

local function collectWalkableCells(navigationGrid, padding)
    local walkable = {}
    for y = 1 + padding, navigationGrid.rows - padding do
        for x = 1 + padding, navigationGrid.cols - padding do
            local cell = navigationGrid.cells[y][x]
            if cell.walkable then
                table.insert(walkable, cell)
            end
        end
    end
    return walkable
end

local function chooseSites(navigationGrid, config, rng)
    local sites = {}
    local candidates = collectWalkableCells(navigationGrid, config.edgePaddingCells or 0)
    local baseMinDistance = config.minDistanceCells or 1

    if #candidates == 0 then
        return sites
    end

    local attempts = config.maxPlacementAttempts or 1000
    local targetCount = config.majorCount or 5
    local relaxation = config.distanceRelaxation or {}

    local function currentMinDistanceSq(attempt)
        if not relaxation.enabled then
            return baseMinDistance * baseMinDistance
        end

        local startRatio = relaxation.startAttemptRatio or 0.35
        local endMultiplier = relaxation.endDistanceMultiplier or 0.55
        local startAttempt = math.floor(attempts * startRatio)

        if attempt <= startAttempt then
            return baseMinDistance * baseMinDistance
        end

        local progress = (attempt - startAttempt) / math.max(1, (attempts - startAttempt))
        progress = math.max(0, math.min(1, progress))

        local distance = baseMinDistance * (1 - progress * (1 - endMultiplier))
        distance = math.max(1, distance)
        return distance * distance
    end

    for attempt = 1, attempts do
        if #sites >= targetCount then
            break
        end

        local minDistanceSq = currentMinDistanceSq(attempt)

        local idx = rng(1, #candidates)
        local candidate = candidates[idx]
        local valid = true

        for _, site in ipairs(sites) do
            local dx = site.cellX - candidate.x
            local dy = site.cellY - candidate.y
            if (dx * dx + dy * dy) < minDistanceSq then
                valid = false
                break
            end
        end

        if valid then
            table.insert(sites, {
                id = string.format("site_%d", #sites + 1),
                cellX = candidate.x,
                cellY = candidate.y,
                x = candidate.worldX,
                y = candidate.worldY
            })
        end
    end

    while #sites < targetCount and #candidates > 0 do
        local candidate = candidates[rng(1, #candidates)]
        table.insert(sites, {
            id = string.format("site_%d", #sites + 1),
            cellX = candidate.x,
            cellY = candidate.y,
            x = candidate.worldX,
            y = candidate.worldY
        })
    end

    return sites
end

local function assignBiomesToSites(sites, biomeConfig, rng)
    for _, site in ipairs(sites) do
        local biome = weightedChoice(biomeConfig, rng)
        site.biomeId = biome.id
    end
end

local function assignVoronoiBiomes(navigationGrid, sites, biomeConfig)
    local biomeById = {}
    for _, biome in ipairs(biomeConfig) do
        biomeById[biome.id] = biome
    end

    for y = 1, navigationGrid.rows do
        for x = 1, navigationGrid.cols do
            local cell = navigationGrid.cells[y][x]
            if cell.walkable then
                local nearestSite = nil
                local nearestDistSq = math.huge

                for _, site in ipairs(sites) do
                    local dx = site.cellX - x
                    local dy = site.cellY - y
                    local distSq = dx * dx + dy * dy
                    if distSq < nearestDistSq then
                        nearestDistSq = distSq
                        nearestSite = site
                    end
                end

                if nearestSite then
                    cell.biomeId = nearestSite.biomeId
                end
            end
        end
    end

    return biomeById
end

local function neighborsFor(grid, current, roadsConfig)
    local result = {}
    local offsets = {
        { -1, 0, 1.0 }, { 1, 0, 1.0 }, { 0, -1, 1.0 }, { 0, 1, 1.0 },
        { -1, -1, roadsConfig.diagonalCost or 1.414 },
        { 1, -1, roadsConfig.diagonalCost or 1.414 },
        { -1, 1, roadsConfig.diagonalCost or 1.414 },
        { 1, 1, roadsConfig.diagonalCost or 1.414 }
    }

    for _, offset in ipairs(offsets) do
        local nx, ny = current.x + offset[1], current.y + offset[2]
        if inBounds(grid.cells, nx, ny) then
            local cell = grid.cells[ny][nx]
            if cell.walkable then
                table.insert(result, { cell = cell, cost = offset[3] })
            end
        end
    end

    return result
end

local function heuristic(a, b)
    local dx = math.abs(a.x - b.x)
    local dy = math.abs(a.y - b.y)
    return dx + dy
end

local function reconstructPath(cameFrom, currentKey, grid)
    local path = {}
    while currentKey do
        local coords = {}
        for token in string.gmatch(currentKey, "[^:]+") do
            table.insert(coords, tonumber(token))
        end
        local x, y = coords[1], coords[2]
        local cell = grid.cells[y] and grid.cells[y][x]
        if cell then
            table.insert(path, 1, { x = cell.worldX, y = cell.worldY, cellX = x, cellY = y })
        end
        currentKey = cameFrom[currentKey]
    end
    return path
end

local function findPath(grid, fromSite, toSite, roadsConfig)
    local start = grid.cells[fromSite.cellY] and grid.cells[fromSite.cellY][fromSite.cellX]
    local goal = grid.cells[toSite.cellY] and grid.cells[toSite.cellY][toSite.cellX]

    if not start or not goal or not start.walkable or not goal.walkable then
        return {}
    end

    local openSet = { [keyOf(start.x, start.y)] = true }
    local openList = { start }
    local cameFrom = {}
    local gScore = { [keyOf(start.x, start.y)] = 0 }
    local fScore = { [keyOf(start.x, start.y)] = heuristic(start, goal) }

    while #openList > 0 do
        local bestIndex = 1
        local bestCell = openList[1]
        local bestKey = keyOf(bestCell.x, bestCell.y)
        local bestScore = fScore[bestKey] or math.huge

        for i = 2, #openList do
            local cell = openList[i]
            local cellKey = keyOf(cell.x, cell.y)
            local score = fScore[cellKey] or math.huge
            if score < bestScore then
                bestScore = score
                bestIndex = i
                bestCell = cell
                bestKey = cellKey
            end
        end

        table.remove(openList, bestIndex)
        openSet[bestKey] = nil

        if bestCell.x == goal.x and bestCell.y == goal.y then
            return reconstructPath(cameFrom, bestKey, grid)
        end

        local neighbors = neighborsFor(grid, bestCell, roadsConfig)
        for _, neighbor in ipairs(neighbors) do
            local nCell = neighbor.cell
            local nKey = keyOf(nCell.x, nCell.y)
            local tentative = (gScore[bestKey] or math.huge) + neighbor.cost

            if tentative < (gScore[nKey] or math.huge) then
                cameFrom[nKey] = bestKey
                gScore[nKey] = tentative
                fScore[nKey] = tentative + heuristic(nCell, goal)
                if not openSet[nKey] then
                    openSet[nKey] = true
                    table.insert(openList, nCell)
                end
            end
        end
    end

    return {}
end

local function computeConnections(sites, roadsConfig)
    if #sites <= 1 then
        return {}
    end

    local edges = {}
    for i = 1, #sites do
        for j = i + 1, #sites do
            local dx = sites[i].cellX - sites[j].cellX
            local dy = sites[i].cellY - sites[j].cellY
            table.insert(edges, {
                a = i,
                b = j,
                distSq = dx * dx + dy * dy
            })
        end
    end

    table.sort(edges, function(left, right)
        return left.distSq < right.distSq
    end)

    local parent = {}
    for i = 1, #sites do
        parent[i] = i
    end

    local function find(i)
        while parent[i] ~= i do
            i = parent[i]
        end
        return i
    end

    local function union(a, b)
        local pa, pb = find(a), find(b)
        if pa ~= pb then
            parent[pb] = pa
            return true
        end
        return false
    end

    local chosen = {}
    for _, edge in ipairs(edges) do
        if union(edge.a, edge.b) then
            table.insert(chosen, edge)
        end
    end

    local extras = roadsConfig.extraConnections or 0
    if extras > 0 then
        for _, edge in ipairs(edges) do
            local inChosen = false
            for _, c in ipairs(chosen) do
                if (c.a == edge.a and c.b == edge.b) or (c.a == edge.b and c.b == edge.a) then
                    inChosen = true
                    break
                end
            end
            if not inChosen then
                table.insert(chosen, edge)
                extras = extras - 1
                if extras <= 0 then
                    break
                end
            end
        end
    end

    return chosen
end

local function collectBiomeColors(biomeConfig)
    local colors = {}
    for _, biome in ipairs(biomeConfig) do
        colors[biome.id] = biome.color
    end
    return colors
end

function WorldGenerationSystem.generate(map, options)
    options = options or {}

    local config = WorldGenerationConfig
    local seed = options.seed or config.defaultSeed
    local rng = makeRng(seed)
    local terrainMaskData = resolveTerrainMaskData(map, options, config)

    local navigationGrid = buildWalkableGrid(map, config.navigation, terrainMaskData)
    applyContinentWaterMask(navigationGrid, config.navigation and config.navigation.continent, seed)
    local sitesConfig = {
        majorCount = options.majorSiteCount or config.sites.majorCount,
        minDistanceCells = options.minDistanceCells or config.sites.minDistanceCells,
        maxPlacementAttempts = config.sites.maxPlacementAttempts,
        edgePaddingCells = config.sites.edgePaddingCells
    }

    local sites = chooseSites(navigationGrid, sitesConfig, rng)
    assignBiomesToSites(sites, config.biomes, rng)

    local biomeById = assignVoronoiBiomes(navigationGrid, sites, config.biomes)
    local connections = computeConnections(sites, config.roads)

    local roads = {}
    for _, edge in ipairs(connections) do
        local fromSite = sites[edge.a]
        local toSite = sites[edge.b]
        local path = findPath(navigationGrid, fromSite, toSite, config.roads)
        if #path > 0 then
            table.insert(roads, {
                id = string.format("road_%s_%s", fromSite.id, toSite.id),
                fromSiteId = fromSite.id,
                toSiteId = toSite.id,
                points = path
            })
        end
    end

    local generationData = {
        seed = seed,
        sites = sites,
        roads = roads,
        biomeById = biomeById,
        biomeColors = collectBiomeColors(config.biomes),
        waterColor = (config.navigation and config.navigation.continent and config.navigation.continent.waterColor) or { 0.08, 0.26, 0.48, 0.85 },
        navigationGrid = navigationGrid
    }

    map.worldGen = generationData

    return generationData
end

return WorldGenerationSystem
