-- Campaign consequences of a terminal battle; simulation and presentation stay outside.
local ResultApplier = require("src.systems.campaign.campaign_battle_result_applier")
local LootResolver = require("src.systems.items.loot_resolver")
local LootApplication = require("src.systems.items.loot_application")
local LootGenerator = require("src.systems.items.loot_generator_system")
local PartySystem = require("src.systems.parties.party_system")
local PlayerSystem = require("src.systems.actors.player_system")
local WorldEvents = require("src.systems.campaign.world_events")
local BattleKnowledge = require("src.systems.knowledge.battle_knowledge_system")
local TimeSystem = require("src.systems.campaign.time_system")

local CampaignBattleResolution = {}

local function computePartyPower(party)
    local power = 0
    for _, actor in ipairs(party.actors) do
        local stats = actor.stats or {}
        local hp = actor.maxHp or stats.health or 50
        power = power + hp + (stats.attack or 10) * 2 + (stats.defense or 10) * 2
    end
    return power
end

function CampaignBattleResolution.resolve(result, context)
    local encounter = context.encounter
    if encounter.resolution then return encounter.resolution end
    -- Notifications can reenter while casualties are being applied.
    if encounter.resolving then return nil end
    assert(context.rewardPolicy == "player" or context.rewardPolicy == "npc",
        "Campaign battle resolution requires an explicit player or npc reward policy")
    assert(result.partyAId == encounter.partyAId and result.partyBId == encounter.partyBId,
        "Battle result does not match the owning encounter")
    local campaignContext = {map = context.map, encounter = encounter, parties = context.parties}
    ResultApplier.validate(result, campaignContext)

    local parties = context.parties
    if not parties then
        local byId = {}
        for _, party in ipairs(context.map:getParties()) do byId[party.id] = party end
        parties = {byId[result.partyAId], byId[result.partyBId]}
    end
    local partyA, partyB = parties[1], parties[2]
    assert(partyA.id == result.partyAId and partyB.id == result.partyBId,
        "Battle participants must be supplied in result order")
    local world = partyA:getWorld()
    local time = {day = TimeSystem.getDay(), hour = TimeSystem.getHour()}
    local eventData = {
        time = time, encounterId = encounter.id,
        mapId = context.map and context.map.id, x = encounter.x, y = encounter.y,
        outcome = result.outcome, winnerPartyId = result.winnerPartyId,
        defeatedPartyIds = result.loserPartyId and {result.loserPartyId} or {},
        participants = {}, subjectIds = {}, ticks = result.ticks
    }
    local survivors = {}
    local rewards = {playerCasualties = {}, enemyCasualties = {}, loot = {}, gold = 0, favor = 0}
    for index, party in ipairs(parties) do
        local participant = {partyId = party.id, name = party.name or tostring(party.id),
            actorIds = {}, casualties = 0}
        eventData.subjectIds[#eventData.subjectIds + 1] = party.id
        for _, actor in ipairs(party.actors) do
            participant.actorIds[#participant.actorIds + 1] = actor.id
            eventData.subjectIds[#eventData.subjectIds + 1] = actor.id
            if result.actors[actor.id].defeated then
                participant.casualties = participant.casualties + 1
                local names = index == 1 and rewards.playerCasualties or rewards.enemyCasualties
                names[#names + 1] = actor.name or "Unknown Unit"
            else
                survivors[actor.id] = true
            end
        end
        eventData.participants[#eventData.participants + 1] = participant
    end

    local lootResult, lootPlan, enemyPower
    if context.rewardPolicy == "npc" then
        lootResult = LootResolver.resolve(partyA, partyB, result, encounter.lootPolicy)
        lootPlan = LootApplication.prepare(lootResult, {
            map = context.map, encounter = encounter, battleResult = result, worldTime = time
        })
    else
        enemyPower = computePartyPower(partyB)
    end

    -- Failures after mutation must not be retried against partially changed rosters/resources.
    encounter.resolving = true
    if lootPlan then
        LootApplication.apply(lootPlan)
    else
        for _, actor in ipairs(partyB.actors) do
            if result.actors[actor.id].defeated and actor.troopType then
                local _, gold = LootGenerator.generateFromTroop(actor.troopType, rewards.loot)
                rewards.gold = rewards.gold + (gold or 0)
            end
        end
    end
    local applied = ResultApplier.apply(result, campaignContext)
    if context.rewardPolicy == "player" and result.winnerPartyId == partyA.id then
        if rewards.gold > 0 then PartySystem.addTreasury(partyA, rewards.gold) end
        rewards.favor = math.floor(4 + enemyPower / math.max(1, computePartyPower(partyA)) * 8)
        PlayerSystem.addFavor(rewards.favor)
    end

    eventData.eliminatedPartyIds = applied.eliminatedPartyIds
    eventData.battlefieldId = lootPlan and lootPlan.remainsSite and lootPlan.remainsSite.id
    if eventData.battlefieldId then
        eventData.subjectIds[#eventData.subjectIds + 1] = eventData.battlefieldId
    end
    if eventData.mapId then eventData.subjectIds[#eventData.subjectIds + 1] = eventData.mapId end
    local event = WorldEvents.record(world, "battle_ended", eventData, "battle_ended:" .. encounter.id)
    BattleKnowledge.learnParticipants(world, event, survivors)
    if lootPlan and lootPlan.remainsSite then lootPlan.remainsSite.history.eventId = event.id end
    encounter.result = result
    encounter.lootResult = lootResult
    encounter.outcome = result.outcome
    encounter.eventId = event.id
    encounter.resolution = {event = event, rewards = rewards, eliminatedPartyIds = applied.eliminatedPartyIds}
    encounter.resolving = nil
    return encounter.resolution
end

return CampaignBattleResolution
