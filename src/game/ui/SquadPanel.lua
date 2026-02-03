local SquadPanel = {}

-- SquadPanel displays a list of squads or units in rows
-- Each row can contain multiple unit icons
-- Supports highlighting, focus indication, and selection

function SquadPanel:new()
  local panel = {
    squads = {},           -- Array of squads (each squad has units)
    selectedSquad = 1,     -- Currently selected squad row
    selectedUnitInSquad = 1, -- Currently selected unit within the squad
    selectedUnits = {},    -- Map of unit indices that are selected (for multi-select)
    entered = false,       -- Whether we're in "entered" mode (selecting units)
    gridCell = 40,
    gridPad = 4,
    rowHeight = 56
  }
  setmetatable(panel, self)
  self.__index = self
  return panel
end

function SquadPanel:setSquads(squads)
  self.squads = squads or {}
  self.selectedSquad = 1
  self.selectedUnitInSquad = 1
  self.selectedUnits = {}
end

function SquadPanel:enter()
  self.entered = true
  self.selectedUnits = {}
end

function SquadPanel:exit()
  self.entered = false
  self.selectedUnits = {}
end

function SquadPanel:toggleUnitSelection(squadIdx, unitIdx)
  if not self.entered then return end
  local key = squadIdx .. "_" .. unitIdx
  if self.selectedUnits[key] then
    self.selectedUnits[key] = nil
  else
    self.selectedUnits[key] = true
  end
end

function SquadPanel:getSelectedUnits()
  local result = {}
  for key, _ in pairs(self.selectedUnits) do
    table.insert(result, key)
  end
  return result
end

function SquadPanel:clearSelection()
  self.selectedUnits = {}
end

function SquadPanel:onAction(action)
  if not self.entered then return end
  
  local currentSquad = self.squads[self.selectedSquad]
  if not currentSquad or not currentSquad.units then return end
  
  local unitCount = #currentSquad.units
  
  if action == 'navigate_left' then
    if self.selectedUnitInSquad > 1 then
      self.selectedUnitInSquad = self.selectedUnitInSquad - 1
    end
  elseif action == 'navigate_right' then
    if self.selectedUnitInSquad < unitCount then
      self.selectedUnitInSquad = self.selectedUnitInSquad + 1
    end
  elseif action == 'navigate_up' or action == 'navigate_down' then
    -- Do nothing: cannot change selected squad while in selection mode
  elseif action == 'activate' then
    self:toggleUnitSelection(self.selectedSquad, self.selectedUnitInSquad)
  end
end

function SquadPanel:draw(x, y, w, h, focus)
  local gridCell = self.gridCell
  local gridPad = self.gridPad
  local rowHeight = self.rowHeight
  
  for squadIdx, squad in ipairs(self.squads) do
    local squadY = y + (squadIdx - 1) * (rowHeight + 8)
    
    -- Draw squad background/border
    local isSelectedRow = (squadIdx == self.selectedSquad)
    if (isSelectedRow and focus and not self.entered) then
      love.graphics.setColor(1, 1, 0, 0.3) -- selected & focused
    elseif (isSelectedRow and self.entered) then
      love.graphics.setColor(0, 1, 0, 0.3) -- entered selection mode
    else
      love.graphics.setColor(0.2, 0.2, 0.2, 0.5) -- neutral when not focused
    end
    love.graphics.rectangle('fill', x, squadY, w, rowHeight, 4, 4)
    
    -- Draw border
    if isSelectedRow and (focus or self.entered) then
      love.graphics.setColor(1, 1, 0)
      love.graphics.setLineWidth(2)
    elseif isSelectedRow and (not focus and not self.entered) then
      love.graphics.setColor(1, 1, 0, 0.5) -- subtle target indicator when not focused
      love.graphics.setLineWidth(1)
    else
      love.graphics.setColor(0.5, 0.5, 0.5)
      love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle('line', x, squadY, w, rowHeight, 4, 4)
    love.graphics.setLineWidth(1)
    
    -- Draw units in this squad
    if squad.units then
      for unitIdx, unit in ipairs(squad.units) do
        local unitX = x + 8 + (unitIdx - 1) * (gridCell + gridPad)
        local unitY = squadY + (rowHeight - gridCell) / 2
        
        -- Determine selection and hover state
        local key = squadIdx .. "_" .. unitIdx
        local isSelected = self.selectedUnits[key] and true or false
        local isHover = self.entered and focus and squadIdx == self.selectedSquad and unitIdx == self.selectedUnitInSquad

        -- Draw sprite if available (dim if selected)
        if unit.sprite then
          love.graphics.setScissor(unitX, unitY, gridCell, gridCell)
          local centerX = unitX + gridCell / 2
          local centerY = unitY + gridCell / 2 - 4
          if isSelected then
            love.graphics.setColor(1, 1, 1, 0.5)
          else
            love.graphics.setColor(1, 1, 1, 1)
          end
          love.graphics.draw(
            unit.sprite,
            centerX,
            centerY,
            0,
            unit.facing_right and 0.6 or -0.6,
            0.6,
            unit.sprite:getWidth() / 2,
            unit.sprite:getHeight() / 2
          )
          love.graphics.setScissor()
          love.graphics.setColor(1, 1, 1, 1)
        end

        -- Hover indicator: small yellow caret above the sprite box
        if isHover then
          local caretX = unitX + gridCell / 2
          local caretY = unitY - 4
          love.graphics.setColor(1, 1, 0, 0.9)
          love.graphics.polygon('fill',
            caretX, caretY,
            caretX - 6, caretY - 8,
            caretX + 6, caretY - 8
          )
          love.graphics.setColor(1, 1, 1, 1)
        end
      end
    end
  end
  
  love.graphics.setColor(1, 1, 1)
end

return SquadPanel
