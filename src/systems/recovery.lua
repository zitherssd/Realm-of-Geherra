-- One world recovery rule for party members and independent important residents.
local EcsWorld = require("src.ecs.world")
local Recovery = {injuredThreshold = 0.6, recoveredThreshold = 0.9,
    passiveHealSecondsToFull = 300, restHealMultiplier = 10}

function Recovery.isLiving(actor)
    return actor and actor.__world and (actor.hp or 0) > 0
        and EcsWorld.findActorById(actor.id, actor.__world) == actor
end

function Recovery.maxHealth(actor)
    return actor.maxHp or (actor.stats and actor.stats.health) or 0
end

function Recovery.needsRest(actor, alreadyResting)
    local maximum = Recovery.maxHealth(actor)
    local threshold = alreadyResting and Recovery.recoveredThreshold or Recovery.injuredThreshold
    return Recovery.isLiving(actor) and maximum > 0 and actor.hp < maximum * threshold
end

function Recovery.advance(actor, dt, multiplier)
    if dt <= 0 or not Recovery.isLiving(actor) or actor.activeEncounterId then return false end
    local maximum = Recovery.maxHealth(actor)
    if maximum <= 0 then return false end
    local rate = maximum / math.max(1, Recovery.passiveHealSecondsToFull)
    actor.hp = math.min(maximum, actor.hp + rate * math.max(0, multiplier or 1) * dt)
    return true
end

local function mapParties(map, playerParty)
    local parties, seenParties = {}, {}
    local function add(party)
        if not party or seenParties[party] or party.__world ~= EcsWorld.campaign
            or EcsWorld.findPartyById(party.id, party.__world) ~= party then return end
        seenParties[party] = true
        parties[#parties + 1] = party
    end
    add(playerParty)
    for _, party in ipairs(map:getParties() or {}) do add(party) end
    for _, location in ipairs(map:getLocations() or {}) do
        if EcsWorld.findLocationById(location.id, location.__world) == location then
            for _, party in ipairs(location.stationedParties or {}) do add(party) end
        end
    end
    return parties
end

-- Capture before advancing encounters: finishing a battle must not grant healing
-- for the same elapsed time that was just spent fighting.
function Recovery.encounterReservations(map, playerParty)
    local reserved = {}
    for _, party in ipairs(mapParties(map, playerParty)) do
        for _, actor in ipairs(party.actors or {}) do
            if party.activeEncounterId or actor.activeEncounterId then reserved[actor] = true end
        end
    end
    for _, location in ipairs(map:getLocations() or {}) do
        for _, actor in ipairs(location.npcs or {}) do
            if actor.activeEncounterId then reserved[actor] = true end
        end
    end
    return reserved
end

local function residentResting(actor)
    for _, goal in ipairs(actor.npc_goals and actor.npc_goals.goals or {}) do
        if goal.type == "rest_and_recover" and goal.recovering
            and goal.status == "active" and not goal.activity then return true end
    end
    return false
end

-- Goals and activities select rest but never add healing themselves.
function Recovery.update(dt, map, playerParty, playerResting, reserved)
    if dt <= 0 or not map or not EcsWorld.campaign then return end
    local parties = mapParties(map, playerParty)
    local actors, membership = {}, {}
    reserved = reserved or {}
    local world = EcsWorld.campaign
    -- Any live roster prevents a stale resident reference healing a member locally.
    for _, party in ipairs(world:query({"party"})) do
        if EcsWorld.findPartyById(party.id, world) == party then
            for _, actor in ipairs(party.actors or {}) do
                membership[actor] = true
                if party.activeEncounterId then reserved[actor] = true end
            end
        end
    end
    for _, party in ipairs(parties) do
        for _, actor in ipairs(party.actors or {}) do
            membership[actor] = true
            if party.activeEncounterId then reserved[actor] = true end
        end
    end
    local function heal(actor, resting, context)
        if actors[actor] then return end
        actors[actor] = true
        local blocked = reserved[actor] or actor.activeEncounterId
        local living = Recovery.isLiving(actor)
        local mode = not living and "inactive" or (blocked and "suspended" or (resting and "resting" or "passive"))
        actor.lastRecovery = {mode = mode, context = context}
        if living and not blocked then
            Recovery.advance(actor, dt, resting and Recovery.restHealMultiplier or 1)
        end
    end
    for _, party in ipairs(parties) do
        local activity = party.world_activity
        local resting = (party == playerParty and playerResting)
            or (activity and activity.type == "rest" and activity.status == "active")
        for _, actor in ipairs(party.actors or {}) do
            if actor.__world == party.__world then heal(actor, resting, "party member") end
        end
    end
    for _, location in ipairs(map:getLocations() or {}) do
        if EcsWorld.findLocationById(location.id, world) == location then
            for _, actor in ipairs(location.npcs or {}) do
                if actor.memory and actor.__world == world and not membership[actor] then
                    heal(actor, residentResting(actor), "independent resident")
                end
            end
        end
    end
end

return Recovery
