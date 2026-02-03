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
  -- Only commanders can equip/unequip
  self.units = {}
  for _, u in ipairs(self.party.units or {}) do
    if u.commander then table.insert(self.units, u) end
  end
  if #self.units == 0 then
    -- No commanders found; keep list empty to avoid errors
  end
  self.unitCols = 5
  self.unitRows = 2
  self.inventoryCols = 5
  self.inventoryRows = 2
  self.selectedUnitIdx = 1
  self.selectedItemIdx = 1
  self.focus = "units" -- or "inventory"
end

function PartyManagementState:onAction(action)
  local units = self.units or {}
  if #units == 0 then
    -- Nothing to draw on the units side; keep inventory visible
    self.selectedUnitIdx = 1
  else
    if self.selectedUnitIdx < 1 then self.selectedUnitIdx = 1 end
    if self.selectedUnitIdx > #units then self.selectedUnitIdx = #units end
  end
  local items = self.party.inventory or {}

  if action == 'cancel' then
    GameState:pop()
    return
  end
  -- Tab/shift-tab cycles selected unit
  if action == 'switch_panel_next' then
    if #units == 0 then return end
    self.selectedUnitIdx = (self.selectedUnitIdx % #units) + 1
    return
  elseif action == 'switch_panel_prev' then
    if #units == 0 then return end
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
      -- Unequip all items from selected unit (structured slots)
      local unit = units[self.selectedUnitIdx]
      if unit and unit.equipmentSlots then
        for _, slot in ipairs(unit.equipmentSlots) do
          if slot.item then
            local removed = unit:unequip(slot.type)
            if removed then table.insert(self.party.inventory, removed) end
          end
        end
      end
    elseif action == 'activate_secondary' then
      -- Also support unequip-all via secondary activate
      local unit = units[self.selectedUnitIdx]
      if unit and unit.equipmentSlots then
        for _, slot in ipairs(unit.equipmentSlots) do
          if slot.item then
            local removed = unit:unequip(slot.type)
            if removed then table.insert(self.party.inventory, removed) end
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
      -- Equip item to selected commander if possible using Unit:equip
      local item = items[self.selectedItemIdx]
      local unit = units[self.selectedUnitIdx]
      if item and unit and unit.equipmentSlots then
        -- Attempt equip via unit's API
        unit:equip(item)
        -- Check if item is now present in any slot
        local placed = false
        for _, slot in ipairs(unit.equipmentSlots) do
          if slot.item == item then placed = true break end
        end
        -- If not placed (no exact slot match), try first empty hand for weapons
        if not placed and item.type == 'weapon' then
          for _, slot in ipairs(unit.equipmentSlots) do
            if (slot.type == 'main_hand' or slot.type == 'off_hand') and not slot.item then
              slot.item = item
              placed = true
              break
            end
          end
        end
        -- If we placed it, remove from party inventory and clamp index
        if placed then
          table.remove(self.party.inventory, self.selectedItemIdx)
          if self.selectedItemIdx > #self.party.inventory then
            self.selectedItemIdx = #self.party.inventory
          end
        end
      end
    end
  end
end

function PartyManagementState:draw()
  local w, h = 640, 480
  love.graphics.clear(0.12, 0.12, 0.15, 1)
  local units = self.units or {}
  local items = self.party.inventory or {}
  -- Layout constants
  local margin = 16
  local gridCell = 56 -- square box size
  local gridPad = 8
  -- Unit grid (top left)
  local ux, uy = margin, margin
  local unitGridW = self.unitCols * gridCell + (self.unitCols-1)*gridPad
  local unitGridH = self.unitRows * gridCell + (self.unitRows-1)*gridPad
  -- Label for commanders
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Commanders:", ux, uy - 18, unitGridW, 'left')
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
    local hpCurr = unit.health or 0
    local hpMax = unit.max_health or hpCurr
    love.graphics.printf("HP: "..hpCurr.."/"..hpMax.."  Morale: "..(unit.morale or 0), infoX+10, infoY+32, infoW-20, 'left')
    love.graphics.printf("ATK: "..(unit.attack or 0).."  DEF: "..(unit.defense or 0), infoX+10, infoY+52, infoW-20, 'left')
    love.graphics.printf("STR: "..(unit.strength or 0).."  PROT: "..(unit.protection or 0).."  SPD: "..(unit.speed or 0), infoX+10, infoY+72, infoW-20, 'left')
    -- Actions list
    local actionNames = {}
    if unit.actions then
      for _, a in ipairs(unit.actions) do
        table.insert(actionNames, a.name or a.id or "?")
      end
    end
    love.graphics.printf("Actions: "..table.concat(actionNames, ", "), infoX+10, infoY+92, infoW-20, 'left')
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