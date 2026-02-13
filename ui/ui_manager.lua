-- ui/ui_manager.lua
-- Central UI management

local UIManager = {}

local screens = {}
local activeScreen = nil

function UIManager.init()
    screens = {}
    activeScreen = nil
end

function UIManager.registerScreen(screenId, screen)
    screens[screenId] = screen
end

function UIManager.showScreen(screenId, ...)
    if screens[screenId] then
        activeScreen = screens[screenId]
        if activeScreen.show then
            activeScreen:show(...)
        end
    end
end

function UIManager.hideScreen()
    if activeScreen and activeScreen.hide then
        activeScreen:hide()
    end
    activeScreen = nil
end

function UIManager.getActiveScreen()
    return activeScreen
end

function UIManager.update(dt)
    if activeScreen and activeScreen.update then
        activeScreen:update(dt)
    end
end

function UIManager.draw()
    if activeScreen and activeScreen.draw then
        activeScreen:draw()
    end
end

function UIManager.mousepressed(x, y, button)
    if activeScreen and activeScreen.mousepressed then
        activeScreen:mousepressed(x, y, button)
    end
end

function UIManager.mousereleased(x, y, button)
    if activeScreen and activeScreen.mousereleased then
        activeScreen:mousereleased(x, y, button)
    end
end

return UIManager
