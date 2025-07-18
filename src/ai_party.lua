-- AI Party module
-- Represents a neutral or hostile party on the overworld

local Biome = require('src.biome')

local AIParty = {}
AIParty.__index = AIParty

function AIParty:new(args)
    local instance = {
        x = args.x or 0,
        y = args.y or 0,
        type = args.type or 'bandit', -- 'bandit', 'lord', etc.
        faction = args.faction or 'hostile', -- 'hostile', 'neutral', 'friendly'
        color = args.color or {1, 0, 0},
        size = args.size or 14,
        speed = args.speed or 80,
        morale = args.morale or 100,
        state = args.state or 'patrolling', -- 'patrolling', 'chasing', 'resting'
        target = nil, -- For chasing
        patrolPoints = args.patrolPoints or {},
        patrolIndex = 1,
        patrolWait = 0,
        army = args.army or {},
        name = args.name or (args.type == 'bandit' and 'Bandit Party' or 'Lord Party'),
    }
    setmetatable(instance, self)
    return instance
end

function AIParty:update(dt, player)
    -- Get biome at current position
    local biome, effects = Biome:getBiomeAt(self.x, self.y)
    local moveSpeed = self.speed * (effects and effects.speed or 1)
    if effects and effects.impassable then return end

    if self.state == 'patrolling' then
        if #self.patrolPoints > 0 then
            local dest = self.patrolPoints[self.patrolIndex]
            local dx, dy = dest.x - self.x, dest.y - self.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < 5 then
                self.patrolWait = (self.patrolWait or 0) + dt
                if self.patrolWait > 1.5 then
                    self.patrolIndex = self.patrolIndex % #self.patrolPoints + 1
                    self.patrolWait = 0
                end
            else
                self.x = self.x + (dx/dist) * moveSpeed * dt
                self.y = self.y + (dy/dist) * moveSpeed * dt
            end
        end
        -- If player is close and hostile, start chasing
        if self.faction == 'hostile' and player then
            local pdx, pdy = player.x - self.x, player.y - self.y
            local pdist = math.sqrt(pdx*pdx + pdy*pdy)
            if pdist < 180 then
                self.state = 'chasing'
                self.target = player
            end
        end
    elseif self.state == 'chasing' and self.target then
        local dx, dy = self.target.x - self.x, self.target.y - self.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist > 300 then
            self.state = 'patrolling'
            self.target = nil
        else
            self.x = self.x + (dx/dist) * moveSpeed * dt
            self.y = self.y + (dy/dist) * moveSpeed * dt
        end
    elseif self.state == 'resting' then
        -- Could implement healing or waiting
    end
    -- Clamp to map bounds
    self.x = math.max(0, math.min(self.x, 2048))
    self.y = math.max(0, math.min(self.y, 2048))
end

function AIParty:draw()
    love.graphics.setColor(self.color)
    love.graphics.circle('fill', self.x, self.y, self.size)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(self.name, self.x - self.size, self.y - self.size - 12)
end

return AIParty