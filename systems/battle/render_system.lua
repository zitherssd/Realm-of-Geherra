-- systems/battle/render_system.lua
-- Handles visual updates (lerping) and drawing

local RenderSystem = {}

local CELL_OFFSETS = {
    [1] = {{0, 0}},
    [2] = {{0.25, -0.25}, {-0.25, 0.25}},
    [3] = {{0, -0.25}, {-0.25, 0.25}, {0.25, 0.25}},
    [4] = {{-0.25, -0.25}, {0.25, -0.25}, {-0.25, 0.25}, {0.25, 0.25}},
    [5] = {{0, 0}, {-0.3, -0.3}, {0.3, -0.3}, {-0.3, 0.3}, {0.3, 0.3}},
    [6] = {{-0.15, -0.3}, {0.15, -0.3}, {-0.3, 0}, {0.3, 0}, {-0.15, 0.3}, {0.15, 0.3}},
    [7] = {{0, 0}, {-0.3, -0.15}, {0.3, -0.15}, {-0.3, 0.15}, {0.3, 0.15}, {-0.15, -0.35}, {0.15, -0.35}},
    [8] = {{-0.15, -0.35}, {0.15, -0.35}, {-0.35, -0.15}, {0.35, -0.15}, {-0.35, 0.15}, {0.35, 0.15}, {-0.15, 0.35}, {0.15, 0.35}},
    [9] = {{0,0}, {-0.3, 0}, {0.3, 0}, {0, -0.3}, {0, 0.3}, {-0.3, -0.3}, {0.3, -0.3}, {-0.3, 0.3}, {0.3, 0.3}},
    [10] = {{-0.15, -0.35}, {0.15, -0.35}, {-0.35, -0.15}, {0.35, -0.15}, {-0.35, 0.15}, {0.35, 0.15}, {-0.15, 0.35}, {0.15, 0.35}, {-0.15, 0}, {0.15, 0}}
}

local imageCache = {}

-- Simple Flash Shader
local flashShader = love.graphics.newShader[[
    extern vec3 flashColor;
    extern number flashAmount;
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, texture_coords);
        vec3 flashed = mix(pixel.rgb, flashColor, flashAmount);
        return vec4(flashed, pixel.a) * color;
    }
]]

local function getImage(path)
    if not path then return nil end
    if imageCache[path] == nil then
        local status, img = pcall(love.graphics.newImage, path)
        if status then
            imageCache[path] = img
        else
            imageCache[path] = false -- Mark as failed so we don't try again
        end
    end
    return imageCache[path] or nil
end

function RenderSystem.update(dt, context)
    local units = context.data.unitList
    local grid = context.data.grid
    local LERP_SPEED = 10.0

    -- Pre-calculate target positions for all units
    local unitTargetPositions = {}
    if grid then
        for x = 1, grid.width do
            for y = 1, grid.height do
                local occupants = grid:getOccupants(x, y)
                local occupantCount = #occupants
                if occupantCount > 0 then
                    local offsets = CELL_OFFSETS[occupantCount] or {}
                    for i, unitId in ipairs(occupants) do
                        local unit = context.data.units[unitId]
                        if unit then
                            local cellCenterX, cellCenterY = grid:gridToWorld(unit.x, unit.y)
                            local offsetX, offsetY = 0, 0
                            if offsets[i] then
                                offsetX = (offsets[i][1] or 0) * grid.cellSize
                                offsetY = (offsets[i][2] or 0) * grid.cellSize
                            end
                            unitTargetPositions[unit.id] = {
                                x = cellCenterX + offsetX,
                                y = cellCenterY + offsetY
                            }
                        end
                    end
                end
            end
        end
    end

    for _, unit in ipairs(units) do
        -- Calculate target visual position from grid
        local target = unitTargetPositions[unit.id]
        if not target then
            target = {x=0, y=0}
            local targetX, targetY = grid:gridToWorld(unit.x, unit.y)
            target.x = targetX
            target.y = targetY
        end
        
        -- Lerp visual position
        local dx = target.x - unit.visualX
        local dy = target.y - unit.visualY
        
        if math.abs(dx) < 1 and math.abs(dy) < 1 then
            unit.visualX = target.x
            unit.visualY = target.y
        else
            unit.visualX = unit.visualX + dx * LERP_SPEED * dt
            unit.visualY = unit.visualY + dy * LERP_SPEED * dt
        end
        
        -- Update Visual Effects
        if unit.visualEffects then
            if unit.visualEffects.shakeTime > 0 then
                unit.visualEffects.shakeTime = math.max(0, unit.visualEffects.shakeTime - dt) -- Decay in seconds
            end
            if unit.visualEffects.flashTime > 0 then
                unit.visualEffects.flashTime = math.max(0, unit.visualEffects.flashTime - dt)
            end
            if unit.visualEffects.lungeTime > 0 then
                unit.visualEffects.lungeTime = math.max(0, unit.visualEffects.lungeTime - dt)
            end
        end
    end
    
    -- Update Projectiles (Visual Interpolation)
    local projectiles = context.data.projectiles
    if projectiles then
        local PROJ_LERP = 15.0 -- Fast lerp for projectiles
        for _, proj in ipairs(projectiles) do
            local dx = proj.x - proj.visualX
            local dy = proj.y - proj.visualY
            proj.visualX = proj.visualX + dx * PROJ_LERP * dt
            proj.visualY = proj.visualY + dy * PROJ_LERP * dt
        end
    end
    
    -- Update Camera
    local camera = context.data.camera
    local selectedUnitId = context.data.selectedUnitId
    local unit = context.data.units[selectedUnitId]
    
    if camera and unit then
        local screenW = love.graphics.getWidth()
        local screenH = love.graphics.getHeight()
        
        -- Target is unit position centered on screen
        local targetX = unit.visualX - screenW / 2
        local targetY = unit.visualY - screenH / 2
        
        -- Lerp camera
        local camSpeed = 5.0
        camera.x = camera.x + (targetX - camera.x) * camSpeed * dt
        camera.y = camera.y + (targetY - camera.y) * camSpeed * dt
    end
    
    -- Update Floating Texts
    local texts = context.data.floatingTexts
    if texts then
        for i = #texts, 1, -1 do
            local txt = texts[i]
            txt.time = txt.time + dt
            txt.offsetY = txt.offsetY - (30 * dt) -- Float up 30px/sec
            
            if txt.time >= txt.duration then
                table.remove(texts, i)
            end
        end
    end
end

function RenderSystem.draw(context)
    local grid = context.data.grid
    if not grid then return end
    
    local camera = context.data.camera
    love.graphics.push()
    if camera then
        local screenW = love.graphics.getWidth()
        local screenH = love.graphics.getHeight()
        local zoom = camera.zoom or 1.0
        
        -- Scale around screen center
        love.graphics.translate(screenW / 2, screenH / 2)
        love.graphics.scale(zoom)
        love.graphics.translate(-screenW / 2, -screenH / 2)
        
        love.graphics.translate(-math.floor(camera.x), -math.floor(camera.y))
    end
    
    -- 1. Draw Grid
    love.graphics.setLineWidth(1)
    for x = 1, grid.width do
        for y = 1, grid.height do
            local wx, wy = grid:gridToWorld(x, y)
            local size = grid.cellSize
            
            -- Draw cell background
            if grid:isWalkable(x, y) then
                love.graphics.setColor(0.2, 0.2, 0.2, 0.5)
            else
                love.graphics.setColor(0.5, 0.2, 0.2, 0.5)
            end
            love.graphics.rectangle("fill", wx - size/2, wy - size/2, size, size)
            
            -- Draw cell border
            love.graphics.setColor(0.3, 0.3, 0.3, 1)
            love.graphics.rectangle("line", wx - size/2, wy - size/2, size, size)
        end
    end
    
    -- 2. Draw Units
    for _, unit in ipairs(context.data.unitList) do
        if unit.hp > 0 then
            local sprite = getImage(unit.actor.sprite)
            local drawX, drawY = unit.visualX, unit.visualY
            
            -- Apply Shake Offset
            if unit.visualEffects and unit.visualEffects.shakeTime > 0 then
                local magnitude = 3 * (unit.visualEffects.shakeTime * 4) -- Decay magnitude (0.5s * 4 = 2 -> 6px offset)
                drawX = drawX + (math.random() - 0.5) * magnitude
                drawY = drawY + (math.random() - 0.5) * magnitude
            end
            
            -- Apply Lunge Offset
            if unit.visualEffects and unit.visualEffects.lungeTime > 0 then
                local p = 1.0 - (unit.visualEffects.lungeTime / unit.visualEffects.lungeDuration)
                local offset = math.sin(p * math.pi) * (grid.cellSize * 0.3) -- Lunge 20% of a cell
                drawX = drawX + unit.visualEffects.lungeX * offset
                drawY = drawY + unit.visualEffects.lungeY * offset
            end
            
            if sprite then
                love.graphics.setColor(1, 1, 1, 1)
                
                -- Apply Flash Shader
                if unit.visualEffects and unit.visualEffects.flashTime > 0 then
                    local baseIntensity = unit.visualEffects.flashIntensity or 0.7
                    local duration = unit.visualEffects.flashDuration or 1.0
                    
                    -- Calculate fade (1.0 -> 0.0)
                    local fade = math.min(1, math.max(0, unit.visualEffects.flashTime / duration))
                    local intensity = baseIntensity * fade
                    
                    flashShader:send("flashColor", unit.visualEffects.flashColor)
                    flashShader:send("flashAmount", intensity)
                    love.graphics.setShader(flashShader)
                end
                
                local w, h = sprite:getDimensions()
                -- Scale to fit 80% of cell
                local scale = (grid.cellSize * 0.8) / math.max(w, h)
                love.graphics.draw(sprite, drawX, drawY, 0, scale * (unit.facing or 1), scale, w/2, h)
                
                love.graphics.setShader() -- Reset shader
            else
                -- Fallback: Colored Circle
                if unit.team == "player" then
                    love.graphics.setColor(0.2, 0.8, 0.2, 1)
                elseif unit.team == "enemy" then
                    love.graphics.setColor(0.8, 0.2, 0.2, 1)
                else
                    love.graphics.setColor(0.8, 0.8, 0.2, 1)
                end
                love.graphics.circle("fill", drawX, drawY, grid.cellSize * 0.3)
            end
            
            -- Draw HP Bar
            local barWidth = grid.cellSize * 0.8
            local barHeight = 4
            local barX = drawX - barWidth / 2
            local barY = drawY + 5
            
            -- Background (Dark Red)
            love.graphics.setColor(0.3, 0, 0, 1)
            love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
            
            -- Foreground (Green)
            local hpPercent = math.max(0, unit.hp / math.max(1, unit.maxHp))
            love.graphics.setColor(0.2, 0.8, 0.2, 1)
            love.graphics.rectangle("fill", barX, barY, barWidth * hpPercent, barHeight)
        end
    end
    
    -- 3. Draw Projectiles
    local projectiles = context.data.projectiles
    if projectiles then
        for _, proj in ipairs(projectiles) do
            local sprite = getImage(proj.sprite)
            if sprite then
                -- Get target world coordinates from grid coordinates
                local tx, ty = grid:gridToWorld(proj.targetGridX, proj.targetGridY)

                -- Recalculate progress based on visual position for smooth arc
                local visualProgress = proj.progress or 0
                local totalDist = math.sqrt((tx - proj.startX)^2 + (ty - proj.startY)^2)
                if totalDist > 0 then
                    local currentDist = math.sqrt((tx - proj.visualX)^2 + (ty - proj.visualY)^2)
                    visualProgress = 1.0 - (currentDist / totalDist)
                end

                -- Calculate Arc Offset
                local arcOffset = 0
                if proj.arc and proj.arc > 0 then
                    arcOffset = -4 * proj.arc * visualProgress * (1 - visualProgress)
                end
                
                -- Calculate Rotation
                local dx = tx - proj.startX
                local dy_linear = ty - proj.startY
                local dy_arc = 0
                if proj.arc and proj.arc > 0 then
                    -- Derivative of the arc parabola
                    dy_arc = -4 * proj.arc * (1 - 2 * visualProgress)
                end

                local target_angle = math.atan2(dy_linear + dy_arc, dx)
                
                local horizontal_angle = 0
                if dx < 0 then
                    horizontal_angle = math.pi
                end

                -- Interpolate between horizontal and target angle
                local rotation = (horizontal_angle + target_angle) / 2
                
                -- Determine flip and adjust rotation
                local sx = 1
                if dx < 0 then
                    sx = -1
                    -- We must adjust the angle to compensate for the horizontal flip
                    rotation = math.pi - rotation
                end

                local drawX = proj.visualX
                local drawY = proj.visualY + arcOffset
                
                -- Draw centered
                local w, h = sprite:getDimensions()
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(sprite, drawX, drawY, rotation, sx, 1, w/2, h/2)
            end
        end
    end
    
    -- 4. Draw Floating Texts
    local texts = context.data.floatingTexts
    if texts then
        for _, txt in ipairs(texts) do
            local alpha = 1.0 - (txt.time / txt.duration)
            love.graphics.setColor(txt.color[1], txt.color[2], txt.color[3], alpha)
            love.graphics.print(txt.text, txt.x - 5, txt.y + txt.offsetY - 20, 0, 0.7, 0.7)
        end
    end
    
    love.graphics.pop()
end

return RenderSystem