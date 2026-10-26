-- ecs/components/world_activity.lua
-- Serializable state for a party's current world activity.
local Concord = require("src.libs.concord")

return Concord.component.new("world_activity", function(component)
    component.type = nil
    component.phase = nil
    component.status = "idle"
    component.params = {}
    component.targetId = nil
    component.contactEmitted = false
    component.stalledSeconds = 0
    component.lastDistance = nil
    component.lastKnownX = nil
    component.lastKnownY = nil
    component.targetLostSeconds = 0
    component.reason = nil
    component.encounterId = nil
    component.lastActivity = nil
    component.sequence = 0
    component.goalActorId = nil
    component.retryCooldownSeconds = 0
    component.outcome = nil
    component.waypoints = nil
    component.waypointIndex = nil
    component.previousPartyState = nil
    component.roamOriginX = nil
    component.roamOriginY = nil
    component.elapsedSeconds = nil
end)
