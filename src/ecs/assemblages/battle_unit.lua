-- ecs/assemblages/battle_unit.lua
-- Assembles a transient battle-world unit wrapping a campaign actor entity.
-- Holds world-space position, visual position, and current intent.

local Concord = require("src.libs.concord")
local Skills = require("src.data.skills")
local Items = require("src.data.items")

local DEFAULT_MOVE_STEP = 24
local DEFAULT_COLLISION_RADIUS = 18
local DEFAULT_ATTACK_REACH = 8

local function copyTable(source)
    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = copyTable(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local function battleUnitAssemblage(e, actor, worldX, worldY, team)
    e:give("battleUnit")

    -- Persistent Data Reference
    e.actor = actor
    e.id = actor.id

    -- Logical State (World)
    e.x = worldX
    e.y = worldY
    e.velocityX = 0
    e.velocityY = 0
    e.moveCooldown = 0
    e.moveStep = DEFAULT_MOVE_STEP
    e.collisionRadius = DEFAULT_COLLISION_RADIUS
    e.attackRange = DEFAULT_ATTACK_REACH
    e.moveTarget = nil
    e.state = "idle"
    e.team = team or "neutral" -- "player", "enemy", "ally"
    e.facing = 1 -- 1 = Left (Default), -1 = Right (Flipped)

    -- Visual State (Pixels)
    e.visualX = 0
    e.visualY = 0

    -- Combat State
    e.stats = {}         -- Derived stats (Base + Equipment)
    e.skills = {}        -- Available skills (Learned + Granted)
    e.hp = 0
    e.maxHp = 0
    e.statusEffects = {} -- Runtime statuses (e.g. burn, bleed, stun)
    e.protections = {    -- Flat damage reduction per type (Innate + Equipment)
        slashing = 0,
        piercing = 0,
        blunt = 0,
        fire = 0,
        ice = 0,
        shock = 0,
        poison = 0
    }

    -- Action State
    e.intent = nil       -- { type="MOVE", target={x,y} } or { type="SKILL", id="slash", target=unitId }
    e.cooldowns = {}     -- Map of skill_id -> time_remaining (seconds)
    e.charges = {}       -- Map of skill_id -> remaining_uses
    e.currentCast = nil  -- { skillId, targetUnitId, remaining }
    e.skillList = {}      -- Ordered list of skill IDs for UI

    -- Visual Effects State
    e.visualEffects = {
        shakeTime = 0,
        flashTime = 0,
        flashColor = {1, 1, 1}, -- {r, g, b}
        flashIntensity = 0,
        lungeTime = 0,
        lungeDuration = 0,
        lungeX = 0,
        lungeY = 0
    }
    e.globalCooldown = 0 -- GCD timer

    -- Set initial facing based on team
    if e.team == "player" then
        e.facing = -1 -- Player units start facing Right
    end

    -- 1. Copy Base Stats
    if actor.stats then
        for k, v in pairs(actor.stats) do e.stats[k] = v end
    end

    -- 2. Copy Learned Skills
    if actor.skills then
        for k, v in pairs(actor.skills) do e.skills[k] = v end
    end

    -- 2b. Copy status effects (if any)
    if actor.statusEffects then
        e.statusEffects = copyTable(actor.statusEffects)
    end

    -- 3. Apply Equipment Bonuses & Granted Skills
    if actor.equipment then
        for slot, itemId in pairs(actor.equipment) do
            local item = Items[itemId]
            if item then
                -- Add Stats
                if item.stats then
                    for stat, val in pairs(item.stats) do
                        e.stats[stat] = (e.stats[stat] or 0) + val
                    end
                end
                -- Grant Skill
                if item.grantsSkill then
                    e.skills[item.grantsSkill] = {level = 1, source = "item"}
                end
            end
        end
    end

    -- 3b. Initialize Protections (Innate + Equipment)
    if actor.innateProtections then
        for damageType, value in pairs(actor.innateProtections) do
            e.protections[damageType] = (e.protections[damageType] or 0) + value
        end
    end

    if actor.equipment then
        for slot, itemId in pairs(actor.equipment) do
            local item = Items[itemId]
            if item and item.protections then
                for damageType, value in pairs(item.protections) do
                    e.protections[damageType] = (e.protections[damageType] or 0) + value
                end
            end
        end
    end

    -- 4. Finalize HP
    e.maxHp = e.stats.health or 100
    if actor.hp then
        e.hp = actor.hp
    else
        e.hp = e.maxHp
    end

    -- Initialize charges for skills that have limits
    e.skillList = {}
    for skillId, _ in pairs(e.skills) do
        table.insert(e.skillList, skillId)
        local skillData = Skills[skillId]
        if skillData and skillData.maxCharges then
            e.charges[skillId] = skillData.maxCharges
        end
    end
    table.sort(e.skillList)
end

local BattleUnit = {assemble = battleUnitAssemblage}

function BattleUnit.create(world, actor, worldX, worldY, team)
    return Concord.entity(world):assemble(battleUnitAssemblage, actor, worldX, worldY, team)
end

return BattleUnit
