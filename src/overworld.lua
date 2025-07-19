-- Overworld module (singleton)
-- Handles the overworld map with towns and terrain

local Overworld = {}
local biomeTypes = require('src.data.biome_types')

function Overworld:init()
    self.width = 2048
    self.height = 2048
    self.towns = {
        {
            name = "Millhaven",
            x = 300,
            y = 300,
            size = 40,
            color = {0.8, 0.6, 0.2},
            type = "village",
            population = 150,
            description = "A small farming village"
        },
        {
            name = "Ironforge",
            x = 800,
            y = 200,
            size = 60,
            color = {0.7, 0.7, 0.7},
            type = "city",
            population = 500,
            description = "A prosperous mining city"
        },
        {
            name = "Greenwood",
            x = 1200,
            y = 600,
            size = 35,
            color = {0.3, 0.7, 0.3},
            type = "village",
            population = 100,
            description = "A village near the forest"
        },
        {
            name = "Coastal Port",
            x = 1500,
            y = 1000,
            size = 50,
            color = {0.2, 0.4, 0.8},
            type = "port",
            population = 300,
            description = "A busy trading port"
        },
        {
            name = "Mountain Keep",
            x = 400,
            y = 800,
            size = 45,
            color = {0.5, 0.5, 0.5},
            type = "fortress",
            population = 200,
            description = "A military fortress"
        }
    }
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

    -- Draw towns
    for _, town in ipairs(self.towns) do
        love.graphics.setColor(town.color)
        love.graphics.circle('fill', town.x, town.y, town.size)
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.setLineWidth(2)
        love.graphics.circle('line', town.x, town.y, town.size)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(town.name, town.x - town.size/2, town.y - town.size - 10)
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

    -- Draw interaction indicators for nearby towns
    for _, town in ipairs(self.towns) do
        local distance = math.sqrt((player.x - town.x)^2 + (player.y - town.y)^2)
        if distance <= self.interactionDistance then
            love.graphics.setColor(1, 1, 0, 0.8)
            love.graphics.setLineWidth(3)
            love.graphics.circle('line', town.x, town.y, town.size/2 + 10)
            love.graphics.setColor(1, 1, 1, 1)
            local font = love.graphics.getFont()
            local text = "Press Enter"
            local textWidth = font:getWidth(text)
            love.graphics.print(text, town.x - textWidth/2, town.y + town.size/2 + 25)
        end
    end

    -- Draw player
    player:draw()
end

function Overworld:getTownTypeIndicator(townType)
    local indicators = {
        village = "♦",
        city = "■",
        port = "⚓",
        fortress = "⛨"
    }
    return indicators[townType] or "◊"
end

function Overworld:checkTownInteraction(playerX, playerY)
    for _, town in ipairs(self.towns) do
        local distance = math.sqrt((playerX - town.x)^2 + (playerY - town.y)^2)
        if distance <= self.interactionDistance then
            return town
        end
    end
    return nil
end

function Overworld:getTownByName(name)
    for _, town in ipairs(self.towns) do
        if town.name == name then
            return town
        end
    end
    return nil
end

function Overworld:addTown(name, x, y, size, townType, population, description)
    local colors = {
        village = {0.8, 0.6, 0.2},
        city = {0.7, 0.7, 0.7},
        port = {0.2, 0.4, 0.8},
        fortress = {0.5, 0.5, 0.5}
    }
    
    local newTown = {
        name = name,
        x = x,
        y = y,
        size = size or 40,
        color = colors[townType] or {0.6, 0.6, 0.6},
        type = townType or "village",
        population = population or 100,
        description = description or "A settlement"
    }
    
    table.insert(self.towns, newTown)
    return newTown
end

function Overworld:removeTown(name)
    for i, town in ipairs(self.towns) do
        if town.name == name then
            table.remove(self.towns, i)
            return true
        end
    end
    return false
end

function Overworld:getAllTowns()
    return self.towns
end

function Overworld:getNearbyTowns(x, y, radius)
    local nearby = {}
    for _, town in ipairs(self.towns) do
        local distance = math.sqrt((x - town.x)^2 + (y - town.y)^2)
        if distance <= radius then
            table.insert(nearby, {town = town, distance = distance})
        end
    end
    
    -- Sort by distance
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