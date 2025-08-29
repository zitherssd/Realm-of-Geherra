local unit_types = require('src.data.unit_types')

local UnitRenderer = {}

-- options: {scale=1, ...} (optional)
function UnitRenderer.placeSprites(unit, x, y, options)
  options = options or {}
  local scale = options.scale or 1
  local img = unit.composedImage or unit.composed_image or nil
  if not img and unit.getComposedImage then
    img = unit:getComposedImage()
  end
  if not img and UnitModule and UnitModule.getComposedImage then
    img = UnitModule.getComposedImage(unit)
  end
  if img then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, x, y, 0, scale, scale, img:getWidth()/2, img:getHeight())
  end
end

return UnitRenderer 