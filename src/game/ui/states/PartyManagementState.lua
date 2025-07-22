local PartyManagementState = {}

local PartyModule = require('src.game.modules.PartyModule')
local ItemModule = require('src.game.modules.ItemModule')
local GameState = require('src.game.GameState')
local EquipmentPanel = require('src.game.ui.EquipmentPanel')
local InputModule = require('src.game.modules.InputModule')
local UnitListPanel = require('src.game.ui.UnitListPanel')
local InventoryPanel = require('src.game.ui.InventoryPanel')

function PartyManagementState:enter()
  self.party = PartyModule.parties[1] -- player party
  self.unitCols = 5
  self.unitRows = 2
  self.inventoryCols = 5
  self.inventoryRows = 2
  self.selectedUnitIdx = 1
  self.selectedItemIdx = 1
  self.focus = "units" -- or "inventory"
end

function PartyManagementState:onAction(action)
  local units = self.party.units or {}
  local items = self.party.inventory or {}
  if action == 'cancel' then
    GameState:pop()
    return
  end
  -- Tab/shift-tab cycles selected unit
  if action == 'switch_panel_next' then
    self.selectedUnitIdx = (self.selectedUnitIdx % #units) + 1
    return
  elseif action == 'switch_panel_prev' then
    self.selectedUnitIdx = (self.selectedUnitIdx - 2) % #units + 1
    return
  end
  -- Navigation
  if self.focus == "units" then
    if action == 'navigate_left' then
      if self.selectedUnitIdx > 1 then self.selectedUnitIdx = self.selectedUnitIdx - 1 end
    elseif action == 'navigate_right' then
      if self.selectedUnitIdx < #units then self.selectedUnitIdx = self.selectedUnitIdx + 1 end
    elseif action == 'navigate_down' then
      -- Move to inventory grid
      self.focus = "inventory"
    elseif action == 'activate' then
      -- Unequip all items from selected unit
      local unit = units[self.selectedUnitIdx]
      if unit and unit.equipment then
        for slot, item in pairs(unit.equipment) do
          if item then
            table.insert(self.party.inventory, item)
            unit.equipment[slot] = nil
          end
        end
      end
    end
  elseif self.focus == "inventory" then
    if action == 'navigate_left' then
      if self.selectedItemIdx > 1 then self.selectedItemIdx = self.selectedItemIdx - 1 end
    elseif action == 'navigate_right' then
      if self.selectedItemIdx < #items then self.selectedItemIdx = self.selectedItemIdx + 1 end
    elseif action == 'navigate_up' then
      -- Move to unit grid
      self.focus = "units"
    elseif action == 'activate' then
      -- Equip item to selected unit if possible
      local item = items[self.selectedItemIdx]
      local unit = units[self.selectedUnitIdx]
      if item and unit and item.slot and unit.equipmentSlots then
        for _, slot in ipairs(unit.equipmentSlots) do
          if slot == item.slot then
            -- Equip
            if not unit.equipment then unit.equipment = {} end
            if unit.equipment[slot] then
              table.insert(self.party.inventory, unit.equipment[slot])
            end
            unit.equipment[slot] = item
            table.remove(self.party.inventory, self.selectedItemIdx)
            -- Stay on inventory grid, update selection
            if self.selectedItemIdx > #self.party.inventory then
              self.selectedItemIdx = #self.party.inventory
            end
            break
          end
        end
      end
    end
  end
end

function PartyManagementState:draw()
  local w, h = 640, 480
  love.graphics.clear(0.12, 0.12, 0.15, 1)
  local units = self.party.units or {}
  local items = self.party.inventory or {}
  -- Layout constants
  local margin = 16
  local gridCell = 56 -- square box size
  local gridPad = 8
  -- Unit grid (top left)
  local ux, uy = margin, margin
  local unitGridW = self.unitCols * gridCell + (self.unitCols-1)*gridPad
  local unitGridH = self.unitRows * gridCell + (self.unitRows-1)*gridPad
  UnitListPanel:draw(units, self.selectedUnitIdx, ux, uy, unitGridW, unitGridH, self.focus=="units")
  -- Inventory grid (bottom left)
  local ix, iy = margin, uy + unitGridH + 32
  local invGridW = self.inventoryCols * gridCell + (self.inventoryCols-1)*gridPad
  local invGridH = self.inventoryRows * gridCell + (self.inventoryRows-1)*gridPad
  InventoryPanel:draw(items, self.selectedItemIdx, ix, iy, invGridW, invGridH, self.focus=="inventory")
  -- Info panel for selected unit (right side)
  local unit = units[self.selectedUnitIdx]
  if unit then
    local infoX, infoY, infoW, infoH = 340, margin, 280, 160
    love.graphics.setColor(0.15, 0.2, 0.15, 0.95)
    love.graphics.rectangle('fill', infoX, infoY, infoW, infoH, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(unit.name, infoX+10, infoY+10, infoW-20, 'left')
    love.graphics.printf("HP: "..unit.health.."  Morale: "..unit.morale, infoX+10, infoY+32, infoW-20, 'left')
    love.graphics.printf("ATK: "..unit.attack.."  DEF: "..unit.defense, infoX+10, infoY+52, infoW-20, 'left')
    -- Equipment panel (display only, below info panel)
    local eqX, eqY, eqW, eqH = infoX, infoY+infoH+8, infoW, 100
    EquipmentPanel:draw(unit, nil, eqX, eqY, eqW, eqH)
  end
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Arrows: Move  Tab/Shift-Tab: Cycle Unit  Enter: Equip/Unequip  Esc: Close", 0, h-28, w, 'center')
end

function PartyManagementState:keypressed(key)
  InputModule:handleKeyEvent(key, self)
end

return PartyManagementState 