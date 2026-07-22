-- game/battle/battle_unit.lua
-- Transient wrapper for an Actor during combat
-- Holds world-space position, visual position, and current intent

local BattleUnit = {}
BattleUnit.__index = BattleUnit
local Skills = require("data.skills")
local EquipmentData = require("data.equipment")

local DEFAULT_MOVE_STEP = 24
local DEFAULT_COLLISION_RADIUS = 18
local DEFAULT_ATTACK_REACH = 8
local DEFAULT_VISUAL_RADIUS = 24

local function getVisualRadiusScale(size)
    if not size then return 1.0 end
    return 0.7 + (size * 0.1)
end

function BattleUnit.new(actor, worldX, worldY, team)
    local self = {
        -- Persistent Data Reference
        actor = actor,
        id = actor.id,
        
        -- Logical State (World)
        x = worldX,
        y = worldY,
        velocityX = 0,
        velocityY = 0,
        moveCooldown = 0,
        moveStep = DEFAULT_MOVE_STEP,
        collisionRadius = DEFAULT_COLLISION_RADIUS,
        visualRadius = DEFAULT_VISUAL_RADIUS,
        attackRange = DEFAULT_ATTACK_REACH,
        moveTarget = nil,
        state = "idle",
        team = team or "neutral", -- "player", "enemy", "ally"
        facing = 1, -- 1 = Left (Default), -1 = Right (Flipped)
        
        -- Visual State (Pixels)
        visualX = 0, 
        visualY = 0,
        
        -- Combat State
        stats = {},         -- Derived stats (Base + Equipment)
        skills = {},        -- Available skills (Learned + Granted)
        hp = 0,
        maxHp = 0,
        statusEffects = {}, -- Runtime statuses (e.g. burn, bleed, stun)
        
        -- Action State
        intent = nil,       -- { type="MOVE", target={x,y} } or { type="SKILL", id="slash", target=unitId }
        cooldowns = {},     -- Map of skill_id -> time_remaining (seconds)
        charges = {},       -- Map of skill_id -> remaining_uses
        currentCast = nil,  -- { skillId, targetUnitId, remaining }
        skillList = {},     -- Ordered list of skill IDs for UI
        
        -- Visual Effects State
        visualEffects = {
            shakeTime = 0,
            flashTime = 0,
            flashColor = {1, 1, 1}, -- {r, g, b}
            flashIntensity = 0,
            lungeTime = 0,
            lungeDuration = 0,
            lungeX = 0,
            lungeY = 0
        },
        globalCooldown = 0  -- GCD timer
    }
    
    setmetatable(self, BattleUnit)
    
    -- Set initial facing based on team
    if self.team == "player" then
        self.facing = -1 -- Player units start facing Right
    end
    
    -- 1. Copy Base Stats
    if actor.stats then
        for k, v in pairs(actor.stats) do self.stats[k] = v end
    end

    -- Visual sizing is independent from gameplay collision.
    if actor.size then
        self.visualRadius = math.max(8, DEFAULT_VISUAL_RADIUS * getVisualRadiusScale(actor.size))
    end
    
    -- 2. Copy Learned Skills
    if actor.skills then
        for k, v in pairs(actor.skills) do self.skills[k] = v end
    end

    -- 2b. Copy status effects (if any)
    if actor.statusEffects then
        for k, v in pairs(actor.statusEffects) do
            self.statusEffects[k] = v
        end
    end
    
    -- 3. Apply Equipment Bonuses & Granted Skills
    if actor.equipment then
        for slot, itemId in pairs(actor.equipment) do
            local item = EquipmentData[itemId]
            if item then
                -- Add Stats
                if item.stats then
                    for stat, val in pairs(item.stats) do
                        self.stats[stat] = (self.stats[stat] or 0) + val
                    end
                end
                -- Grant Skill
                if item.grantsSkill then
                    self.skills[item.grantsSkill] = {level = 1, source = "item"}
                end
            end
        end
    end
    
    -- 4. Finalize HP
    self.maxHp = self.stats.health or 100
    if actor.hp then
        self.hp = actor.hp
    else
        self.hp = self.maxHp
    end
    
    -- Initialize charges for skills that have limits
    self.skillList = {}
    for skillId, _ in pairs(self.skills) do
        table.insert(self.skillList, skillId)
        local skillData = Skills[skillId]
        if skillData and skillData.maxCharges then
            self.charges[skillId] = skillData.maxCharges
        end
    end
    table.sort(self.skillList)
    
    return self
end

-- Helper to check if unit can act
function BattleUnit:canAct()
    return self.hp > 0 and self.globalCooldown <= 0
end

-- Sync visual position immediately to world position (teleport)
function BattleUnit:snapToWorld()
    self.visualX = self.x
    self.visualY = self.y
end

return BattleUnit