-- Readable snapshots for the debug overlay; never retain entity references.
local PartySystem = require("src.systems.party_system")
local EcsWorld = require("src.ecs.world")
local Tools = require("src.debug.campaign_tools")
local Inspector = {}

local function label(entity)
    return (entity.name or "Unnamed") .. " [" .. tostring(entity.id) .. "]"
end

function Inspector.lines(map, kind, id)
    local entity = Tools.resolve(map, kind, id)
    if not entity then return {"This entity was removed or is no longer on this map."} end
    local lines = {label(entity), string.format("Position: %.1f, %.1f", entity.x, entity.y),
        "Faction: " .. tostring(entity.faction or "none")}
    local function add(text) lines[#lines + 1] = text end
    if kind == "party" then
        local leader = PartySystem.getLeader(entity)
        add("Leader: " .. (leader and label(leader) or "none"))
        add("Treasury: " .. tostring(entity.treasury) .. " | Supplies: " .. tostring(entity.supplies))
        add("State: " .. tostring(entity.state) .. " | Hostile: " .. tostring(entity.hostile == true or entity.faction == "bandits"))
        add("Sight: " .. PartySystem.getPartySight(entity) .. " | Profile: " .. PartySystem.getPartyProfile(entity))
        for _, location in ipairs(map:getLocations()) do
            for _, party in ipairs(location.stationedParties or {}) do
                if party == entity then add("Stationed at: " .. label(location)) end
            end
        end
        add("Encounter: " .. tostring(entity.activeEncounterId or "none"))
        local activity = entity.world_activity or {}
        add("Activity: " .. tostring(activity.type or "none") .. " / " .. tostring(activity.status or "idle")
            .. " / " .. tostring(activity.phase or "-"))
        add("Attempt: " .. tostring(activity.sequence or 0) .. " | Goal owner: " .. tostring(activity.goalActorId or "none"))
        add("Target: " .. tostring(activity.targetId or (activity.params or {}).destinationLocationId or "none"))
        add(string.format("Activity retry: %.1fs", activity.retryCooldownSeconds or 0))
        if activity.reason then add("Activity reason: " .. activity.reason) end
        if activity.lastActivity then
            local last = activity.lastActivity
            add("Last activity: " .. tostring(last.type) .. " #" .. tostring(last.sequence) .. " / "
                .. tostring(last.status) .. " / " .. tostring(last.reason or "-"))
        end
        local state = leader and leader.npc_goals
        add("")
        add("LEADER GOALS")
        if not state then add("Unconfigured (legacy Raid behavior).")
        else
            add("Capabilities: Raid " .. tostring(state.capabilities.raid == true) .. ", Travel " .. tostring(state.capabilities.travel == true))
            if #state.goals == 0 then add("Empty goal list (legacy Raid suppressed).") end
            for index, goal in ipairs(state.goals) do
                add(index .. ". " .. goal.type .. " | priority " .. goal.priority .. " | " .. goal.status)
                add("  Target: " .. tostring(goal.amount or goal.destinationLocationId))
                add(string.format("  Attempts: %d | Retry: %.1fs", goal.attempts, goal.retrySeconds))
                if goal.reason then add("  Reason: " .. goal.reason) end
                if goal.lastOutcome then
                    add("  Last outcome: " .. tostring(goal.lastOutcome.activityType or "activity") .. " / "
                        .. goal.lastOutcome.status .. " / " .. tostring(goal.lastOutcome.reason or "-"))
                end
            end
        end
        add("")
        add("ACTORS (" .. #entity.actors .. ")")
        for _, actor in ipairs(entity.actors) do
            add(label(actor) .. " | HP " .. tostring(actor.hp) .. "/" .. tostring(actor.maxHp)
                .. (EcsWorld.findActorById(actor.id) ~= actor and " (removed)" or ""))
        end
        add("CARGO (" .. #entity.inventory .. " stacks)")
        for _, item in ipairs(entity.inventory) do add(tostring(item.name or item.id) .. " x" .. tostring(item.quantity or 1)) end
    else
        add("Type: " .. tostring(entity.type) .. " | Owner: " .. tostring(entity.owner or "none"))
        add("Population: " .. tostring(entity.population) .. " | Prosperity: " .. tostring(entity.prosperity))
        add("Discovered: " .. tostring(entity.discovered) .. " | Profile: " .. tostring(entity.profile))
        add("Road site: " .. tostring(entity.siteId or "none"))
        add("RESIDENTS (" .. #entity.npcs .. ")")
        for _, npc in ipairs(entity.npcs) do add(label(npc) .. " | HP " .. tostring(npc.hp)) end
        add("STATIONED PARTIES (" .. #entity.stationedParties .. ")")
        for _, party in ipairs(entity.stationedParties) do add(label(party) .. " | Actors " .. #party.actors) end
    end
    return lines
end

return Inspector
