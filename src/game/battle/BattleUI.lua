local GameState = require("src.game.GameState")
local BattleUI = {
    damagePopups = {},
    result = nil
}

function BattleUI:createDamagePopup(x, y, damage)
    local popup = {
        x = x,
        y = y - 20, -- Start above the unit
        targetY = y - 40, -- Float upward
        damage = damage,
        timer = 0,
        duration = 1.0, -- 1 second duration
        alpha = 1.0,
        scale = 1.0
    }
    table.insert(self.damagePopups, popup)
end

function BattleUI:update(dt)
    -- Update damage popups
    for i = #self.damagePopups, 1, -1 do
        local popup = self.damagePopups[i]
        popup.timer = popup.timer + dt
        
        -- Calculate progress (0 to 1)
        local progress = popup.timer / popup.duration
        
        -- Update position (float upward)
        popup.y = popup.y - (dt * 20) -- Move up 20 pixels per second
        
        -- Update alpha (fade out)
        popup.alpha = 1.0 - progress
        
        -- Update scale (slight growth effect)
        popup.scale = 1.0 + (progress * 0.3)
        
        -- Remove popup when duration is complete
        if popup.timer >= popup.duration then
            table.remove(self.damagePopups, i)
        end
    end

    if self.startCountdown then
        self.resultTimer = self.resultTimer - dt
        if self.resultTimer <= 0 then
            GameState:pop()
        end
    end
end

function BattleUI:drawWorld(battle)
    -- Called with camera transform applied; draw world-space popups
    for _, popup in ipairs(self.damagePopups) do
        love.graphics.setColor(1, 0, 0, popup.alpha)
        love.graphics.printf(tostring(popup.damage), popup.x - 20, popup.y - 10, 40, 'center')
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function BattleUI:draw(battle)
  local w, h = love.graphics.getDimensions()
  -- Screen-space HUD
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print("Tick: " .. battle.currentTick, 10, 25)
  if self.result then
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.printf(self.result, 0, h/2 - 20, w, 'center')
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Player action bars (top-right)
  local unit = battle.playerUnit
  local unitActions = unit and unit:getActions()
  if unitActions and #unitActions > 0 then
    local margin = 12
    local barW, barH = 180, 22
    local startX = w - barW - margin
    local startY = margin
    for i, action in ipairs(unitActions) do
      local y = startY + (i - 1) * (barH + 6)
      -- background
      love.graphics.setColor(0.1, 0.1, 0.12, 0.8)
      love.graphics.rectangle('fill', startX, y, barW, barH, 6, 6)
      -- progress overlay (timestamp-based windup or cooldown)
      local now = battle.currentTick or 0
      local windupTotal = action.cooldownStart or 0
      local cooldownTotal = action.cooldownEnd or 0
      local usedAt = action.last_used_tick
      local execAt = action.executed_tick
      -- Windup: last_used set, executed not yet set
      if usedAt and (not execAt) and windupTotal > 0 then
        local elapsed = math.max(0, now - usedAt)
        local pct = math.max(0, math.min(1, elapsed / windupTotal))
        if pct > 0 then
          love.graphics.setColor(0.6, 0.6, 0.6, 0.9)
          love.graphics.rectangle('fill', startX, y, barW * pct, barH, 6, 6)
        end
      -- Cooldown: executed set
      elseif execAt and cooldownTotal > 0 then
        local elapsed = math.max(0, now - execAt)
        local remainingPct = math.max(0, math.min(1, 1 - (elapsed / cooldownTotal)))
        if remainingPct > 0 then
          local wfill = math.floor(barW * remainingPct + 0.5)
          love.graphics.setColor(0.6, 0.6, 0.6, 0.9)
          love.graphics.rectangle('fill', startX, y, wfill, barH, 6, 6)
        end
      end
      -- border
      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle('line', startX, y, barW, barH, 6, 6)
      love.graphics.setLineWidth(1)
      -- label
      if battle.selectedAction == i then
        love.graphics.setColor(1, 1, 0, 1) -- highlighted for focused action
      else
        love.graphics.setColor(1, 1, 1, 0.85)
      end
      local label = action.name or action.id or "Action"
      love.graphics.printf(label, startX + 8, y + 3, barW - 16, 'left')
    end
  end
end

function BattleUI:setResult(result)
    self.result = result
    self.resultTimer = 3
    self.startCountdown = true
end

return BattleUI