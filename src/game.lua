-- Main game state manager
-- This module handles the overall game state and coordinates between different game modes

local Player = require('src.player')
local Overworld = require('src.overworld')
local Town = require('src.town')
local Utils = require('src.utils')
local Biome = require('src.biome')
local Party = require('src.party')

local Game = {
    state = "overworld", -- Current game state: "overworld", "town", "menu"
    -- player = nil, -- Remove old player
    party = nil, -- New party object
    overworld = nil,
    town = nil,
    currentTown = nil,
    camera = {x = 0, y = 0},
    screenWidth = 1024,
    screenHeight = 768
}

function Game:init()
    -- Initialize the game systems
    -- self.player = Player:new() -- Remove old player
    self.party = Party:new()
    self.overworld = Overworld:new()
    self.town = Town:new()
    self.encounteredParty = nil
    self.encounterMenuIndex = 1
    
    -- Load images
    Biome:load('assets/biome_map.png')
    self.overworld:loadImages()
    
    -- Center camera on party
    self.camera.x = self.party.x - self.screenWidth / 2
    self.camera.y = self.party.y - self.screenHeight / 2
    
    print("Game initialized. Use WASD or arrow keys to move, Enter to interact with towns, ESC to quit.")
end

function Game:update(dt)
    if self.state == "overworld" then
        self.party:update(dt)
        self.overworld:update(dt, self.party)
        
        -- Update camera to follow party
        self.camera.x = self.party.x - self.screenWidth / 2
        self.camera.y = self.party.y - self.screenHeight / 2
        
        -- Check for town interactions
        local nearbyTown = self.overworld:checkTownInteraction(self.party.x, self.party.y)
        if nearbyTown and love.keyboard.isDown('return') then
            self:enterTown(nearbyTown)
        end
        
        -- Check for AI party interaction
        local nearbyAIParty = self.overworld:getNearbyParty(self.party.x, self.party.y, 32)
        if nearbyAIParty then
            self.state = "encounter"
            self.encounteredParty = nearbyAIParty
            self.encounterMenuIndex = 1
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
        
        -- Draw party
        self.party:draw()
        
        love.graphics.pop()
        
        -- Draw UI
        self:drawUI()
        
    elseif self.state == "town" then
        self.town:draw()
    elseif self.state == "encounter" then
        self:drawEncounter()
    end
end

function Game:drawEncounter()
    local party = self.encounteredParty
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle('fill', 0, 0, self.screenWidth, self.screenHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(28))
    love.graphics.printf("Encounter!", 0, 60, self.screenWidth, 'center')
    love.graphics.setFont(love.graphics.newFont(18))
    love.graphics.printf((party.name or "AI Party") .. " [" .. (party.type or '?') .. ", " .. (party.faction or '?') .. "]", 0, 120, self.screenWidth, 'center')
    love.graphics.printf("Morale: " .. (party.morale or '?'), 0, 150, self.screenWidth, 'center')
    love.graphics.printf("State: " .. (party.state or '?'), 0, 170, self.screenWidth, 'center')
    love.graphics.setFont(love.graphics.newFont(20))
    local encounterOptions = {"Talk", "Pay", "Fight", "Leave"}
    for i, option in ipairs(encounterOptions) do
        local y = 240 + i * 40
        if i == self.encounterMenuIndex then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.printf((i == self.encounterMenuIndex and "> " or "  ") .. option, 0, y, self.screenWidth, 'center')
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.printf("Up/Down: Navigate  Enter: Select  Esc: Leave", 0, self.screenHeight - 40, self.screenWidth, 'center')
end

function Game:drawUI()
    -- Draw party stats in top-left corner
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', 10, 10, 320, 140)
    love.graphics.setColor(1, 1, 1, 1)
    
    love.graphics.print(string.format("Morale: %d", self.party.morale), 20, 20)
    love.graphics.print(string.format("Movement Speed: %.1f", self.party.movement_speed), 20, 40)
    love.graphics.print(string.format("Healing Rate: %.2f", self.party.healing_rate), 20, 60)
    love.graphics.print(string.format("Biome: %s", self.party.current_biome), 20, 80)
    love.graphics.print(string.format("Impassable: %s", tostring(self.party.impassable)), 20, 100)
    
    -- Draw instructions
    love.graphics.print("WASD/Arrows: Move | Enter: Interact | ESC: Quit", 10, self.screenHeight - 25)
end

function Game:enterTown(town)
    self.state = "town"
    self.currentTown = town
    self.town:enter(town, self.party)
end

function Game:exitTown()
    self.state = "overworld"
    self.currentTown = nil
end

function Game:keypressed(key)
    if key == 'escape' then
        if self.state == "town" then
            self:exitTown()
        elseif self.state == "encounter" then
            self.state = "overworld"
            self.encounteredParty = nil
        else
            love.event.quit()
        end
    elseif self.state == "town" then
        self.town:keypressed(key)
    elseif self.state == "encounter" then
        if key == 'up' then
            self.encounterMenuIndex = math.max(1, self.encounterMenuIndex - 1)
        elseif key == 'down' then
            self.encounterMenuIndex = math.min(#encounterOptions, self.encounterMenuIndex + 1)
        elseif key == 'return' then
            local selected = encounterOptions[self.encounterMenuIndex]
            if selected == "Leave" then
                self.state = "overworld"
                self.encounteredParty = nil
            elseif selected == "Talk" then
                -- Future: dialog logic
                print("You try to talk to " .. (self.encounteredParty.name or 'the party') .. ".")
            elseif selected == "Pay" then
                -- Future: pay logic
                print("You offer to pay the party.")
            elseif selected == "Fight" then
                -- Future: battle logic
                print("You prepare to fight!")
            end
        end
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