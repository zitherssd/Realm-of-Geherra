-- systems/battle/render_system.lua
-- Handles visual updates (lerping) and drawing

local RenderSystem = {}

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
            unit.isMoving = false
        else
            unit.visualX = unit.visualX + dx * LERP_SPEED * dt
            unit.visualY = unit.visualY + dy * LERP_SPEED * dt
            unit.isMoving = true
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
            if unit.team == "player" then
                love.graphics.setColor(0.2, 0.8, 0.2, 1)
            elseif unit.team == "enemy" then
                love.graphics.setColor(0.8, 0.2, 0.2, 1)
            else
                love.graphics.setColor(0.8, 0.8, 0.2, 1)
            end
            
            love.graphics.circle("fill", unit.visualX, unit.visualY, grid.cellSize * 0.3)
            
            -- Selection Highlight
            if context.data.selectedUnitId == unit.id then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.circle("line", unit.visualX, unit.visualY, grid.cellSize * 0.4)
            end
        end
    end
end

return RenderSystem