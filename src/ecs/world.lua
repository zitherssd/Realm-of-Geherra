-- ecs/world.lua
-- Holds the persistent campaign Concord world (parties, actors, locations,
-- quests) and the ephemeral battle world (created on battle start, torn down
-- on battle end). Replaces the old prototype-OOP entity graph; GameContext/
-- BattleContext still hold session/battle-level bookkeeping (current map,
-- flags, camera, casualties, etc.).

local Concord = require("src.libs.concord")
require("src.ecs.components")

local EcsWorld = {
    campaign = nil,
    battle = nil
}

function EcsWorld.init()
    EcsWorld.campaign = Concord.world.new()
    return EcsWorld.campaign
end

function EcsWorld.startBattle()
    EcsWorld.battle = Concord.world.new()
    return EcsWorld.battle
end

function EcsWorld.endBattle()
    if EcsWorld.battle then
        EcsWorld.battle:clear()
        EcsWorld.battle = nil
    end
end

return EcsWorld
