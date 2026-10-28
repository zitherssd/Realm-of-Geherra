-- game/game_initializer.lua
-- Handles new game initialization and setup
-- Creates player, initializes world, and sets up starting state
--
-- World setup is split into phases so a splash state can show live generation
-- progress: beginNewGame() does the fast setup (player, party, inventory),
-- then the painted map is generated step-by-step (systems/painted_map_loader),
-- then finalizeNewGame() places the player and wires up the map.

local GameInitializer = {}

local GameContext = require("src.game.game_context")
local EcsWorld = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local Unit = require("src.ecs.assemblages.unit")
local PartySystem = require("src.systems.party_system")
local LocationSystem = require("src.systems.location_system")
local Items = require("src.data.items")
local TroopsData = require("src.data.troops")
local PaintedMapLoader = require("src.systems.painted_map_loader")
local LocationPopulationSystem = require("src.systems.location_population_system")
local PartyAiSystem = require("src.systems.party_ai_system")
local TraderSystem = require("src.systems.trader_system")
local InventorySystem = require("src.systems.inventory_system")

-- Debug trader: spawns in the starter location and sells every item (for testing)
local DEBUG_TRADER_ENABLED = true
local DEBUG_TRADER_STOCK_QTY = 5

function GameInitializer.getMapLoader(options)
    if options and options.debugCampaign then return require("src.debug.campaign_map") end
    return PaintedMapLoader
end

-- Fast setup phase: player character, player party, starter inventory and the
-- (empty) quest tables. No world/map work happens here so a generation splash
-- can run afterwards without blocking.
function GameInitializer.beginNewGame(options)
    options = options or {}
    require("src.systems.location_action_registry").validateHandlers()
    local profile = options.debugCampaign
    if profile then
        local fixture = require("src.debug.campaign_fixture")
        fixture.validate(profile)
        math.randomseed(fixture.seed)
        love.math.setRandomSeed(fixture.seed)
    end

    -- Reset game context to clean state
    local world = require("src.game.campaign.campaign_runtime").beginNewGame(options)
    GameContext.data.debugCampaignProfile = profile

    -- Set game options
    GameContext.data.difficulty = options.difficulty or "normal"
    GameContext.data.playtime = 0

    -- Create player character
    local player = Unit.create(world, "player")
    player:give("player")
    player.attributes.shadowcraft = 2  -- Allow equipping poison dagger
    player.favor = 15
    GameContext.setPlayer(player)

    -- Create player party
    local playerParty = Party.create(world, options.playerName or "Wanderer", player.id, "party_player")
    PartySystem.addActor(playerParty, player)
    PartySystem.addActor(playerParty, Unit.create(world, "companion"))
    PartySystem.addActor(playerParty, Unit.create(world, "pelas_youth"))
    PartySystem.addActor(playerParty, Unit.create(world, "pelas_tribesman"))
    PartySystem.addActor(playerParty, Unit.create(world, "pelas_skirmisher"))
    PartySystem.addTreasury(playerParty, 50)

    -- Starter inventory (for testing).
    -- Handed out as fresh copies so the shared data/items.lua catalog is never mutated.
    local starterItems = {
        "iron_sword", "fire_sword", "ice_sword", "fire_wand", "ice_wand",
        "storm_wand", "shock_sword", "dagger", "poison_dagger", "javelin",
        "leather_armor", "helmet", "boots", "wooden_shield"
    }
    for _, itemId in ipairs(starterItems) do
        if Items[itemId] then
            PartySystem.addItemDefCopy(playerParty, Items[itemId], 1)
        end
    end

    GameContext.setPlayerParty(playerParty)

    return playerParty
end

-- Finalize phase: place the player beside the starter location, inject the
-- debug trader, and register the player party + starter parties on the map.
function GameInitializer.finalizeNewGame(map, locations)
    if GameContext.data.campaignFinalized then return end
    local playerParty = GameContext.data.playerParty
    local starterLocation = locations and locations[1]

    if starterLocation then
        local px, py = map:nearestWalkable(starterLocation.x + 24, starterLocation.y + 24)
        PartySystem.setPosition(playerParty, px, py)
    else
        PartySystem.setPosition(playerParty, 512, 512)
    end

    -- Inject a debug trader into the starter location (for testing).
    -- Sells (and buys back) every item in data/items.lua.
    if DEBUG_TRADER_ENABLED and starterLocation then
        local debugTrader = Unit.create(EcsWorld.campaign, "debug_trader")
        debugTrader:give("memory")
        debugTrader.name = "Merchant of Everything"
        debugTrader.dialogueId = "debug_trader_greeting"
        debugTrader.buysFromPlayers = true

        -- Stock the trader with every item from the catalog
        debugTrader.inventory = {}
        debugTrader.inventoryFormat = "list"
        for _, def in pairs(Items) do
            local item = InventorySystem.deepClone(def)
            item.quantity = DEBUG_TRADER_STOCK_QTY
            table.insert(debugTrader.inventory, item)
        end

        LocationSystem.addNPC(starterLocation, debugTrader)
    end

    GameContext.data.currentMap = map

    -- Add player party to map
    map:addParty(playerParty)

    -- Create starter parties
    if GameContext.data.debugCampaignProfile then
        require("src.debug.campaign_fixture").populate(map, GameContext.data.debugCampaignProfile)
    else
        GameInitializer._createStarterParties(map)
    end
    GameContext.data.campaignFinalized = true
end

-- Synchronous convenience wrapper: begin -> generate -> populate -> finalize.
-- Kept for the world_state contract and any non-splash callers.
function GameInitializer.initNewGame(options)
    options = options or {}
    GameInitializer.beginNewGame(options)
    local map = GameInitializer.getMapLoader(options).generate(options)
    local locations = LocationPopulationSystem.populate(map, map.worldGen, options)
    GameInitializer.finalizeNewGame(map, locations)
    return true
end

-- Create initial parties for a new game
function GameInitializer._createStarterParties(map)
    local firstLocation = map.locations[1]
    local spawnX = firstLocation and (firstLocation.x + 60) or 350
    local spawnY = firstLocation and (firstLocation.y + 60) or 350

    -- Create a bandit party
    local banditLeader = Unit.create(EcsWorld.campaign, "bandit")
    banditLeader:give("memory") -- Explicit important NPC, independent of leadership.
    
    local banditParty = Party.create(EcsWorld.campaign, "Forest Bandits", banditLeader.id)
    PartySystem.setPosition(banditParty, spawnX, spawnY)
    banditParty.faction = "bandits"

    -- Roam near the spawn point and chase once the player is spotted.
    banditParty.state = "wander"
    banditParty.wanderOriginX, banditParty.wanderOriginY = spawnX, spawnY
    banditParty.wanderRadius = PartyAiSystem.wanderRadiusDefault
    
    -- Add members
    PartySystem.addActor(banditParty, banditLeader)
    PartySystem.addActor(banditParty, Unit.create(EcsWorld.campaign, "bandit"))
    PartySystem.addActor(banditParty, Unit.create(EcsWorld.campaign, "bandit"))
    PartySystem.addActor(banditParty, Unit.create(EcsWorld.campaign, "bandit"))
    PartySystem.addActor(banditParty, Unit.create(EcsWorld.campaign, "bandit"))
    PartySystem.addActor(banditParty, Unit.create(EcsWorld.campaign, "bandit"))

    
    map:addParty(banditParty)

    -- Create a neutral trader caravan that wanders near the starter location.
    local trader = Unit.create(EcsWorld.campaign, "trader")
    trader:give("memory")
    trader.name = "Wandering Trader"

    local traderParty = Party.create(EcsWorld.campaign, trader.name, trader.id)
    local traderX, traderY = spawnX + 18, spawnY - 12
    if map.nearestWalkable then
        traderX, traderY = map:nearestWalkable(traderX, traderY)
    end
    PartySystem.setPosition(traderParty, traderX, traderY)
    traderParty.faction = "neutral"
    traderParty.hostile = false
    traderParty.isTraderParty = true
    traderParty.dialogueId = "trader_greeting"
    traderParty.state = "wander"
    traderParty.wanderOriginX, traderParty.wanderOriginY = traderX, traderY
    traderParty.wanderRadius = PartyAiSystem.wanderRadiusDefault
    traderParty.treasury = 500

    local traderDefinition = TroopsData.trader
    traderParty.inventory = TraderSystem.buildStockInventory(traderDefinition)
    traderParty.buysFromPlayers = traderDefinition.buysFromPlayers
    traderParty.sellPriceFactor = traderDefinition.sellPriceFactor

    -- Give the trader party initial gold so it will be raided by bandits
    PartySystem.addTreasury(traderParty, 10000)

    PartySystem.addActor(traderParty, trader)
    PartySystem.addActor(traderParty, Unit.create(EcsWorld.campaign, "soldier"))

    map:addParty(traderParty)
end

-- Validate player name
function GameInitializer.validatePlayerName(name)
    if not name or name == "" then
        return false, "Name cannot be empty"
    end
    if #name < 2 then
        return false, "Name must be at least 2 characters"
    end
    if #name > 30 then
        return false, "Name must be 30 characters or fewer"
    end
    return true, nil
end

return GameInitializer
