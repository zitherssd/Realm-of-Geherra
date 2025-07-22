local UnitListPanel = {}

function UnitListPanel:draw(units, selected, x, y, w, h)
  love.graphics.setColor(0.15, 0.15, 0.2, 0.9)
  love.graphics.rectangle('fill', x, y, w, h, 8, 8)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Units", x, y + 8, w, 'center')
  for i, unit in ipairs(units) do
    local uy = y + 30 + (i-1)*28
    if i == selected then
      love.graphics.setColor(1, 1, 0)
    else
      love.graphics.setColor(1, 1, 1)
    end
    love.graphics.printf(unit.name, x + 10, uy, w - 20, 'left')
  end
  love.graphics.setColor(1, 1, 1)
end

return UnitListPanel 