-- systems/battle/render_system.lua
-- Handles visual updates (lerping) and drawing

local RenderSystem = {}

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

    for _, unit in ipairs(units) do
        -- Calculate target visual position from grid
        local targetX, targetY = grid:gridToWorld(unit.x, unit.y)
        
        -- Lerp visual position
        local dx = targetX - unit.visualX
        local dy = targetY - unit.visualY
        
        if math.abs(dx) < 1 and math.abs(dy) < 1 then
            unit.visualX = targetX
            unit.visualY = targetY
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
end

function RenderSystem.draw(context)
    local grid = context.data.grid
    if not grid then return end
    
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
                love.graphics.draw(sprite, drawX, drawY, 0, scale, scale, w/2, h/2)
                
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
            local barY = drawY + grid.cellSize * 0.4 + 2
            
            -- Background (Dark Red)
            love.graphics.setColor(0.3, 0, 0, 1)
            love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
            
            -- Foreground (Green)
            local hpPercent = math.max(0, unit.hp / math.max(1, unit.maxHp))
            love.graphics.setColor(0.2, 0.8, 0.2, 1)
            love.graphics.rectangle("fill", barX, barY, barWidth * hpPercent, barHeight)
            
            -- Selection Highlight
            if context.data.selectedUnitId == unit.id then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.circle("line", drawX, drawY, grid.cellSize * 0.4)
            end
        end
    end
end

return RenderSystem