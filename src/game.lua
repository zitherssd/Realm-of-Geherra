-- Main game state manager
-- This module handles the overall game state and coordinates between different game modes

local Player = require('src.player')
local Overworld = require('src.overworld')
local Town = require('src.town')
local Utils = require('src.utils')

local Game = {
    state = "overworld", -- Current game state: "overworld", "town", "menu"
    player = nil,
    overworld = nil,
    town = nil,
    currentTown = nil,
    camera = {x = 0, y = 0},
    screenWidth = 1024,
    screenHeight = 768
}

function Game:init()
    -- Initialize the game systems
    self.player = Player:new()
    self.overworld = Overworld:new()
    self.town = Town:new()
    
    -- Center camera on player
    self.camera.x = self.player.x - self.screenWidth / 2
    self.camera.y = self.player.y - self.screenHeight / 2
    
    print("Game initialized. Use WASD or arrow keys to move, Enter to interact with towns, ESC to quit.")
end

function Game:update(dt)
    if self.state == "overworld" then
        self.player:update(dt)
        self.overworld:update(dt)
        
        -- Update camera to follow player
        self.camera.x = self.player.x - self.screenWidth / 2
        self.camera.y = self.player.y - self.screenHeight / 2
        
        -- Check for town interactions
        local nearbyTown = self.overworld:checkTownInteraction(self.player.x, self.player.y)
        if nearbyTown and love.keyboard.isDown('return') then
            self:enterTown(nearbyTown)
        end
        
    elseif self.state == "town" then
        self.town:update(dt)
    end
end

function Game:draw()
    if self.state == "overworld" then
        love.graphics.push()
        love.graphics.translate(-self.camera.x, -self.camera.y)
        
        -- Draw overworld
        self.overworld:draw()
        
        -- Draw player
        self.player:draw()
        
        love.graphics.pop()
        
        -- Draw UI
        self:drawUI()
        
    elseif self.state == "town" then
        self.town:draw()
    end
end

function Game:drawUI()
    -- Draw player stats in top-left corner
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', 10, 10, 300, 120)
    love.graphics.setColor(1, 1, 1, 1)
    
    local stats = self.player:getStats()
    love.graphics.print(string.format("Gold: %d", stats.gold), 20, 20)
    love.graphics.print(string.format("Strength: %d", stats.strength), 20, 40)
    love.graphics.print(string.format("Agility: %d", stats.agility), 20, 60)
    love.graphics.print(string.format("Vitality: %d", stats.vitality), 20, 80)
    love.graphics.print(string.format("Leadership: %d", stats.leadership), 20, 100)
    
    -- Draw army size
    love.graphics.print(string.format("Army Size: %d", #self.player.army), 180, 20)
    
    -- Draw instructions
    love.graphics.print("WASD/Arrows: Move | Enter: Interact | ESC: Quit", 10, self.screenHeight - 25)
end

function Game:enterTown(town)
    self.state = "town"
    self.currentTown = town
    self.town:enter(town, self.player)
end

function Game:exitTown()
    self.state = "overworld"
    self.currentTown = nil
end

function Game:keypressed(key)
    if key == 'escape' then
        if self.state == "town" then
            self:exitTown()
        else
            love.event.quit()
        end
    elseif self.state == "town" then
        self.town:keypressed(key)
    end
end

function Game:mousepressed(x, y, button)
    if self.state == "town" then
        self.town:mousepressed(x, y, button)
    end
end

function Game:mousereleased(x, y, button)
    if self.state == "town" then
        self.town:mousereleased(x, y, button)
    end
end

return Game