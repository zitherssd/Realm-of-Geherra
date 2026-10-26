-- ecs/components/init.lua
-- Registers every marker component used across the campaign world.

require("src.ecs.components.party")
require("src.ecs.components.player")
require("src.ecs.components.npc")
require("src.ecs.components.unit")
require("src.ecs.components.battle_unit")
require("src.ecs.components.quest")
require("src.ecs.components.location")
require("src.ecs.components.world_activity")
require("src.ecs.components.npc_goals")

return true
