-- world/location.lua
-- Persistent world location

local Location = {}
Location.__index = Location

function Location.new(id, name)
    local self = {
        id = id,
        name = name or "Location",
        type = "town",
        x = 0,
        y = 0,
        faction = nil,
        owner = nil,
        population = 100,
        prosperity = 50,
        npcs = {},
        quests = {},
        shops = {}
    }
    setmetatable(self, Location)
    return self
end

function Location:setPosition(x, y)
    self.x = x
    self.y = y
end

function Location:getPosition()
    return self.x, self.y
end

function Location:addNPC(npc)
    table.insert(self.npcs, npc)
end

function Location:removeNPC(npcId)
    for i, npc in ipairs(self.npcs) do
        if npc.id == npcId then
            table.remove(self.npcs, i)
            break
        end
    end
end

function Location:getNPCs()
    return self.npcs
end

return Location