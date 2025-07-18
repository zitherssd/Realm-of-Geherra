-- Party module
-- Handles party stats, movement, and biome effects

local Biome = require('src.biome')

local Party = {}

function Party:new(x, y)
    local instance = {
        x = x or 512,
        y = y or 384,
        morale = 100,
        movement_speed = 100,
        healing_rate = 1.0,
        current_biome = 'plains',
        impassable = false,
        size = 16,
        color = {0.2, 0.6, 1.0},
    }
    setmetatable(instance, {__index = self})
    return instance
end

function Party:update(dt)
    local moveX, moveY = 0, 0
    if love.keyboard.isDown('w') or love.keyboard.isDown('up') then moveY = moveY - 1 end
    if love.keyboard.isDown('s') or love.keyboard.isDown('down') then moveY = moveY + 1 end
    if love.keyboard.isDown('a') or love.keyboard.isDown('left') then moveX = moveX - 1 end
    if love.keyboard.isDown('d') or love.keyboard.isDown('right') then moveX = moveX + 1 end
    if moveX ~= 0 and moveY ~= 0 then moveX = moveX * 0.707 moveY = moveY * 0.707 end

    -- Get biome at new position
    local biome, effects = Biome:getBiomeAt(self.x, self.y)
    self.current_biome = biome
    self.impassable = effects.impassable
    self.healing_rate = effects.healing
    local speed = self.movement_speed * effects.speed

    -- Prevent movement on impassable terrain
    if not self.impassable then
        self.x = self.x + moveX * speed * dt
        self.y = self.y + moveY * speed * dt
    end
    -- Clamp to map bounds (assuming 2048x2048 for now)
    self.x = math.max(0, math.min(self.x, 2048))
    self.y = math.max(0, math.min(self.y, 2048))
end

function Party:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle('fill', self.x - self.size/2, self.y - self.size/2, self.size, self.size)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle('fill', self.x, self.y - self.size/4, 2)
end

return Party