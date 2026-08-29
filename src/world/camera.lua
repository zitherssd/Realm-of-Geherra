-- world/camera.lua
-- Camera system for following the player and viewport management

local Camera = {}
Camera.__index = Camera

function Camera.new(screenWidth, screenHeight)
    local self = {
        x = 0,
        y = 0,
        screenWidth = screenWidth or 1280,
        screenHeight = screenHeight or 720,
        scale = 1.0,
        targetX = 0,
        targetY = 0,
        lerpSpeed = 8.0,  -- Smoothing factor for camera movement
        
        -- Bounds that camera should stay within
        minX = 0,
        minY = 0,
        maxX = 1024,
        maxY = 1024,
    }
    setmetatable(self, Camera)
    return self
end

-- Set the bounds for the camera based on map dimensions
function Camera:setBounds(minX, minY, maxX, maxY)
    self.minX = minX
    self.minY = minY
    self.maxX = maxX
    self.maxY = maxY
end

-- Update camera to follow a target entity
function Camera:update(dt, targetEntity)
    if not targetEntity then return end
    
    -- Target position is center of target entity
    self.targetX = targetEntity.x
    self.targetY = targetEntity.y
    
    -- Smooth camera movement towards target
    self.x = self.x + (self.targetX - self.x) * self.lerpSpeed * dt
    self.y = self.y + (self.targetY - self.y) * self.lerpSpeed * dt
    
    -- Clamp camera to bounds, accounting for screen size
    local viewWidth = self.screenWidth / self.scale
    local viewHeight = self.screenHeight / self.scale
    
    local mapWidth = self.maxX - self.minX
    local mapHeight = self.maxY - self.minY
    
    -- If viewport is larger than map, center the map on screen
    if viewWidth >= mapWidth then
        self.x = self.minX + mapWidth / 2
    else
        -- Clamp so viewport edges stay within bounds
        self.x = math.max(self.minX + viewWidth / 2, math.min(self.x, self.maxX - viewWidth / 2))
    end
    
    if viewHeight >= mapHeight then
        self.y = self.minY + mapHeight / 2
    else
        self.y = math.max(self.minY + viewHeight / 2, math.min(self.y, self.maxY - viewHeight / 2))
    end
end

-- Get view coordinates (what's visible on screen)
function Camera:getViewBounds()
    local viewWidth = self.screenWidth / self.scale
    local viewHeight = self.screenHeight / self.scale
    return self.x - viewWidth / 2, self.y - viewHeight / 2, 
           self.x + viewWidth / 2, self.y + viewHeight / 2
end

-- Convert world coordinates to screen coordinates
function Camera:worldToScreen(worldX, worldY)
    local screenX = (worldX - self.x) * self.scale + self.screenWidth / 2
    local screenY = (worldY - self.y) * self.scale + self.screenHeight / 2
    return screenX, screenY
end

-- Convert screen coordinates to world coordinates
function Camera:screenToWorld(screenX, screenY)
    local worldX = (screenX - self.screenWidth / 2) / self.scale + self.x
    local worldY = (screenY - self.screenHeight / 2) / self.scale + self.y
    return worldX, worldY
end

-- Apply camera transformation to graphics context
function Camera:apply()
    love.graphics.translate(self.screenWidth / 2, self.screenHeight / 2)
    love.graphics.scale(self.scale)
    love.graphics.translate(-self.x, -self.y)
end

-- Reset graphics transformations
function Camera:unapply()
    love.graphics.origin()
end

-- Set zoom level
function Camera:setZoom(scale)
    self.scale = math.max(0.1, scale)  -- Prevent zoom to 0
end

-- Get current zoom level
function Camera:getZoom()
    return self.scale
end

return Camera
