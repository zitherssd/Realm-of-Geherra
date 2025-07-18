-- Overworld module
-- Handles the overworld map with towns and terrain

local Overworld = {}
local AIParty = require('src.ai_party')

function Overworld:new()
    local instance = {
        width = 2048,
        height = 2048,
        
        -- Map images
        worldMap = nil, -- love.graphics.Image
        biomeDebug = false, -- Toggle biome overlay
        
        -- Towns on the map
        towns = {
            {
                name = "Millhaven",
                x = 300,
                y = 300,
                size = 40,
                color = {0.8, 0.6, 0.2}, -- Gold/brown
                type = "village",
                population = 150,
                description = "A small farming village"
            },
            {
                name = "Ironforge",
                x = 800,
                y = 200,
                size = 60,
                color = {0.7, 0.7, 0.7}, -- Gray
                type = "city",
                population = 500,
                description = "A prosperous mining city"
            },
            {
                name = "Greenwood",
                x = 1200,
                y = 600,
                size = 35,
                color = {0.3, 0.7, 0.3}, -- Green
                type = "village",
                population = 100,
                description = "A village near the forest"
            },
            {
                name = "Coastal Port",
                x = 1500,
                y = 1000,
                size = 50,
                color = {0.2, 0.4, 0.8}, -- Blue
                type = "port",
                population = 300,
                description = "A busy trading port"
            },
            {
                name = "Mountain Keep",
                x = 400,
                y = 800,
                size = 45,
                color = {0.5, 0.5, 0.5}, -- Dark gray
                type = "fortress",
                population = 200,
                description = "A military fortress"
            }
        },
        
        -- Terrain features (for visual variety)
        terrain = {
            -- Forests
            {type = "forest", x = 1100, y = 500, width = 200, height = 200, color = {0.2, 0.5, 0.2}},
            {type = "forest", x = 600, y = 1200, width = 150, height = 150, color = {0.2, 0.5, 0.2}},
            
            -- Mountains
            {type = "mountain", x = 300, y = 700, width = 180, height = 180, color = {0.4, 0.4, 0.4}},
            {type = "mountain", x = 1400, y = 300, width = 120, height = 120, color = {0.4, 0.4, 0.4}},
            
            -- Lakes
            {type = "lake", x = 900, y = 800, width = 100, height = 100, color = {0.2, 0.4, 0.8}},
            {type = "lake", x = 1600, y = 1200, width = 80, height = 80, color = {0.2, 0.4, 0.8}}
        },
        
        -- Roads (simple connections between towns)
        roads = {
            {from = {300, 300}, to = {800, 200}},
            {from = {800, 200}, to = {1200, 600}},
            {from = {1200, 600}, to = {1500, 1000}},
            {from = {300, 300}, to = {400, 800}},
            {from = {400, 800}, to = {1500, 1000}}
        },
        
        interactionDistance = 50, -- Distance to interact with towns
        parties = {}, -- AI-controlled parties
    }
    
    setmetatable(instance, {__index = self})
    instance:spawnParties()
    return instance
end

function Overworld:spawnParties()
    -- Example: spawn a few bandit and lord parties
    table.insert(self.parties, AIParty:new{
        x = 600, y = 600, type = 'bandit', faction = 'hostile', color = {0.8,0.1,0.1}, name = 'Bandit Gang',
        patrolPoints = {{x=600,y=600},{x=800,y=800},{x=600,y=900}},
    })
    table.insert(self.parties, AIParty:new{
        x = 1000, y = 400, type = 'lord', faction = 'neutral', color = {0.2,0.2,1.0}, name = 'Lord Beran',
        patrolPoints = {{x=1000,y=400},{x=1200,y=600},{x=900,y=700}},
    })
    -- Add more as needed
end

function Overworld:loadImages()
    self.worldMap = love.graphics.newImage('assets/world_map.png')
end

function Overworld:update(dt, player)
    -- Update all AI parties
    for _, party in ipairs(self.parties) do
        party:update(dt, player)
    end
    -- Future: Add overworld events, weather, etc.
end

function Overworld:draw()
    -- Draw world map image if loaded
    if self.worldMap then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self.worldMap, 0, 0)
    else
        love.graphics.setColor(0.4, 0.6, 0.3) -- Grass green fallback
        love.graphics.rectangle('fill', 0, 0, self.width, self.height)
    end
    -- Optionally: draw biome debug overlay here
    -- Draw AI parties
    for _, party in ipairs(self.parties) do
        party:draw()
    end
    -- Draw roads
    love.graphics.setColor(0.6, 0.4, 0.2) -- Brown
    love.graphics.setLineWidth(4)
    for _, road in ipairs(self.roads) do
        love.graphics.line(road.from[1], road.from[2], road.to[1], road.to[2])
    end
    
    -- Draw towns
    for _, town in ipairs(self.towns) do
        -- Town background
        love.graphics.setColor(town.color)
        love.graphics.rectangle('fill', town.x - town.size/2, town.y - town.size/2, town.size, town.size)
        
        -- Town border
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle('line', town.x - town.size/2, town.y - town.size/2, town.size, town.size)
        
        -- Town name
        love.graphics.setColor(1, 1, 1)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(town.name)
        love.graphics.print(town.name, town.x - textWidth/2, town.y - town.size/2 - 20)
        
        -- Town type indicator
        local typeIndicator = self:getTownTypeIndicator(town.type)
        love.graphics.print(typeIndicator, town.x - 5, town.y - 5)
    end
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

function Overworld:getNearbyParty(x, y, radius)
    for _, party in ipairs(self.parties) do
        local dx, dy = x - party.x, y - party.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist <= (radius or 40) then
            return party
        end
    end
    return nil
end

return Overworld