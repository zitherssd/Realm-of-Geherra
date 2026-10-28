-- Purposeful, timed exploration using Roam's bounded navigation and cleanup.
local Roam = require("src.systems.world_activities.roam_activity")
local Search = {initialPhase = "search", update = Roam.update, onTerminal = Roam.onTerminal}

function Search.prepare(party, params, map)
    if params.durationSeconds == nil then return nil, "search_duration_required" end
    return Roam.prepare(party, params, map)
end

function Search.onStart(party, activity, prepared, map)
    local started, reason = Roam.onStart(party, activity, prepared, map)
    if started then party.state = "search" end
    return started, reason
end

return Search
