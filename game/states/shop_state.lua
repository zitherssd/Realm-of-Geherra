-- game/states/shop_state.lua
-- Trading state: buy from / sell to a merchant

local ShopState = {}

local StateManager = require("core.state_manager")
local UIManager = require("ui.ui_manager")
local ShopScreen = require("ui.screens.shop_screen")
local GameContext = require("game.game_context")

function ShopState.enter(params)
    params = params or {}

    local playerParty = GameContext.data.playerParty
    local merchant = params.merchant

    if not playerParty or not merchant then
        StateManager.pop()
        return
    end

    -- A merchant with no stock is just an empty shop
    if not merchant.inventory then
        merchant.inventory = {}
    end

    local screen = ShopScreen.new(playerParty, merchant, function()
        StateManager.pop()
    end)

    UIManager.registerScreen("shop", screen)
    UIManager.showScreen("shop")
end

function ShopState.exit()
    UIManager.hideScreen()
end

function ShopState.update(dt)
    UIManager.update(dt)
end

function ShopState.draw()
    UIManager.draw()
end

function ShopState.mousepressed(x, y, button)
    UIManager.mousepressed(x, y, button)
end

function ShopState.mousereleased(x, y, button)
    UIManager.mousereleased(x, y, button)
end

function ShopState.keypressed(key)
    UIManager.keypressed(key)
end

function ShopState.keyreleased(key)
    UIManager.keyreleased(key)
end

function ShopState.wheelmoved(x, y)
    UIManager.wheelmoved(x, y)
end

return ShopState
