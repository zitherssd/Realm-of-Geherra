-- Executes one active world activity per party; player movement activities are explicit.
local EventBus = require("src.core.event_bus")
local RaidActivity = require("src.systems.world_activities.raid_activity")
local TravelActivity = require("src.systems.world_activities.travel_activity")
local RoamActivity = require("src.systems.world_activities.roam_activity")
local RestActivity = require("src.systems.world_activities.rest_activity")
local PartySystem = require("src.systems.party_system")

local WorldActivitySystem = {}

local function isHostile(party)
    return party.hostile == true or party.faction == "bandits"
end

local ACTIVITY_TYPES = {
    raid = RaidActivity,
    travel = TravelActivity,
    roam = RoamActivity,
    rest = RestActivity
}

WorldActivitySystem.terminalRetryCooldownSeconds = 5

local function copyPrimitiveParams(params)
    if params ~= nil and type(params) ~= "table" then
        error("World activity parameters must be a table")
    end

    local copy = {}
    for key, value in pairs(params or {}) do
        local valueType = type(value)
        if type(key) ~= "string"
            or (valueType ~= "string" and valueType ~= "number" and valueType ~= "boolean") then
            error("World activity parameters must be keyed primitive values")
        end
        copy[key] = value
    end
    return copy
end

local function getActivity(party)
    if not party.world_activity then
        party:ensure("world_activity")
    end
    return party.world_activity
end

local function findParty(map, partyId)
    for _, party in ipairs(map:getParties() or {}) do
        if party.id == partyId then return party end
    end
    return nil
end

local function allMapParties(map)
    local parties, seen = {}, {}
    local function add(party)
        if not seen[party.id] then
            seen[party.id] = true
            parties[#parties + 1] = party
        end
    end
    for _, party in ipairs(map:getParties() or {}) do add(party) end
    for _, location in ipairs(map.getLocations and map:getLocations() or {}) do
        for _, party in ipairs(location.stationedParties or {}) do add(party) end
    end
    return parties
end

local function cleanupTerminalActivity(party, map)
    local activity = party.world_activity
    if not activity or (activity.status ~= "completed" and
        activity.status ~= "cancelled" and activity.status ~= "failed") then
        return false
    end

    local encounterCooldown = map and map.partyEncounterCooldowns
        and map.partyEncounterCooldowns[party.id] or 0
    -- A goal's Roam-to-Raid handoff is not a failed attempt. Cleanup still
    -- releases all movement state before the next activity may start.
    local opportunityHandoff = activity.type == "roam" and activity.goalActorId
        and activity.reason == "opportunity_detected"
    if encounterCooldown <= 0 and not opportunityHandoff then
        activity.retryCooldownSeconds = WorldActivitySystem.terminalRetryCooldownSeconds
    end
    local implementation = ACTIVITY_TYPES[activity.type]
    if implementation and implementation.onTerminal then
        implementation.onTerminal(party, activity, activity.status)
    end
    activity.lastActivity = {
        sequence = activity.sequence,
        type = activity.type,
        status = activity.status,
        reason = activity.reason,
        outcome = activity.outcome
    }
    activity.type = nil
    activity.phase = nil
    activity.status = "idle"
    activity.params = {}
    activity.targetId = nil
    activity.contactEmitted = false
    activity.stalledSeconds = 0
    activity.lastDistance = nil
    activity.lastKnownX = nil
    activity.lastKnownY = nil
    activity.targetLostSeconds = 0
    activity.reason = nil
    activity.encounterId = nil
    activity.waypoints = nil
    activity.waypointIndex = nil
    activity.previousPartyState = nil
    activity.goalActorId = nil
    return true
end

local function updateRetryCooldowns(dt, map)
    for _, party in ipairs(allMapParties(map)) do
        local activity = party.world_activity
        if activity and (activity.retryCooldownSeconds or 0) > 0 then
            activity.retryCooldownSeconds = math.max(0, activity.retryCooldownSeconds - math.max(0, dt))
        end
    end
end

local function handleEncounterNotification(event, callbackName)
    if type(event) ~= "table" then return end
    local GameContext = require("src.game.game_context")
    local map = GameContext.data and GameContext.data.currentMap
    if not map or event.mapId ~= map.id then return end

    local party = findParty(map, event.sourcePartyId)
    local activity = party and party.world_activity
    if not activity or activity.type ~= event.activityType then return end

    local implementation = ACTIVITY_TYPES[activity.type]
    local callback = implementation and implementation[callbackName]
    if callback then callback(activity, event) end
end

function WorldActivitySystem.init()
    EventBus.unsubscribe("party_encounter_started", WorldActivitySystem._onEncounterStarted)
    EventBus.unsubscribe("party_encounter_rejected", WorldActivitySystem._onEncounterRejected)
    EventBus.unsubscribe("party_encounter_finished", WorldActivitySystem._onEncounterFinished)
    EventBus.subscribe("party_encounter_started", WorldActivitySystem._onEncounterStarted)
    EventBus.subscribe("party_encounter_rejected", WorldActivitySystem._onEncounterRejected)
    EventBus.subscribe("party_encounter_finished", WorldActivitySystem._onEncounterFinished)
end

function WorldActivitySystem._onEncounterStarted(event)
    handleEncounterNotification(event, "onEncounterStarted")
end

function WorldActivitySystem._onEncounterRejected(event)
    handleEncounterNotification(event, "onEncounterRejected")
end

function WorldActivitySystem._onEncounterFinished(event)
    handleEncounterNotification(event, "onEncounterFinished")
end

function WorldActivitySystem.start(party, activityType, params, map)
    if party and party.activeEncounterId then
        return false, "party_in_encounter"
    end

    local implementation = ACTIVITY_TYPES[activityType]
    if not implementation then
        error("Unknown world activity type: " .. tostring(activityType))
    end

    local copiedParams = copyPrimitiveParams(params)
    local activity = getActivity(party)
    if activity.status == "completed" or activity.status == "cancelled" or
        activity.status == "failed" then
        cleanupTerminalActivity(party)
    end
    if activity.status == "active" then
        return false, "party_already_active"
    end
    if (activity.retryCooldownSeconds or 0) > 0 then
        return false, "activity_cooldown"
    end

    local prepared
    if implementation.prepare then
        if not map then
            local GameContext = require("src.game.game_context")
            map = GameContext.data and GameContext.data.currentMap
        end
        local reason
        prepared, reason = implementation.prepare(party, copiedParams, map)
        if not prepared then return false, reason end
    end

    if implementation.onStart then
        local started, reason = implementation.onStart(party, activity, prepared, map)
        if not started then return false, reason end
    end

    activity.type = activityType
    activity.goalActorId = nil
    activity.sequence = (activity.sequence or 0) + 1
    activity.phase = implementation.initialPhase or "acquire"
    activity.status = "active"
    activity.params = copiedParams
    activity.targetId = nil
    activity.contactEmitted = false
    activity.encounterId = nil
    activity.stalledSeconds = 0
    activity.lastDistance = nil
    activity.lastKnownX = nil
    activity.lastKnownY = nil
    activity.targetLostSeconds = 0
    activity.reason = nil
    activity.outcome = nil
    return true
end

function WorldActivitySystem.cancel(party, reason)
    if reason ~= nil and type(reason) ~= "string" then
        error("World activity cancellation reason must be a string")
    end

    local activity = party and party.world_activity
    if not activity or activity.status ~= "active" then
        return false
    end

    activity.status = "cancelled"
    activity.phase = "cancelled"
    activity.reason = reason or "cancelled"
    activity.outcome = {
        destinationLocationId = activity.params
            and activity.params.destinationLocationId or nil,
        status = "cancelled",
        reason = activity.reason
    }
    return true
end

local function startDefaultRaids(map, playerParty)
    for _, party in ipairs(map:getParties() or {}) do
        local activity = party.world_activity
        local leader = PartySystem.getLeader(party)
        if party ~= playerParty and not party.activeEncounterId and isHostile(party)
            and not (leader and leader.npc_goals)
            and activity and activity.status == "idle" and activity.type == nil
            and (activity.retryCooldownSeconds or 0) <= 0
            and RaidActivity.hasEligibleTarget(party, map, playerParty) then
            WorldActivitySystem.start(party, "raid")
        end
    end
end

function WorldActivitySystem.ensureDefaultActivities(map, playerParty)
    if map then
        startDefaultRaids(map, playerParty)
    end
end

function WorldActivitySystem.update(dt, map, playerParty)
    if not map then return end

    updateRetryCooldowns(dt, map)

    for _, party in ipairs(allMapParties(map)) do
        cleanupTerminalActivity(party, map)
    end

    if dt <= 0 then
        return
    end

    WorldActivitySystem.ensureDefaultActivities(map, playerParty)

    -- Rest can execute in place at a location; movement activities still use
    -- only traveling parties (Travel unstations its party in onStart).
    local parties, traveling = allMapParties(map), {}
    for _, party in ipairs(map:getParties() or {}) do traveling[party] = true end

    for _, party in ipairs(parties) do
        local activity = party.world_activity
        if (party ~= playerParty or (activity and (activity.type == "travel" or activity.type == "roam")))
            and (traveling[party] or (activity and activity.type == "rest"))
            and not party.activeEncounterId and
            activity and activity.status == "active" then
            local implementation = ACTIVITY_TYPES[activity.type]
            if not implementation then
                WorldActivitySystem.cancel(party, "unknown_activity")
            else
                local result, reason, target = implementation.update(party, activity, dt, map, playerParty)
                if result == "contact" then
                    if not activity.contactEmitted then
                        activity.contactEmitted = true
                        activity.phase = "contact"
                        local lootPolicy = implementation.getLootPolicy
                            and implementation.getLootPolicy(activity) or nil
                        EventBus.emit("party_contact", {
                            activityType = activity.type,
                            sourcePartyId = party.id,
                            targetPartyId = target.id,
                            mapId = map.id,
                            x = target.x,
                            y = target.y,
                            lootPolicy = lootPolicy
                        })
                    end
                elseif result == "failed" then
                    WorldActivitySystem.cancel(party, reason)
                elseif result == "completed" then
                    activity.status = "completed"
                    activity.phase = "complete"
                    activity.reason = reason or "completed"
                    activity.outcome = {
                        destinationLocationId = activity.params.destinationLocationId,
                        status = "completed",
                        reason = activity.reason
                    }
                    cleanupTerminalActivity(party, map)
                end
            end
        end
    end
end

return WorldActivitySystem
