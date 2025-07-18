-- Overworld module
-- Handles the overworld map with towns and terrain

local Overworld = {}

function Overworld:new()
    local instance = {
        width = 2048,
        height = 2048,
        
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
<<<<<<< HEAD
            {type = "lake", x = 1600, y = 1200, width = 80, height = 80, color = {0.2, 0.4, 0.8}},
            
            -- Rivers (added as water obstacles)
            {type = "river", x = 700, y = 400, width = 20, height = 300, color = {0.3, 0.5, 0.9}},
            {type = "river", x = 1300, y = 800, width = 200, height = 25, color = {0.3, 0.5, 0.9}}
=======
            {type = "lake", x = 1600, y = 1200, width = 80, height = 80, color = {0.2, 0.4, 0.8}}
>>>>>>> origin/cursor/enable-bandit-parties-to-wander-towns-2efd
        },
        
        -- Roads (simple connections between towns)
        roads = {
            {from = {300, 300}, to = {800, 200}},
            {from = {800, 200}, to = {1200, 600}},
            {from = {1200, 600}, to = {1500, 1000}},
            {from = {300, 300}, to = {400, 800}},
            {from = {400, 800}, to = {1500, 1000}}
        },
        
        interactionDistance = 50 -- Distance to interact with towns
    }
    
    setmetatable(instance, {__index = self})
    return instance
end

function Overworld:update(dt)
    -- Future: Add overworld events, weather, etc.
end

<<<<<<< HEAD
-- Check if a position is blocked by water
function Overworld:isWaterAt(x, y, playerSize)
    playerSize = playerSize or 16 -- Default player size
    local halfSize = playerSize / 2
    
    for _, feature in ipairs(self.terrain) do
        if feature.type == "lake" then
            -- Check collision with elliptical lake
            local centerX = feature.x + feature.width / 2
            local centerY = feature.y + feature.height / 2
            local radiusX = feature.width / 2
            local radiusY = feature.height / 2
            
            -- Check if any corner of the player rectangle is inside the ellipse
            local corners = {
                {x - halfSize, y - halfSize},
                {x + halfSize, y - halfSize},
                {x - halfSize, y + halfSize},
                {x + halfSize, y + halfSize}
            }
            
            for _, corner in ipairs(corners) do
                local dx = (corner[1] - centerX) / radiusX
                local dy = (corner[2] - centerY) / radiusY
                if dx * dx + dy * dy <= 1 then
                    return true
                end
            end
        elseif feature.type == "river" then
            -- Check collision with rectangular river
            if x - halfSize < feature.x + feature.width and
               x + halfSize > feature.x and
               y - halfSize < feature.y + feature.height and
               y + halfSize > feature.y then
                return true
            end
        end
    end
    
    return false
end

-- Check if the player can move to a specific position
function Overworld:canMoveTo(x, y, playerSize)
    -- Check world boundaries
    if x < 0 or x > self.width or y < 0 or y > self.height then
        return false
    end
    
    -- Check water collision
    if self:isWaterAt(x, y, playerSize) then
        return false
    end
    
    return true
end

=======
>>>>>>> origin/cursor/enable-bandit-parties-to-wander-towns-2efd
function Overworld:draw()
    -- Draw background
    love.graphics.setColor(0.4, 0.6, 0.3) -- Grass green
    love.graphics.rectangle('fill', 0, 0, self.width, self.height)
    
    -- Draw terrain features
    for _, feature in ipairs(self.terrain) do
        love.graphics.setColor(feature.color)
<<<<<<< HEAD
        if feature.type == "forest" or feature.type == "mountain" or feature.type == "river" then
=======
        if feature.type == "forest" or feature.type == "mountain" then
>>>>>>> origin/cursor/enable-bandit-parties-to-wander-towns-2efd
            love.graphics.rectangle('fill', feature.x, feature.y, feature.width, feature.height)
        elseif feature.type == "lake" then
            love.graphics.ellipse('fill', feature.x + feature.width/2, feature.y + feature.height/2, feature.width/2, feature.height/2)
        end
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

<<<<<<< HEAD
-- Draw enemy parties on the overworld
function Overworld:drawEnemyParties(enemyParties)
    for _, party in ipairs(enemyParties) do
        -- Draw enemy party as red circles
        love.graphics.setColor(1, 0, 0, 0.8) -- Red with transparency
        love.graphics.circle('fill', party.x, party.y, 15)
        
        -- Draw border
        love.graphics.setColor(0.8, 0, 0, 1)
        love.graphics.setLineWidth(2)
        love.graphics.circle('line', party.x, party.y, 15)
        
        -- Draw unit count
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(tostring(party.size), party.x - 5, party.y - 5)
    end
end

-- Draw bandit parties on the overworld
function Overworld:drawBanditParties(banditParties)
    for _, banditParty in ipairs(banditParties) do
        -- Draw bandit party as orange circles
        love.graphics.setColor(1, 0.5, 0, 0.8) -- Orange with transparency
        love.graphics.circle('fill', banditParty.x, banditParty.y, 12)
        
        -- Draw border
        love.graphics.setColor(0.8, 0.4, 0, 1)
        love.graphics.setLineWidth(2)
        love.graphics.circle('line', banditParty.x, banditParty.y, 12)
        
        -- Draw unit count
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(tostring(banditParty.size), banditParty.x - 5, banditParty.y - 5)
        
        -- Draw movement indicator if moving
        if banditParty.is_moving then
            love.graphics.setColor(1, 1, 0, 0.6) -- Yellow for movement
            love.graphics.circle('line', banditParty.x, banditParty.y, 18)
        end
    end
end

-- Draw interaction indicators for nearby towns
function Overworld:drawInteractionIndicators(playerX, playerY)
    for _, town in ipairs(self.towns) do
        local distance = math.sqrt((playerX - town.x)^2 + (playerY - town.y)^2)
        if distance <= self.interactionDistance then
            -- Draw interaction indicator
            love.graphics.setColor(1, 1, 0, 0.8) -- Yellow with transparency
            love.graphics.setLineWidth(3)
            love.graphics.circle('line', town.x, town.y, town.size/2 + 10)
            
            -- Draw "Press Enter" text
            love.graphics.setColor(1, 1, 1, 1)
            local font = love.graphics.getFont()
            local text = "Press Enter"
            local textWidth = font:getWidth(text)
            love.graphics.print(text, town.x - textWidth/2, town.y + town.size/2 + 25)
        end
    end
end

=======
>>>>>>> origin/cursor/enable-bandit-parties-to-wander-towns-2efd
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

return Overworld