-- Raid activity: a hostile party selects and pursues an eligible target.
local PartyInteractionSystem = require("src.systems.party_interaction_system")
local VisibilitySystem = require("src.systems.visibility_system")
local Pursuit = require("src.systems.world_activities.pursuit")

local RaidActivity = {}

RaidActivity.speed = 40
RaidActivity.maxStallSeconds = 8
RaidActivity.maxLostSightSeconds = 5

function RaidActivity.getLootPolicy(activity)
    local params = activity.params or {}
    local policy = {
        plunderAllowed = params.plunderAllowed ~= false
    }
    if params.stolenProportion ~= nil then
        policy.stolenProportion = params.stolenProportion
    end
    if params.destroyedProportion ~= nil then
        policy.destroyedProportion = params.destroyedProportion
    end
    return policy
end

local function isHostile(party)
    return party.hostile == true or party.faction == "bandits"
end

local function isTraderTarget(party)
    return party.isTraderParty == true and
        (party.state == "travel" or party.state == "wander")
end

local function findParty(map, partyId)
    for _, party in ipairs(map:getParties() or {}) do
        if party.id == partyId then
            return party
        end
    end
    return nil
end

local function isEligibleTarget(raider, party, map, playerParty)
    if party == raider or findParty(map, party.id) ~= party or
        not party.actors or #party.actors == 0 or party.activeEncounterId or
        (map.partyEncounterCooldowns and (map.partyEncounterCooldowns[party.id] or 0) > 0) then
        return false
    end

    local eligibleType = party == playerParty or isTraderTarget(party)
    return eligibleType and VisibilitySystem.canSee(raider, party)
end

local function isStillValidTarget(raider, party, map, playerParty)
    return party ~= raider and findParty(map, party.id) == party
        and party.actors and #party.actors > 0
        and not party.activeEncounterId
        and not (map.partyEncounterCooldowns and
            (map.partyEncounterCooldowns[party.id] or 0) > 0)
        and (party == playerParty or isTraderTarget(party))
end

local function selectTarget(raider, map, playerParty)
    local closest, closestDistance
    local function consider(party)
        if isEligibleTarget(raider, party, map, playerParty) then
            local dx, dy = party.x - raider.x, party.y - raider.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if not closestDistance or distance < closestDistance then
                closest, closestDistance = party, distance
            end
        end
    end

    for _, party in ipairs(map:getParties() or {}) do
        consider(party)
    end

    return closest
end

function RaidActivity.hasEligibleTarget(raider, map, playerParty)
    return selectTarget(raider, map, playerParty) ~= nil
end

RaidActivity.selectTarget = selectTarget

function RaidActivity.visibleTarget(raider, map, playerParty, id)
    local target = findParty(map, id)
    if target and isEligibleTarget(raider, target, map, playerParty) then return target end
end

function RaidActivity.update(raider, activity, dt, map, playerParty)
    if activity.phase == "contact" or activity.phase == "engaged" then
        return nil
    end

    if not isHostile(raider) then
        return "failed", "raider_not_hostile"
    end

    if activity.phase == "acquire" then
        local target
        if activity.params.targetPartyId ~= nil then
            target = RaidActivity.visibleTarget(raider, map, playerParty, activity.params.targetPartyId)
        else
            target = selectTarget(raider, map, playerParty)
        end
        if not target then
            return "failed", "no_target"
        end
        activity.targetId = target.id
        activity.phase = "pursuit"
        activity.lastDistance = nil
        activity.stalledSeconds = 0
        activity.lastKnownX = target.x
        activity.lastKnownY = target.y
        activity.targetLostSeconds = 0
    end

    local target = findParty(map, activity.targetId)
    if not target then
        return "failed", "target_missing"
    end
    if not isStillValidTarget(raider, target, map, playerParty) then
        return "failed", "target_unavailable"
    end

    if not VisibilitySystem.canSee(raider, target) then
        if activity.lastKnownX == nil or activity.lastKnownY == nil then
            return "failed", "target_lost"
        end

        activity.targetLostSeconds = (activity.targetLostSeconds or 0) + math.max(0, dt)
        if activity.targetLostSeconds >= RaidActivity.maxLostSightSeconds then
            return "failed", "target_lost"
        end

        local result, reason = Pursuit.update(
            raider,
            target,
            activity,
            dt,
            map,
            RaidActivity.speed,
            PartyInteractionSystem.interactionRadius,
            RaidActivity.maxStallSeconds,
            {
                targetX = activity.lastKnownX,
                targetY = activity.lastKnownY,
                canContact = false
            }
        )
        return result, reason
    end

    activity.lastKnownX = target.x
    activity.lastKnownY = target.y
    activity.targetLostSeconds = 0
    local result, reason = Pursuit.update(
        raider,
        target,
        activity,
        dt,
        map,
        RaidActivity.speed,
        PartyInteractionSystem.interactionRadius,
        RaidActivity.maxStallSeconds
    )
    return result, reason, target
end

function RaidActivity.onEncounterStarted(activity, event)
    if activity.phase ~= "contact" or activity.targetId ~= event.targetPartyId then
        return false
    end

    activity.phase = "engaged"
    activity.encounterId = event.encounterId
    return true
end

function RaidActivity.onEncounterRejected(activity, event)
    if activity.phase ~= "contact" or activity.targetId ~= event.targetPartyId then
        return false
    end

    activity.status = "cancelled"
    activity.phase = "cancelled"
    activity.reason = "contact_rejected:" .. tostring(event.reason)
    return true
end

function RaidActivity.onEncounterFinished(activity, event)
    if activity.phase ~= "engaged" or activity.encounterId ~= event.encounterId then
        return false
    end

    activity.encounterId = nil
    if event.outcome == "victory" and event.winnerPartyId == event.sourcePartyId then
        activity.status = "completed"
        activity.phase = "complete"
    else
        activity.status = "cancelled"
        activity.phase = "cancelled"
        activity.reason = event.outcome == "victory" and "raider_defeated"
            or ("encounter_" .. tostring(event.outcome))
    end
    return true
end

return RaidActivity
