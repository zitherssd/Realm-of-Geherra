local EquipmentPanel = {}

function EquipmentPanel:draw(unit, hoveredSlot, x, y, w, h)
  love.graphics.setColor(0.18, 0.22, 0.18, 0.95)
  love.graphics.rectangle('fill', x, y, w, h, 8, 8)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Equipment", x, y + 8, w, 'center')
  for i, slot in ipairs(unit.equipmentSlots or {}) do
    local sy = y + 30 + (i-1)*38
    if hoveredSlot == i then
      love.graphics.setColor(1, 1, 0, 0.4)
      love.graphics.rectangle('fill', x + 8, sy, w - 16, 32, 6, 6)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('line', x + 8, sy, w - 16, 32, 6, 6)
    local eq = unit.equipment and unit.equipment[slot] or nil
    local label = slot .. ": " .. (eq and eq.name or "-")
    love.graphics.printf(label, x + 16, sy + 8, w - 32, 'left')
  end
  love.graphics.setColor(1, 1, 1)
end

return EquipmentPanel 