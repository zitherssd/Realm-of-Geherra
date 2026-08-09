-- game/states/battle_end_state.lua
-- Controller state for the battle end screen

local BattleEndState = {}

local StateManager = require("core.state_manager")
local UIManager = require("ui.ui_manager")
local BattleEndScreen = require("ui.screens.battle_end_screen")
local LootScreen = require("ui.screens.loot_screen")
local WorldState = require("game.states.world_state")

-- Return to the world map, popping up the favor reward once we arrive.
local function returnToWorld(favor)
    if favor and favor > 0 then
        WorldState.showFavorPopup(favor)
    end
    StateManager.swap("world")
end

function BattleEndState.enter(params)
    params = params or {}
    
    -- Prepare results data structure
    local results = {
        victory = params.victory or false,
        playerCasualties = params.playerCasualties or {},
        enemyCasualties = params.enemyCasualties or {},
        loot = params.loot or {},
        gold = params.gold or 0,
        favor = params.favor or 0
    }
    
    -- Initialize the UI Screen with a callback for the continue button
    local screen = BattleEndScreen.new(results, function()
        -- If there is loot, go to loot screen, otherwise world
        if #results.loot > 0 then
            local lootScreen = LootScreen.new(results.loot, function()
                returnToWorld(results.favor)
            end)
            UIManager.registerScreen("loot", lootScreen)
            UIManager.showScreen("loot")
        else
            returnToWorld(results.favor)
        end
    end)
    
    UIManager.registerScreen("battle_end", screen)
    UIManager.showScreen("battle_end")
end

function BattleEndState.exit()
    UIManager.hideScreen()
end

function BattleEndState.update(dt)
    UIManager.update(dt)
end

function BattleEndState.draw()
    UIManager.draw()
end

function BattleEndState.mousepressed(x, y, button)
    UIManager.mousepressed(x, y, button)
end

return BattleEndState