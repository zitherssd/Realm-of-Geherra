local BattleState = {}

local PartyModule = require('src.game.modules.PartyModule')
local ItemModule = require('src.game.modules.ItemModule')
local GameState = require('src.game.GameState')
local battleActions = require('src.data.battle_actions')
local itemTemplates = require('src.data.item_templates')
local PlayerModule = require('src.game.modules.PlayerModule')
local InputModule = require('src.game.modules.InputModule')
local UnitModule = require('src.game.modules.UnitModule')  
-- Remove Playmat/Mode 7
-- local PM = require('lib.playmat') -- REMOVE

-- Remove pmCamera and related logic
-- Remove all PM.* calls

-- Local helper functions for modularity
local function ellipseDist(x1, y1, x2, y2, r1, r2)
  local dx = x2 - x1
  local dy = (y2 - y1) * 2
  local dist = math.sqrt(dx*dx + dy*dy)
  return dist, r1, r2
end

local function placeUnits(self, party1, party2, map_w, map_h)
  self.units = {}
  -- Player units on left edge, enemy units on right edge, both in vertical lines
  local leftX, rightX = 100, map_w - 100
  local n1, n2 = #party1.units, #party2.units
  local spacing = 48
  local yStart1 = map_h/2 - ((n1-1)*spacing)/2
  local yStart2 = map_h/2 - ((n2-1)*spacing)/2
  for i, unit in ipairs(party1.units) do
    unit.battle_x = leftX
    unit.battle_y = yStart1 + (i-1)*spacing
    unit.battle_party = 1
    unit.battle_cooldown = 0
    table.insert(self.units, unit)
  end
  for i, unit in ipairs(party2.units) do
    unit.battle_x = rightX
    unit.battle_y = yStart2 + (i-1)*spacing
    unit.battle_party = 2
    unit.battle_cooldown = 0
    table.insert(self.units, unit)
  end
end

-- Remove old updateUnitAI and updateUnits logic, replace with per-unit update
local function updateUnits(self, dt)
  for _, unit in ipairs(self.units) do
    if unit.health > 0 and unit.update then
      unit:update(dt, self)
    end
  end
end


local function checkVictory(self)
  local alive1, alive2 = false, false
  for _, u in ipairs(self.units) do
    if u.battle_party == 1 and u.health > 0 then alive1 = true end
    if u.battle_party == 2 and u.health > 0 then alive2 = true end
  end
  if not alive1 then
    self.result = "Party 2 Wins!"
  elseif not alive2 then
    self.result = "Party 1 Wins!"
  end
end

-- In drawBackground, just draw the background image or a color fill
local function drawBackground(self, w, h)
  if self.backgroundImage then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.backgroundImage, 0, 0)
  else
    love.graphics.setColor(0.3, 0.6, 1, 1)
    love.graphics.rectangle('fill', 0, 0, w, h/2)
    love.graphics.setColor(0.2, 0.7, 0.2, 1)
    love.graphics.rectangle('fill', 0, h/2, w, h/2)
    love.graphics.setColor(1,1,1)
  end
end

-- In drawUnits, draw each unit at unit.battle_x, unit.battle_y using love.graphics.draw
local function drawUnits(self)
  for _, unit in ipairs(self.units) do
    if unit.health > 0 then
      unit:draw(unit.battle_x, unit.battle_y)
    end
  end
end

-- Remove all references to self.pmCamera, PM.*, and related debug drawing
local function drawDebug(self)
  if self.result then
    love.graphics.setColor(1,1,0)
    love.graphics.printf(self.result, 0, 220, 800, 'center')
    love.graphics.setColor(1,1,1)
  end
  -- Remove Playmat/Mode 7
  -- if self.pmCamera then -- REMOVE
  --   local cam = self.pmCamera -- REMOVE
  --   love.graphics.setColor(1, 1, 1, 1) -- REMOVE
  --   love.graphics.print(string.format( -- REMOVE
  --     "Camera X: %.2f\nCamera Y: %.2f\nRot: %.2f\nFOV: %.2f\nZoom: %.2f\nOffset: %.2f", -- REMOVE
  --     cam.x, cam.y, cam.r, cam.f, cam.z, cam.o), 10, 10) -- REMOVE
  -- end -- REMOVE
end

function BattleState:enter(party1, party2, stage)
  self.parties = {party1, party2}
  self.stage = stage
  self.paused = false
  self.result = nil
  self.playerAutoAttack = false
  self.playerUnit = PlayerModule.getPlayerUnit(party1)
  -- Load background image and get map size
  self.backgroundImage = love.graphics.newImage(self.stage.map)
  local map_w, map_h = self.backgroundImage:getWidth(), self.backgroundImage:getHeight()
  -- Place units using modular function
  placeUnits(self, party1, party2, map_w, map_h)
end



function BattleState:moveWithCollision(unit, dx, dy, dt)
  local scale = unit.scale or 1
  local radius = (unit.battle_radius or 14) * scale
  local nx = unit.battle_x + dx
  local ny = unit.battle_y + dy
  ny = math.max(240 + (radius * 0.5), math.min(ny, 480 - (radius * 0.5)))
  for _, other in ipairs(self.units) do
    if other ~= unit and other.health > 0 then
      local oscale = other.scale or 1
      local oradius = (other.battle_radius or 14) * oscale
      local dist = ellipseDist(nx, ny, other.battle_x, other.battle_y, radius, oradius)
      if dist < radius + oradius then
        local overlap = radius + oradius - dist
        if dist > 0 then
          nx = nx + (nx - other.battle_x)/dist * overlap
          ny = ny + (ny - other.battle_y)/dist * overlap
        else
          nx = nx + math.random(-1,1)
          ny = ny + math.random(-1,1)
        end
      end
    end
  end
  unit.battle_x = nx
  unit.battle_y = ny
end

function BattleState:update(dt)
  if self.paused or self.result then return end
  updateUnits(self, dt)
  checkVictory(self)
end

function BattleState:pickTarget(unit)
  -- AI: pick nearest enemy, but spread out
  local enemies = {}
  for _, u in ipairs(self.units) do
    if u.battle_party ~= unit.battle_party and u.health > 0 then
      table.insert(enemies, u)
    end
  end
  if #enemies == 0 then return nil end
  -- Count how many allies are targeting each enemy
  local targetCounts = {}
  for _, ally in ipairs(self.units) do
    if ally.battle_party == unit.battle_party and ally ~= unit and ally.battle_target then
      targetCounts[ally.battle_target] = (targetCounts[ally.battle_target] or 0) + 1
    end
  end
  -- Prefer nearest enemy with lowest target count
  table.sort(enemies, function(a, b)
    local ca = targetCounts[a] or 0
    local cb = targetCounts[b] or 0
    if ca ~= cb then return ca < cb end
    local da = math.abs(a.battle_x - unit.battle_x) + math.abs(a.battle_y - unit.battle_y)
    local db = math.abs(b.battle_x - unit.battle_x) + math.abs(b.battle_y - unit.battle_y)
    return da < db
  end)
  return enemies[1]
end

local debugDrawParty1 = false
local debugDrawParty2 = false

function BattleState:keypressed(key)
  if key == 'space' then self.paused = not self.paused end
  if key == 'escape' then GameState:pop() end
  if key == '1' then debugDrawParty1 = not debugDrawParty1 end
  if key == '2' then debugDrawParty2 = not debugDrawParty2 end
end

function BattleState:draw()
  local w, h = 800, 600
  love.graphics.clear(0.1, 0.1, 0.12, 1)
  drawBackground(self, w, h)
  -- Draw debug vertical lines for party spawn
  if self.backgroundImage then
    local map_w, map_h = self.backgroundImage:getWidth(), self.backgroundImage:getHeight()
    love.graphics.setColor(1, 0, 0, 0.5)
    love.graphics.line(100, 0, 100, map_h)
    love.graphics.line(map_w - 100, 0, map_w - 100, map_h)
    love.graphics.setColor(1, 1, 1, 1)
  end
  drawUnits(self)
  drawDebug(self)
end

return BattleState 