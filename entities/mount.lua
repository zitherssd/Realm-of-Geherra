-- entities/mount.lua
-- Rideable creature or vehicle

local Entity = require("entities.entity")
local Mount = setmetatable({}, Entity)
Mount.__index = Mount

function Mount.new(id, mountType)
    local self = Entity.new(id, "mount")
    setmetatable(self, Mount)
    
    self.mountType = mountType or "horse"
    self:addTag("mount")
    
    self.rider = nil
    self.stats = {
        health = 50,
        speed = 20
    }
    
    return self
end

function Mount:setRider(actor)
    self.rider = actor
end

function Mount:removeRider()
    self.rider = nil
end

return Mount
