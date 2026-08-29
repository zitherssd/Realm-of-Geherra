-- entities/actor.lua
-- Living, acting entities (NPCs, player, troops)

local Entity = require("src.entities.entity")
local Actor = setmetatable({}, Entity)
Actor.__index = Actor

function Actor.new(id, actorType)
    local self = Entity.new(id, actorType or "actor")
    setmetatable(self, Actor)
    
    self.stats = {
        health = 100,
        attack = 10,
        defense = 10,
        speed = 10,        -- World map speed
        battle_speed = 10  -- Combat action speed (baseline 10)
    }
    self.maxHp = self.stats.health
    self.hp = self.maxHp
    
    self.level = 1
    self.experience = 0
    self.size = 3
    
    -- Default Humanoid Slots
    self.availableSlots = {
        "mainHand", "offHand", "rangedWeapon", "head", "body", "hands", "feet"
    }
    self.inventory = {}
    self.equipment = {}
    self.skills = {
        ["attack"] = {learned = true} -- Default basic attack
    }
    self.attributes = {
        tracking = 0,
        shadowcraft = 0,
        divination = 0,
        engineering = 0,
        oratory = 0,
        command = 0,
        navigation = 0
    }
    self.factions = {}
    
    -- Innate protections (flat damage reduction per type)
    self.innateProtections = {
        slashing = 0,
        piercing = 0,
        blunt = 0,
        fire = 0,
        ice = 0,
        shock = 0,
        poison = 0
    }

    self.velocity = {x = 0, y = 0}
    self.ai = {state = "idle"}
    self.sprite = "src/assets/sprites/units/imp.png"
    
    return self
end

return Actor
