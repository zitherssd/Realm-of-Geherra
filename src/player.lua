-- Player module
-- Handles player stats, inventory, army, and movement

local ArmyUnit = require('src.army_unit')

local Player = {}

function Player:new()
    local instance = {
        -- Position
        x = 512,
        y = 384,
        
        -- Stats
        strength = 10,
        agility = 10,
        vitality = 10,
        leadership = 10,
        
        -- Resources
        gold = 100,
        
        -- Inventory (future expansion)
        inventory = {
            weapons = {},
            armor = {},
            items = {}
        },
        
        -- Army
        army = {},
        
        -- Movement
        speed = 100,
<<<<<<< HEAD
        rotation = 0, -- Direction the player is facing (in radians)
        
        -- Visual
        color = {0.2, 0.6, 1.0}, -- Blue color
        size = 16,
        
        -- Reference to overworld for collision detection
        overworld = nil
=======
        
        -- Visual
        color = {0.2, 0.6, 1.0}, -- Blue color
        size = 16
>>>>>>> origin/cursor/enable-bandit-parties-to-wander-towns-2efd
    }
    
    -- Add a starting unit to the army
    table.insert(instance.army, ArmyUnit:new("Peasant"))
    
    setmetatable(instance, {__index = self})
    return instance
end

<<<<<<< HEAD
function Player:setOverworld(overworld)
    self.overworld = overworld
end

function Player:update(dt)
    -- Handle movement input (keyboard and gamepad)
    local moveX, moveY = 0, 0
    
    -- Keyboard input
=======
function Player:update(dt)
    -- Handle movement input
    local moveX, moveY = 0, 0
    
>>>>>>> origin/cursor/enable-bandit-parties-to-wander-towns-2efd
    if love.keyboard.isDown('w') or love.keyboard.isDown('up') then
        moveY = moveY - 1
    end
    if love.keyboard.isDown('s') or love.keyboard.isDown('down') then
        moveY = moveY + 1
    end
    if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
        moveX = moveX - 1
    end
    if love.keyboard.isDown('d') or love.keyboard.isDown('right') then
        moveX = moveX + 1
    end
    
<<<<<<< HEAD
    -- Gamepad input
    if love.joystick then
        local joysticks = love.joystick.getJoysticks()
        local gamepad = joysticks[1]
        if gamepad then
            -- Left stick for movement
            local stickX = gamepad:getAxis(1)
            local stickY = gamepad:getAxis(2)
            
            -- Apply deadzone to prevent drift
            local deadzone = 0.2
            if math.abs(stickX) > deadzone then
                moveX = moveX + stickX
            end
            if math.abs(stickY) > deadzone then
                moveY = moveY + stickY
            end
            
            -- D-pad as alternative
            if gamepad:isDown(1) then -- Up
                moveY = moveY - 1
            end
            if gamepad:isDown(2) then -- Down
                moveY = moveY + 1
            end
            if gamepad:isDown(3) then -- Left
                moveX = moveX - 1
            end
            if gamepad:isDown(4) then -- Right
                moveX = moveX + 1
            end
        end
    end
    
=======
>>>>>>> origin/cursor/enable-bandit-parties-to-wander-towns-2efd
    -- Normalize diagonal movement
    if moveX ~= 0 and moveY ~= 0 then
        moveX = moveX * 0.707
        moveY = moveY * 0.707
    end
    
<<<<<<< HEAD
    -- Update rotation based on movement direction
    if moveX ~= 0 or moveY ~= 0 then
        self.rotation = math.atan2(moveY, moveX)
    end
    
    -- Calculate new position
    local newX = self.x + moveX * self.speed * dt
    local newY = self.y + moveY * self.speed * dt
    
    -- Check for collisions if overworld is available
    if self.overworld then
        -- Check X movement
        if self.overworld:canMoveTo(newX, self.y, self.size) then
            self.x = newX
        end
        
        -- Check Y movement
        if self.overworld:canMoveTo(self.x, newY, self.size) then
            self.y = newY
        end
    else
        -- Fallback to old movement if no overworld reference
        self.x = newX
        self.y = newY
    end
    
    -- Keep player within world bounds
    self.x = math.max(self.size/2, math.min(self.x, 2048 - self.size/2))
    self.y = math.max(self.size/2, math.min(self.y, 2048 - self.size/2))
=======
    -- Apply movement
    self.x = self.x + moveX * self.speed * dt
    self.y = self.y + moveY * self.speed * dt
    
    -- Keep player within reasonable bounds
    self.x = math.max(0, math.min(self.x, 2048))
    self.y = math.max(0, math.min(self.y, 2048))
>>>>>>> origin/cursor/enable-bandit-parties-to-wander-towns-2efd
end

function Player:draw()
    -- Draw player as a rectangle
    love.graphics.setColor(self.color)
    love.graphics.rectangle('fill', self.x - self.size/2, self.y - self.size/2, self.size, self.size)
    
    -- Draw a simple direction indicator
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle('fill', self.x, self.y - self.size/4, 2)
end

function Player:getStats()
    return {
        strength = self.strength,
        agility = self.agility,
        vitality = self.vitality,
        leadership = self.leadership,
        gold = self.gold
    }
end

<<<<<<< HEAD
function Player:getGold()
    return self.gold
end

=======
>>>>>>> origin/cursor/enable-bandit-parties-to-wander-towns-2efd
function Player:addGold(amount)
    self.gold = self.gold + amount
end

function Player:spendGold(amount)
    if self.gold >= amount then
        self.gold = self.gold - amount
        return true
    end
    return false
end

function Player:addUnit(unitType)
    local unit = ArmyUnit:new(unitType)
    table.insert(self.army, unit)
end

function Player:removeUnit(index)
    if index > 0 and index <= #self.army then
        table.remove(self.army, index)
    end
end

<<<<<<< HEAD
function Player:removeUnitFromArmy(unitToRemove)
    -- Find and remove the specific unit from the army
    for i, unit in ipairs(self.army) do
        if unit == unitToRemove then
            table.remove(self.army, i)
            return true
        end
    end
    return false
end

=======
>>>>>>> origin/cursor/enable-bandit-parties-to-wander-towns-2efd
function Player:getArmySize()
    return #self.army
end

function Player:getArmyStrength()
    local totalStrength = 0
    for _, unit in ipairs(self.army) do
        totalStrength = totalStrength + unit:getCombatRating()
    end
    return totalStrength
end

function Player:increasestat(stat, amount)
    amount = amount or 1
    if stat == "strength" then
        self.strength = self.strength + amount
    elseif stat == "agility" then
        self.agility = self.agility + amount
    elseif stat == "vitality" then
        self.vitality = self.vitality + amount
    elseif stat == "leadership" then
        self.leadership = self.leadership + amount
    end
end

function Player:canLeadUnits()
    -- Leadership determines how many units the player can command
    return self.leadership * 2 -- 2 units per leadership point
end

function Player:addItemToInventory(itemType, item)
    if not self.inventory[itemType] then
        self.inventory[itemType] = {}
    end
    table.insert(self.inventory[itemType], item)
end

return Player