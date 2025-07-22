local InventoryPanel = {}

function InventoryPanel:draw(items, selected, x, y, w, h)
  love.graphics.setColor(0.2, 0.15, 0.15, 0.9)
  love.graphics.rectangle('fill', x, y, w, h, 8, 8)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Inventory", x, y + 8, w, 'center')
  for i, item in ipairs(items) do
    local iy = y + 30 + (i-1)*28
    if i == selected then
      love.graphics.setColor(1, 1, 0)
    else
      love.graphics.setColor(1, 1, 1)
    end
    local qty = item.quantity and (" x" .. item.quantity) or ""
    love.graphics.printf(item.name .. qty, x + 10, iy, w - 20, 'left')
  end
  love.graphics.setColor(1, 1, 1)
end

return InventoryPanel 