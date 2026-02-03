local PartyManagementState = {}

local PartyModule = require('src.game.modules.PartyModule')
local GameState = require('src.game.GameState')
local InputModule = require('src.game.modules.InputModule')
local UnitListPanel = require('src.game.ui.UnitListPanel')
local SquadPanel = require('src.game.ui.SquadPanel')

-- Initialize state
function PartyManagementState:enter()
  self.party = PartyModule.parties[1] -- player party

  -- Build commanders list from party units flagged as commander
  local units = self.party.units or {}
  self.commanders = {}
  for _, u in ipairs(units) do
    if u.commander then
      table.insert(self.commanders, u)
      -- Ensure commander has squads array (UnitModule should create it, but be safe)
      if not u.squads then
        u.squads = { {units={}}, {units={}}, {units={}}, {units={}} }
      end
    end
  end
  if #self.commanders == 0 and units[1] then
    -- Fallback: treat first unit as commander
    units[1].commander = true
    units[1].squads = units[1].squads or { {units={}}, {units={}}, {units={}}, {units={}} }
    table.insert(self.commanders, units[1])
  end

  -- Selection/UI state
  self.selectedCommander = 1
  self.selectedSquad = 1
  self.focus = "squads" -- start focused on squads
  self.entered = false      -- Whether we're in unit selection mode

  -- Panels
  self.commanderPanel = UnitListPanel
  self.squadPanel = SquadPanel:new()
  self.unassignedPanel = SquadPanel:new()

  -- Helper to recompute bindings
  function self:refreshBindings()
    local cmd = self.commanders[self.selectedCommander]
    local squads = (cmd and cmd.squads) or { {units={}}, {units={}}, {units={}}, {units={}} }
    self.squadPanel:setSquads(squads)
    -- Keep visual selection in sync
    self.squadPanel.selectedSquad = self.selectedSquad

    -- Compute unassigned = party units that are not commanders and not present in any squad
    local assigned = {}
    for _, c in ipairs(self.commanders) do
      if c.squads then
        for _, sq in ipairs(c.squads) do
          if sq.units then
            for _, u in ipairs(sq.units) do assigned[u] = true end
          end
        end
      end
    end
    local pool = {}
    for _, u in ipairs(self.party.units or {}) do
      if not u.commander and not assigned[u] then table.insert(pool, u) end
    end
    self.unassignedPanel:setSquads({ { units = pool } })
  end

  self:refreshBindings()
end

-- Handle input actions
function PartyManagementState:onAction(action)
  if action == 'cancel' then
    if self.entered then
      -- Exit unit selection mode
      self.entered = false
      self.squadPanel:exit()
      self.unassignedPanel:exit()
    else
      -- Close the state
      GameState:pop()
    end
    return
  end
  
  if not self.entered then
    -- Navigation mode
    if action == 'switch_panel_next' then
      self.selectedCommander = (self.selectedCommander % #self.commanders) + 1
      self:refreshBindings()
      return
    elseif action == 'switch_panel_prev' then
      self.selectedCommander = (self.selectedCommander - 2) % #self.commanders + 1
      self:refreshBindings()
      return
    end
    
    if action == 'navigate_up' then
      if self.focus == "squads" then
        if self.squadPanel.selectedSquad > 1 then
          self.squadPanel.selectedSquad = self.squadPanel.selectedSquad - 1
          self.selectedSquad = self.squadPanel.selectedSquad
        end
      end
      return
    elseif action == 'navigate_down' then
      if self.focus == "squads" then
        local currentCmd = self.commanders[self.selectedCommander]
        local total = (currentCmd and currentCmd.squads and #currentCmd.squads) or 4
        if self.squadPanel.selectedSquad < total then
          self.squadPanel.selectedSquad = self.squadPanel.selectedSquad + 1
          self.selectedSquad = self.squadPanel.selectedSquad
        end
      end
      return
    elseif action == 'navigate_left' then
      -- Only allow moving left from Unassigned -> Squads. Do not go back to Commanders with left.
      if self.focus == "unassigned" then
        self.focus = "squads"
      end
      return
    elseif action == 'navigate_right' then
      if self.focus == "commanders" then
        self.focus = "squads"
      elseif self.focus == "squads" then
        self.focus = "unassigned"
      end
      return
    elseif action == 'activate' then
      -- Enter unit selection mode
      self.entered = true
      if self.focus == "squads" then
        self.squadPanel:enter()
      elseif self.focus == "unassigned" then
        self.unassignedPanel:enter()
      end
      return
    end
  else
    -- Unit selection mode
    if self.focus == "squads" then
      self.squadPanel:onAction(action)
    elseif self.focus == "unassigned" then
      self.unassignedPanel:onAction(action)
    end

    -- Do not allow switching focus between panels while in selection mode

    -- Transfer units with activate_secondary
    if action == 'activate_secondary' then
      local cmd = self.commanders[self.selectedCommander]
      if cmd and cmd.squads then
        local targetSquad = cmd.squads[self.squadPanel.selectedSquad]
        if self.focus == 'unassigned' then
          -- Move selected from pool to target squad
          local pool = self.unassignedPanel.squads[1].units
          local toMove = {}
          for key, _ in pairs(self.unassignedPanel.selectedUnits or {}) do
            local _, unitIdx = key:match("^(%d+)_([%d]+)$")
            unitIdx = tonumber(unitIdx)
            if unitIdx and pool[unitIdx] then table.insert(toMove, pool[unitIdx]) end
          end
          -- If activating already highlighted unit, select all same type
          if #toMove == 0 and pool[self.unassignedPanel.selectedUnitInSquad] then
            local name = pool[self.unassignedPanel.selectedUnitInSquad].name
            for _, u in ipairs(pool) do if u.name == name then table.insert(toMove, u) end end
          end
          -- Remove from pool and add to squad
          for _, u in ipairs(toMove) do
            -- remove
            for i=#pool,1,-1 do if pool[i] == u then table.remove(pool, i) break end end
            -- add
            targetSquad.units = targetSquad.units or {}
            table.insert(targetSquad.units, u)
          end
          self.unassignedPanel:clearSelection()
          self:refreshBindings()
          -- Auto-exit selection if source becomes empty
          local newPool = self.unassignedPanel.squads[1].units
          if #newPool == 0 then
            self.unassignedPanel:exit()
            self.entered = false
          else
            -- Clamp cursor
            if self.unassignedPanel.selectedUnitInSquad > #newPool then
              self.unassignedPanel.selectedUnitInSquad = math.max(1, #newPool)
            end
          end
        elseif self.focus == 'squads' then
          -- Move selected from squad back to pool
          local squad = targetSquad
          local pool = self.unassignedPanel.squads[1].units
          local toMove = {}
          for key, _ in pairs(self.squadPanel.selectedUnits or {}) do
            local sIdx, unitIdx = key:match("^(%d+)_([%d]+)$")
            sIdx = tonumber(sIdx); unitIdx = tonumber(unitIdx)
            if sIdx == self.squadPanel.selectedSquad and squad.units[unitIdx] then
              table.insert(toMove, squad.units[unitIdx])
            end
          end
          if #toMove == 0 and squad.units[self.squadPanel.selectedUnitInSquad] then
            local name = squad.units[self.squadPanel.selectedUnitInSquad].name
            for _, u in ipairs(squad.units) do if u.name == name then table.insert(toMove, u) end end
          end
          for _, u in ipairs(toMove) do
            -- remove from squad
            for i=#squad.units,1,-1 do if squad.units[i] == u then table.remove(squad.units, i) break end end
            -- add to pool
            table.insert(pool, u)
          end
          self.squadPanel:clearSelection()
          self:refreshBindings()
          -- Auto-exit selection if source becomes empty
          if #squad.units == 0 then
            self.squadPanel:exit()
            self.entered = false
          else
            if self.squadPanel.selectedUnitInSquad > #squad.units then
              self.squadPanel.selectedUnitInSquad = math.max(1, #squad.units)
            end
          end
        end
      end
      return
    end
  end
end

-- Draw the entire screen
function PartyManagementState:draw()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  
  -- Clear background
  love.graphics.clear(0.12, 0.12, 0.15, 1)
  
  -- Layout constants
  local margin = 16
  local midX = w / 2
  local leftW = midX - margin - 8
  local rightW = w - midX - margin
  
  -- ===== LEFT SIDE =====
  local leftX = margin
  local leftY = margin
  
  -- Commanders label and panel
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Commanders:", leftX, leftY, leftW, 'left')
  
  local cmdY = leftY + 24
  local cmdH = 80
  self.commanderPanel:draw(
    self.commanders,
    self.selectedCommander,
    leftX,
    cmdY,
    leftW,
    cmdH,
    self.focus == "commanders" and not self.entered
  )
  
  -- Squads label and panel
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Squads", leftX, cmdY + cmdH + 16, leftW, 'left')
  
  local squadY = cmdY + cmdH + 40
  local squadH = h - squadY - 60
  self.squadPanel:draw(leftX, squadY, leftW, squadH, self.focus == "squads")
  
  -- ===== RIGHT SIDE =====
  local rightX = midX + 8
  local rightY = margin
  
  -- Unassigned units label and panel
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Unassigned units:", rightX, rightY, rightW, 'left')
  
  local unassignedY = rightY + 24
  local unassignedH = 80
  self.unassignedPanel:draw(
    rightX,
    unassignedY,
    rightW,
    unassignedH,
    self.focus == "unassigned"
  )
  
  -- Deployment map placeholder
  love.graphics.setColor(0.2, 0.3, 0.2, 0.6)
  local mapY = unassignedY + unassignedH + 16
  local mapH = h - mapY - 60
  love.graphics.rectangle('fill', rightX, mapY, rightW, mapH, 8, 8)
  love.graphics.setColor(0.5, 0.7, 0.5)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle('line', rightX, mapY, rightW, mapH, 8, 8)
  love.graphics.setLineWidth(1)
  
  love.graphics.setColor(0.7, 0.7, 0.7)
  love.graphics.printf("[Deployment Map]", rightX, mapY + mapH / 2 - 10, rightW, 'center')
  
  -- ===== HELP TEXT =====
  love.graphics.setColor(0.7, 0.7, 0.7)
  love.graphics.printf(
    "Arrows: Move  Tab/Shift-Tab: Cycle Commander  Enter: Select  X: Transfer  Esc: Close",
    0,
    h - 28,
    w,
    'center'
  )
  
  love.graphics.setColor(1, 1, 1)
end

-- Handle keypressed
function PartyManagementState:keypressed(key)
  InputModule:handleKeyEvent(key, self)
end

return PartyManagementState
