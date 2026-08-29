-- systems/encounter_system.lua
-- Threat-driven random encounters on the world map.
--
-- Computes a dynamic "threat" value (0-100) from the biome the party is in,
-- the time of day and the in-game day counter, and the player party's power.
-- While the party travels, this system accumulates distance and rolls for an
-- encounter; when one fires, a hostile party (built from a data-driven
-- template in data/encounters.lua) is spawned on the map near the player,
-- where the existing collision -> dialogue -> fight flow takes over.
--
-- Tunables (step distance, chances, spawn radii, biome map, bonuses) all live
-- in data/encounters.lua -- no content changes here.

local GameContext = require("src.game.game_context")
local EncounterData = require("src.data.encounters")
local TimeSystem = require("src.systems.time_system")
local EventBus = require("src.core.event_bus")
local EcsWorld = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local Unit = require("src.ecs.assemblages.unit")
local PartySystem = require("src.systems.party_system")
local PartyAiSystem = require("src.systems.party_ai_system")

local EncounterSystem = {}

-- Distance (px) traveled since the last spawned encounter. Gates how often new
-- encounters can fire so they never repeat back-to-back.
local distanceSinceEncounter = 0
-- Distance (px) accumulated toward the next encounter roll while moving.
local travelAccumulator = 0

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Weighted pick from a list of entries with a `weight` field.
local function weightedPick(entries)
    local total = 0
    for _, entry in ipairs(entries) do
        total = total + (entry.weight or 1)
    end
    if total <= 0 then
        return entries[1]
    end

    local roll = math.random() * total
    local cursor = 0
    for _, entry in ipairs(entries) do
        cursor = cursor + (entry.weight or 1)
        if roll <= cursor then
            return entry
        end
    end
    return entries[#entries]
end

-- Rough "power" score for the player party: the sum of each actor's max HP,
-- attack, and defense. Used to scale threat so stronger parties reach tougher
-- encounter bands.
local function partyPower()
    local playerParty = GameContext.data.playerParty
    if not playerParty then
        return 0
    end

    local power = 0
    for _, actor in ipairs(PartySystem.getActors(playerParty) or {}) do
        local stats = actor.stats or {}
        power = power + (actor.maxHp or stats.health or 0)
        power = power + (stats.attack or 0)
        power = power + (stats.defense or 0)
    end
    return power
end

-- Distance from (x, y) to the nearest location on the map.
local function distanceToNearestLocation(map, x, y)
    local nearest = math.huge
    for _, location in ipairs(map:getLocations() or {}) do
        local dx = location.x - x
        local dy = location.y - y
        local d = dx * dx + dy * dy
        if d < nearest then
            nearest = d
        end
    end
    if nearest == math.huge then
        return math.huge
    end
    return math.sqrt(nearest)
end

-- True when (x, y) is near a road polyline (mirrors the check in world_state;
-- roads halve the biome threat contribution).
local function onRoad(map, x, y)
    local roads = map and map.worldGen and map.worldGen.roads
    if not roads then
        return false
    end

    local roadOnDistance = 12
    local maxD2 = roadOnDistance * roadOnDistance
    for _, road in ipairs(roads) do
        local pts = road.points
        for i = 1, #pts - 1 do
            local a, b = pts[i], pts[i + 1]
            local dx, dy = b.x - a.x, b.y - a.y
            local len2 = dx * dx + dy * dy
            local t = 0
            if len2 > 0 then
                t = ((x - a.x) * dx + (y - a.y) * dy) / len2
                if t < 0 then t = 0 elseif t > 1 then t = 1 end
            end
            local cx, cy = a.x + dx * t, a.y + dy * t
            local qx, qy = x - cx, y - cy
            if qx * qx + qy * qy <= maxD2 then
                return true
            end
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

-- Compute the current threat value (0-100) from biome, time of day, the day
-- counter, and the player party's power.
function EncounterSystem.computeThreat()
    local map = GameContext.data.currentMap
    local playerParty = GameContext.data.playerParty
    if not map or not playerParty then
        return 0
    end

    local config = EncounterData.config or {}
    local px, py = PartySystem.getPosition(playerParty)

    -- 1. Biome contribution (roads halve it).
    local biomeId = map:getBiomeAt(px, py)
    local biomeThreat = (config.biomeThreat and config.biomeThreat[biomeId]) or 0
    if onRoad(map, px, py) then
        biomeThreat = biomeThreat * 0.5
    end

    -- 2. Time of day + day counter.
    local timeThreat = 0
    if TimeSystem.isNightTime() then
        timeThreat = timeThreat + (config.nightBonus or 20)
    end
    local hour = TimeSystem.getHour()
    local isEdgeOfDay = (hour >= 7 and hour < 9) or (hour >= 17 and hour < 20)
    if isEdgeOfDay then
        timeThreat = timeThreat + (config.dawnDuskBonus or 8)
    end
    local dayRamp = math.min(
        config.dayRampCap or 25,
        math.max(0, (TimeSystem.getDay() - 1) * (config.dayRamp or 1))
    )
    timeThreat = timeThreat + dayRamp

    -- 3. Player party power scaling.
    local powerThreat = partyPower() * (config.powerToThreat or 0.03)

    local threat = biomeThreat + timeThreat + powerThreat
    return math.max(0, math.min(100, threat))
end

-- Roll whether an encounter fires this step. Chance rises with threat and is
-- gated by the minimum distance between encounters.
function EncounterSystem.rollEncounter()
    local config = EncounterData.config or {}
    if not GameContext.data.playerParty then
        return false
    end

    local threat = EncounterSystem.computeThreat()
    local chance = (config.baseChance or 0.10) + threat * (config.chancePerThreat or 0.004)
    chance = math.max(0, math.min(1, chance))

    local minDist = config.minDistBetweenEncounters or 400
    if distanceSinceEncounter < minDist then
        return false
    end

    return math.random() < chance
end

-- Pick a weighted pool entry from the band that contains `threat`.
function EncounterSystem.pickTemplate(threat)
    threat = threat or EncounterSystem.computeThreat()

    for _, band in ipairs(EncounterData.bands or {}) do
        if threat >= (band.minThreat or 0) and threat <= (band.maxThreat or math.huge) then
            return weightedPick(band.pools or {})
        end
    end

    -- Fallback: the first pool of the highest band.
    local bands = EncounterData.bands or {}
    if #bands > 0 then
        local pools = bands[#bands].pools or {}
        if #pools > 0 then
            return pools[1]
        end
    end
    return nil
end

-- Build a hostile Party from a template and place it on the map near the
-- player. Returns the party, or nil when no valid spawn point was found (the
-- caller should simply wait for the next roll).
function EncounterSystem.spawnEncounterParty(template)
    local map = GameContext.data.currentMap
    local playerParty = GameContext.data.playerParty
    if not template or not map or not playerParty then
        return nil
    end

    local config = EncounterData.config or {}
    local px, py = PartySystem.getPosition(playerParty)
    local minLocationDist = config.minDistFromLocation or 200
    local minPartyDist = config.minDistFromParty or 120

    -- Try a handful of placements; keep the first valid one.
    for _ = 1, 8 do
        local dist = math.random(config.spawnMinDist or 90, config.spawnMaxDist or 140)
        local angle = math.random() * math.pi * 2
        local sx, sy = map:nearestWalkable(
            px + math.cos(angle) * dist,
            py + math.sin(angle) * dist
        )

        -- Reject spots too close to a settlement or to another party.
        local tooCloseToLocation = distanceToNearestLocation(map, sx, sy) < minLocationDist
        local blockedByParty = false
        for _, other in ipairs(map:getParties() or {}) do
            if other ~= playerParty then
                local dx = other.x - sx
                local dy = other.y - sy
                if dx * dx + dy * dy < minPartyDist * minPartyDist then
                    blockedByParty = true
                    break
                end
            end
        end

        if not tooCloseToLocation and not blockedByParty then
            local party = Party.create(EcsWorld.campaign, template.name or "Wild Encounter", nil)
            party.faction = template.faction or "neutral"
            party.hostile = template.hostile ~= false
            party.isEncounter = true
            party.dialogueId = template.dialogueId or "encounter_ambush"
            PartySystem.setPosition(party, sx, sy)

            -- Roam near the spawn point and chase once the player is spotted.
            party.state = "wander"
            party.wanderOriginX, party.wanderOriginY = sx, sy
            party.wanderRadius = PartyAiSystem.wanderRadiusDefault

            for _, spec in ipairs(template.enemies or {}) do
                local count = math.random(spec.min or 1, spec.max or 1)
                for _ = 1, count do
                    PartySystem.addActor(party, Unit.create(EcsWorld.campaign, spec.type))
                end
            end

            map:addParty(party)
            print(string.format(
                "Encounter spawned: %s (%d enemies) near (%d, %d)",
                party.name, #party.actors, math.floor(sx), math.floor(sy)
            ))
            return party
        end
    end

    return nil
end

-- Called by the world state every frame the party is moving. Accumulates the
-- distance traveled and rolls for a spawn once the step threshold is crossed.
function EncounterSystem.update(dt, distanceTraveled)
    distanceSinceEncounter = distanceSinceEncounter + (distanceTraveled or 0)
    travelAccumulator = travelAccumulator + (distanceTraveled or 0)

    local config = EncounterData.config or {}
    local stepDistance = config.stepDistance or 180
    if travelAccumulator >= stepDistance then
        travelAccumulator = travelAccumulator - stepDistance

        if EncounterSystem.rollEncounter() then
            local template = EncounterSystem.pickTemplate()
            if template then
                local party = EncounterSystem.spawnEncounterParty(template)
                if party then
                    EncounterSystem.recordSpawn()
                end
            end
        end
    end
end

-- Record that an encounter was spawned (resets the distance cooldown).
function EncounterSystem.recordSpawn()
    distanceSinceEncounter = 0
end

-- Clear the travel accumulators (e.g. when entering or leaving a safe area).
function EncounterSystem.reset()
    travelAccumulator = 0
    distanceSinceEncounter = 0
end

-- Remove a defeated encounter party from the map so its "corpse" doesn't
-- re-trigger a collision after battle. Non-encounter parties are untouched.
function EncounterSystem._onPartyKilled(partyId)
    local map = GameContext.data.currentMap
    if not map then
        return
    end

    for _, party in ipairs(map:getParties() or {}) do
        if party.id == partyId then
            if party.isEncounter then
                map:removeParty(partyId)
                EncounterSystem.reset()
                print("Encounter party defeated and removed: " .. tostring(partyId))
            end
            break
        end
    end
end

function EncounterSystem.init()
    EncounterSystem.reset()
    EventBus.subscribe("party_killed", EncounterSystem._onPartyKilled)
end

return EncounterSystem
