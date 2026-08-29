-- debug/draw.lua
-- Debug drawing utilities

local DebugDraw = {}

DebugDraw.enabled = false
DebugDraw.drawGrid = false
DebugDraw.drawCollision = false

function DebugDraw.toggle()
    DebugDraw.enabled = not DebugDraw.enabled
end

function DebugDraw.toggleGrid()
    DebugDraw.drawGrid = not DebugDraw.drawGrid
end

function DebugDraw.toggleCollision()
    DebugDraw.drawCollision = not DebugDraw.drawCollision
end

function DebugDraw.draw()
    if not DebugDraw.enabled then return end
    
    if DebugDraw.drawGrid then
        love.graphics.setColor(0.2, 0.2, 0.2)
        local gridSize = 32
        for x = 0, love.graphics.getWidth(), gridSize do
            love.graphics.line(x, 0, x, love.graphics.getHeight())
        end
        for y = 0, love.graphics.getHeight(), gridSize do
            love.graphics.line(0, y, love.graphics.getWidth(), y)
        end
    end
    
    if DebugDraw.drawCollision then
        -- Draw collision boxes
    end
end

return DebugDraw
