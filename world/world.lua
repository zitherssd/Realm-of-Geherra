-- world/world.lua
-- Main world container

local World = {}

function World.new()
    local self = {
        maps = {},
        currentMap = nil,
        settlements = {},
        encounters = {},
        time = 0
    }
    return self
end

function World:addMap(mapId, map)
    self.maps[mapId] = map
end

function World:getMap(mapId)
    return self.maps[mapId]
end

function World:setCurrentMap(mapId)
    self.currentMap = mapId
end

function World:getCurrentMap()
    return self.maps[self.currentMap]
end

return World
