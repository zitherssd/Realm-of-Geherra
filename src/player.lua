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
        
        -- Visual
        color = {0.2, 0.6, 1.0}, -- Blue color
        size = 16
    }
    
    -- Add a starting unit to the army
    table.insert(instance.army, ArmyUnit:new("Peasant"))
    
    setmetatable(instance, {__index = self})
    return instance
end

function Player:update(dt)
    -- Handle movement input
    local moveX, moveY = 0, 0
    
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
    
    -- Normalize diagonal movement
    if moveX ~= 0 and moveY ~= 0 then
        moveX = moveX * 0.707
        moveY = moveY * 0.707
    end
    
    -- Apply movement
    local newX = self.x + moveX * self.speed * dt
    local newY = self.y + moveY * self.speed * dt
    local biome = nil
    if self.overworld and self.overworld.getBiomeAt then
        biome = self.overworld:getBiomeAt(newX, newY)
    end
    if biome and biome.passable == false then
        -- Block movement into impassable biome (e.g., water)
        return
    end
    self.x = newX
    self.y = newY
    
    -- Keep player within reasonable bounds
    self.x = math.max(0, math.min(self.x, 2048))
    self.y = math.max(0, math.min(self.y, 2048))
end

function Player:draw()
    -- Draw player as a rectangle
    love.graphics.setColor(self.color)
    love.graphics.rectangle('fill', self.x - self.size/2, self.y - self.size/2, self.size, self.size)
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