local UnitPanel = {}

function UnitPanel:draw(unit, selectedSlot, x, y, w, h)
  love.graphics.setColor(0.15, 0.2, 0.15, 0.9)
  love.graphics.rectangle('fill', x, y, w, h, 8, 8)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf(unit.name, x, y + 8, w, 'center')
  -- Stats
  local sy = y + 32
  love.graphics.printf("HP: " .. unit.health .. "  Morale: " .. unit.morale, x + 10, sy, w - 20, 'left')
  love.graphics.printf("ATK: " .. unit.attack .. "  DEF: " .. unit.defense, x + 10, sy + 20, w - 20, 'left')
  -- Equipment slots
  love.graphics.printf("Equipment:", x + 10, sy + 48, w - 20, 'left')
  for i, slot in ipairs(unit.equipmentSlots or {}) do
    local eq = unit.equipment and unit.equipment[slot] or nil
    local label = slot .. ": " .. (eq and eq.name or "-")
    local ey = sy + 48 + i * 22
    if selectedSlot == i then
      love.graphics.setColor(1, 1, 0)
    else
      love.graphics.setColor(1, 1, 1)
    end
    love.graphics.printf(label, x + 24, ey, w - 40, 'left')
  end
  love.graphics.setColor(1, 1, 1)
end

return UnitPanel 