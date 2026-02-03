-- Main entry point for the game
-- This handles the Love2D callbacks and manages the game state

local Game = require('src.game')

function love.load()
    -- Initialize the game
    love.window.setTitle("Realms-of-Geherra")
    love.graphics.setDefaultFilter('nearest', 'nearest')
    
    Game:init()
end

function love.update(dt)
    -- Update the game state
    Game:update(dt)
end

function love.draw()
    -- Draw the game
    Game:draw()
end

function love.keypressed(key)
    -- Handle key press events
    Game:keypressed(key)
end

function love.mousepressed(x, y, button)
    -- Handle mouse press events
    Game:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    -- Handle mouse release events
    Game:mousereleased(x, y, button)
end