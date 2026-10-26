-- Optional actor-owned, serializable decision state. No entity references.
local Concord = require("src.libs.concord")

return Concord.component.new("npc_goals", function(component)
    component.goals = {}
    component.capabilities = {}
    component.evaluationCooldownSeconds = 0
end)
