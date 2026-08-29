-- systems/location_system.lua
-- Plain functions for location entities (replaces the old Location:setPosition()/:addNPC() methods).

local LocationSystem = {}

function LocationSystem.setPosition(location, x, y)
    location.x = x
    location.y = y
end

function LocationSystem.addNPC(location, npc)
    table.insert(location.npcs, npc)
end

return LocationSystem
