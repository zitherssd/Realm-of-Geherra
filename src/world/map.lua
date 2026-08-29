-- world/map.lua
-- Individual map or location

local PartySystem = require("src.systems.party_system")

local Map = {}
Map.__index = Map

function Map.new(id, name)
    local self = {
        id = id,
        name = name or "Map",
        width = 2048,
        height = 2048,
        parties = {},
        tiles = {},
        objects = {},
        locations = {},
        spriteCache = {},   -- loaded marker sprite images (path -> Image | false)
        worldGen = nil,
        renderOptions = {
            showWater = true,
            showBiomeOverlay = true,
            showRoads = true
        },
        visuals = {
            image = nil,
            overlayImage = nil,
            tileSize = 32
        }
    }
    setmetatable(self, Map)
    return self
end

function Map:setWorldGenerationData(worldGen)
    self.worldGen = worldGen
end

function Map:isWalkable(worldX, worldY)
    if not self.worldGen or not self.worldGen.navigationGrid then
        return true
    end

    local grid = self.worldGen.navigationGrid
    local cellSize = grid.cellSize
    local cellX = math.floor(worldX / cellSize) + 1
    local cellY = math.floor(worldY / cellSize) + 1

    if cellX < 1 or cellY < 1 or cellX > grid.cols or cellY > grid.rows then
        return false
    end

    local cell = grid.cells[cellY][cellX]
    return cell and cell.walkable or false
end

function Map:getBiomeAt(worldX, worldY)
    if not self.worldGen or not self.worldGen.navigationGrid then
        return nil
    end

    local grid = self.worldGen.navigationGrid
    local cellSize = grid.cellSize
    local cellX = math.floor(worldX / cellSize) + 1
    local cellY = math.floor(worldY / cellSize) + 1

    if cellX < 1 or cellY < 1 or cellX > grid.cols or cellY > grid.rows then
        return nil
    end

    local cell = grid.cells[cellY][cellX]
    return cell and cell.biomeId or nil
end

-- Return the centre of the nearest walkable navigation cell to (worldX, worldY)
-- so entities never spawn/land on water (ocean or marsh lake). Returns the
-- requested position unchanged when no navigation grid is present.
function Map:nearestWalkable(worldX, worldY)
    if not self.worldGen or not self.worldGen.navigationGrid then
        return worldX, worldY
    end

    local grid = self.worldGen.navigationGrid
    local cellSize = grid.cellSize
    local cellX = math.floor(worldX / cellSize) + 1
    local cellY = math.floor(worldY / cellSize) + 1

    local function centerOf(cx, cy)
        return (cx - 0.5) * cellSize, (cy - 0.5) * cellSize
    end

    -- Already inside a walkable cell
    if cellX >= 1 and cellX <= grid.cols and cellY >= 1 and cellY <= grid.rows then
        local cell = grid.cells[cellY][cellX]
        if cell.walkable then
            return centerOf(cellX, cellY)
        end
    end

    -- Expanding-ring search for the nearest walkable cell
    local maxR = math.max(grid.cols, grid.rows)
    for r = 1, maxR do
        local bestDist, bestX, bestY = math.huge, cellX, cellY
        for dy = -r, r do
            for dx = -r, r do
                if math.max(math.abs(dx), math.abs(dy)) == r then
                    local nx, ny = cellX + dx, cellY + dy
                    if nx >= 1 and nx <= grid.cols and ny >= 1 and ny <= grid.rows then
                        local c = grid.cells[ny][nx]
                        if c.walkable then
                            local d = dx * dx + dy * dy
                            if d < bestDist then
                                bestDist, bestX, bestY = d, nx, ny
                            end
                        end
                    end
                end
            end
        end
        if bestDist ~= math.huge then
            return centerOf(bestX, bestY)
        end
    end

    return worldX, worldY
end

-- Load the visual map image
function Map:loadVisualMap(imagePath)
    if love.filesystem.getInfo(imagePath) then
        self.visuals.image = love.graphics.newImage(imagePath)
        self.visuals.image:setFilter("nearest", "nearest")  -- Pixel-perfect rendering
    else
        print("Warning: Map image not found at " .. imagePath)
    end
end

-- Set bounds for the map
function Map:setBounds(minX, minY, maxX, maxY)
    self.minX = minX or 0
    self.minY = minY or 0
    self.maxX = maxX or self.width
    self.maxY = maxY or self.height
end

-- Add location to the map
function Map:addLocation(location)
    table.insert(self.locations, location)
end

-- Get all locations
function Map:getLocations()
    return self.locations
end

-- Add party to the map
function Map:addParty(party)
    table.insert(self.parties, party)
end

-- Remove party from the map
function Map:removeParty(partyId)
    for i, party in ipairs(self.parties) do
        if party.id == partyId then
            table.remove(self.parties, i)
            return true
        end
    end
    return false
end

-- Get all parties on the map
function Map:getParties()
    return self.parties
end

-- Draw the map visuals
function Map:drawMap()
    if self.visuals.image then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.visuals.image, 0, 0)
        -- Painted glyph overlay (mountains + trees) on top of the terrain
        if self.visuals.overlayImage then
            love.graphics.draw(self.visuals.overlayImage, 0, 0)
        end
    else
        -- Fallback: draw a simple background
        love.graphics.setColor(0.3, 0.5, 0.3, 1)
        love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    end

    if self.renderOptions.showWater then
        self:drawWaterOverlay()
    end

    if self.renderOptions.showBiomeOverlay then
        self:drawBiomeOverlay()
    end

    if self.renderOptions.showRoads then
        self:drawRoads()
    end
end

function Map:drawWaterOverlay()
    if not self.worldGen or not self.worldGen.navigationGrid then
        return
    end

    local grid = self.worldGen.navigationGrid
    local waterColor = self.worldGen.waterColor or { 0.08, 0.26, 0.48, 0.85 }
    local cellSize = grid.cellSize

    love.graphics.setColor(waterColor)
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local cell = grid.cells[y][x]
            if not cell.walkable and cell.blockedReason == "water" then
                love.graphics.rectangle("fill", (x - 1) * cellSize, (y - 1) * cellSize, cellSize, cellSize)
            end
        end
    end
end

function Map:drawBiomeOverlay()
    if not self.worldGen or not self.worldGen.navigationGrid then
        return
    end

    local grid = self.worldGen.navigationGrid
    local colors = self.worldGen.biomeColors or {}
    local cellSize = grid.cellSize

    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local cell = grid.cells[y][x]
            if cell.walkable and cell.biomeId then
                local color = colors[cell.biomeId]
                if color then
                    love.graphics.setColor(color)
                    love.graphics.rectangle("fill", (x - 1) * cellSize, (y - 1) * cellSize, cellSize, cellSize)
                end
            end
        end
    end
end

function Map:drawRoads()
    if not self.worldGen or not self.worldGen.roads then
        return
    end

    love.graphics.setColor(0.45, 0.45, 0.45, 0.9)
    love.graphics.setLineWidth(2)

    for _, road in ipairs(self.worldGen.roads) do
        for i = 1, #road.points - 1 do
            local fromPoint = road.points[i]
            local toPoint = road.points[i + 1]
            love.graphics.line(fromPoint.x, fromPoint.y, toPoint.x, toPoint.y)
        end
    end

    love.graphics.setLineWidth(1)
end

-- Maximum on-screen marker size for world-map sprites (scaled down from the
-- full unit/location sprite dimensions).
local MARKER_SPRITE_SIZE = 26

-- Load (and cache) a sprite image by file path. Returns nil when the path is
-- missing or unloadable.
function Map:getSpriteImage(path)
    if not path then return nil end
    if self.spriteCache[path] == nil then
        local status, img = pcall(love.graphics.newImage, path)
        if status then
            img:setFilter("nearest", "nearest")
            self.spriteCache[path] = img
        else
            self.spriteCache[path] = false
        end
    end
    return self.spriteCache[path] or nil
end

-- Draw a sprite scaled down to the marker box, centred at the origin of the
-- current (counter-scaled) transform so it stays a constant screen size.
local function drawMarkerSprite(spriteImg)
    local iw, ih = spriteImg:getDimensions()
    local s = math.min(MARKER_SPRITE_SIZE / iw, MARKER_SPRITE_SIZE / ih)
    s = math.min(s, 1)  -- only scale down, never upscale
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(spriteImg, -iw * s / 2, -ih * s / 2, 0, s, s)
end

-- Draw locations on the map. The optional inverseScale keeps markers a
-- constant on-screen size when the camera is zoomed in. Locations render
-- their `sprite` image (scaled down) when defined, else a green circle.
function Map:drawLocations(inverseScale)
    inverseScale = inverseScale or 1
    for _, location in ipairs(self.locations) do
        if location.discovered then
            love.graphics.push()
            love.graphics.translate(location.x, location.y)
            love.graphics.scale(inverseScale)

            local spriteImg = self:getSpriteImage(location.sprite)
            if spriteImg then
                drawMarkerSprite(spriteImg)
            else
                -- Fallback: green circle marker
                love.graphics.setColor(0.2, 0.8, 0.2, 1)
                love.graphics.circle("fill", 0, 0, 12)
            end

            -- Draw location name (optional, for debug/clarity)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.printf(location.name, -40, -25, 80, "center")
            love.graphics.pop()
        end
    end
end

-- Draw parties on the map. The optional inverseScale keeps markers a constant
-- on-screen size when the camera is zoomed in. Each party is represented by
-- its leader's sprite (scaled down), falling back to a green circle.
function Map:drawParties(inverseScale)
    inverseScale = inverseScale or 1
    for _, party in ipairs(self.parties) do
        if party and party.visible then
            love.graphics.push()
            love.graphics.translate(party.x, party.y)
            love.graphics.scale(inverseScale)

            local leader = PartySystem.getLeader(party)
            local spriteImg = leader and self:getSpriteImage(leader.sprite)
            if spriteImg then
                drawMarkerSprite(spriteImg)
            else
                -- Fallback: green circle marker + size ring
                love.graphics.setColor(0.2, 0.8, 0.2, 1)
                love.graphics.circle("fill", 0, 0, 10)
                love.graphics.setColor(0.1, 0.6, 0.1, 1)
                love.graphics.circle("line", 0, 0, 15)
            end

            -- Draw party name if available
            if party.name then
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.printf(party.name, -40, -25, 80, "center")
            end
            love.graphics.pop()
        end
    end
end
return Map
