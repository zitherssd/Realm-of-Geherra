local LocationsModule = {}

LocationsModule.locations = {}

function LocationsModule:update(dt)
  -- Update locations if needed (e.g., prosperity changes)
end

function LocationsModule:draw()
  -- Draw all locations (placeholder: squares)
  for _, loc in ipairs(self.locations) do
    love.graphics.setColor(0.7, 0.7, 0.9)
    love.graphics.rectangle('fill', loc.position.x - 10, loc.position.y - 10, 20, 20)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print(loc.name, loc.position.x + 12, loc.position.y - 8)
    love.graphics.setColor(1, 1, 1)
  end
end

return LocationsModule 