local Map = require("src.world.map")
local VisibilitySystem = require("src.systems.visibility_system")
local BattlefieldRemainsSystem = require("src.systems.battlefield_remains_system")
local BattlefieldInteraction = require("src.systems.battlefield_interaction")
local BattlefieldResourceCollection = require("src.systems.battlefield_resource_collection")
local DialogueData = require("src.data.dialogue")
local DialogueState = require("src.game.states.dialogue_state")
local GameContext = require("src.game.game_context")
local StateManager = require("src.core.state_manager")
local UIManager = require("src.ui.ui_manager")
local TimeSystem = require("src.systems.time_system")
local LocationScreen = require("src.ui.screens.location_screen")

local function makeSite(id, x, y, discovered)
    return {
        id = id,
        discovered = discovered or false,
        currentlyVisible = false,
        profile = 0,
        loot = {
            items = {{id = "sealed_crate", quantity = 2, metadata = {grade = "rare"}}},
            gold = 12
        },
        corpses = {{
            actorId = "fallen-guard",
            name = "Mira",
            unitTypeId = "guard",
            species = "human",
            race = "riverfolk",
            faction = "watch",
            deathTime = {day = 3, hour = 6}
        }},
        history = {
            encounterId = "encounter-" .. id,
            position = {x = x, y = y},
            participants = {
                {partyId = "watch", name = "Watch patrol"},
                {partyId = "raiders", name = "Road raiders"}
            },
            victorPartyId = "raiders",
            worldTime = {day = 3, hour = 6}
        }
    }
end

local function findOption(dialogue, action)
    for _, option in ipairs(dialogue.lines[1].options or {}) do
        if option.action == action then return option end
    end
    return nil
end

local function testVisibilityAndRememberedDiscovery()
    local map = Map.new("battlefield-visibility")
    local visibleSite = makeSite("visible", 8, 0)
    local hiddenSite = makeSite("hidden", 12, 0)
    map:addBattlefieldRemains(visibleSite)
    map:addBattlefieldRemains(hiddenSite)
    local playerParty = {id = "player", x = 0, y = 0, actors = {{sight = 40}}}

    VisibilitySystem.update(playerParty, map)
    assert(visibleSite.currentlyVisible and visibleSite.discovered,
        "site inside the existing sight radius was not discovered")
    assert(not hiddenSite.currentlyVisible and not hiddenSite.discovered,
        "site outside the existing sight radius was discovered")

    playerParty.x = 100
    VisibilitySystem.update(playerParty, map)
    assert(not visibleSite.currentlyVisible and visibleSite.discovered,
        "discovery was not remembered after current visibility was lost")
    assert(not hiddenSite.currentlyVisible and not hiddenSite.discovered,
        "unseen site became remembered without detection")
end

local function testDialogueContentAndConditionalOptions()
    local map = Map.new("battlefield-dialogue")
    local site = makeSite("dialogue-site", 10, 20)
    map:addBattlefieldRemains(site)

    local dialogue = BattlefieldInteraction.buildDialogue(map, site.id)
    assert(findOption(dialogue, "battlefield_inspect"),
        "battlefield dialogue omitted Inspect")
    assert(findOption(dialogue, "battlefield_collect"),
        "battlefield dialogue omitted conditional supply action")
    local corpseOptions = 0
    for _, option in ipairs(dialogue.lines[1].options) do
        if option.action == "battlefield_unavailable" and
            (option.unavailableAction == "corpse_loot" or option.unavailableAction == "bury") then
            corpseOptions = corpseOptions + 1
        end
    end
    assert(corpseOptions == 2, "corpse actions were not conditional on corpses")
    assert(dialogue.lines[1].text:find("Watch patrol versus Road raiders", 1, true) and
        dialogue.lines[1].text:find("12 gold", 1, true),
        "overview did not describe stored participants and gold")

    local inspect = BattlefieldInteraction.buildInspectDialogue(map, site.id)
    local inspectLines = {}
    for _, line in ipairs(inspect.lines) do
        inspectLines[#inspectLines + 1] = line.text
    end
    local inspectText = table.concat(inspectLines, "\n")
    for _, expected in ipairs({
        "encounter-dialogue-site", "Watch patrol", "Road raiders", "Mira",
        "riverfolk", "sealed_crate x2", "Gold: 12", "day 3"
    }) do
        assert(inspectText:find(expected, 1, true),
            "Inspect omitted stored battlefield detail: " .. expected)
    end

    site.loot.items = {}
    site.loot.gold = 0
    site.corpses = {}
    local emptyDialogue = BattlefieldInteraction.buildDialogue(map, site.id)
    assert(not findOption(emptyDialogue, "battlefield_collect"),
        "empty site displayed Search for Supplies")
    assert(#emptyDialogue.lines[1].options == 2,
        "empty site should only offer Inspect and Leave")

    local unchangedItemCount = #site.loot.items
    local unavailable = BattlefieldInteraction.buildUnavailableDialogue(map, site.id, "bury")
    assert(unavailable.lines[1].text:find("not implemented", 1, true) and
        #site.loot.items == unchangedItemCount,
        "placeholder action implied success or changed remains")
end

local function testMultipleSitesRemovalAndSerialization()
    local map = Map.new("battlefield-persistence")
    local first = makeSite("first", 5, 6, true)
    local second = makeSite("second", 50, 60, true)
    second.currentlyVisible = true
    map:addBattlefieldRemains(first)
    map:addBattlefieldRemains(second)

    assert(BattlefieldInteraction.findSite(map, first.id) == first and
        BattlefieldInteraction.findSite(map, second.id) == second,
        "multiple battlefield sites were not independently addressable")

    local data = BattlefieldRemainsSystem.serialize(map)
    assert(data.sites[1].discovered and data.sites[2].discovered,
        "remembered discovery was not serialized")
    assert(not data.sites[2].currentlyVisible,
        "transient visibility was serialized as current")
    local restored = Map.new("battlefield-persistence")
    BattlefieldRemainsSystem.restore(restored, data)
    local restoredFirst = BattlefieldInteraction.findSite(restored, first.id)
    local restoredSecond = BattlefieldInteraction.findSite(restored, second.id)
    assert(restoredFirst and restoredSecond and restoredFirst.discovered and
        restoredSecond.discovered and not restoredSecond.currentlyVisible,
        "site discovery did not survive restore or transient visibility was not reset")

    assert(restored:removeBattlefieldRemains(first.id),
        "map could not remove a battlefield site")
    assert(not BattlefieldInteraction.findSite(restored, first.id),
        "removed site remained addressable")
    local staleDialogue = BattlefieldInteraction.buildInspectDialogue(restored, first.id)
    assert(staleDialogue.lines[1].text:find("no longer present", 1, true),
        "removed site was not handled safely by dialogue")
end

local function testOrdinaryDialogueRegistryRemainsAvailable()
    assert(DialogueData.npc_greeting and DialogueData.bandit_start,
        "ordinary NPC dialogue data was affected")

    local npc = {id = "ordinary-location-npc", name = "Local", dialogueId = "npc_greeting"}
    local location = {
        id = "ordinary-location",
        name = "Old Ruin",
        type = "ruins",
        npcs = {npc},
        shops = {},
        quests = {}
    }
    local locationScreen = LocationScreen.new(location, function() end)
    local routedParams
    local originalPush = StateManager.push
    StateManager.push = function(stateName, params)
        assert(stateName == "dialogue")
        routedParams = params
    end
    locationScreen.buttons[1].callback()
    StateManager.push = originalPush
    assert(routedParams and routedParams.dialogueId == "npc_greeting" and
        routedParams.target == npc,
        "ordinary location NPC dialogue routing changed")
end

local function makePlayerParty()
    return {
        id = "player-party",
        inventory = {
            {id = "healing_herb", quantity = 1, metadata = {quality = "common"}}
        },
        treasury = 5
    }
end

local function testCollectCargoGoldAndIdempotence()
    local map = Map.new("battlefield-collection")
    local site = makeSite("collection-site", 0, 0)
    site.discovered = true
    site.loot.items = {
        {id = "healing_herb", quantity = 3, metadata = {quality = "rare", seal = {intact = true}}},
        {id = "healing_herb", quantity = 2, metadata = {quality = "common"}}
    }
    site.loot.gold = 17
    map:addBattlefieldRemains(site)
    local party = makePlayerParty()
    local partyInventory = party.inventory
    local corpses = site.corpses
    local sourceItems = site.loot.items

    local wasPaused = TimeSystem.isPaused()
    TimeSystem.setPaused(true)
    local beforeDay, beforeHour = TimeSystem.getDay(), TimeSystem.getHour()
    local result = BattlefieldInteraction.collectSupplies(map, site.id, party)
    assert(result.success and result.collected and #result.items == 2 and result.gold == 17,
        "collection did not return all abandoned resources")
    assert(#party.inventory == 3 and party.treasury == 22,
        "cargo or gold was not fully transferred")
    assert(party.inventory == partyInventory, "collection replaced the inventory table")
    assert(party.inventory[2].id == party.inventory[3].id and
        party.inventory[2].quantity == 3 and party.inventory[3].quantity == 2,
        "same-ID cargo stacks were merged")
    assert(party.inventory[2].metadata.quality == "rare" and
        party.inventory[2].metadata.seal.intact and
        party.inventory[3].metadata.quality == "common",
        "item metadata or variant identity was lost")
    assert(party.inventory[2] ~= sourceItems[1] and
        party.inventory[2].metadata ~= sourceItems[1].metadata,
        "collected items retained references to battlefield resources")
    assert(#site.loot.items == 0 and site.loot.gold == 0 and site.corpses == corpses,
        "collection did not clear only cargo and gold")
    assert(TimeSystem.getDay() == beforeDay and TimeSystem.getHour() == beforeHour and
        TimeSystem.isPaused(), "collection advanced or unpaused world time")

    local repeated = BattlefieldResourceCollection.collect(map, site.id, party)
    assert(repeated.success and not repeated.collected and #party.inventory == 3 and
        party.treasury == 22, "repeated collection duplicated resources")
    local resultDialogue = BattlefieldInteraction.buildCollectionDialogue(result)
    local resultText = {}
    for _, line in ipairs(resultDialogue.lines) do
        resultText[#resultText + 1] = line.text
    end
    local joined = table.concat(resultText, "\n")
    assert(joined:find("healing_herb x3", 1, true) and
        joined:find("healing_herb x2", 1, true) and joined:find("17 gold", 1, true),
        "collection feedback did not describe recovered items and gold")
    local refreshed = BattlefieldInteraction.buildDialogue(map, site.id)
    assert(not findOption(refreshed, "battlefield_collect") and
        findOption(refreshed, "battlefield_inspect"),
        "options were not refreshed after collection")
    assert(#site.corpses > 0 and findOption(refreshed, "battlefield_unavailable"),
        "site or corpse interactions disappeared after supply collection")
    TimeSystem.setPaused(wasPaused)
end

local function testGoldOnlyItemOnlyAndEmptySites()
    local map = Map.new("battlefield-collection-cases")
    local goldOnly = makeSite("gold-only", 0, 0)
    goldOnly.discovered = true
    goldOnly.loot.items = {}
    goldOnly.loot.gold = 7
    local itemOnly = makeSite("item-only", 1, 1)
    itemOnly.discovered = true
    itemOnly.loot.items = {{id = "bandage", quantity = 4, metadata = {clean = true}}}
    itemOnly.loot.gold = 0
    local empty = makeSite("empty", 2, 2)
    empty.discovered = true
    empty.loot.items = {}
    empty.loot.gold = 0
    map:addBattlefieldRemains(goldOnly)
    map:addBattlefieldRemains(itemOnly)
    map:addBattlefieldRemains(empty)
    local party = makePlayerParty()

    local goldResult = BattlefieldResourceCollection.collect(map, goldOnly.id, party)
    assert(goldResult.gold == 7 and #goldResult.items == 0 and party.treasury == 12,
        "gold-only supplies were not collected")
    local itemResult = BattlefieldResourceCollection.collect(map, itemOnly.id, party)
    assert(itemResult.gold == 0 and #itemResult.items == 1 and
        party.inventory[#party.inventory].id == "bandage" and
        party.inventory[#party.inventory].quantity == 4,
        "item-only supplies were not collected")
    local inventoryCount = #party.inventory
    local emptyResult = BattlefieldResourceCollection.collect(map, empty.id, party)
    assert(emptyResult.success and not emptyResult.collected and emptyResult.gold == 0 and
        #party.inventory == inventoryCount and party.treasury == 12,
        "empty battlefield collection changed player resources")
    assert(not findOption(BattlefieldInteraction.buildDialogue(map, empty.id), "battlefield_collect"),
        "empty battlefield offered collection")
end

local function testInvalidCollectionDoesNotPartiallyMutate()
    local map = Map.new("battlefield-invalid-collection")
    local site = makeSite("invalid-site", 0, 0)
    site.discovered = true
    site.loot.items = {
        {id = "valid-item", quantity = 1},
        {id = "invalid-item", quantity = 1, metadata = {callback = function() end}}
    }
    map:addBattlefieldRemains(site)
    local party = makePlayerParty()
    local inventory = party.inventory
    local initialGold = party.treasury
    local ok = pcall(function()
        BattlefieldResourceCollection.collect(map, site.id, party)
    end)
    assert(not ok and party.inventory == inventory and party.treasury == initialGold and
        #site.loot.items == 2 and site.loot.gold == 12,
        "invalid resources caused a partial collection")

    local missing = BattlefieldResourceCollection.collect(map, "removed-site", party)
    assert(not missing.success and #party.inventory == 1 and party.treasury == initialGold,
        "removed site collection was not safely rejected")
end

local function testExistingDialogueInterface()
    local map = Map.new("battlefield-dialogue-ui")
    local site = makeSite("ui-site", 0, 0)
    map:addBattlefieldRemains(site)
    local previousMap = GameContext.data.currentMap
    GameContext.data.currentMap = map

    UIManager.init()
    DialogueState.enter({battlefieldSiteId = site.id})
    local screen = UIManager.getActiveScreen()
    assert(screen and screen.dialogueTree.speaker == "Battlefield" and
        findOption(screen.dialogueTree, "battlefield_inspect"),
        "battlefield interaction did not use the existing dialogue screen")

    local swapParameters
    local originalSwap = StateManager.swap
    StateManager.swap = function(stateName, params)
        assert(stateName == "dialogue")
        swapParameters = params
    end
    local ok, err = xpcall(function()
        screen.onChoice(findOption(screen.dialogueTree, "battlefield_inspect"))
    end, debug.traceback)
    StateManager.swap = originalSwap
    DialogueState.exit()
    GameContext.data.currentMap = previousMap
    if not ok then error(err, 0) end

    assert(swapParameters and swapParameters.battlefieldSiteId == site.id and
        swapParameters.battlefieldView == "inspect",
        "Inspect choice did not route through the existing dialogue state")

    DialogueState.enter({dialogueId = "npc_greeting"})
    local ordinaryScreen = UIManager.getActiveScreen()
    assert(ordinaryScreen and ordinaryScreen.dialogueTree.speaker == "Local" and
        ordinaryScreen:currentLine().text == "No task waits for you now.",
        "ordinary NPC dialogue no longer uses the expected dialogue flow")
    DialogueState.exit()
    GameContext.data.currentMap = previousMap
end

local function testSearchDialogueActionAndUpdatedOptions()
    local map = Map.new("battlefield-search-dialogue")
    local site = makeSite("search-dialogue-site", 0, 0)
    site.discovered = true
    site.loot.items = {{id = "travel_ration", quantity = 2}}
    site.loot.gold = 3
    map:addBattlefieldRemains(site)
    local previousMap = GameContext.data.currentMap
    local previousParty = GameContext.data.playerParty
    -- Dialogue resolves the player party through its persistent campaign ID.
    local EcsWorld = require("src.ecs.world")
    local Party = require("src.ecs.assemblages.party")
    local party = Party.create(EcsWorld.campaign or EcsWorld.init(), "Supply collectors")
    local resources = makePlayerParty()
    party.inventory, party.treasury = resources.inventory, resources.treasury
    GameContext.data.currentMap = map
    GameContext.data.playerParty = party
    UIManager.init()

    local originalSwap = StateManager.swap
    local swapParameters
    StateManager.swap = function(stateName, params)
        assert(stateName == "dialogue")
        swapParameters = params
    end
    local ok, err = xpcall(function()
        DialogueState.enter({battlefieldSiteId = site.id})
        local screen = UIManager.getActiveScreen()
        assert(findOption(screen.dialogueTree, "battlefield_collect"),
            "dialogue omitted Search for Supplies")
        screen.onChoice(findOption(screen.dialogueTree, "battlefield_collect"))
        assert(party.treasury == 8 and #party.inventory == 2,
            "dialogue action did not apply collection")
        assert(swapParameters and swapParameters.battlefieldView == "collection_result" and
            swapParameters.dialogueTree.lines[1].text:find("recover", 1, true),
            "dialogue action did not display collection results")

        StateManager.swap = originalSwap
        DialogueState.exit()
        DialogueState.enter(swapParameters)
        local resultScreen = UIManager.getActiveScreen()
        local returnOption
        for _, line in ipairs(resultScreen.lines) do
            returnOption = findOption({lines = {line}}, "battlefield_back")
            if returnOption then break end
        end
        assert(returnOption, "collection result omitted return-to-site choice")

        StateManager.swap = function(stateName, params)
            assert(stateName == "dialogue")
            swapParameters = params
        end
        resultScreen.onChoice(returnOption)
        StateManager.swap = originalSwap
        DialogueState.exit()
        DialogueState.enter(swapParameters)
        local updatedScreen = UIManager.getActiveScreen()
        assert(not findOption(updatedScreen.dialogueTree, "battlefield_collect") and
            findOption(updatedScreen.dialogueTree, "battlefield_inspect"),
            "return dialogue did not refresh options after collection")
        assert(findOption(updatedScreen.dialogueTree, "battlefield_unavailable"),
            "remaining corpse options disappeared after collection")
    end, debug.traceback)

    StateManager.swap = originalSwap
    DialogueState.exit()
    GameContext.data.currentMap = previousMap
    GameContext.data.playerParty = previousParty
    if not ok then error(err, 0) end
end

local Scenario = {}

function Scenario.run()
    testVisibilityAndRememberedDiscovery()
    testDialogueContentAndConditionalOptions()
    testMultipleSitesRemovalAndSerialization()
    testOrdinaryDialogueRegistryRemainsAvailable()
    testCollectCargoGoldAndIdempotence()
    testGoldOnlyItemOnlyAndEmptySites()
    testInvalidCollectionDoesNotPartiallyMutate()
    testExistingDialogueInterface()
    testSearchDialogueActionAndUpdatedOptions()
end

return Scenario
