local UnitListPanel = {}

function UnitListPanel:draw(units, selected, x, y, w, h, focus)
  local gridCell = 56
  local gridPad = 8
  local cols = math.floor((w + gridPad) / (gridCell + gridPad))
  
  for i, unit in ipairs(units) do
    local col = (i-1) % cols
    local row = math.floor((i-1) / cols)
    local cx, cy = x + col*(gridCell+gridPad), y + row*(gridCell+gridPad)
    
    -- Draw selection highlight (focus state ignored; always same style)
    if i == selected then
      love.graphics.setColor(1, 1, 0, 0.7)
      love.graphics.setLineWidth(4)
      love.graphics.rectangle('line', cx-2, cy-2, gridCell+4, gridCell+4, 8, 8)
      love.graphics.setLineWidth(1)
    end
    
    -- Draw box
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('line', cx, cy, gridCell, gridCell, 8, 8)
    
    -- Draw sprite if available
       if unit.sprite then
            -- Start clipping
            love.graphics.setScissor(cx, cy, gridCell, gridCell)
            
            -- Calculate center position of the box
            local centerX = cx + gridCell/2
            local centerY = cy + gridCell/2 - 8
            
            love.graphics.setColor(1, 1, 1)
            -- Draw sprite centered, with optional flipping
            -- Parameters: sprite, x, y, rotation, scaleX, scaleY, originX, originY
            love.graphics.draw(
                unit.sprite, 
                centerX, 
                centerY, 
                0,  -- rotation
                unit.facing_right and 1 or -1,  -- scaleX (flip based on facing)
                1,  -- scaleY
                unit.sprite:getWidth()/2,  -- originX (center of sprite)
                unit.sprite:getHeight()/2   -- originY (center of sprite)
            )
            
            -- Reset scissor
            love.graphics.setScissor()
    end
    
    -- Draw text
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(unit.name, cx+2, cy+42, gridCell-4, 'center')
  end
  love.graphics.setColor(1, 1, 1)
end

return UnitListPanel 