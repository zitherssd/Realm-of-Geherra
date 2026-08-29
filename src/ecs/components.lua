-- ecs/components.lua
-- Registers the marker components used to tag entity kinds for Concord queries.
-- Required once (module caching keeps registration idempotent).

local Concord = require("src.libs.concord")

Concord.component.new("party")
Concord.component.new("player")
Concord.component.new("npc")
Concord.component.new("troop")

return true
