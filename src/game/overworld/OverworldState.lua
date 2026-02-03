local OverworldState = {}

local WorldMapModule = require('src.game.overworld.WorldMap')
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
local SimpleMenu = require('src.game.ui.SimpleMenu')
local LocationState = require('src.game.location.LocationState')
local AssetManager = require('src.game.util.AssetManager')

local heartIcon = AssetManager:loadImage("icons/heart.png")
local moraleIcon = AssetManager:loadImage("icons/morale.png")

OverworldState.mapZoom = 1

function OverworldState:enter()
  self.camera_x = 0
  self.camera_y = 0
  self.enterCooldown = 0
end

function OverworldState:update(dt)
  
  if SimpleMenu:isOpen() then
    TimeModule:setPaused(true)
    return
  end

  -- Reduce interaction cooldown
  if self.enterCooldown and self.enterCooldown > 0 then
    self.enterCooldown = math.max(0, self.enterCooldown - dt)
  end

  -- Camera follow logic (now local)
  local player = PlayerModule:getPlayerParty()
  if player then
    local screen_w, screen_h = love.graphics.getWidth(), love.graphics.getHeight()
    local map_w, map_h = WorldMapModule.width, WorldMapModule.height
    self.camera_x = math.max(0, math.min(player.position.x - screen_w/2, map_w - screen_w))
    self.camera_y = math.max(0, math.min(player.position.y - screen_h/2, map_h - screen_h))
  end

  -- Only update player movement if no menu is open
  if not SimpleMenu:isOpen() then
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
  self.nearInteractable = false

  if player then
    -- Check locations
    for _, loc in ipairs(LocationsModule.locations) do
      local dx, dy = loc.position.x - px, loc.position.y - py
      if (dx*dx + dy*dy) <= (radius*radius) then
        self.nearInteractable = loc
        break
      end
    end

    if self.nearInteractable then
      self.interactPrompt = { text = "Enter", x = self.nearInteractable.position.x, y = self.nearInteractable.position.y + 20}
      if (self.enterCooldown or 0) <= 0 and InputModule:isActionDown("activate") then
        self.enterCooldown = 0.25
        GameState:push(LocationState, self.nearInteractable)
      end
    else
      self.interactPrompt = nil
    end

    -- Check other parties if not already near a location
    if not self.nearInteractable then
      for _, party in ipairs(PartyModule.parties) do
        if party.id ~= "player" then
          local dx, dy = party.position.x - px, party.position.y - py
          if (dx*dx + dy*dy) <= (radius*radius) then
            self.nearInteractable = true
            if (not SimpleMenu:isOpen()) and (not SimpleMenu:isCooldown()) then
              SimpleMenu:open(party)
            end
            break
          end
        end
      end
    end
  end
  
  -- Reset cooldown if player is not near any interactable
  if not self.nearInteractable then
    SimpleMenu:resetCooldown()
  end
  PartyModule:update(dt)
end

local function drawStatusBars()
  local barX, barY = 20, 20
  local barWidth, barHeight = 150, 20
  local iconSize = barHeight + 4
  local spacing = 6

  local partyHealth = PartyModule:getPartyHealthAverage(PartyModule.parties[1]) or 0
  local playerHealth = PlayerModule:getPlayerHealthPercentage() or 0
  local favor = PlayerModule.favor or 0

  -------------------------------------------------
  -- === HEALTH BAR ===
  -------------------------------------------------
  -- 1. Draw heart icon
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(heartIcon, barX, barY - 2, 0,
    iconSize / heartIcon:getWidth(), iconSize / heartIcon:getHeight())

  -- Offset bar position to the right of the icon
  local barStartX = barX + iconSize + spacing

  -- 2. Background (to prevent transparency)
  love.graphics.setColor(0.2, 0.1, 0.1)
  love.graphics.rectangle("fill", barStartX, barY, barWidth, barHeight)

  -- 3. Red fill for current health
  love.graphics.setColor(1, 0, 0)
  love.graphics.rectangle("fill", barStartX, barY, barWidth * partyHealth, barHeight)

  -- 4. Player marker line
  love.graphics.setColor(1, 1, 1)
  local playerX = barStartX + barWidth * playerHealth
  love.graphics.rectangle("fill", playerX - 1, barY, 2, barHeight)

  -- 5. Border
  love.graphics.setColor(0, 0, 0)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", barStartX, barY, barWidth, barHeight)
  love.graphics.setLineWidth(1)

  -------------------------------------------------
  -- === FAVOR / MORALE BAR ===
  -------------------------------------------------
  barY = barY + barHeight + 10

  -- 1. Draw morale icon
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(moraleIcon, barX, barY - 2, 0,
    iconSize / moraleIcon:getWidth(), iconSize / moraleIcon:getHeight())

  -- Offset bar position
  local barStartY = barY

  -- 2. Background
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.rectangle("fill", barStartX, barStartY, barWidth, barHeight)

  -- 3. White fill for current favor/morale
  love.graphics.setColor(0.9, 0.9, 0.9)
  love.graphics.rectangle("fill", barStartX, barStartY, barWidth * favor / 100, barHeight)

  -- 4. Border
  love.graphics.setColor(0, 0, 0)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", barStartX, barStartY, barWidth, barHeight)
  love.graphics.setLineWidth(1)

  -- Reset color
  love.graphics.setColor(1, 1, 1, 1)
end

function OverworldState:draw()
  -- Draw map and entities
  love.graphics.push()
  love.graphics.translate(-self.camera_x, -self.camera_y)
  WorldMapModule:draw()
  LocationsModule:draw()
  PartyModule:draw()

  -- Draw interact prompt in world space
  if self.interactPrompt then
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(self.interactPrompt.text, self.interactPrompt.x - 50, self.interactPrompt.y, 100, "center")
  end
  love.graphics.pop()

  drawStatusBars()



  -- === NIGHT TINT + TIME DEBUG ===
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local r, g, b, a = TimeModule:getNightTint()
  if a > 0 then
    love.graphics.setColor(r, g, b, a)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
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
end



function OverworldState:keypressed(key)
  InputModule:handleKeyEvent(key, self)
end

function OverworldState:onAction(action)
  if action == 'camp_menu' then
    --SimpleMenu:showMessage(" Trololol ol ol oltorl olt oltrolt otlrotl o lo l ol Haha fk u")
    SimpleMenu:open(interactions.camp)
    return
  end

  if action == 'open_party_screen' then
    SimpleMenu:showMessage(" Trololol ol ol oltorl olt oltrolt otlrotl o lo l ol Haha fk u")
    --GameState:push(PartyManagementState)
    return
  end
end

return OverworldState