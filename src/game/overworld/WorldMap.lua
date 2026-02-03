local WorldMap = {}

WorldMap.width = 1660
WorldMap.height = 1174
local mapImg = nil

function WorldMap:update(dt)
  -- Map logic (e.g., scrolling, effects) goes here
end

function WorldMap:draw()
  if not mapImg then
    mapImg = love.graphics.newImage('assets/map/visual_map.png')
  end
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(mapImg, 0, 0)
end

return WorldMap 