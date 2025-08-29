local OverworldState = {}

local WorldMapModule = require('src.game.modules.WorldMapModule')
local PartyModule = require('src.game.modules.PartyModule')
local LocationsModule = require('src.game.modules.LocationsModule')
local InteractionModule = require('src.game.modules.InteractionModule')
local PlayerModule = require('src.game.modules.PlayerModule')
local GameState = require('src.game.GameState')
local PartyManagementState = require('src.game.ui.states.PartyManagementState')
local TradingState = require('src.game.ui.states.TradingState')
-- Character editor removed
local InputModule = require('src.game.modules.InputModule')
local interactions = require('src.data.interactions')
local TimeModule = require('src.game.modules.TimeModule')

local borderImg = nil
local borderQuads = nil
local borderTileSize = 16 -- corner size for 9-slice
local borderImgSize = 48

OverworldState.mapZoom = 1

function OverworldState:enter()
  if not borderImg then
    borderImg = love.graphics.newImage('assets/sprites/ui/border2.png')
    -- Create 9 quads for 9-slice
    borderQuads = {
      -- Corners
      tl = love.graphics.newQuad(0, 0, borderTileSize, borderTileSize, borderImgSize, borderImgSize),
      tr = love.graphics.newQuad(borderImgSize - borderTileSize, 0, borderTileSize, borderTileSize, borderImgSize, borderImgSize),
      bl = love.graphics.newQuad(0, borderImgSize - borderTileSize, borderTileSize, borderTileSize, borderImgSize, borderImgSize),
      br = love.graphics.newQuad(borderImgSize - borderTileSize, borderImgSize - borderTileSize, borderTileSize, borderTileSize, borderImgSize, borderImgSize),
      -- Edges
      top = love.graphics.newQuad(borderTileSize, 0, borderImgSize - 2*borderTileSize, borderTileSize, borderImgSize, borderImgSize),
      bottom = love.graphics.newQuad(borderTileSize, borderImgSize - borderTileSize, borderImgSize - 2*borderTileSize, borderTileSize, borderImgSize, borderImgSize),
      left = love.graphics.newQuad(0, borderTileSize, borderTileSize, borderImgSize - 2*borderTileSize, borderImgSize, borderImgSize),
      right = love.graphics.newQuad(borderImgSize - borderTileSize, borderTileSize, borderTileSize, borderImgSize - 2*borderTileSize, borderImgSize, borderImgSize),
      -- Center
      center = love.graphics.newQuad(borderTileSize, borderTileSize, borderImgSize - 2*borderTileSize, borderImgSize - 2*borderTileSize, borderImgSize, borderImgSize),
    }
  end
  self.activeMenu = nil
  if self.lastMenuTarget then
    self:openMenu(self.lastMenuTarget)
    self.lastMenuTarget = nil
  end
  self.menuJustOpened = false
  self.menuCooldown = false -- Require player to move away before reopening
  self.camera_x = 0
  self.camera_y = 0
end

function OverworldState:openMenu(target)
  self.lastMenuTarget = target
  local options = {}
  for _, interactionKey in ipairs(target.interactions or {}) do
    local interaction = interactions[interactionKey]
    if interaction then
    table.insert(options, {
        label = interaction.label,
      action = function()
          interaction.action({
            target = target,
            closeMenu = function()
        self.activeMenu = nil
        self.menuCooldown = true
              self.lastMenuTarget = nil -- Prevent menu restoration
            end
          })
      end
    })
    end
  end
  table.insert(options, { label = "Leave", action = function() self.activeMenu = nil; self.menuCooldown = true; self.lastMenuTarget = nil end })
  self.activeMenu = {
    target = target,
    options = options,
    selected = 1
  }
  self.menuJustOpened = true
end

function OverworldState:update(dt)
  if self.activeMenu then
    self.menuJustOpened = false
    TimeModule:setPaused(true)
    return
  end
  -- Camera follow logic (now local)
  local player = PlayerModule:getPlayerParty()
  if player then
    local screen_w, screen_h = love.graphics.getWidth(), love.graphics.getHeight()
    local map_w, map_h = WorldMapModule.width, WorldMapModule.height
    self.camera_x = math.max(0, math.min(player.position.x - screen_w/2, map_w - screen_w))
    self.camera_y = math.max(0, math.min(player.position.y - screen_h/2, map_h - screen_h))
  end
  WorldMapModule:update(dt)
  LocationsModule:update(dt)
  -- Only update player movement if no menu is open
  if not self.activeMenu then
  PlayerModule:update(dt)
    if PlayerModule:isMoving() then
      TimeModule:setPaused(false)
    else
      TimeModule:setPaused(true)
    end
    if TimeModule:getTimeStatus() == "RUNNING" then
      TimeModule:update(dt)
    end
  end
  -- Proximity detection: open menu if near something
  local px, py = player and player.position.x or 0, player and player.position.y or 0
  local radius = 32
  local nearInteractable = false
  if player then
    -- Check locations
    for _, loc in ipairs(LocationsModule.locations) do
      local dx, dy = loc.position.x - px, loc.position.y - py
      if (dx*dx + dy*dy) <= (radius*radius) then
        nearInteractable = true
        if not self.menuJustOpened and not self.menuCooldown then
          self:openMenu(loc)
        end
        break
      end
    end
    -- Check other parties if not already near a location
    if not nearInteractable then
      for _, party in ipairs(PartyModule.parties) do
        if party.id ~= "player" then
          local dx, dy = party.position.x - px, party.position.y - py
          if (dx*dx + dy*dy) <= (radius*radius) then
            nearInteractable = true
            if not self.menuJustOpened and not self.menuCooldown then
              self:openMenu(party)
            end
            break
          end
        end
      end
    end
  end
  -- Reset cooldown if player is not near any interactable
  if not nearInteractable then
    self.menuCooldown = false
  end
  PartyModule:update(dt)
end

function OverworldState:draw()
  love.graphics.push()
  love.graphics.translate(-self.camera_x, -self.camera_y)
  WorldMapModule:draw()
  LocationsModule:draw()
  PartyModule:draw()
  love.graphics.pop()
  -- Draw night tint overlay
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local r, g, b, a = TimeModule:getNightTint()
  if a > 0 then
    love.graphics.setColor(r, g, b, a)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
  end
  if self.activeMenu then
    local mw, mh = 300, 40 + 30 * #self.activeMenu.options
    local mx, my = (w - mw) / 2, (h - mh) / 2
    -- Make the background rectangle a bit bigger to fit inside the border
    local bgPad = borderTileSize - 2
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', mx - bgPad, my - bgPad, mw + bgPad * 2, mh + bgPad * 2, 8, 8)
    -- Draw 9-slice border
    if borderImg and borderQuads then
      love.graphics.setColor(1, 1, 1, 1)
      self:draw9SliceBorder(borderImg, borderQuads, mx - borderTileSize, my - borderTileSize, mw + borderTileSize * 2, mh + borderTileSize * 2)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(self.activeMenu.target.name .. " - Choose an action:", mx, my + 10, mw, 'center')
    for i, opt in ipairs(self.activeMenu.options) do
      local y = my + 30 + (i-1)*30
      if i == self.activeMenu.selected then
        love.graphics.setColor(1, 1, 0)
      else
        love.graphics.setColor(1, 1, 1)
      end
      love.graphics.printf(opt.label, mx + 20, y, mw - 40, 'left')
    end
    love.graphics.setColor(1, 1, 1)
  end
  -- Display current time period and debug info in top right
  local period = TimeModule:getPeriodName()
  local hour = TimeModule:getHour()
  local timeStatus = TimeModule:getTimeStatus()
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle('fill', w-160, 10, 150, 60, 8, 8)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf(period, w-150, 18, 130, 'center')
  love.graphics.printf(string.format("Hour: %.2f", hour), w-150, 34, 130, 'center')
  love.graphics.printf("Time: "..timeStatus, w-150, 50, 130, 'center')
  
  -- Character editor removed
end

function OverworldState:keypressed(key)
  InputModule:handleKeyEvent(key, self)
end


function OverworldState:onAction(action)
  if self.activeMenu then
    if action == 'navigate_up' then
      self.activeMenu.selected = (self.activeMenu.selected - 2) % #self.activeMenu.options + 1
    elseif action == 'navigate_down' then
      self.activeMenu.selected = self.activeMenu.selected % #self.activeMenu.options + 1
    elseif action == 'activate' then
      local opt = self.activeMenu.options[self.activeMenu.selected]
      if opt and opt.action then opt.action() end
    elseif action == 'cancel' then
      self.activeMenu = nil
      self.menuCooldown = true
    end
    return
  end

  if action == 'camp_menu' then
    if not self.activeMenu then
      self:openMenu(interactions.camp)
    end
    return
  end

  if action == 'open_party_screen' then
    GameState:push(PartyManagementState)
    return
  end

  -- Character editor removed
end

function OverworldState:draw9SliceBorder(img, quads, x, y, w, h)
  local s = borderTileSize
  local ex, ey = x + w - s, y + h - s
  -- Corners
  love.graphics.draw(img, quads.tl, x, y)
  love.graphics.draw(img, quads.tr, ex, y)
  love.graphics.draw(img, quads.bl, x, ey)
  love.graphics.draw(img, quads.br, ex, ey)
  -- Edges
  love.graphics.draw(img, quads.top, x + s, y, 0, (w - 2*s)/(borderImgSize - 2*s), 1)
  love.graphics.draw(img, quads.bottom, x + s, ey, 0, (w - 2*s)/(borderImgSize - 2*s), 1)
  love.graphics.draw(img, quads.left, x, y + s, 0, 1, (h - 2*s)/(borderImgSize - 2*s))
  love.graphics.draw(img, quads.right, ex, y + s, 0, 1, (h - 2*s)/(borderImgSize - 2*s))
  -- Center
  love.graphics.draw(img, quads.center, x + s, y + s, 0, (w - 2*s)/(borderImgSize - 2*s), (h - 2*s)/(borderImgSize - 2*s))
end

return OverworldState 