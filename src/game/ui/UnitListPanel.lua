local UnitListPanel = {}

function UnitListPanel:draw(units, selected, x, y, w, h, focus)
  local gridCell = 56
  local gridPad = 8
  local cols = math.floor((w + gridPad) / (gridCell + gridPad))
  for i, unit in ipairs(units) do
    local col = (i-1) % cols
    local row = math.floor((i-1) / cols)
    local cx, cy = x + col*(gridCell+gridPad), y + row*(gridCell+gridPad)
    if i == selected then
      if focus then
        love.graphics.setColor(1, 1, 0, 0.7) -- yellow highlight for focus
      else
        love.graphics.setColor(0, 0.7, 1, 0.7) -- blue highlight for selected but not focused
      end
      love.graphics.setLineWidth(4)
      love.graphics.rectangle('line', cx-2, cy-2, gridCell+4, gridCell+4, 8, 8)
      love.graphics.setLineWidth(1)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('line', cx, cy, gridCell, gridCell, 8, 8)
    love.graphics.printf(unit.name, cx+2, cy+2, gridCell-4, 'center')
    love.graphics.printf("HP:"..unit.health, cx+2, cy+22, gridCell-4, 'center')
  end
  love.graphics.setColor(1, 1, 1)
end

return UnitListPanel 