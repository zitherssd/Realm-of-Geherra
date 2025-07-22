local WorldMapModule = {}

WorldMapModule.width = 1024
WorldMapModule.height = 768

function WorldMapModule:update(dt)
  -- Map logic (e.g., scrolling, effects) goes here
end

function WorldMapModule:draw()
  -- Placeholder: draw a simple rectangle as the map
  love.graphics.setColor(0.2, 0.6, 0.3)
  love.graphics.rectangle('fill', 0, 0, self.width, self.height)
  love.graphics.setColor(1, 1, 1)
end

return WorldMapModule 