-- game/game_initializer.lua
-- Handles new game initialization and setup
-- Creates player, initializes world, and sets up starting state

local GameInitializer = {}

local GameContext = require("game.game_context")
local Player = require("entities.player")
local Party = require("entities.party")
local Map = require("world.map")
local Location = require("world.location")
local Troop = require("entities.troop")

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
    playerParty:setPosition(512, 512)
    playerParty:addActor(player)
    playerParty:addActor(Troop.new("bandit"))
    playerParty:addActor(Troop.new("bandit"))
    playerParty:addActor(Troop.new("bandit"))
    playerParty:addActor(Troop.new("companion"))
    playerParty:addActor(Troop.new("war_dog"))

    GameContext.data.playerParty = playerParty
    
    -- Create initial world map
    local map = Map.new("realm_of_geherra", "Realm of Geherra")
    map:loadVisualMap("assets/map/visual_map.png")
    map:setBounds(0, 0, 1660, 1174)
    GameContext.data.currentMap = map
    
    -- Add player party to map
    map:addParty(playerParty)
    
    -- Create starter locations
    GameInitializer._createStarterLocations(map)
    
    -- Create starter parties
    GameInitializer._createStarterParties(map)
    
    -- Initialize empty quests
    GameContext.data.activeQuests = {}
    GameContext.data.completedQuests = {}
    GameContext.data.questInstanceCounter = 0
    GameContext.data.questOfferCounter = 0
    
    return true
end

-- Create initial locations for a new game
function GameInitializer._createStarterLocations(map)
    -- Ironhold - Menari location (starting point)
    local ironhold = Location.new("settlement_ironhold", "Ironhold")
    ironhold:setPosition(300, 300)
    ironhold.faction = "menari"
    ironhold.type = "castle"
    ironhold.population = 5000
    ironhold.prosperity = 75
    
    -- Add a test NPC to Ironhold
    local elder = Troop.new("elder")
    elder.name = "Aris"
    elder.dialogueId = "elder_greeting"
    ironhold:addNPC(elder)
    
    map:addLocation(ironhold)
    
    -- Darkwood - Dacian location
    local darkwood = Location.new("settlement_darkwood", "Darkwood")
    darkwood:setPosition(700, 400)
    darkwood.faction = "dacians"
    darkwood.type = "town"
    darkwood.population = 3500
    darkwood.prosperity = 60
    map:addLocation(darkwood)
    
    -- Stonedeep - Hyperborean location
    local stonedeep = Location.new("settlement_stonedeep", "Stonedeep")
    stonedeep:setPosition(450, 750)
    stonedeep.faction = "hyperboreans"
    stonedeep.type = "castle"
    stonedeep.population = 4000
    stonedeep.prosperity = 80
    map:addLocation(stonedeep)
    
    -- Shadowmere - Neutral/Independent location
    local shadowmere = Location.new("settlement_shadowmere", "Shadowmere")
    shadowmere:setPosition(200, 600)
    shadowmere.faction = "neutral"
    shadowmere.type = "village"
    shadowmere.population = 800
    shadowmere.prosperity = 40
    map:addLocation(shadowmere)
end

-- Create initial parties for a new game
function GameInitializer._createStarterParties(map)
    -- Create a bandit party
    local banditLeader = Troop.new("bandit")
    
    local banditParty = Party.new("Forest Bandits", banditLeader.id)
    banditParty:setPosition(350, 350) -- Near Ironhold
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
