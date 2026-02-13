-- game/states/battle_end_state.lua
-- Controller state for the battle end screen

local BattleEndState = {}

local StateManager = require("core.state_manager")
local UIManager = require("ui.ui_manager")
local BattleEndScreen = require("ui.screens.battle_end_screen")
local LootScreen = require("ui.screens.loot_screen")

function BattleEndState.enter(params)
    params = params or {}
    
    -- Prepare results data structure
    local results = {
        victory = params.victory or false,
        playerCasualties = params.playerCasualties or {},
        enemyCasualties = params.enemyCasualties or {},
        loot = params.loot or {}
    }
    
    -- Initialize the UI Screen with a callback for the continue button
    local screen = BattleEndScreen.new(results, function()
        -- If there is loot, go to loot screen, otherwise world
        if #results.loot > 0 then
            local lootScreen = LootScreen.new(results.loot, function()
                StateManager.swap("world")
            end)
            UIManager.registerScreen("loot", lootScreen)
            UIManager.showScreen("loot")
        else
            StateManager.swap("world")
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