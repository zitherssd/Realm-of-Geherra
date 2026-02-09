-- world/settlement.lua
-- Persistent world location

local Settlement = {}
Settlement.__index = Settlement

function Settlement.new(id, name)
    local self = {
        id = id,
        name = name or "Settlement",
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
    setmetatable(self, Settlement)
    return self
end

function Settlement:setPosition(x, y)
    self.x = x
    self.y = y
end

function Settlement:getPosition()
    return self.x, self.y
end

function Settlement:addNPC(npc)
    table.insert(self.npcs, npc)
end

function Settlement:removeNPC(npcId)
    for i, npc in ipairs(self.npcs) do
        if npc.id == npcId then
            table.remove(self.npcs, i)
            break
        end
    end
end

function Settlement:getNPCs()
    return self.npcs
end

return Settlement
