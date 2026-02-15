-- entities/actor.lua
-- Living, acting entities (NPCs, player, troops)

local Entity = require("entities.entity")
local Actor = setmetatable({}, Entity)
Actor.__index = Actor

function Actor.new(id, actorType)
    local self = Entity.new(id, actorType or "actor")
    setmetatable(self, Actor)
    
    self.stats = {
        health = 100,
        strength = 10,
        attack = 10,
        defense = 10,
        speed = 10,        -- World map speed
        battle_speed = 10  -- Combat action speed (baseline 10)
    }
    
    self.level = 1
    self.experience = 0
    
    -- Default Humanoid Slots
    self.availableSlots = {
        "mainHand", "offHand", "rangedWeapon", "head", "body", "hands", "feet"
    }
    self.inventory = {}
    self.equipment = {}
    self.skills = {
        ["slash"] = {learned = true} -- Default basic attack
    }
    self.factions = {}
    
    self.velocity = {x = 0, y = 0}
    self.ai = {state = "idle"}
    self.sprite = "assets/sprites/units/imp.png"
    
    return self
end

return Actor
