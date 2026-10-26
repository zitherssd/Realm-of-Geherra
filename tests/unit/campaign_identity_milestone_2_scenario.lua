local EcsWorld = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Location = require("src.ecs.assemblages.location")
local PartySystem = require("src.systems.party_system")
local LocationSystem = require("src.systems.location_system")
local Map = require("src.world.map")
local GameContext = require("src.game.game_context")
local QuestSystem = require("src.systems.quest_system")
local CampaignBattleResultApplier = require("src.systems.campaign_battle_result_applier")

local function assertEqual(actual, expected, message)
    assert(actual == expected,
        (message or "values differ") .. ": expected " .. tostring(expected) ..
        ", got " .. tostring(actual))
end

local function testAllocationNamespacesAndCompatibility()
    local world = EcsWorld.init()
    local actor = Unit.create(world, "soldier")
    local party = Party.create(world, "Generated Party")
    local location = Location.create(world, nil, "Generated Location")

    assertEqual(actor.id, "actor_1", "actor namespace did not allocate sequentially")
    assertEqual(party.id, "party_1", "party namespace did not start independently")
    assertEqual(location.id, "location_1", "location namespace did not allocate sequentially")

    local explicitActor = Unit.create(world, "soldier", "actor_101")
    local nextActor = Unit.create(world, "soldier")
    assertEqual(explicitActor.id, "actor_101", "explicit legacy actor ID changed")
    assertEqual(nextActor.id, "actor_102", "explicit actor ID did not advance its namespace")

    local staticLocation = Location.create(world, "settlement_01", "Legacy Settlement")
    assertEqual(staticLocation.id, "settlement_01", "static location ID changed")

    local independentCampaign = EcsWorld.init()
    assertEqual(Unit.create(independentCampaign, "soldier").id, "actor_1",
        "campaign allocator state leaked between campaigns")

    local collisionWorld = EcsWorld.init()
    Unit.create(collisionWorld, "soldier", "party_1")
    local collisionAvoidingParty = Party.create(collisionWorld, "Collision Avoidance")
    assertEqual(collisionAvoidingParty.id, "party_2",
        "allocation collided with an explicit ID from another entity type")
    local duplicateAccepted = pcall(Party.create, collisionWorld, "Duplicate", nil, "party_1")
    assertEqual(duplicateAccepted, false, "explicit ID collision was accepted")
end

local function testDeletionAndSafeLookup()
    local world = EcsWorld.init()
    local actor = Unit.create(world, "soldier")
    local party = Party.create(world, "Removable")
    local location = Location.create(world, nil, "Lookups")

    assertEqual(EcsWorld.findActorById(actor.id), actor, "actor lookup failed")
    assertEqual(EcsWorld.findPartyById(party.id), party, "party lookup failed")
    assertEqual(EcsWorld.findLocationById(location.id), location, "location lookup failed")
    GameContext.setPlayer(actor)
    GameContext.setPlayerParty(party)
    assertEqual(rawget(GameContext.data, "player"), nil,
        "game context stored a direct player pointer")
    assertEqual(rawget(GameContext.data, "playerParty"), nil,
        "game context stored a direct party pointer")
    assertEqual(GameContext.data.player, actor, "game context did not resolve player ID")
    assertEqual(GameContext.data.playerParty, party,
        "game context did not resolve player-party ID")

    actor:destroy()
    assertEqual(EcsWorld.findActorById(actor.id), nil,
        "pending actor deletion remained resolvable")
    assertEqual(GameContext.data.player, nil,
        "game context resolved a player after actor destruction")
    party:destroy()
    assertEqual(EcsWorld.findPartyById(party.id), nil,
        "pending party deletion remained resolvable")
    assertEqual(GameContext.data.playerParty, nil,
        "game context resolved a party after destruction")
    world:__flush()
    assertEqual(EcsWorld.findActorById(actor.id), nil, "removed actor was resolvable")
    assertEqual(EcsWorld.findPartyById(party.id), nil, "removed party was resolvable")

    local nextActor = Unit.create(world, "soldier")
    assertEqual(nextActor.id, "actor_2", "deleted actor ID was reused")
    local nextParty = Party.create(world, "After Removal")
    assertEqual(nextParty.id, "party_2", "deleted party ID was reused")
end

local function testAllocatorSerializationAndReconciliation()
    local world = EcsWorld.init()
    Unit.create(world, "soldier")
    Unit.create(world, "soldier")
    local state = EcsWorld.serializeIdAllocator(world)

    local restoredWorld = EcsWorld.init({idAllocatorState = state})
    assertEqual(Unit.create(restoredWorld, "soldier").id, "actor_3",
        "restored allocator did not continue its sequence")

    local collisionWorld = EcsWorld.init()
    Unit.create(collisionWorld, "soldier", "actor_101")
    EcsWorld.restoreIdAllocator(collisionWorld, {
        schemaVersion = 1,
        nextByNamespace = {},
        usedIds = {}
    })
    assertEqual(Unit.create(collisionWorld, "soldier").id, "actor_102",
        "restored allocator did not account for existing entities")

    local restoredUsedIds = EcsWorld.serializeIdAllocator(collisionWorld).usedIds
    local foundExisting = false
    for _, id in ipairs(restoredUsedIds) do
        if id == "actor_101" then foundExisting = true end
    end
    assertEqual(foundExisting, true, "existing IDs were omitted from allocator state")

    local deletedWorld = EcsWorld.init()
    local deletedActor = Unit.create(deletedWorld, "soldier")
    deletedActor:destroy()
    deletedWorld:__flush()
    local deletedState = EcsWorld.serializeIdAllocator(deletedWorld)
    local restoredDeletedWorld = EcsWorld.init({idAllocatorState = deletedState})
    assertEqual(Unit.create(restoredDeletedWorld, "soldier").id, "actor_2",
        "serialized allocator reused an ID after entity deletion")
end

local function testLocationActorIdentityAndQuestInstances()
    GameContext.init()
    local world = EcsWorld.init()
    local location = Location.create(world, nil, "Hearth")
    local leader = Unit.create(world, "elder")
    leader.dialogueId = "elder_greeting"
    local party = Party.create(world, "Stationed", leader.id)
    PartySystem.addActor(party, leader)
    local map = Map.new("identity-location-map")
    map:addLocation(location)

    assertEqual(map:stationParty(location, party), true, "party stationing failed")
    assertEqual(LocationSystem.getAvailableNpcs(location)[1], leader,
        "location did not resolve the original actor")
    assertEqual(EcsWorld.findActorById(leader.id), leader,
        "location actor identity did not resolve from the campaign")
    assertEqual(leader.dialogueId, "elder_greeting", "location dialogue identity changed")

    local firstQuestId = QuestSystem.activateQuest("retrieve_amulet", "Hearth Elder")
    local secondQuestId = QuestSystem.activateQuest("join_army", "Hearth Commander")
    assertEqual(firstQuestId, "quest_1", "quest instances did not use the campaign allocator")
    assertEqual(secondQuestId, "quest_2", "quest IDs were not allocated monotonically")
    assertEqual(EcsWorld.findQuestById(firstQuestId),
        QuestSystem.findQuestByInstanceId(firstQuestId), "quest safe lookup did not resolve instance")
    assertEqual(QuestSystem.findQuestByInstanceId("removed-quest"), nil,
        "missing quest lookup did not return nil")
    local firstQuest = EcsWorld.findQuestById(firstQuestId)
    firstQuest:destroy()
    assertEqual(EcsWorld.findQuestById(firstQuestId), nil,
        "destroyed quest remained resolvable")

    local offer = QuestSystem.generateProceduralQuestOffer(
        {id = leader.id, name = leader.name},
        {questPool = {"hunt_dogs"}}
    )
    assert(offer and offer.offerId == "quest_offer_1",
        "quest offers did not receive campaign-scoped IDs")
end

local function testBattleCasualtyKeepsCampaignActorIdentity()
    GameContext.init()
    local world = EcsWorld.init()
    local map = Map.new("identity-casualty-map")
    local fallen = Unit.create(world, "soldier")
    local survivor = Unit.create(world, "soldier")
    local opponent = Unit.create(world, "soldier")
    local partyA = Party.create(world, "A")
    local partyB = Party.create(world, "B")
    PartySystem.addActor(partyA, fallen)
    PartySystem.addActor(partyA, survivor)
    PartySystem.addActor(partyB, opponent)
    map:addParty(partyA)
    map:addParty(partyB)

    local result = {
        partyAId = partyA.id,
        partyBId = partyB.id,
        -- Partial casualties with survivors on both sides are a timeout, not victory.
        outcome = "timeout",
        actors = {
            [fallen.id] = {partyId = partyA.id, finalHp = 0, defeated = true},
            [survivor.id] = {partyId = partyA.id, finalHp = 25, defeated = false},
            [opponent.id] = {partyId = partyB.id, finalHp = 25, defeated = false}
        }
    }
    CampaignBattleResultApplier.apply(result, {
        map = map,
        encounter = {state = "completed", resultApplied = false}
    })

    assertEqual(#partyA.actors, 1, "battle casualty did not leave the party roster")
    assertEqual(partyA.actors[1], survivor, "battle casualty replaced survivor identity")
    assertEqual(EcsWorld.findActorById(survivor.id), survivor,
        "survivor could not be resolved after battle")
    assertEqual(EcsWorld.findActorById(fallen.id), fallen,
        "campaign actor identity was lost when removed from a roster")
    assertEqual(fallen.hp, 0, "retained casualty did not receive its final HP")
end

local Scenario = {}

function Scenario.run()
    testAllocationNamespacesAndCompatibility()
    testDeletionAndSafeLookup()
    testAllocatorSerializationAndReconciliation()
    testLocationActorIdentityAndQuestInstances()
    testBattleCasualtyKeepsCampaignActorIdentity()
end

return Scenario
