-- world/map.lua
-- Individual map or location

local PartySystem = require("src.systems.party_system")
local DebugMode = require("src.debug.mode")

local Map = {}
Map.__index = Map

Map.biomeSpeedModifiers = {
    desert = 0.6,
    mountain = 0.4,
    hills = 0.7,
    plains = 1.0,
    forest = 0.75,
    marsh = 0.4,
    cliff = 0.65
}

Map.roadOnDistance = 15 -- Distance from a road point to count as "on" the road

function Map.new(id, name)
    local self = {
        id = id,
        name = name or "Map",
        width = 2048,
        height = 2048,
        parties = {},
        activeEncounters = {},
        partyEncounterCooldowns = {},
        nextEncounterSequence = 1,
        battlefieldRemains = {},
        nextBattlefieldRemainsSequence = 1,
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

function Map:isOnRoad(worldX, worldY)
    if not self.worldGen or not self.worldGen.roads then return false end
    
    local thresholdSq = self.roadOnDistance * self.roadOnDistance
    local function pointToLineSegDistSq(px, py, ax, ay, bx, by)
        local l2 = (ax - bx)^2 + (ay - by)^2
        if l2 == 0 then return (px - ax)^2 + (py - ay)^2 end
        local t = math.max(0, math.min(1, ((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / l2))
        local projx = ax + t * (bx - ax)
        local projy = ay + t * (by - ay)
        return (px - projx)^2 + (py - projy)^2
    end
    
    for _, road in ipairs(self.worldGen.roads) do
        for i = 1, #road.points - 1 do
            local pt1 = road.points[i]
            local pt2 = road.points[i + 1]
            if pointToLineSegDistSq(worldX, worldY, pt1.x, pt1.y, pt2.x, pt2.y) <= thresholdSq then
                return true
            end
        end
    end
    return false
end

function Map:getTravelSpeedMod(worldX, worldY)
    local biome = self:getBiomeAt(worldX, worldY)
    local baseSpeed = biome and self.biomeSpeedModifiers[biome] or 1.0
    
    if self:isOnRoad(worldX, worldY) then
        -- Roads halve the biome travel penalty: speed = base + (1 - base) * 0.5.
        -- A 0.6x biome becomes 0.8x on a road; an unpenalised biome stays 1.0x.
        return baseSpeed + (1.0 - baseSpeed) * 0.5
    end
    
    return baseSpeed
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

function Map:getLocationById(locationId)
    if locationId == nil then return nil end
    for _, location in ipairs(self.locations) do
        if location.id == locationId then return location end
    end
    return nil
end

local function sameEntity(left, right)
    if not left or not right then return false end
    if left.id ~= nil and right.id ~= nil then
        return left.id == right.id
    end
    return left == right
end

local function partyContainsActor(party, actor)
    for _, member in ipairs(party.actors or {}) do
        if sameEntity(member, actor) then return true end
    end
    return false
end

-- Add party to the map
function Map:addParty(party)
    if not party then return false end
    for _, existing in ipairs(self.parties) do
        if sameEntity(existing, party) then
            return false
        end
    end

    for _, location in ipairs(self.locations) do
        for _, resident in ipairs(location.npcs or {}) do
            if partyContainsActor(party, resident) then return false end
        end
        for _, stationedParty in ipairs(location.stationedParties or {}) do
            if not sameEntity(stationedParty, party) then
                for _, actor in ipairs(party.actors or {}) do
                    if partyContainsActor(stationedParty, actor) then return false end
                end
            end
        end
    end
    for _, existing in ipairs(self.parties) do
        if not sameEntity(existing, party) then
            for _, actor in ipairs(party.actors or {}) do
                if partyContainsActor(existing, actor) then return false end
            end
        end
    end

    local LocationSystem = require("src.systems.location_system")
    for _, location in ipairs(self.locations) do
        LocationSystem.removeStationedParty(location, party)
    end
    table.insert(self.parties, party)
    return true
end

function Map:stationParty(location, party)
    if not location or not party then return false end
    local previousIndex
    for index, existing in ipairs(self.parties) do
        if existing.id == party.id then
            previousIndex = index
            table.remove(self.parties, index)
            break
        end
    end
    local LocationSystem = require("src.systems.location_system")
    if LocationSystem.addStationedParty(self, location, party) then
        return true
    end
    if previousIndex then
        table.insert(self.parties, previousIndex, party)
    end
    return false
end

-- Remove party from the map
function Map:removeParty(partyId)
    local removed = false
    local removedParty
    for i, party in ipairs(self.parties) do
        if party.id == partyId then
            removedParty = party
            table.remove(self.parties, i)
            removed = true
            break
        end
    end

    local LocationSystem = require("src.systems.location_system")
    for _, location in ipairs(self.locations) do
        if LocationSystem.removeStationedParty(location, { id = partyId }) then
            removed = true
        end
    end
    if removedParty and removedParty.world_activity
        and (removedParty.world_activity.type == "travel" or removedParty.world_activity.type == "roam")
        and removedParty.world_activity.status == "active" then
        local WorldActivitySystem = require("src.systems.world_activity_system")
        WorldActivitySystem.cancel(removedParty, "party_removed")
    end
    return removed
end

-- Get all parties on the map
function Map:getParties()
    return self.parties
end

function Map:getActiveEncounters()
    return self.activeEncounters
end

function Map:addBattlefieldRemains(site)
    table.insert(self.battlefieldRemains, site)
end

function Map:getBattlefieldRemains()
    return self.battlefieldRemains
end

function Map:removeBattlefieldRemains(siteId)
    for index, site in ipairs(self.battlefieldRemains) do
        if site.id == siteId then
            table.remove(self.battlefieldRemains, index)
            return true
        end
    end
    return false
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

            function Map:drawBattlefieldRemains(inverseScale)
                inverseScale = inverseScale or 1
                for _, site in ipairs(self.battlefieldRemains or {}) do
                    if site.discovered then
                        local position = site.history and site.history.position
                        if position and position.x and position.y then
                            local oldLineWidth = love.graphics.getLineWidth()
                            love.graphics.push()
                            love.graphics.translate(position.x, position.y)
                            love.graphics.scale(inverseScale)
                            if site.currentlyVisible then
                                love.graphics.setColor(0.78, 0.63, 0.38, 1)
                            else
                                love.graphics.setColor(0.42, 0.34, 0.25, 1)
                            end
                            love.graphics.circle("fill", 0, 0, 10)
                            love.graphics.setColor(0.16, 0.1, 0.06, 1)
                            love.graphics.setLineWidth(2 / inverseScale)
                            love.graphics.line(-4, -4, 4, 4)
                            love.graphics.line(-4, 4, 4, -4)
                            love.graphics.setLineWidth(oldLineWidth)
                            love.graphics.setColor(1, 1, 1, 1)
                            love.graphics.printf("Battlefield", -42, 13, 84, "center")
                            love.graphics.pop()
                        end
                    end
                end
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
        if party and party then
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

            if DebugMode.enabled then
                local activity = party.world_activity
                local activityLabel
                if activity and activity.type and activity.status ~= "idle" then
                    activityLabel = activity.type .. ": " ..
                        (activity.phase or activity.status)
                else
                    activityLabel = party.state or "idle"
                end
                love.graphics.setColor(0, 0, 0, 0.85)
                love.graphics.printf(activityLabel, -50, 15, 100, "center")
                love.graphics.setColor(0.9, 0.95, 1, 1)
                love.graphics.printf(activityLabel, -50, 14, 100, "center")
            end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.pop()
        end
    end
end
return Map
