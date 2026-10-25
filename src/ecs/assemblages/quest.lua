-- ecs/assemblages/quest.lua
-- Assembles a quest instance (see src/data/quests.lua for templates). Lives
-- in the campaign world for its whole lifetime -- state flips from "active"
-- to "completed"/"failed" rather than moving between separate lists.

local Concord = require("src.libs.concord")
local IdAllocator = require("src.core.id_allocator")

local function questAssemblage(e, instanceId, title, templateId)
    e:give("quest")
    local allocator = IdAllocator.forWorld(e.__world)
    if instanceId ~= nil then
        instanceId = allocator:claim(instanceId)
    else
        instanceId = allocator:allocate("quest")
    end
    e.id = instanceId
    e.instanceId = instanceId
    e.templateId = templateId
    e.title = title or "Quest"
    e.description = ""
    e.giver = nil
    e.giverId = nil
    e.giverName = nil
    e.giverLocationName = nil
    e.giverLocationX = nil
    e.giverLocationY = nil
    e.state = "inactive" -- inactive, active, completed, failed
    e.objectives = {}
    e.rewards = {gold = 0, items = {}, reputation = {}, unlocks = {}}
    e.spawnedPartyIds = {}
end

local Quest = {assemble = questAssemblage}

function Quest.create(world, instanceId, title, templateId)
    if instanceId ~= nil then
        IdAllocator.forWorld(world):assertAvailable(instanceId)
    end
    return Concord.entity(world):assemble(questAssemblage, instanceId, title, templateId)
end

return Quest
