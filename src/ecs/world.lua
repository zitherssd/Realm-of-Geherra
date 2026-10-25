-- ecs/world.lua
-- Holds the persistent campaign Concord world (parties, actors, locations,
-- quests). Battle worlds are created and owned by individual simulations.

local Concord = require("src.libs.concord")
require("src.ecs.components")
local IdAllocator = require("src.core.id_allocator")

local EcsWorld = {
    campaign = nil
}

function EcsWorld.init(options)
    options = options or {}
    EcsWorld.campaign = Concord.world.new()
    EcsWorld.campaign.idAllocator = IdAllocator.new(options.idAllocatorState)
    return EcsWorld.campaign
end

function EcsWorld.getIdAllocator(world)
    return IdAllocator.forWorld(world or EcsWorld.campaign)
end

function EcsWorld.serializeIdAllocator(world)
    return IdAllocator.forWorld(world or EcsWorld.campaign):serialize()
end

function EcsWorld.restoreIdAllocator(world, state)
    world = world or EcsWorld.campaign
    if not world then
        error("Cannot restore ID allocator without a campaign world", 2)
    end
    world.idAllocator = IdAllocator.new(state)
    world.idAllocator:registerWorld(world)
    return world.idAllocator
end

local function isPendingRemoval(world, entity)
    for _, queueName in ipairs({"__removed", "__backRemoved"}) do
        local queue = world[queueName]
        local size = queue and (queue.size or #queue) or 0
        for index = 1, size do
            if queue[index] == entity then return true end
        end
    end
    return false
end

local function findEntityInList(list, entityId, componentName, world, matches)
    local size = list and (list.size or #list) or 0
    for index = 1, size do
        local entity = list[index]
        if entity and entity.id == entityId and
            (not componentName or entity[componentName]) and
            not isPendingRemoval(world, entity) then
            matches[#matches + 1] = entity
        end
    end
end

function EcsWorld.findEntityById(entityId, componentName, world)
    if entityId == nil then return nil end
    world = world or EcsWorld.campaign
    if not world then return nil end

    local matches = {}
    if type(world.getEntities) == "function" then
        findEntityInList(world:getEntities(), entityId, componentName, world, matches)
    end
    findEntityInList(world.__added, entityId, componentName, world, matches)
    findEntityInList(world.__backAdded, entityId, componentName, world, matches)

    local unique = {}
    local result
    for _, entity in ipairs(matches) do
        if not unique[entity] then
            unique[entity] = true
            if result and result ~= entity then
                error("Campaign contains duplicate entity ID " .. tostring(entityId), 2)
            end
            result = entity
        end
    end
    return result
end

function EcsWorld.findActorById(actorId, world)
    return EcsWorld.findEntityById(actorId, "unit", world)
end

function EcsWorld.findPartyById(partyId, world)
    return EcsWorld.findEntityById(partyId, "party", world)
end

function EcsWorld.findLocationById(locationId, world)
    return EcsWorld.findEntityById(locationId, "location", world)
end

function EcsWorld.findQuestById(questId, world)
    return EcsWorld.findEntityById(questId, "quest", world)
end

function EcsWorld.startBattle()
    return Concord.world.new()
end

function EcsWorld.endBattle(battleWorld)
    if battleWorld then
        battleWorld:clear()
    end
end

return EcsWorld
