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
local Troop = require("src.ecs.assemblages.troop")
local PartySystem = require("src.systems.party_system")
local Items = require("src.data.items")
local PaintedMapLoader = require("src.systems.painted_map_loader")
local LocationPopulationSystem = require("src.systems.location_population_system")

-- Debug trader: spawns in the starter location and sells every item (for testing)
local DEBUG_TRADER_ENABLED = true
local DEBUG_TRADER_STOCK_QTY = 5

-- Fast setup phase: player character, player party, starter inventory and the
-- (empty) quest tables. No world/map work happens here so a generation splash
-- can run afterwards without blocking.
function GameInitializer.beginNewGame(options)
    options = options or {}

    -- Reset game context to clean state
    GameContext.init()
    local world = EcsWorld.init()

    -- Set game options
    GameContext.data.difficulty = options.difficulty or "normal"
    GameContext.data.playtime = 0
    GameContext.data.favor = 15

    -- Create player character
    local player = Troop.create(world, "player")
    player:give("player")
    player.attributes.shadowcraft = 2  -- Allow equipping poison dagger
    GameContext.setPlayer(player)

    -- Create player party
    local playerParty = Party.create(world, options.playerName or "Wanderer", player.id, "party_player")
    PartySystem.addActor(playerParty, player)
    PartySystem.addActor(playerParty, Troop.create(world, "pelas_youth"))
    PartySystem.addActor(playerParty, Troop.create(world, "pelas_tribesman"))
    PartySystem.addActor(playerParty, Troop.create(world, "pelas_skirmisher"))
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

    GameContext.data.playerParty = playerParty

    -- Initialize empty quests
    GameContext.data.activeQuests = {}
    GameContext.data.completedQuests = {}
    GameContext.data.questInstanceCounter = 0
    GameContext.data.questOfferCounter = 0

    return playerParty
end

-- Finalize phase: place the player beside the starter location, inject the
-- debug trader, and register the player party + starter parties on the map.
function GameInitializer.finalizeNewGame(map, locations)
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
        local debugTrader = Troop.create(EcsWorld.campaign, "debug_trader")
        debugTrader.name = "Merchant of Everything"
        debugTrader.dialogueId = "debug_trader_greeting"
        debugTrader.buysFromPlayers = true

        -- Stock the trader with every item from the catalog
        debugTrader.inventory = {}
        for _, def in pairs(Items) do
            local item = {}
            for k, v in pairs(def) do
                item[k] = v
            end
            item.quantity = DEBUG_TRADER_STOCK_QTY
            table.insert(debugTrader.inventory, item)
        end

        starterLocation:addNPC(debugTrader)
    end

    GameContext.data.currentMap = map

    -- Add player party to map
    map:addParty(playerParty)

    -- Create starter parties
    GameInitializer._createStarterParties(map)
end

-- Synchronous convenience wrapper: begin -> generate -> populate -> finalize.
-- Kept for the world_state contract and any non-splash callers.
function GameInitializer.initNewGame(options)
    options = options or {}
    GameInitializer.beginNewGame(options)
    local map = PaintedMapLoader.generate(options)
    local locations = LocationPopulationSystem.populate(map, map.worldGen)
    GameInitializer.finalizeNewGame(map, locations)
    return true
end

-- Create initial parties for a new game
function GameInitializer._createStarterParties(map)
    local firstLocation = map.locations[1]
    local spawnX = firstLocation and (firstLocation.x + 60) or 350
    local spawnY = firstLocation and (firstLocation.y + 60) or 350

    -- Create a bandit party
    local banditLeader = Troop.create(EcsWorld.campaign, "bandit")
    
    local banditParty = Party.create(EcsWorld.campaign, "Forest Bandits", banditLeader.id)
    PartySystem.setPosition(banditParty, spawnX, spawnY)
    banditParty.faction = "bandits"
    
    -- Add members
    PartySystem.addActor(banditParty, banditLeader)
    PartySystem.addActor(banditParty, Troop.create(EcsWorld.campaign, "bandit"))
    PartySystem.addActor(banditParty, Troop.create(EcsWorld.campaign, "bandit"))
    PartySystem.addActor(banditParty, Troop.create(EcsWorld.campaign, "bandit"))

    
    map:addParty(banditParty)
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
