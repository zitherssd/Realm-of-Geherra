-- ecs/world.lua
-- Holds the persistent campaign Concord world (parties, actors, locations,
-- quests). Battle worlds are created and owned by individual simulations.

local Concord = require("src.libs.concord")
require("src.ecs.components")

local EcsWorld = {
    campaign = nil
}

function EcsWorld.init()
    EcsWorld.campaign = Concord.world.new()
    return EcsWorld.campaign
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
