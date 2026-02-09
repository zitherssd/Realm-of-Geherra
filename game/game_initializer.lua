-- game/game_initializer.lua
-- Handles new game initialization and setup
-- Creates player, initializes world, and sets up starting state

local GameInitializer = {}

local GameContext = require("game.game_context")
local Player = require("entities.player")
local Party = require("entities.party")
local Map = require("world.map")
local Settlement = require("world.settlement")
local Troop = require("entities.troop")

-- Initialize a new game with starting conditions
function GameInitializer.initNewGame(options)
    options = options or {}
    
    -- Reset game context to clean state
    GameContext.init()
    
    -- Set game options
    GameContext.data.difficulty = options.difficulty or "normal"
    GameContext.data.playtime = 0
    
    -- Create player character
    local player = Player.new("player_1", options.playerName or "Wanderer")
    GameContext.setPlayer(player)
    
    -- Create player party
    local playerParty = Party.new("party_player", options.playerName or "Wanderer", "player_1")
    playerParty:setPosition(512, 512)
    playerParty:addMember("player_1")
    GameContext.data.playerParty = playerParty
    
    -- Create initial world map
    local map = Map.new("realm_of_geherra", "Realm of Geherra")
    map:loadVisualMap("assets/map/visual_map.png")
    map:setBounds(0, 0, 1024, 1024)
    GameContext.data.currentMap = map
    
    -- Add player party to map
    map:addParty(playerParty)
    
    -- Create starter settlements
    GameInitializer._createStarterSettlements(map)
    
    -- Create starter parties
    GameInitializer._createStarterParties(map)
    
    -- Initialize empty quests
    GameContext.data.activeQuests = {}
    GameContext.data.completedQuests = {}
    
    return true
end

-- Create initial settlements for a new game
function GameInitializer._createStarterSettlements(map)
    -- Ironhold - Human settlement (starting point)
    local ironhold = Settlement.new("settlement_ironhold", "Ironhold")
    ironhold:setPosition(300, 300)
    ironhold.faction = "human"
    ironhold.type = "castle"
    ironhold.population = 5000
    ironhold.prosperity = 75
    map:addSettlement(ironhold)
    
    -- Darkwood - Elven settlement
    local darkwood = Settlement.new("settlement_darkwood", "Darkwood")
    darkwood:setPosition(700, 400)
    darkwood.faction = "elf"
    darkwood.type = "town"
    darkwood.population = 3500
    darkwood.prosperity = 60
    map:addSettlement(darkwood)
    
    -- Stonedeep - Dwarven settlement
    local stonedeep = Settlement.new("settlement_stonedeep", "Stonedeep")
    stonedeep:setPosition(450, 750)
    stonedeep.faction = "dwarf"
    stonedeep.type = "fortress"
    stonedeep.population = 4000
    stonedeep.prosperity = 80
    map:addSettlement(stonedeep)
    
    -- Shadowmere - Neutral/Independent settlement
    local shadowmere = Settlement.new("settlement_shadowmere", "Shadowmere")
    shadowmere:setPosition(200, 600)
    shadowmere.faction = nil
    shadowmere.type = "village"
    shadowmere.population = 800
    shadowmere.prosperity = 40
    map:addSettlement(shadowmere)
end

-- Create initial parties for a new game
function GameInitializer._createStarterParties(map)
    -- Create a bandit party
    local banditLeader = Troop.new("bandit_leader_1", "bandit")
    
    local banditParty = Party.new("party_bandits_1", "Forest Bandits", banditLeader.id)
    banditParty:setPosition(350, 350) -- Near Ironhold
    banditParty.faction = "bandits"
    
    -- Add members
    banditParty:addMember(banditLeader.id)
    banditParty:addMember(Troop.new("bandit_1", "bandit").id)
    banditParty:addMember(Troop.new("bandit_2", "bandit").id)
    
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
