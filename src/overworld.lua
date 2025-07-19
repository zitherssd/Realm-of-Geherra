-- Overworld module (singleton)
-- Handles the overworld map with locations and terrain

local Overworld = {}
local biomeTypes = require('src.data.biome_types')

function Overworld:init()
    self.width = 2048
    self.height = 2048
    -- Locations will be loaded from src/data/locations.lua
    self.locations = require('src.data.locations')
    self.interactionDistance = 50
    self.visualMap = nil
    self.biomeMap = nil
    if love.filesystem.getInfo('assets/maps/visual_map.png') then
        self.visualMap = love.graphics.newImage('assets/maps/visual_map.png')
    end
    if love.filesystem.getInfo('assets/maps/biome_map.png') then
        self.biomeMap = love.image.newImageData('assets/maps/biome_map.png')
    end
end

function Overworld:update(dt)
    -- Future: Add overworld events, weather, etc.
end

function Overworld:draw(player, parties)
    -- Draw terrain/biome map (existing logic)
    if self.visualMap then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.visualMap, 0, 0)
    elseif self.biomeMap then
        -- Draw biome map as colored rectangles (optional fallback)
        -- ... (existing biome map drawing logic if any) ...
    end
    -- Draw locations
    for _, location in ipairs(self.locations) do
        love.graphics.setColor(location.color)
        love.graphics.circle('fill', location.x, location.y, location.size)
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.setLineWidth(2)
        love.graphics.circle('line', location.x, location.y, location.size)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(location.name, location.x - location.size/2, location.y - location.size - 10)
    end
    -- Draw parties (enemy and bandit)
    for _, party in ipairs(parties) do
        if party.party_type == "enemy" then
            love.graphics.setColor(1, 0, 0, 0.8)
            love.graphics.circle('fill', party.x, party.y, 15)
            love.graphics.setColor(0.8, 0, 0, 1)
            love.graphics.setLineWidth(2)
            love.graphics.circle('line', party.x, party.y, 15)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(tostring(party.size), party.x - 5, party.y - 5)
        elseif party.party_type == "bandit" then
            love.graphics.setColor(1, 0.5, 0, 0.8)
            love.graphics.circle('fill', party.x, party.y, 12)
            love.graphics.setColor(0.8, 0.4, 0, 1)
            love.graphics.setLineWidth(2)
            love.graphics.circle('line', party.x, party.y, 12)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(tostring(party.size), party.x - 5, party.y - 5)
            if party.is_moving then
                love.graphics.setColor(1, 1, 0, 0.6)
                love.graphics.circle('line', party.x, party.y, 18)
            end
        end
    end
    -- Draw interaction indicators for nearby locations
    for _, location in ipairs(self.locations) do
        local distance = math.sqrt((player.x - location.x)^2 + (player.y - location.y)^2)
        if distance <= self.interactionDistance then
            love.graphics.setColor(1, 1, 0, 0.8)
            love.graphics.setLineWidth(3)
            love.graphics.circle('line', location.x, location.y, location.size/2 + 10)
            love.graphics.setColor(1, 1, 1, 1)
            local font = love.graphics.getFont()
            local text = "Press Enter"
            local textWidth = font:getWidth(text)
            love.graphics.print(text, location.x - textWidth/2, location.y + location.size/2 + 25)
        end
    end
    -- Draw player
    player:draw()
end

function Overworld:getLocationTypeIndicator(locationType)
    local indicators = {
        village = "♦",
        city = "■",
        port = "⚓",
        fortress = "⛨"
    }
    return indicators[locationType] or "◊"
end

function Overworld:checkLocationInteraction(playerX, playerY)
    for _, location in ipairs(self.locations) do
        local distance = math.sqrt((playerX - location.x)^2 + (playerY - location.y)^2)
        if distance <= self.interactionDistance then
            return location
        end
    end
    return nil
end

function Overworld:getLocationByName(name)
    for _, location in ipairs(self.locations) do
        if location.name == name then
            return location
        end
    end
    return nil
end

function Overworld:addLocation(location)
    table.insert(self.locations, location)
    return location
end

function Overworld:removeLocation(name)
    for i, location in ipairs(self.locations) do
        if location.name == name then
            table.remove(self.locations, i)
            return true
        end
    end
    return false
end

function Overworld:getAllLocations()
    return self.locations
end

function Overworld:getNearbyLocations(x, y, radius)
    local nearby = {}
    for _, location in ipairs(self.locations) do
        local distance = math.sqrt((x - location.x)^2 + (y - location.y)^2)
        if distance <= radius then
            table.insert(nearby, {location = location, distance = distance})
        end
    end
    table.sort(nearby, function(a, b) return a.distance < b.distance end)
    return nearby
end

function Overworld:getBiomeAt(x, y)
    if not self.biomeMap then return nil end
    local r, g, b = self.biomeMap:getPixel(math.floor(x), math.floor(y))
    local hex = string.format("#%02x%02x%02x", r*255, g*255, b*255)
    return biomeTypes[hex]
end

return Overworld