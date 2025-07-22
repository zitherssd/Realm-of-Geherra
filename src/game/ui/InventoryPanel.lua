local InventoryPanel = {}

function InventoryPanel:draw(items, selected, x, y, w, h, focus)
  local gridCell = 56
  local gridPad = 8
  local cols = math.floor((w + gridPad) / (gridCell + gridPad))
  for i, item in ipairs(items) do
    local col = (i-1) % cols
    local row = math.floor((i-1) / cols)
    local cx, cy = x + col*(gridCell+gridPad), y + row*(gridCell+gridPad)
    if i == selected and focus then
      love.graphics.setColor(1, 1, 0, 0.7) -- yellow highlight for focus
      love.graphics.setLineWidth(4)
      love.graphics.rectangle('line', cx-2, cy-2, gridCell+4, gridCell+4, 8, 8)
      love.graphics.setLineWidth(1)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('line', cx, cy, gridCell, gridCell, 8, 8)
    love.graphics.printf(item.name, cx+2, cy+2, gridCell-4, 'center')
    if item.quantity then
      love.graphics.printf("x"..item.quantity, cx+2, cy+22, gridCell-4, 'center')
    end
  end
  love.graphics.setColor(1, 1, 1)
end

return InventoryPanel 