-- Owns active off-screen NPC battles for a campaign map.

local GameContext = require("src.game.game_context")
local EventBus = require("src.core.event_bus")
local HeadlessBattleRunner = require("src.systems.headless_battle_runner")
local CampaignBattleResultApplier = require("src.systems.campaign_battle_result_applier")
local LootResolver = require("src.systems.loot_resolver")
local LootApplication = require("src.systems.loot_application")
local TimeSystem = require("src.systems.time_system")

local WorldEncounterSystem = {
    combatTicksPerWorldHour = 200,
    reengagementCooldownHours = 1,
    maxCombatTicks = HeadlessBattleRunner.DEFAULT_MAX_TICKS
}

local function ensureMapState(map)
    map.activeEncounters = map.activeEncounters or {}
    map.partyEncounterCooldowns = map.partyEncounterCooldowns or {}
    map.nextEncounterSequence = map.nextEncounterSequence or 1
    map.battlefieldRemains = map.battlefieldRemains or {}
    map.nextBattlefieldRemainsSequence = map.nextBattlefieldRemainsSequence or 1
end

local function findParty(map, partyId)
    for _, party in ipairs(map:getParties() or {}) do
        if party.id == partyId then return party end
    end
    return nil
end

local function containsParty(map, expected)
    return findParty(map, expected.id) == expected
end

local function encounterIsActive(map, partyId)
    for _, encounter in pairs(map.activeEncounters) do
        if encounter.state == "active" and
            (encounter.partyAId == partyId or encounter.partyBId == partyId) then
            return true
        end
    end
    return false
end

local function validateTicksPerWorldHour(value)
    if type(value) ~= "number" or value ~= value or value == math.huge or
        value == -math.huge or value <= 0 then
        error("ticksPerWorldHour must be a finite positive number", 3)
    end
    return value
end

local function addCooldown(map, encounter)
    local duration = WorldEncounterSystem.reengagementCooldownHours
    if duration <= 0 then return end
    map.partyEncounterCooldowns[encounter.partyAId] = duration
    map.partyEncounterCooldowns[encounter.partyBId] = duration
end

local function releaseParties(encounter)
    if encounter.partyA.activeEncounterId == encounter.id then
        encounter.partyA.activeEncounterId = nil
    end
    if encounter.partyB.activeEncounterId == encounter.id then
        encounter.partyB.activeEncounterId = nil
    end
end

local function removeActiveEncounter(map, encounter)
    map.activeEncounters[encounter.id] = nil
end

local function cleanRunner(encounter)
    if encounter.runner then
        local runner = encounter.runner
        encounter.runner = nil
        runner:cleanup()
    end
end

local function publishActivityEvent(eventName, encounter, outcome, winnerPartyId)
    if not encounter.activitySourceId then return end
    local sourceParty = encounter.partyAId == encounter.activitySourceId
        and encounter.partyA or encounter.partyB
    EventBus.emit(eventName, {
        mapId = encounter.mapId,
        activityType = encounter.activityType,
        sourcePartyId = encounter.activitySourceId,
        sourceParty = sourceParty,
        targetPartyId = encounter.targetPartyId,
        encounterId = encounter.id,
        outcome = outcome,
        winnerPartyId = winnerPartyId
    })
end

local function failEncounter(map, encounter, message)
    encounter.state = "failed"
    encounter.error = tostring(message)
    addCooldown(map, encounter)
    removeActiveEncounter(map, encounter)
    releaseParties(encounter)

    local ok, cleanupError = pcall(cleanRunner, encounter)
    if not ok then
        encounter.cleanupError = tostring(cleanupError)
    end
    publishActivityEvent("party_encounter_finished", encounter, "error", nil)
    error("World encounter " .. encounter.id .. " failed: " .. encounter.error, 0)
end

local function updateCooldowns(map, elapsedWorldHours)
    for partyId, remaining in pairs(map.partyEncounterCooldowns) do
        remaining = remaining - elapsedWorldHours
        if remaining <= 0 then
            map.partyEncounterCooldowns[partyId] = nil
        else
            map.partyEncounterCooldowns[partyId] = remaining
        end
    end
end

local function finishEncounter(map, encounter, result)
    local lootResult = LootResolver.resolve(
        encounter.partyA,
        encounter.partyB,
        result,
        encounter.lootPolicy
    )
    local lootPlan = LootApplication.prepare(lootResult, {
        map = map,
        encounter = encounter,
        battleResult = result,
        worldTime = {
            day = TimeSystem.getDay(),
            hour = TimeSystem.getHour()
        }
    })
    local campaignContext = {
        map = map,
        encounter = encounter.runner
    }
    CampaignBattleResultApplier.validate(result, campaignContext)

    LootApplication.apply(lootPlan)
    CampaignBattleResultApplier.apply(result, {
        map = map,
        encounter = encounter.runner
    })
    encounter.result = result
    encounter.lootResult = lootResult
    encounter.outcome = result.outcome
    encounter.resultApplied = true
    encounter.state = "completed"
    addCooldown(map, encounter)
    removeActiveEncounter(map, encounter)
    releaseParties(encounter)
    local casualties = 0
    for _, actorResult in pairs(result.actors) do
        if actorResult.defeated then casualties = casualties + 1 end
    end
    print(string.format(
        "[WorldEncounter] %s completed: outcome=%s winner=%s casualties=%d duration=%.3f world-hours ticks=%d",
        encounter.id,
        result.outcome,
        tostring(result.winnerPartyId or "none"),
        casualties,
        encounter.elapsedWorldHours,
        result.ticks
    ))
    publishActivityEvent("party_encounter_finished", encounter, result.outcome, result.winnerPartyId)
    cleanRunner(encounter)
end

local function advanceEncounter(map, encounter, elapsedWorldHours)
    if not containsParty(map, encounter.partyA) or not containsParty(map, encounter.partyB) then
        error("A participating party is no longer on the campaign map", 2)
    end

    encounter.elapsedWorldHours = encounter.elapsedWorldHours + elapsedWorldHours
    encounter.tickAccumulator = encounter.tickAccumulator +
        elapsedWorldHours * encounter.ticksPerWorldHour
    local ticksToAdvance = math.floor(encounter.tickAccumulator + 1e-9)
    if ticksToAdvance > 0 then
        encounter.tickAccumulator = encounter.tickAccumulator - ticksToAdvance
    end

    local result = encounter.runner:advance(ticksToAdvance)
    if result then
        finishEncounter(map, encounter, result)
    end
end

function WorldEncounterSystem.isPartyReserved(party)
    return party ~= nil and party.activeEncounterId ~= nil
end

function WorldEncounterSystem.getInspectionData(map, encounterId)
    if not map then return nil end
    ensureMapState(map)
    local encounter = map.activeEncounters[encounterId]
    if not encounter or encounter.state ~= "active" or not encounter.runner or
        not encounter.runner.simulation then
        return nil
    end

    local context = encounter.runner.simulation.context
    local survivors = {player = 0, enemy = 0}
    for _, unit in ipairs(context.data.unitList or {}) do
        if unit.hp > 0 then
            survivors[unit.team] = (survivors[unit.team] or 0) + 1
        end
    end

    return {
        id = encounter.id,
        status = encounter.state,
        partyAName = encounter.partyA.name or tostring(encounter.partyAId),
        partyBName = encounter.partyB.name or tostring(encounter.partyBId),
        elapsedWorldHours = encounter.elapsedWorldHours,
        survivingPartyA = survivors.player or 0,
        survivingPartyB = survivors.enemy or 0,
        tick = context.data.tick
    }
end

local function rejectContact(event, reason)
    EventBus.emit("party_encounter_rejected", {
        mapId = event.mapId,
        activityType = event.activityType,
        sourcePartyId = event.sourcePartyId,
        targetPartyId = event.targetPartyId,
        reason = reason
    })
    return false, reason
end

function WorldEncounterSystem.request(map, sourcePartyId, targetPartyId, activityType, lootPolicy)
    if type(map) ~= "table" or type(map.getParties) ~= "function" then
        return false, "map_unavailable"
    end
    local sourceParty = findParty(map, sourcePartyId)
    local targetParty = findParty(map, targetPartyId)
    if not sourceParty or not targetParty then
        return false, "party_missing"
    end
    if sourceParty == targetParty or sourceParty.id == targetParty.id then
        return false, "same_party"
    end
    if sourceParty == GameContext.data.playerParty or targetParty == GameContext.data.playerParty then
        return false, "player_party_not_allowed"
    end
    if not sourceParty.actors or #sourceParty.actors == 0 or
        not targetParty.actors or #targetParty.actors == 0 then
        return false, "party_empty"
    end

    local activity = sourceParty.world_activity
    if not activity or activity.type ~= activityType or activity.status ~= "active" or
        activity.phase ~= "contact" or activity.targetId ~= targetParty.id then
        return false, "contact_stale"
    end

    return WorldEncounterSystem.start(map, sourceParty, targetParty, {
        maxTicks = WorldEncounterSystem.maxCombatTicks,
        ticksPerWorldHour = WorldEncounterSystem.combatTicksPerWorldHour,
        activitySourceId = sourceParty.id,
        activityType = activityType,
        targetPartyId = targetParty.id,
        lootPolicy = lootPolicy
    })
end

function WorldEncounterSystem._onPartyContact(event)
    if type(event) ~= "table" then return end
    local playerParty = GameContext.data and GameContext.data.playerParty
    if playerParty and event.targetPartyId == playerParty.id then
        return
    end

    local map = GameContext.data and GameContext.data.currentMap
    if not map or map.id ~= event.mapId then
        rejectContact(event, "map_unavailable")
        return
    end

    local ok, started, encounterOrReason = pcall(
        WorldEncounterSystem.request,
        map,
        event.sourcePartyId,
        event.targetPartyId,
        event.activityType,
        event.lootPolicy
    )
    if not ok then
        rejectContact(event, "encounter_start_failed")
        error(started, 0)
    end
    if not started then
        rejectContact(event, encounterOrReason)
        return
    end

    EventBus.emit("party_encounter_started", {
        mapId = map.id,
        activityType = event.activityType,
        sourcePartyId = event.sourcePartyId,
        targetPartyId = event.targetPartyId,
        encounterId = encounterOrReason.id
    })
end

function WorldEncounterSystem.init()
    EventBus.unsubscribe("party_contact", WorldEncounterSystem._onPartyContact)
    EventBus.subscribe("party_contact", WorldEncounterSystem._onPartyContact)
end

function WorldEncounterSystem.start(map, partyA, partyB, options)
    if type(map) ~= "table" or type(map.getParties) ~= "function" then
        error("WorldEncounterSystem.start requires a campaign map", 2)
    end
    if type(options) ~= "table" and options ~= nil then
        error("World encounter options must be a table", 2)
    end
    options = options or {}
    ensureMapState(map)
    local lootPolicy = options.lootPolicy or {plunderAllowed = false}
    if type(lootPolicy) ~= "table" or type(lootPolicy.plunderAllowed) ~= "boolean" then
        error("World encounter loot policy must explicitly set plunderAllowed", 2)
    end
    local stolenProportion = lootPolicy.stolenProportion or LootResolver.DEFAULT_STOLEN_PROPORTION
    local destroyedProportion = lootPolicy.destroyedProportion or LootResolver.DEFAULT_DESTROYED_PROPORTION
    if type(stolenProportion) ~= "number" or stolenProportion < 0 or stolenProportion > 1 or
        type(destroyedProportion) ~= "number" or destroyedProportion < 0 or destroyedProportion > 1 or
        stolenProportion ~= stolenProportion or destroyedProportion ~= destroyedProportion or
        stolenProportion == math.huge or destroyedProportion == math.huge or
        stolenProportion + destroyedProportion > 1 then
        error("World encounter loot proportions must be between 0 and 1 and total at most 1", 2)
    end
    lootPolicy = {
        plunderAllowed = lootPolicy.plunderAllowed,
        stolenProportion = stolenProportion,
        destroyedProportion = destroyedProportion
    }

    if type(partyA) ~= "table" or type(partyB) ~= "table" then
        error("World encounters require two campaign parties", 2)
    end
    if partyA == partyB or partyA.id == partyB.id then
        return false, "same_party"
    end
    if partyA == GameContext.data.playerParty or partyB == GameContext.data.playerParty or
        partyA == options.playerParty or partyB == options.playerParty then
        return false, "player_party_not_allowed"
    end
    if not containsParty(map, partyA) or not containsParty(map, partyB) then
        return false, "party_not_on_map"
    end
    if partyA.activeEncounterId or partyB.activeEncounterId or
        encounterIsActive(map, partyA.id) or encounterIsActive(map, partyB.id) then
        return false, "party_already_engaged"
    end
    if (map.partyEncounterCooldowns[partyA.id] or 0) > 0 or
        (map.partyEncounterCooldowns[partyB.id] or 0) > 0 then
        return false, "party_cooldown"
    end

    local ticksPerWorldHour = validateTicksPerWorldHour(
        options.ticksPerWorldHour or WorldEncounterSystem.combatTicksPerWorldHour
    )
    local runner = HeadlessBattleRunner.start(partyA, partyB, options)
    local sequence = map.nextEncounterSequence
    map.nextEncounterSequence = sequence + 1
    local encounterId = tostring(map.id or "map") .. ":encounter:" .. tostring(sequence)
    local encounter = {
        id = encounterId,
        partyAId = partyA.id,
        partyBId = partyB.id,
        partyA = partyA,
        partyB = partyB,
        state = "active",
        elapsedWorldHours = 0,
        ticksPerWorldHour = ticksPerWorldHour,
        tickAccumulator = 0,
        runner = runner,
        result = nil,
        resultApplied = false,
        mapId = map.id,
        activitySourceId = options.activitySourceId,
        activityType = options.activityType,
        targetPartyId = options.targetPartyId,
        lootPolicy = lootPolicy,
        x = (partyA.x + partyB.x) / 2,
        y = (partyA.y + partyB.y) / 2,
        lootApplied = false,
        remainsCreated = false
    }

    partyA.activeEncounterId = encounterId
    partyB.activeEncounterId = encounterId
    map.activeEncounters[encounterId] = encounter
    print(string.format(
        "[WorldEncounter] %s started: %s vs %s",
        encounterId,
        tostring(partyA.name or partyA.id),
        tostring(partyB.name or partyB.id)
    ))
    return true, encounter
end

function WorldEncounterSystem.update(elapsedWorldHours, map)
    if not map then return end
    if type(elapsedWorldHours) ~= "number" or elapsedWorldHours ~= elapsedWorldHours or
        elapsedWorldHours == math.huge or elapsedWorldHours == -math.huge or
        elapsedWorldHours < 0 then
        error("Elapsed world time must be a finite non-negative number", 2)
    end

    ensureMapState(map)
    updateCooldowns(map, elapsedWorldHours)

    local encounterIds = {}
    for encounterId in pairs(map.activeEncounters) do
        encounterIds[#encounterIds + 1] = encounterId
    end
    table.sort(encounterIds)

    for _, encounterId in ipairs(encounterIds) do
        local encounter = map.activeEncounters[encounterId]
        if encounter and encounter.state == "active" then
            local ok, err = xpcall(function()
                advanceEncounter(map, encounter, elapsedWorldHours)
            end, debug.traceback)
            if not ok then
                failEncounter(map, encounter, err)
            end
        end
    end
end

return WorldEncounterSystem
