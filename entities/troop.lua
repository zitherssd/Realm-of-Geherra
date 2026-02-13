-- entities/troop.lua
-- Mass-produced combat units (soldiers, guards, bandits)

local Actor = require("entities.actor")
local Troop = setmetatable({}, Actor)
Troop.__index = Troop
local TroopsData = require("data.troops")

function Troop.new(troopType, id)
    local self = Actor.new(id, "troop")
    setmetatable(self, Troop)
    
    self.troopType = troopType or "soldier"
    self:addTag("troop")
    self:addTag(self.troopType)
    
    self.formation = nil
    self.squad = nil
    
    -- Load definition from data
    local data = TroopsData[troopType]
    if data then
        self.name = data.name
        -- Apply Stats
        if data.stats then
            for k, v in pairs(data.stats) do
                self.stats[k] = v
            end
        end
        
        -- Apply Custom Slots (if defined)
        if data.slots then
            self.availableSlots = data.slots
        end
        
        -- Apply Starting Equipment
        if data.equipment then
            for slot, itemId in pairs(data.equipment) do
                -- Direct assignment for initialization
                self.equipment[slot] = itemId
            end
        end
        
        -- Apply Sprite
        if data.sprite then
            if type(data.sprite) == "table" then
                self.sprite = data.sprite[math.random(#data.sprite)]
            else
                self.sprite = data.sprite
            end
        end
    end
    
    return self
end

function Troop:setFormation(formation)
    self.formation = formation
end

function Troop:setSquad(squadId)
    self.squad = squadId
end

return Troop
