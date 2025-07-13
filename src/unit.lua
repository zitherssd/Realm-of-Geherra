-- Unit module
-- Defines the Unit class used for both allies and enemies in battles

local Unit = {}

function Unit:new(team, unitType, x, y)
    local instance = {
        -- Position
        x = x or 0,
        y = y or 0,
        
        -- Stats
        hp = 100,
        max_hp = 100,
        speed = 50,
        attack_damage = 20,
        attack_range = 30,
        attack_cooldown = 1.0,
        attack_timer = 0,
        
        -- Team (1 = player/ally, 2 = enemy)
        team = team or 1,
        
        -- Unit type for different behaviors
        unit_type = unitType or "soldier",
        
        -- State machine
        state = "idle", -- idle, moving, attacking, dead
        
        -- Visual properties
        width = 20,
        height = 30,
        color = {1, 1, 1, 1},
        
        -- Collision properties (elliptical) - squashed on Y-axis
        collision_radius_x = 15, -- Horizontal radius of collision ellipse (larger)
        collision_radius_y = 8, -- Vertical radius of collision ellipse (smaller)
        collision_offset_y = 10, -- How far down from center the collision ellipse is
        
        -- AI properties
        target = nil,
        pathfinding_timer = 0,
        pathfinding_interval = 0.5,
        
        -- Animation properties
        animation_timer = 0,
        direction = 1, -- 1 for right, -1 for left
        attack_animation_duration = 0.3
    }
    
    -- Set team-specific colors
    if team == 1 then
        instance.color = {0.2, 0.6, 1.0, 1.0} -- Blue for allies
    else
        instance.color = {1.0, 0.2, 0.2, 1.0} -- Red for enemies
    end
    
    -- Set unit type-specific properties
    if unitType == "archer" then
        instance.attack_range = 80
        instance.attack_damage = 15
        instance.speed = 40
        instance.width = 18
        instance.height = 28
        instance.collision_radius_x = 12
        instance.collision_radius_y = 6
    elseif unitType == "knight" then
        instance.hp = 150
        instance.max_hp = 150
        instance.attack_damage = 30
        instance.attack_range = 25
        instance.speed = 35
        instance.width = 22
        instance.height = 32
        instance.collision_radius_x = 18
        instance.collision_radius_y = 10
    elseif unitType == "peasant" then
        instance.hp = 60
        instance.max_hp = 60
        instance.attack_damage = 10
        instance.attack_range = 25
        instance.speed = 45
        instance.width = 16
        instance.height = 26
        instance.collision_radius_x = 10
        instance.collision_radius_y = 5
    end
    
    setmetatable(instance, {__index = self})
    return instance
end

function Unit:update(dt, units)
    if self.state == "dead" then
        return
    end
    
    -- Update attack timer
    if self.attack_timer > 0 then
        self.attack_timer = self.attack_timer - dt
    end
    
    -- Update pathfinding timer
    self.pathfinding_timer = self.pathfinding_timer - dt
    
    -- Find target if we don't have one or if pathfinding timer expired
    if not self.target or self.pathfinding_timer <= 0 then
        self:findTarget(units)
        self.pathfinding_timer = self.pathfinding_interval
    end
    
    -- Push away from other units if too close
    self:pushAwayFromUnits(units)
    
    -- Update based on current state
    if self.state == "idle" then
        self:updateIdle(dt, units)
    elseif self.state == "moving" then
        self:updateMoving(dt, units)
    elseif self.state == "attacking" then
        self:updateAttacking(dt, units)
    end
end

function Unit:pushAwayFromUnits(units)
    local pushForce = 0.5 -- How much to push units apart
    
    for _, unit in ipairs(units) do
        if unit ~= self and unit.state ~= "dead" then
            local dx = self.x - unit.x
            local dy = self.y - unit.y
            local distance = math.sqrt(dx^2 + dy^2)
            
            -- Use elliptical collision check
            if self:checkEllipticalCollision(self.x, self.y, unit) and distance > 0 then
                -- Push both units apart
                local pushX = (dx / distance) * pushForce
                local pushY = (dy / distance) * pushForce
                
                self.x = self.x + pushX
                self.y = self.y + pushY
                unit.x = unit.x - pushX
                unit.y = unit.y - pushY
            end
        end
    end
end

function Unit:findAlternativePath(dt, units)
    -- Try different directions to go around obstacles
    local directions = {
        {dx = 1, dy = 0},   -- Right
        {dx = -1, dy = 0},  -- Left
        {dx = 0, dy = 1},   -- Down
        {dx = 0, dy = -1},  -- Up
        {dx = 1, dy = 1},   -- Diagonal right-down
        {dx = 1, dy = -1},  -- Diagonal right-up
        {dx = -1, dy = 1},  -- Diagonal left-down
        {dx = -1, dy = -1}  -- Diagonal left-up
    }
    
    -- Shuffle directions to prevent congo lines
    for i = #directions, 2, -1 do
        local j = math.random(i)
        directions[i], directions[j] = directions[j], directions[i]
    end
    
    local speed = self.speed * dt
    
    -- Try each direction with full speed
    for _, dir in ipairs(directions) do
        local newX = self.x + dir.dx * speed
        local newY = self.y + dir.dy * speed
        
        if self:canMoveTo(newX, newY, units) then
            -- This direction is clear, move in this direction
            self.x = newX
            self.y = newY
            return
        end
    end
    
    -- If all directions are blocked, try with reduced speed
    local reducedSpeed = speed * 0.5
    for _, dir in ipairs(directions) do
        local newX = self.x + dir.dx * reducedSpeed
        local newY = self.y + dir.dy * reducedSpeed
        
        if self:canMoveTo(newX, newY, units) then
            self.x = newX
            self.y = newY
            return
        end
    end
    
    -- If still blocked, try to find a completely different path
    self:findDistantPath(dt, units)
end

function Unit:findDistantPath(dt, units)
    -- Try to move away from current position to find a clear path
    local directions = {
        {dx = 1, dy = 0},   -- Right
        {dx = -1, dy = 0},  -- Left
        {dx = 0, dy = 1},   -- Down
        {dx = 0, dy = -1},  -- Up
    }
    
    -- Shuffle directions
    for i = #directions, 2, -1 do
        local j = math.random(i)
        directions[i], directions[j] = directions[j], directions[i]
    end
    
    local speed = self.speed * dt * 0.3 -- Very slow movement
    
    for _, dir in ipairs(directions) do
        local newX = self.x + dir.dx * speed
        local newY = self.y + dir.dy * speed
        
        if self:canMoveTo(newX, newY, units) then
            self.x = newX
            self.y = newY
            return
        end
    end
end

function Unit:canMoveTo(newX, newY, units)
    -- Check collision with other units using elliptical collision
    for _, unit in ipairs(units) do
        if unit ~= self and unit.state ~= "dead" then
            if self:checkEllipticalCollision(newX, newY, unit) then
                return false
            end
        end
    end
    
    return true
end

function Unit:checkEllipticalCollision(x1, y1, unit2)
    -- Get collision centers
    local cx1, cy1 = self:getCollisionCenter()
    local cx2, cy2 = unit2:getCollisionCenter()
    
    -- Calculate relative position
    local dx = x1 - cx2
    local dy = (y1 + self.collision_offset_y) - cy2
    
    -- Calculate combined radii
    local rx = self.collision_radius_x + unit2.collision_radius_x
    local ry = self.collision_radius_y + unit2.collision_radius_y
    
    -- Check if point is inside ellipse using ellipse equation
    local normalizedX = dx / rx
    local normalizedY = dy / ry
    local distance = normalizedX * normalizedX + normalizedY * normalizedY
    
    return distance <= 1
end

function Unit:getCollisionCenter()
    -- Return the center of the collision ellipse (at the feet)
    return self.x, self.y + self.collision_offset_y
end

function Unit:updateAttacking(dt, units)
    self.animation_timer = self.animation_timer - dt
    
    if self.animation_timer <= 0 then
        -- Attack animation finished, perform attack
        if self.target and self.target.state ~= "dead" then
            local distance = math.sqrt((self.x - self.target.x)^2 + (self.y - self.target.y)^2)
            
            if distance <= self.attack_range and self.attack_timer <= 0 then
                -- Perform attack
                self.target:takeDamage(self.attack_damage)
                self.attack_timer = self.attack_cooldown
            end
        end
        
        -- Return to idle state
        self.state = "idle"
    end
end

function Unit:takeDamage(damage)
    self.hp = math.max(0, self.hp - damage)
    
    if self.hp <= 0 then
        self.state = "dead"
    end
end

function Unit:draw()
    if self.state == "dead" then
        return
    end
    
    -- Draw unit body
    love.graphics.setColor(self.color)
    love.graphics.rectangle('fill', self.x - self.width/2, self.y - self.height/2, self.width, self.height)
    
    -- Draw direction indicator
    love.graphics.setColor(1, 1, 1, 1)
    local indicator_x = self.x + (self.width/2 + 5) * self.direction
    love.graphics.circle('fill', indicator_x, self.y, 3)
    
    -- Draw health bar
    local bar_width = self.width
    local bar_height = 4
    local bar_x = self.x - bar_width/2
    local bar_y = self.y - self.height/2 - 10
    
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle('fill', bar_x, bar_y, bar_width, bar_height)
    
    -- Health
    local health_ratio = self.hp / self.max_hp
    love.graphics.setColor(0.2, 0.8, 0.2, 1.0)
    love.graphics.rectangle('fill', bar_x, bar_y, bar_width * health_ratio, bar_height)
    
    -- Draw attack animation if attacking
    if self.state == "attacking" then
        love.graphics.setColor(1, 1, 0, 0.7)
        local attack_x = self.x + (self.width/2 + 10) * self.direction
        love.graphics.circle('fill', attack_x, self.y, 8)
    end
    
    -- Debug: Draw collision ellipse (enabled for debugging)
    love.graphics.setColor(0, 1, 0, 0.3)
    local collision_x, collision_y = self:getCollisionCenter()
    love.graphics.ellipse('fill', collision_x, collision_y, self.collision_radius_x, self.collision_radius_y)
    
    -- Draw collision center point
    love.graphics.setColor(1, 0, 0, 0.8)
    love.graphics.circle('fill', collision_x, collision_y, 2)
end

function Unit:isAlive()
    return self.state ~= "dead"
end

function Unit:getTeam()
    return self.team
end

function Unit:findTarget(units)
    local best_score = -1
    local closest_unit = nil
    
    -- Add some randomization to prevent all units targeting the same enemy
    local target_preference = math.random() * 0.3 + 0.85 -- 0.85 to 1.15
    
    for _, unit in ipairs(units) do
        if unit.team ~= self.team and unit.state ~= "dead" then
            local distance = math.sqrt((self.x - unit.x)^2 + (self.y - unit.y)^2)
            
            -- Calculate accessibility score (how easy it is to reach this target)
            local accessibility = self:calculateTargetAccessibility(unit, units)
            local score = (accessibility * target_preference) / (distance + 1) -- Prefer closer, more accessible targets
            
            if score > best_score then
                best_score = score
                closest_unit = unit
            end
        end
    end
    
    self.target = closest_unit
end

function Unit:calculateTargetAccessibility(target, units)
    local accessibility = 1.0
    
    -- Check if there are units blocking the direct path
    local dx = target.x - self.x
    local dy = target.y - self.y
    local distance = math.sqrt(dx^2 + dy^2)
    
    if distance > 0 then
        local numBlockers = 0
        local checkPoints = 5 -- Check 5 points along the path
        
        for i = 1, checkPoints do
            local t = i / checkPoints
            local checkX = self.x + dx * t
            local checkY = self.y + dy * t
            
            for _, unit in ipairs(units) do
                if unit ~= self and unit ~= target and unit.state ~= "dead" then
                    if self:checkEllipticalCollision(checkX, checkY, unit) then
                        numBlockers = numBlockers + 1
                        break
                    end
                end
            end
        end
        
        -- Reduce accessibility based on number of blockers
        accessibility = math.max(0.1, 1.0 - (numBlockers / checkPoints))
    end
    
    return accessibility
end

function Unit:updateIdle(dt, units)
    if self.target then
        local distance = math.sqrt((self.x - self.target.x)^2 + (self.y - self.target.y)^2)
        
        if distance <= self.attack_range then
            -- In attack range, start attacking
            self.state = "attacking"
            self.animation_timer = self.attack_animation_duration
        else
            -- Move toward target
            self.state = "moving"
        end
    end
end

function Unit:updateMoving(dt, units)
    if not self.target or self.target.state == "dead" then
        self.state = "idle"
        return
    end
    
    local distance = math.sqrt((self.x - self.target.x)^2 + (self.y - self.target.y)^2)
    
    if distance <= self.attack_range then
        -- In attack range, stop and attack
        self.state = "attacking"
        self.animation_timer = self.attack_animation_duration
        return
    end
    
    -- Calculate direct path to target
    local dx = self.target.x - self.x
    local dy = self.target.y - self.y
    local length = math.sqrt(dx^2 + dy^2)
    
    if length > 0 then
        dx = dx / length
        dy = dy / length
        
        -- Update direction for visual purposes
        if dx > 0 then
            self.direction = 1
        else
            self.direction = -1
        end
        
        -- Try direct path first
        local newX = self.x + dx * self.speed * dt
        local newY = self.y + dy * self.speed * dt
        
        if self:canMoveTo(newX, newY, units) then
            -- Direct path is clear, move normally
            self.x = newX
            self.y = newY
        else
            -- Direct path blocked, try to find alternative path
            self:findAlternativePath(dt, units)
        end
        
        -- Constrain movement to battle area (with some margin)
        self.x = math.max(50, math.min(self.x, 750))
        self.y = math.max(100, math.min(self.y, 400))
    end
end

return Unit 