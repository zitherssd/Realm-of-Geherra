-- game/states/inventory_state.lua
-- State for managing player inventory

local InventoryState = {}
local StateManager = require("src.core.state_manager")
local UIManager = require("src.ui.ui_manager")
local InventoryScreen = require("src.ui.screens.inventory_screen")
local GameContext = require("src.game.game_context")

function InventoryState.enter()
    local playerParty = GameContext.data.playerParty
    if not playerParty then 
        StateManager.pop()
        return 
    end
    
    local screen = InventoryScreen.new(playerParty, function()
        StateManager.pop()
    end)
    
    UIManager.registerScreen("inventory", screen)
    UIManager.showScreen("inventory")
end

function InventoryState.exit()
    UIManager.hideScreen()
end

function InventoryState.update(dt)
    UIManager.update(dt)
end

function InventoryState.draw()
    UIManager.draw()
end

function InventoryState.mousepressed(x, y, button)
    UIManager.mousepressed(x, y, button)
end

function InventoryState.mousereleased(x, y, button)
    UIManager.mousereleased(x, y, button)
end

function InventoryState.keypressed(key)
    UIManager.keypressed(key)
end

function InventoryState.keyreleased(key)
    UIManager.keyreleased(key)
end

return InventoryState