-- ecs/assemblages/unit.lua
-- Assembles a living unit entity (player character, NPC, or troop) from a
-- data/troops.lua template. There is no behavioral split between "player",
-- "npc", and "unit" beyond marker tags added by the caller -- all of them
-- are hydrated the same way.

local Concord = require("src.libs.concord")
local TroopsData = require("src.data.troops")
local IdAllocator = require("src.core.id_allocator")
local Inventory = require("src.systems.items.inventory_system")

local function unitAssemblage(e, troopType, id)
    local allocator = IdAllocator.forWorld(e.__world)
    if id ~= nil then
        e.id = allocator:claim(id)
    else
        e.id = allocator:allocate("actor")
    end
    e.troopType = troopType or "soldier"
    e.injuries = {}
    e:give("unit")

    e.x, e.y = 0, 0

    e.stats = {
        health = 100,
        morale = 10,
        precision = 10,
        attack = 10,
        defense = 10,
        speed = 10,        -- World map speed
        battle_speed = 10  -- Combat action speed (baseline 10)
    }
    e.maxHp = e.stats.health
    e.hp = e.maxHp

    e.level = 1
    e.experience = 0
    e.size = 3
    e.profile = e.size * 10  -- how noticeable the unit is (spotting/scouting)
    e.sight = e.size * 10    -- how good the unit is at spotting others

    -- Default Humanoid Slots
    e.availableSlots = {
        "mainHand", "offHand", "rangedWeapon", "head", "body", "hands", "feet"
    }
    e.treasury = 0 -- Personal gold; party members transact through their party treasury.
    e.inventory = Inventory.new()
    e.equipment = {}
    e.skills = {
        ["attack"] = {learned = true} -- Default basic attack
    }
    e.attributes = {
        tracking = 0,
        shadowcraft = 0,
        divination = 0,
        engineering = 0,
        oratory = 0,
        command = 0,
        navigation = 0
    }
    e.factions = {}

    -- Innate protections (flat damage reduction per type)
    e.innateProtections = {
        slashing = 0,
        piercing = 0,
        blunt = 0,
        fire = 0,
        ice = 0,
        shock = 0,
        poison = 0
    }

    e.velocity = {x = 0, y = 0}
    e.ai = {state = "idle"}
    e.sprite = "src/assets/sprites/units/imp.png"

    e.formation = nil
    e.squad = nil

    -- Load definition from data
    local data = TroopsData[e.troopType]
    if data then
        e.injuryProfile = data.injuryProfile
        e.heightMultiplier = data.heightMultiplier
        -- Reuse existing character template conventions. A troop's display name
        -- or appointment as leader alone does not make it an important character.
        if data.type == "player" or data.type == "companion" then e:give("memory") end
        e.name = data.name

        if data.stats then
            for k, v in pairs(data.stats) do
                e.stats[k] = v
            end
            if data.stats.health then
                e.maxHp = data.stats.health
                e.hp = e.maxHp
            end
        end

        if data.innateProtections then
            for kind, value in pairs(data.innateProtections) do
                e.innateProtections[kind] = value
            end
        end

        if data.size then
            e.size = data.size
            e.profile = e.size * 10
            e.sight = e.size * 10
        end

        if data.profile then
            e.profile = data.profile
        end

        if data.sight then
            e.sight = data.sight
        end

        if data.slots then
            e.availableSlots = data.slots
        end

        if data.equipment then
            for slot, itemId in pairs(data.equipment) do
                if type(itemId) == "table" then
                    itemId = itemId[math.random(#itemId)]
                end
                e.equipment[slot] = itemId
            end
        end

        if data.skills then
            e.skills = {} -- Clear default skills
            for _, skillId in ipairs(data.skills) do
                e.skills[skillId] = {learned = true}
            end
        end

        if data.attributes then
            for attr, level in pairs(data.attributes) do
                e.attributes[attr] = level
            end
        end

        if data.sprite then
            if type(data.sprite) == "table" then
                e.sprite = data.sprite[math.random(#data.sprite)]
            else
                e.sprite = data.sprite
            end
        end
    end
end

local Unit = {assemble = unitAssemblage}

function Unit.create(world, troopType, id)
    if id ~= nil then
        IdAllocator.forWorld(world):assertAvailable(id)
    end
    return Concord.entity(world):assemble(unitAssemblage, troopType, id)
end

return Unit
