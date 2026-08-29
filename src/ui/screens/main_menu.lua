-- ui/screens/main_menu.lua
-- Antediluvian Earth themed main menu per art bible

local MainMenu = {}
local StateManager = require("src.core.state_manager")

local function newGame()
    StateManager.swap("world")
end

local function quitGame()
    love.event.quit()
end

function MainMenu.show()
    -- Initialize main menu
end

function MainMenu.hide()
    -- Cleanup menu
end

function MainMenu.update(dt)
    if love.keyboard.isDown("n") then newGame() end
    if love.keyboard.isDown("q") then quitGame() end
end

function MainMenu.draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    -- Background — deep charcoal
    love.graphics.clear(0.08, 0.07, 0.06)

    -- Title with Terracotta/Amber gradient feel
    local titleFont = love.graphics.newFont(48)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.92, 0.65, 0.14, 1)  -- Amber
    love.graphics.printf("REALM OF GEHERRA", 0, h * 0.25, w, "center")

    -- Subtitle
    local subFont = love.graphics.newFont(18)
    love.graphics.setFont(subFont)
    love.graphics.setColor(0.71, 0.35, 0.22, 1)  -- Terracotta
    love.graphics.printf("A Warband of the Antediluvian Age", 0, h * 0.25 + 60, w, "center")

    -- Decorative separator line
    love.graphics.setColor(0.6, 0.4, 0.15, 0.6)
    local sepY = h * 0.25 + 100
    love.graphics.line(w * 0.3, sepY, w * 0.7, sepY)
    love.graphics.line(w * 0.3, sepY + 1, w * 0.7, sepY + 1)

    -- Menu options
    local menuFont = love.graphics.newFont(24)
    love.graphics.setFont(menuFont)
    local items = {
        { key = "N", label = "New Game", action = newGame },
        { key = "L", label = "Load Game", action = nil },
        { key = "Q", label = "Quit",     action = quitGame },
    }

    local startY = h * 0.25 + 140
    for i, item in ipairs(items) do
        local y = startY + (i - 1) * 50

        -- Key binding in Amber
        love.graphics.setColor(0.92, 0.65, 0.14, 1)
        love.graphics.printf("[" .. item.key .. "]", w * 0.35, y, 60, "right")

        -- Label in Parchment
        love.graphics.setColor(0.90, 0.84, 0.73, item.action and 1 or 0.5)
        love.graphics.printf(item.label, w * 0.35 + 70, y, 300, "left")
    end
end

return MainMenu
