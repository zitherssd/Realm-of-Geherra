-- ecs/world.lua
-- Holds the persistent campaign Concord world (parties, actors, locations).
-- Replaces the old prototype-OOP entity graph; GameContext still holds
-- session-level bookkeeping (current map, quests, flags, etc.).

local Concord = require("src.libs.concord")
require("src.ecs.components")

local EcsWorld = {
    campaign = nil
}

function EcsWorld.init()
    EcsWorld.campaign = Concord.world.new()
    return EcsWorld.campaign
end

return EcsWorld
