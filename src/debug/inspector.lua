-- debug/inspector.lua
-- Debug inspector for entities and systems

local Inspector = {}

Inspector.enabled = false
Inspector.selectedEntity = nil

function Inspector.toggle()
    Inspector.enabled = not Inspector.enabled
end

function Inspector.inspect(entity)
    Inspector.selectedEntity = entity
end

function Inspector.draw()
    if not Inspector.enabled or not Inspector.selectedEntity then return end
    
    local entity = Inspector.selectedEntity
    
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 800, 0, 224, 600)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Entity Inspector", 810, 10)
    love.graphics.print("ID: " .. (entity.id or "N/A"), 810, 40)
    love.graphics.print("Type: " .. (entity.type or "N/A"), 810, 60)
    
    if entity.stats then
        love.graphics.print("Health: " .. entity.stats.health, 810, 90)
    end
end

return Inspector
