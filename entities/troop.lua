-- entities/troop.lua
-- Mass-produced combat units (soldiers, guards, bandits)

local Actor = require("entities.actor")
local Troop = setmetatable({}, Actor)
Troop.__index = Troop

function Troop.new(id, troopType)
    local self = Actor.new(id, "troop")
    setmetatable(self, Troop)
    
    self.troopType = troopType or "soldier"
    self.addTag(self, "troop")
    self.addTag(self, troopType)
    
    self.formation = nil
    self.squad = nil
    
    return self
end

function Troop:setFormation(formation)
    self.formation = formation
end

function Troop:setSquad(squadId)
    self.squad = squadId
end

return Troop
