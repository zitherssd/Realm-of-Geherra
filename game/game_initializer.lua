-- game/game_initializer.lua
-- Handles new game initialization and setup
-- Creates player, initializes world, and sets up starting state

local GameInitializer = {}

local GameContext = require("game.game_context")
local Party = require("entities.party")
local Map = require("world.map")
local Troop = require("entities.troop")
local Items = require("data.items")
local WorldGenerationConfig = require("data.world_generation")
local WorldGenerationSystem = require("systems.world_generation_system")
local LocationPopulationSystem = require("systems.location_population_system")

-- Initialize a new game with starting conditions
function GameInitializer.initNewGame(options)
    options = options or {}
    
    -- Reset game context to clean state
    GameContext.init()
    
    -- Set game options
    GameContext.data.difficulty = options.difficulty or "normal"
    GameContext.data.playtime = 0
    GameContext.data.favor = 5
    
    -- Create player character
    local player = Troop.new("player")
    GameContext.setPlayer(player)
    
    -- Create player party
    local playerParty = Party.new(options.playerName or "Wanderer", player.id, "party_player")
    playerParty:addActor(player)
    playerParty:addActor(Troop.new("companion"))
    playerParty:addActor(Troop.new("war_dog"))

    -- Starter inventory
    if Items["fire_wand"] then
        table.insert(playerParty.inventory, Items["fire_wand"])
    end
    if Items["dagger"] then
        table.insert(playerParty.inventory, Items["dagger"])
    end

    GameContext.data.playerParty = playerParty
    
    -- Create initial world map
    local map = Map.new("realm_of_geherra", "Realm of Geherra")
    local visualPath = options.mapVisualPath
        or (WorldGenerationConfig.map and WorldGenerationConfig.map.visualPath)

    if visualPath then
        map:loadVisualMap(visualPath)
    end

    map:setBounds(0, 0, 1660, 1174)

    local generatedWorld = WorldGenerationSystem.generate(map, {
        seed = options.worldSeed,
        majorSiteCount = options.majorSiteCount,
        terrainMaskPath = options.terrainMaskPath
    })
    map:setWorldGenerationData(generatedWorld)

    local generatedLocations = LocationPopulationSystem.populate(map, generatedWorld)
    local starterLocation = generatedLocations[1]

    if starterLocation then
        playerParty:setPosition(starterLocation.x + 24, starterLocation.y + 24)
    else
        playerParty:setPosition(512, 512)
    end

    GameContext.data.currentMap = map
    
    -- Add player party to map
    map:addParty(playerParty)
    
    -- Create starter parties
    GameInitializer._createStarterParties(map)
    
    -- Initialize empty quests
    GameContext.data.activeQuests = {}
    GameContext.data.completedQuests = {}
    GameContext.data.questInstanceCounter = 0
    GameContext.data.questOfferCounter = 0
    
    return true
end

-- Create initial parties for a new game
function GameInitializer._createStarterParties(map)
    local firstLocation = map.locations[1]
    local spawnX = firstLocation and (firstLocation.x + 60) or 350
    local spawnY = firstLocation and (firstLocation.y + 60) or 350

    -- Create a bandit party
    local banditLeader = Troop.new("bandit")
    
    local banditParty = Party.new("Forest Bandits", banditLeader.id)
    banditParty:setPosition(spawnX, spawnY)
    banditParty.faction = "bandits"
    
    -- Add members
    banditParty:addActor(banditLeader)
    banditParty:addActor(Troop.new("bandit"))
    banditParty:addActor(Troop.new("bandit"))
    banditParty:addActor(Troop.new("bandit"))

    
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
