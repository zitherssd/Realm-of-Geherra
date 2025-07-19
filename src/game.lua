-- Main game state manager
-- This module handles the overall game state and coordinates between different game modes

local Player = require('src.player')
local Overworld = require('src.overworld')
local Town = require('src.town')
local Battle = require('src.battle')
local Utils = require('src.utils')

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
    },
    
    -- Battle triggers
    battle_triggers = {
        -- Random encounter chance per second
        encounter_chance = 0.01,
        encounter_timer = 0,
        
        -- Parties on the map
        parties = {
            {x = 600, y = 400, size = 3, types = {"soldier", "archer", "soldier"}, party_type = "enemy"},
            {x = 1200, y = 800, size = 4, types = {"knight", "soldier", "archer", "soldier"}, party_type = "enemy"},
            {x = 400, y = 1200, size = 2, types = {"peasant", "soldier"}, party_type = "enemy"},
            {x = 1000, y = 1000, size = 3, types = {"peasant", "soldier", "archer"}, party_type = "bandit"},
            {x = 1500, y = 1500, size = 2, types = {"soldier", "archer"}, party_type = "bandit"}
        }
    }
}

function Game:init()
    -- Initialize the game systems
    self.player = Player:new()
    self.overworld = Overworld:new()
    self.town = Town:new()
    
    -- Connect player to overworld for collision detection
    self.player:setOverworld(self.overworld)
    
    -- Initialize bandit parties around settlements
    self:initializeBanditParties()
    
    -- Center camera on player
    self.camera.x = self.player.x - self.screenWidth / 2
    self.camera.y = self.player.y - self.screenHeight / 2
    
    print("Game initialized. Use WASD or arrow keys to move, Enter to interact with towns, ESC to quit.")
end

function Game:initializeBanditParties()
    local towns = self.overworld:getAllTowns()
    
    for _, town in ipairs(towns) do
        -- Create 1-3 bandit parties per settlement
        local numParties = math.random(1, 3)
        
        for i = 1, numParties do
            local banditParty = self:createBanditParty(town)
            table.insert(self.battle_triggers.parties, banditParty)
        end
    end
end

function Game:createBanditParty(town)
    -- Random number of bandits (1-5)
    local numBandits = math.random(1, 5)
    
    -- Random bandit types
    local banditTypes = {"peasant", "soldier", "archer"}
    local types = {}
    
    for i = 1, numBandits do
        local randomType = banditTypes[math.random(1, #banditTypes)]
        table.insert(types, randomType)
    end
    
    -- Random position around the settlement
    local angle = math.random() * 2 * math.pi
    local distance = math.random(50, self.battle_triggers.bandit_roam_radius)
    local x = town.x + math.cos(angle) * distance
    local y = town.y + math.sin(angle) * distance
    
    -- Keep within world bounds
    x = math.max(50, math.min(x, 2048 - 50))
    y = math.max(50, math.min(y, 2048 - 50))
    
    return {
        x = x,
        y = y,
        size = numBandits,
        types = types,
        home_town = town,
        target_x = x,
        target_y = y,
        movement_timer = 0,
        movement_duration = math.random(3, 8), -- How long to move to target
        is_moving = false,
        party_type = "bandit"
    }
end

function Game:updateBanditParties(dt)
    self.battle_triggers.bandit_update_timer = self.battle_triggers.bandit_update_timer + dt
    
    if self.battle_triggers.bandit_update_timer >= self.battle_triggers.bandit_update_interval then
        self.battle_triggers.bandit_update_timer = 0
        
        for _, banditParty in ipairs(self.battle_triggers.parties) do
            self:updateBanditParty(banditParty, dt)
        end
    end
end

function Game:updateBanditParty(banditParty, dt)
    if banditParty.is_moving then
        -- Move toward target
        local dx = banditParty.target_x - banditParty.x
        local dy = banditParty.target_y - banditParty.y
        local distance = math.sqrt(dx^2 + dy^2)
        
        if distance > 0 then
            local speed = self.battle_triggers.bandit_movement_speed
            local moveX = (dx / distance) * speed * dt
            local moveY = (dy / distance) * speed * dt
            
            banditParty.x = banditParty.x + moveX
            banditParty.y = banditParty.y + moveY
        end
        
        banditParty.movement_timer = banditParty.movement_timer + dt
        
        if banditParty.movement_timer >= banditParty.movement_duration then
            -- Reached target, stop moving
            banditParty.is_moving = false
            banditParty.x = banditParty.target_x
            banditParty.y = banditParty.target_y
        end
    else
        -- Choose new target position around home town
        local angle = math.random() * 2 * math.pi
        local distance = math.random(30, self.battle_triggers.bandit_roam_radius)
        local targetX = banditParty.home_town.x + math.cos(angle) * distance
        local targetY = banditParty.home_town.y + math.sin(angle) * distance
        
        -- Keep within world bounds
        targetX = math.max(50, math.min(targetX, 2048 - 50))
        targetY = math.max(50, math.min(targetY, 2048 - 50))
        
        banditParty.target_x = targetX
        banditParty.target_y = targetY
        banditParty.movement_timer = 0
        banditParty.movement_duration = math.random(3, 8)
        banditParty.is_moving = true
    end
end

function Game:update(dt)
    if self.state == "overworld" then
        self.player:update(dt)
        self.overworld:update(dt)
        
        -- Update bandit parties
        self:updateBanditParties(dt)
        
        -- Update camera to follow player
        self.camera.x = self.player.x - self.screenWidth / 2
        self.camera.y = self.player.y - self.screenHeight / 2
        
        -- Check for town interactions
        local nearbyTown = self.overworld:checkTownInteraction(self.player.x, self.player.y)
        if nearbyTown and love.keyboard.isDown('return') then
            self:enterTown(nearbyTown)
        end
        
        -- Check for battle triggers
        self:checkBattleTriggers(dt)
        
    elseif self.state == "town" then
        self.town:update(dt)
        
    elseif self.state == "battle" then
        self.battle:update(dt)
        
        -- Check if battle is finished
        if self.battle:isFinished() then
            self:exitBattle()
        end
        
    elseif self.state == "army" then
        -- Army screen - no updates needed
    end
end

function Game:checkBattleTriggers(dt)
    -- Random encounters
    self.battle_triggers.encounter_timer = self.battle_triggers.encounter_timer + dt
    if self.battle_triggers.encounter_timer >= 1.0 then
        self.battle_triggers.encounter_timer = 0
        if math.random() < self.battle_triggers.encounter_chance then
            self:startRandomEncounter()
        end
    end
    
    -- Check for enemy party encounters
    for i, party in ipairs(self.battle_triggers.parties) do
        if party.party_type == "enemy" then
            local distance = math.sqrt((self.player.x - party.x)^2 + (self.player.y - party.y)^2)
            if distance < 50 then
                self:startEnemyPartyBattle(party)
                table.remove(self.battle_triggers.parties, i)
                break
            end
        end
    end
    
    -- Check for bandit party encounters
    for i, banditParty in ipairs(self.battle_triggers.parties) do
        if banditParty.party_type == "bandit" then
            local distance = math.sqrt((self.player.x - banditParty.x)^2 + (self.player.y - banditParty.y)^2)
            if distance < 50 then
                self:startBanditBattle(banditParty)
                table.remove(self.battle_triggers.parties, i)
                break
            end
        end
    end
end

function Game:startRandomEncounter()
    local enemyArmy = {
        {type = "soldier"},
        {type = "archer"}
    }
    
    -- Add more enemies based on player's army size
    if #self.player.army > 2 then
        table.insert(enemyArmy, {type = "soldier"})
    end
    
    self:startBattle("encounter", enemyArmy, "forest")
end

function Game:startEnemyPartyBattle(party)
    local enemyArmy = {}
    for _, unitType in ipairs(party.types) do
        table.insert(enemyArmy, {type = unitType})
    end
    
    self:startBattle("encounter", enemyArmy, "forest")
end

function Game:startBanditBattle(banditParty)
    local enemyArmy = {}
    for _, unitType in ipairs(banditParty.types) do
        table.insert(enemyArmy, {type = unitType})
    end
    
    self:startBattle("bandit_encounter", enemyArmy, "forest")
end

function Game:startBattle(battleType, enemyArmy, backgroundType)
    self.state = "battle"
    
    -- Create battle with player's army and enemy army
    self.battle = Battle:new(battleType, self.player.army, enemyArmy, backgroundType)
    
    -- Set battle end callback
    self.battle:setBattleEndCallback(function(victory)
        -- Remove lost units from player's army
        local lostUnits = self.battle:getLostUnits()
        for _, lostUnit in ipairs(lostUnits) do
            self.player:removeUnitFromArmy(lostUnit)
        end
        
        if victory then
            -- Victory rewards
            self.player:addGold(50)
            print("Battle won! Gained 50 gold.")
            if #lostUnits > 0 then
                print("Lost " .. #lostUnits .. " units in battle.")
            end
        else
            -- Defeat penalties
            self.player:addGold(-20)
            print("Battle lost! Lost 20 gold.")
            if #lostUnits > 0 then
                print("Lost " .. #lostUnits .. " units in battle.")
            end
        end
    end)
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
    
    -- Draw minimap background
    love.graphics.setColor(unpack(minimap.backgroundColor))
    love.graphics.rectangle('fill', x, y, minimap.size, minimap.size)
    
    -- Draw minimap border
    love.graphics.setColor(unpack(minimap.borderColor))
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', x, y, minimap.size, minimap.size)
    
    -- Calculate minimap scale and offset (center on player)
    local scale = minimap.scale
    local offsetX = x + minimap.size / 2
    local offsetY = y + minimap.size / 2
    
    -- Draw terrain features
    for _, feature in ipairs(self.overworld.terrain) do
        if feature.type == "forest" then
            love.graphics.setColor(0.2, 0.5, 0.2, 0.6) -- Dark green for forests
            local forestX = (feature.x - self.player.x) * scale
            local forestY = (feature.y - self.player.y) * scale
            local forestW = feature.width * scale
            local forestH = feature.height * scale
            
            if forestX >= -minimap.size/2 and forestX <= minimap.size/2 and 
               forestY >= -minimap.size/2 and forestY <= minimap.size/2 then
                love.graphics.rectangle('fill', offsetX + forestX, offsetY + forestY, forestW, forestH)
            end
        elseif feature.type == "mountain" then
            love.graphics.setColor(0.4, 0.4, 0.4, 0.7) -- Gray for mountains
            local mountainX = (feature.x - self.player.x) * scale
            local mountainY = (feature.y - self.player.y) * scale
            local mountainW = feature.width * scale
            local mountainH = feature.height * scale
            
            if mountainX >= -minimap.size/2 and mountainX <= minimap.size/2 and 
               mountainY >= -minimap.size/2 and mountainY <= minimap.size/2 then
                love.graphics.rectangle('fill', offsetX + mountainX, offsetY + mountainY, mountainW, mountainH)
            end
        end
    end
    
    -- Draw water features (lakes and rivers)
    love.graphics.setColor(unpack(minimap.waterColor))
    for _, feature in ipairs(self.overworld.terrain) do
        if feature.type == "lake" then
            local centerX = (feature.x + feature.width / 2 - self.player.x) * scale
            local centerY = (feature.y + feature.height / 2 - self.player.y) * scale
            local radiusX = feature.width * scale / 2
            local radiusY = feature.height * scale / 2
            
            if centerX >= -minimap.size/2 and centerX <= minimap.size/2 and 
               centerY >= -minimap.size/2 and centerY <= minimap.size/2 then
                love.graphics.ellipse('fill', offsetX + centerX, offsetY + centerY, radiusX, radiusY)
            end
        elseif feature.type == "river" then
            local riverX = (feature.x - self.player.x) * scale
            local riverY = (feature.y - self.player.y) * scale
            local riverW = feature.width * scale
            local riverH = feature.height * scale
            
            if riverX >= -minimap.size/2 and riverX <= minimap.size/2 and 
               riverY >= -minimap.size/2 and riverY <= minimap.size/2 then
                love.graphics.rectangle('fill', offsetX + riverX, offsetY + riverY, riverW, riverH)
            end
        end
    end
    
    -- Draw roads on minimap
    love.graphics.setColor(0.6, 0.4, 0.2, 0.8) -- Brown for roads
    love.graphics.setLineWidth(1)
    for _, road in ipairs(self.overworld.roads) do
        local fromX = (road.from[1] - self.player.x) * scale
        local fromY = (road.from[2] - self.player.y) * scale
        local toX = (road.to[1] - self.player.x) * scale
        local toY = (road.to[2] - self.player.y) * scale
        
        -- Only draw roads that are at least partially visible
        if (fromX >= -minimap.size/2 or toX >= -minimap.size/2) and 
           (fromX <= minimap.size/2 or toX <= minimap.size/2) and
           (fromY >= -minimap.size/2 or toY >= -minimap.size/2) and
           (fromY <= minimap.size/2 or toY <= minimap.size/2) then
            love.graphics.line(offsetX + fromX, offsetY + fromY, offsetX + toX, offsetY + toY)
        end
    end
    
    -- Draw towns on minimap with different colors based on type
    for _, town in ipairs(self.overworld.towns) do
        local townX = (town.x - self.player.x) * scale
        local townY = (town.y - self.player.y) * scale
        local townSize = math.max(2, town.size * scale / 4) -- Minimum size of 2 pixels
        
        -- Only draw towns that are within the minimap bounds
        if townX >= -minimap.size/2 and townX <= minimap.size/2 and 
           townY >= -minimap.size/2 and townY <= minimap.size/2 then
            
            -- Set color based on town type
            if town.type == "village" then
                love.graphics.setColor(0.8, 0.6, 0.2, 1) -- Gold for villages
            elseif town.type == "city" then
                love.graphics.setColor(0.7, 0.7, 0.7, 1) -- Gray for cities
            elseif town.type == "port" then
                love.graphics.setColor(0.2, 0.4, 0.8, 1) -- Blue for ports
            elseif town.type == "fortress" then
                love.graphics.setColor(0.5, 0.5, 0.5, 1) -- Dark gray for fortresses
            else
                love.graphics.setColor(unpack(minimap.townColor))
            end
            
            love.graphics.circle('fill', offsetX + townX, offsetY + townY, townSize)
            
            -- Draw town border
            love.graphics.setColor(0.2, 0.2, 0.2, 1)
            love.graphics.setLineWidth(1)
            love.graphics.circle('line', offsetX + townX, offsetY + townY, townSize)
        end
    end
    
    -- Draw player position on minimap (centered)
    love.graphics.setColor(unpack(minimap.playerColor))
    -- Player is at (0,0) relative to themselves, so they're at the center
    local playerX = 0
    local playerY = 0
    
    -- Draw player as a small circle (at center)
    love.graphics.circle('fill', offsetX + playerX, offsetY + playerY, 3)
    
    -- Draw player direction indicator (small line)
    local directionX = math.cos(self.player.rotation) * 6
    local directionY = math.sin(self.player.rotation) * 6
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(
        offsetX + playerX, 
        offsetY + playerY, 
        offsetX + playerX + directionX, 
        offsetY + playerY + directionY
    )
    
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
    love.graphics.print("ESC: Return to overworld | A: Add unit (if you have gold)", 10, self.screenHeight - 30)
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

return Game