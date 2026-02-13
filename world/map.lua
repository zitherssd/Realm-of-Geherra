-- world/map.lua
-- Individual map or location

local Map = {}
Map.__index = Map

function Map.new(id, name)
    local self = {
        id = id,
        name = name or "Map",
        width = 1660,
        height = 1174,
        parties = {},
        tiles = {},
        objects = {},
        locations = {},
        visuals = {
            image = nil,
            tileSize = 32
        }
    }
    setmetatable(self, Map)
    return self
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
    else
        -- Fallback: draw a simple background
        love.graphics.setColor(0.3, 0.5, 0.3, 1)
        love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    end
end

-- Draw locations on the map
function Map:drawLocations()
    for _, location in ipairs(self.locations) do
        -- Draw location icon/marker
        love.graphics.setColor(1, 0.8, 0.2, 1)  -- Gold color
        love.graphics.circle("fill", location.x, location.y, 12)
        
        -- Draw location name (optional, for debug/clarity)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.printf(location.name, location.x - 40, location.y - 25, 80, "center")
    end
end

-- Draw parties on the map
function Map:drawParties()
    for _, party in ipairs(self.parties) do
        if party then
            -- Draw party marker (larger circle for parties)
            love.graphics.setColor(0.2, 0.8, 0.2, 1)  -- Green for player/friendly parties
            love.graphics.circle("fill", party.x, party.y, 10)
            
            -- Draw party size indicator
            love.graphics.setColor(0.1, 0.6, 0.1, 1)
            love.graphics.circle("line", party.x, party.y, 15)
            
            -- Draw party name if available
            if party.name then
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.printf(party.name, party.x - 40, party.y - 25, 80, "center")
            end
        end
    end
end
return Map
