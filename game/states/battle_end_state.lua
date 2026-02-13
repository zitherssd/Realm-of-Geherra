-- game/states/battle_end_state.lua
-- Controller state for the battle end screen

local BattleEndState = {}

local StateManager = require("core.state_manager")
local BattleEndScreen = require("ui.screens.battle_end_screen")
local LootScreen = require("ui.screens.loot_screen")

BattleEndState.screen = nil

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
    BattleEndState.screen = BattleEndScreen.new(results, function()
        -- If there is loot, go to loot screen, otherwise world
        if #results.loot > 0 then
            BattleEndState.screen = LootScreen.new(results.loot, function()
                StateManager.swap("world")
            end)
        else
            StateManager.swap("world")
        end
    end)
end

function BattleEndState.exit()
    BattleEndState.screen = nil
end

function BattleEndState.update(dt)
    if BattleEndState.screen then
        BattleEndState.screen:update(dt)
    end
end

function BattleEndState.draw()
    if BattleEndState.screen then
        BattleEndState.screen:draw()
    end
end

function BattleEndState.mousepressed(x, y, button)
    if BattleEndState.screen then
        BattleEndState.screen:mousepressed(x, y, button)
    end
end

return BattleEndState