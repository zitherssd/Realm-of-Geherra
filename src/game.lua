-- Main game state manager
-- This module handles the overall game state and coordinates between different game modes

local Player = require('src.player')
local Overworld = require('src.overworld')
local Town = require('src.town')
local Battle = require('src.battle')
local Utils = require('src.utils')
local Party = require('src.parties')
local Encounter = require('src.encounter')

local Game = {
    state = "overworld", -- Current game state: "overworld", "town", "battle", "army", "menu"
    player = nil,
    overworld = nil,
    town = nil,
    battle = nil,
    currentTown = nil,
    camera = {x = 0, y = 0},
    screenWidth = 1024,
    screenHeight = 768,
    
    -- Minimap settings
    minimap = {
        size = 200,
        margin = 10,
        scale = 0.1, -- Scale factor for minimap (1/10th of actual world)
        borderColor = {0.2, 0.2, 0.2, 0.8},
        backgroundColor = {0.1, 0.1, 0.1, 0.7},
        playerColor = {1, 1, 0, 1}, -- Yellow for player
        townColor = {0.8, 0.6, 0.2, 1}, -- Gold for towns
        waterColor = {0.2, 0.4, 0.8, 0.5} -- Blue for water
    }
}

function Game:init()
    -- Initialize the game systems
    self.player = Player:new()
    self.overworld = Overworld:new()
    self.town = Town:new()
    
    -- Connect player to overworld for collision detection
    self.player:setOverworld(self.overworld)
    
    -- Center camera on player
    self.camera.x = self.player.x - self.screenWidth / 2
    self.camera.y = self.player.y - self.screenHeight / 2
    
    Party:init()
    
    print("Game initialized. Use WASD or arrow keys to move, Enter to interact with towns, ESC to quit.")
end

function Game:update(dt)
    if self.state == "overworld" then
        self.player:update(dt)
        self.overworld:update(dt)
        Party:update(dt, self.player)
        
        -- Update camera to follow player
        self.camera.x = self.player.x - self.screenWidth / 2
        self.camera.y = self.player.y - self.screenHeight / 2
        
        self:checkEncounter()
        
        -- Check for town interactions
        local nearbyTown = self.overworld:checkTownInteraction(self.player.x, self.player.y)
        if nearbyTown and love.keyboard.isDown('return') then
            self:enterTown(nearbyTown)
        end
        
    elseif self.state == "encounter" then
        Encounter:update(dt)
    elseif self.state == "town" then
        self.town:update(dt)
        
    elseif self.state == "battle" then
        self.battle:update(dt)
        
        -- Removed polling for isFinished
        
    elseif self.state == "army" then
        -- Army screen - no updates needed
    end
end

function Game:checkEncounter()
    if self.state ~= "overworld" then return end
    local nearbyParties = Party:getNearbyParties(self.player.x, self.player.y, 50)
    for _, party in ipairs(nearbyParties) do
        self.state = "encounter"
        Encounter:init(party, function(nextState)
            self.state = nextState
        end)
        break
    end
end

function Game:startBattle(battleType, enemyArmy, backgroundType)
    self.state = "battle"
    self.battle = Battle.start(
        battleType,
        self.player,
        enemyArmy,
        backgroundType,
        function(newState) self.state = newState end
    )
end

function Game:exitBattle()
    self.state = "overworld"
    self.battle = nil
end

function Game:draw()
    if self.state == "overworld" then
        love.graphics.push()
        love.graphics.translate(-self.camera.x, -self.camera.y)
        
        -- Draw overworld
        self.overworld:draw()
        
        -- Draw enemy parties
        self.overworld:drawEnemyParties(self.battle_triggers.parties)
        
        -- Draw bandit parties
        self.overworld:drawBanditParties(self.battle_triggers.parties)
        
        -- Draw interaction indicators
        self.overworld:drawInteractionIndicators(self.player.x, self.player.y)
        
        -- Draw player
        self.player:draw()
        
        love.graphics.pop()
        
        -- Draw UI
        self:drawUI()
        
    elseif self.state == "encounter" then
        Encounter:draw(self.screenWidth, self.screenHeight)
    elseif self.state == "town" then
        self.town:draw()
        
    elseif self.state == "battle" then
        self.battle:draw()
        
    elseif self.state == "army" then
        self:drawArmyScreen()
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
    
    -- Draw minimap
    self:drawMinimap()
    
    -- Draw instructions
    if self.state == "overworld" then
        love.graphics.print("WASD/Arrows/Stick: Move | Enter/A: Interact | I/Y: Army | ESC/Start: Quit", 10, self.screenHeight - 25)
        love.graphics.print("Red circles = Enemy parties | Orange circles = Bandit parties", 10, self.screenHeight - 45)
    elseif self.state == "battle" then
        love.graphics.print("Battle in progress! | ESC/Start: Retreat (costs 10 gold)", 10, self.screenHeight - 25)
    elseif self.state == "army" then
        love.graphics.print("Army Inspection | ESC/B: Return to overworld | A: Add unit", 10, self.screenHeight - 25)
    else
        love.graphics.print("WASD/Arrows/Stick: Move | Enter/A: Interact | ESC/Start: Quit", 10, self.screenHeight - 25)
    end
end

function Game:drawMinimap()
    local minimap = self.minimap
    local x = self.screenWidth - minimap.size - minimap.margin
    local y = minimap.margin
    local size = minimap.size
    local block = 4 -- block size for performance
    local scale = minimap.scale
    local offsetX = x + size / 2
    local offsetY = y + size / 2
    local biomeMap = self.overworld.biomeMap
    local biomeTypes = require('src.data.biome_types')
    if biomeMap then
        for mx = 0, size-1, block do
            for my = 0, size-1, block do
                -- World coordinates for this minimap block
                local wx = self.player.x + (mx - size/2) / scale
                local wy = self.player.y + (my - size/2) / scale
                local r, g, b = biomeMap:getPixel(math.floor(wx), math.floor(wy))
                local hex = string.format("#%02x%02x%02x", r*255, g*255, b*255)
                local biome = biomeTypes[hex]
                if biome then
                    love.graphics.setColor(biome.color[1], biome.color[2], biome.color[3], 1)
                else
                    love.graphics.setColor(0.1, 0.1, 0.1, 1) -- fallback
                end
                love.graphics.rectangle('fill', x + mx, y + my, block, block)
            end
        end
    else
        -- fallback: draw background
        love.graphics.setColor(unpack(minimap.backgroundColor))
        love.graphics.rectangle('fill', x, y, size, size)
    end
    -- Draw minimap border
    love.graphics.setColor(unpack(minimap.borderColor))
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', x, y, size, size)
    -- Draw towns on minimap with different colors based on type
    for _, town in ipairs(self.overworld.towns) do
        local townX = (town.x - self.player.x) * scale
        local townY = (town.y - self.player.y) * scale
        local townSize = math.max(2, town.size * scale / 4)
        if townX >= -size/2 and townX <= size/2 and townY >= -size/2 and townY <= size/2 then
            if town.type == "village" then
                love.graphics.setColor(0.8, 0.6, 0.2, 1)
            elseif town.type == "city" then
                love.graphics.setColor(0.7, 0.7, 0.7, 1)
            elseif town.type == "port" then
                love.graphics.setColor(0.2, 0.4, 0.8, 1)
            elseif town.type == "fortress" then
                love.graphics.setColor(0.5, 0.5, 0.5, 1)
            else
                love.graphics.setColor(unpack(minimap.townColor))
            end
            love.graphics.circle('fill', offsetX + townX, offsetY + townY, townSize)
            love.graphics.setColor(0.2, 0.2, 0.2, 1)
            love.graphics.setLineWidth(1)
            love.graphics.circle('line', offsetX + townX, offsetY + townY, townSize)
        end
    end
    -- Draw player position on minimap (centered)
    love.graphics.setColor(unpack(minimap.playerColor))
    love.graphics.circle('fill', offsetX, offsetY, 3)
    -- Draw minimap title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Minimap", x + 5, y + 5)
end

function Game:drawArmyScreen()
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.2, 1.0)
    love.graphics.rectangle('fill', 0, 0, self.screenWidth, self.screenHeight)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("ARMY INSPECTION", self.screenWidth/2 - 100, 20)
    
    -- Draw army statistics
    local stats = self.player:getStats()
    love.graphics.print("Gold: " .. stats.gold, 20, 60)
    love.graphics.print("Army Size: " .. #self.player.army, 20, 80)
    love.graphics.print("Army Strength: " .. self.player:getArmyStrength(), 20, 100)
    
    -- Draw unit list
    local startY = 140
    local unitHeight = 60
    local unitsPerRow = 3
    local unitWidth = (self.screenWidth - 40) / unitsPerRow
    
    for i, unit in ipairs(self.player.army) do
        local row = math.floor((i - 1) / unitsPerRow)
        local col = (i - 1) % unitsPerRow
        local x = 20 + col * unitWidth
        local y = startY + row * unitHeight
        
        self:drawUnitCard(unit, x, y, unitWidth - 10, unitHeight - 10)
    end
    
    -- Draw instructions
    love.graphics.print("ESC: Return to overworld | A: Add unit", 10, self.screenHeight - 30)
end

function Game:drawUnitCard(unit, x, y, width, height)
    -- Draw unit card background
    love.graphics.setColor(0.2, 0.2, 0.3, 1.0)
    love.graphics.rectangle('fill', x, y, width, height)
    
    -- Draw unit card border
    love.graphics.setColor(0.4, 0.4, 0.5, 1.0)
    love.graphics.rectangle('line', x, y, width, height)
    
    -- Draw unit info
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(unit.type, x + 5, y + 5)
    
    local info = unit:getInfo()
    love.graphics.print("ATK: " .. info.attack, x + 5, y + 20)
    love.graphics.print("DEF: " .. info.defense, x + 5, y + 35)
    love.graphics.print("HP: " .. info.health, x + 5, y + 50)
=======
    -- Draw instructions
    love.graphics.print("WASD/Arrows: Move | Enter: Interact | ESC: Quit", 10, self.screenHeight - 25)
>>>>>>> origin/cursor/enable-bandit-parties-to-wander-towns-2efd
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
    if self.state == "encounter" then
        Encounter:keypressed(key, function(...)
            self:startBattle(...)
        end, function(party)
            Party:removeParty(party)
        end)
        return
    end
    if key == 'escape' then
        if self.state == "town" then
            self:exitTown()
        elseif self.state == "battle" then
            -- Allow escaping from battle (with penalty)
            self.player:addGold(-10)
            self:exitBattle()
        elseif self.state == "army" then
            self:exitArmyScreen()
        else
            love.event.quit()
        end
    elseif key == 'i' and self.state == "overworld" then
        -- Enter army inspection screen
        self:enterArmyScreen()
    elseif key == 'return' and self.state == "overworld" then
        -- Check for town interactions
        local nearbyTown = self.overworld:checkTownInteraction(self.player.x, self.player.y)
        if nearbyTown then
            self:enterTown(nearbyTown)
        end
    elseif self.state == "town" then
        self.town:keypressed(key)
    elseif self.state == "battle" then
        self.battle:keypressed(key)
    elseif self.state == "army" then
        self:armyKeypressed(key)
    end
end

function Game:gamepadpressed(joystick, button)
    -- Handle gamepad button presses
    if button == 'start' or button == 'back' then
        -- Start/Back button acts like ESC
        if self.state == "town" then
            self:exitTown()
        elseif self.state == "battle" then
            -- Allow escaping from battle (with penalty)
            self.player:addGold(-10)
            self:exitBattle()
        elseif self.state == "army" then
            self:exitArmyScreen()
        else
            love.event.quit()
        end
    elseif button == 'a' or button == 'cross' then
        -- A button (Xbox) / Cross button (PlayStation) for interactions
        if self.state == "overworld" then
            -- Check for town interactions
            local nearbyTown = self.overworld:checkTownInteraction(self.player.x, self.player.y)
            if nearbyTown then
                self:enterTown(nearbyTown)
            end
        elseif self.state == "army" then
            self:armyKeypressed('a')
        end
    elseif button == 'y' or button == 'triangle' then
        -- Y button (Xbox) / Triangle button (PlayStation) for army screen
        if self.state == "overworld" then
            self:enterArmyScreen()
        end
    elseif button == 'b' or button == 'circle' then
        -- B button (Xbox) / Circle button (PlayStation) for cancel/back
        if self.state == "army" then
            self:exitArmyScreen()
        elseif self.state == "town" then
            self:exitTown()
        end
    end
end

function Game:enterArmyScreen()
    self.state = "army"
end

function Game:exitArmyScreen()
    self.state = "overworld"
end

function Game:armyKeypressed(key)
    if key == 'a' then
        if self.player:getGold() >= 10 then -- Example cost for adding a unit
            self.player:addGold(-10)
            self.player:addUnit("Soldier") -- Add a soldier unit
            print("Added soldier to army. Gold: " .. self.player:getGold())
        else
            print("Not enough gold to add unit.")
        end
=======
        else
            love.event.quit()
        end
    elseif self.state == "town" then
        self.town:keypressed(key)
>>>>>>> origin/cursor/enable-bandit-parties-to-wander-towns-2efd
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

local GRID_SIZE = 128

function Game:getCell(x, y)
    return math.floor(x / GRID_SIZE), math.floor(y / GRID_SIZE)
end

function Game:buildPartyGrid()
    local grid = {}
    for _, party in ipairs(self.battle_triggers.parties) do
        local cx, cy = self:getCell(party.x, party.y)
        grid[cx] = grid[cx] or {}
        grid[cx][cy] = grid[cx][cy] or {}
        table.insert(grid[cx][cy], party)
    end
    self.partyGrid = grid
end

function Game:getNearbyParties(px, py, radius)
    local cx, cy = self:getCell(px, py)
    local parties = {}
    for dx = -1, 1 do
        for dy = -1, 1 do
            local cell = self.partyGrid[cx + dx] and self.partyGrid[cx + dx][cy + dy]
            if cell then
                for _, party in ipairs(cell) do
                    local dist = math.sqrt((px - party.x)^2 + (py - party.y)^2)
                    if dist < radius then
                        table.insert(parties, party)
                    end
                end
            end
        end
    end
    return parties
end

-- Call Game:buildPartyGrid() whenever parties move or are added/removed
-- Refactor checkBattleTriggers to use getNearbyParties instead of iterating all parties

return Game