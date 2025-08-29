local Object = require('lib.classic')
local unitTemplates = require('src.data.unit_templates')
local unitAnimations = require('src.data.unit_animations')
-- LPC system removed
local nextUnitId = 1

local Unit = Object:extend()


function Unit:new(templateName)
  local tpl = unitTemplates[templateName]
  if not tpl then error('Unknown unit template: ' .. tostring(templateName)) end
  self.id = 'unit_' .. nextUnitId
  nextUnitId = nextUnitId + 1
  self.template = templateName
  self.name = tpl.name
  self.attack = tpl.attack
  self.defense = tpl.defense
  self.strength = tpl.strength
  self.protection = tpl.protection
  self.morale = tpl.morale
  self.health = tpl.health
  self.max_health = tpl.health
  self.speed = tpl.speed
  self.equipmentSlots = tpl.equipmentSlots
  self.equipment = {}
  self.abilities = tpl.abilities
  self.scale = tpl.scale or 1
  self.controllable = tpl.controllable or false
  self.unit_type = tpl.unit_type or "human"
  -- State machine fields
  self.state = "idle"
  self.state_timer = 0
  self.animation = 'idle'
  self.animationFrame = 1
  -- For drawing
  self.battle_x = 0
  self.battle_y = 0
  self.battle_radius = 12
  -- LPC system removed
  -- Add more fields as needed
end

-- LPC system removed

function Unit:drawHpBar(x, y)
  -- Draw name and HP bar above the unit
  local img = self:getComposedImage()
  local sx, sy = x, y
  local name_y = sy - img:getHeight() * (self.scale or 1) - 24
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle('fill', sx - 40, name_y - 2, 80, 18, 6, 6)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf(self.name, sx - 40, name_y, 80, 'center')
  -- HP bar
  local hp_w = 60
  local hp_x = sx - hp_w/2
  local hp_y = name_y + 14
  local hp_frac = math.max(0, math.min(1, self.health / (self.max_health or self.health)))
  love.graphics.setColor(0.2, 0.2, 0.2, 1)
  love.graphics.rectangle('fill', hp_x, hp_y, hp_w, 6, 3, 3)
  love.graphics.setColor(0.2, 1, 0.2, 1)
  love.graphics.rectangle('fill', hp_x, hp_y, hp_w * hp_frac, 6, 3, 3)
  love.graphics.setColor(1, 1, 1, 1)
end

function Unit:moveWithCollision(dx, dy, dt, units)
  local scale = self.scale or 1
  local radius = (self.battle_radius or 14) * scale
  local nx = self.battle_x + dx
  local ny = self.battle_y + dy
  ny = math.max(240 + (radius * 0.5), math.min(ny, 480 - (radius * 0.5)))
  for _, other in ipairs(units) do
    if other ~= self and other.health > 0 then
      local oscale = other.scale or 1
      local oradius = (other.battle_radius or 14) * oscale
      local dist = math.sqrt((nx - other.battle_x)^2 + ((ny - other.battle_y) * 2)^2)
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
  self.battle_x = nx
  self.battle_y = ny
end

function Unit:drawCollisionBox(x, y)
  local scale = self.scale or 1
  local radius = (self.battle_radius or 14) * scale
  love.graphics.setColor(1, 0, 0, 0.5)
  love.graphics.ellipse('line', x, y, radius, radius * 0.5)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Update Unit:draw to optionally draw collision box
function Unit:draw(x, y)
  if require('src.game.modules.UnitModule').debugOnlyCollision then
    self:drawCollisionBox(x, y)
    return
  end
  
  -- LPC system removed
  
  -- Fallback to original rendering
  local animName = self.animation or 'idle'
  local frame = self.animationFrame or 1
  local anim = unitAnimations[animName] and unitAnimations[animName][frame] or nil
  if not anim then anim = unitAnimations['idle'][1] end
  -- Draw body
  if self.bodySprite then
    love.graphics.draw(self.bodySprite, x + anim.body.x, y + anim.body.y, anim.body.r, anim.body.sx, anim.body.sy)
  end
  -- Draw armor (if any, as overlay)
  if self.equipment.chest and self.equipment.chest.sprite then
    love.graphics.draw(self.equipment.chest.sprite, x + anim.body.x, y + anim.body.y, anim.body.r, anim.body.sx, anim.body.sy)
  end
  -- Draw head
  if self.headSprite then
    love.graphics.draw(self.headSprite, x + anim.head.x, y + anim.head.y, anim.head.r, anim.head.sx, anim.head.sy)
  end
  -- Draw helmet (if any)
  if self.equipment.head and self.equipment.head.sprite then
    love.graphics.draw(self.equipment.head.sprite, x + anim.head.x, y + anim.head.y, anim.head.r, anim.head.sx, anim.head.sy)
  end
  -- Draw main hand (weapon)
  if self.equipment.main_hand and self.equipment.main_hand.sprite then
    love.graphics.draw(self.equipment.main_hand.sprite, x + anim.main_hand.x, y + anim.main_hand.y, anim.main_hand.r, anim.main_hand.sx, anim.main_hand.sy)
  end
  -- Draw off hand (weapon/shield)
  if self.equipment.off_hand and self.equipment.off_hand.sprite then
    love.graphics.draw(self.equipment.off_hand.sprite, x + anim.off_hand.x, y + anim.off_hand.y, anim.off_hand.r, anim.off_hand.sx, anim.off_hand.sy)
  end
  -- Draw HP bar and name
  --self:drawHpBar(x, y)
  -- Optionally draw collision box
  self:drawCollisionBox(x, y)
end

function Unit:getComposedImage()
  local canvas = love.graphics.newCanvas(25, 32)
  canvas:setFilter('nearest', 'nearest')
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0,0,0,0)
  -- Load images if needed
  local base_img = self.unit_type.base_sprite
  if type(base_img) == "string" then
    if love.filesystem.getInfo(base_img) then
      base_img = love.graphics.newImage(base_img)
    else
      print("Missing base sprite:", base_img)
      base_img = nil
    end
  end
  local head_img = self.unit_type.head_sprite
  if type(head_img) == "string" then
    if love.filesystem.getInfo(head_img) then
      head_img = love.graphics.newImage(head_img)
    else
      print("Missing head sprite:", head_img)
      head_img = nil
    end
  end
  -- Draw with correct origin
  if base_img then
    local bw, bh = base_img:getWidth(), base_img:getHeight()
    love.graphics.draw(base_img, 12, 16, 0, 1, 1, bw/2, bh)
  end
  if head_img then
    local hw, hh = head_img:getWidth(), head_img:getHeight()
    love.graphics.draw(head_img, 12, 16, 0, 1, 1, hw/2, hh)
  end
  love.graphics.setCanvas()
  return canvas
end

function Unit:pickTarget(battle)
  -- AI: pick nearest enemy, but spread out
  if not battle or not battle.units then return nil end
  local enemies = {}
  for _, u in ipairs(battle.units) do
    if u.battle_party ~= self.battle_party and u.health > 0 then
      table.insert(enemies, u)
    end
  end
  if #enemies == 0 then return nil end
  -- Count how many allies are targeting each enemy
  local targetCounts = {}
  for _, ally in ipairs(battle.units) do
    if ally.battle_party == self.battle_party and ally ~= self and ally.battle_target then
      targetCounts[ally.battle_target] = (targetCounts[ally.battle_target] or 0) + 1
    end
  end
  -- Prefer nearest enemy with lowest target count
  table.sort(enemies, function(a, b)
    local ca = targetCounts[a] or 0
    local cb = targetCounts[b] or 0
    if ca ~= cb then return ca < cb end
    local da = math.abs(a.battle_x - self.battle_x) + math.abs(a.battle_y - self.battle_y)
    local db = math.abs(b.battle_x - self.battle_x) + math.abs(b.battle_y - self.battle_y)
    return da < db
  end)
  return enemies[1]
end

-- State machine update for battle
function Unit:update(dt, battle)
  -- If dead, do nothing
  if self.health <= 0 then return end

  -- State timers
  self.state_timer = self.state_timer - dt
  if self.state_timer < 0 then self.state_timer = 0 end

  -- Helper: get weapon and range
  local weapon = self.equipment and self.equipment.main_hand or nil
  local weapon_range = weapon and weapon.range or 24
  local weapon_damage = weapon and weapon.damage or 5
  local attack_speed = weapon and weapon.attack_speed or 1.2
  local windup_time = 1
  local recover_time = 0.5
  local stagger_time = 0.4
  local block_chance = 0.25
  local move_speed = self.speed or 15

  -- Helper: distance to target
  local function distToTarget(target)
    if not target then return math.huge end
    local dx = target.battle_x - self.battle_x
    local dy = target.battle_y - self.battle_y
    return math.sqrt(dx*dx + dy*dy)
  end

  if self.state == "idle" then
    -- Pick a target
    if not self.battle_target or self.battle_target.health <= 0 then
      self.battle_target = self:pickTarget(battle)
    end
    if self.battle_target and self.battle_target.health > 0 then
      if distToTarget(self.battle_target) > weapon_range then
        self.state = "moving"
        self.animation = "walk"
        self._stuckTime = 0
        self._lastDist = distToTarget(self.battle_target)
      else
        self.state = "windup"
        self.state_timer = windup_time
        self.animation = "windup"
        self.animationFrame = 1
      end
    end
  elseif self.state == "moving" then
    -- Move toward target
    local target = self.battle_target
    if not target or target.health <= 0 then
      self.state = "idle"
      self.animation = "idle"
      return
    end
    local dx = target.battle_x - self.battle_x
    local dy = target.battle_y - self.battle_y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist > 0 then
      local mx = dx / dist * move_speed * dt
      local my = dy / dist * move_speed * dt
      -- Collision handled by battle:moveWithCollision
      if battle and battle.moveWithCollision then
        battle:moveWithCollision(self, mx, my, dt)
      else
        self.battle_x = self.battle_x + mx
        self.battle_y = self.battle_y + my
      end
    end
    -- Animation: 2-frame walk
    self.animation = "walk"
    self.animationFrame = 1 + math.floor(love.timer.getTime() * 6) % 2
    -- Stuck detection
    self._stuckTime = self._stuckTime or 0
    self._lastDist = self._lastDist or dist
    if dist >= self._lastDist - 1e-2 then
      self._stuckTime = self._stuckTime + dt
    else
      self._stuckTime = 0
    end
    self._lastDist = dist
    if self._stuckTime > 1.0 then
      -- Try to pick a new target
      local newTarget = self:pickTarget(battle)
      if newTarget ~= self.battle_target then
        self.battle_target = newTarget
        self._stuckTime = 0
        self._lastDist = distToTarget(self.battle_target)
      end
    end
    if dist <= weapon_range then
      self.state = "windup"
      self.state_timer = windup_time
      self.animation = "windup"
      self.animationFrame = 1
      self._stuckTime = 0
    end
  elseif self.state == "windup" then
    -- Play windup, then attack
    self.animation = "windup"
    if self.state_timer <= 0 then
      self.state = "attacking"
      self.state_timer = attack_speed / 3
      self.animation = "attack"
      self.animationFrame = 1
      self._attack_resolved = false
    end
  elseif self.state == "attacking" then
    -- Attack happens on first frame
    if not self._attack_resolved then
      local target = self.battle_target
      if target and target.health > 0 and distToTarget(target) <= weapon_range + 4 then
        -- Block check
        if math.random() < block_chance then
          target.state = "blocking"
          target.state_timer = 0.1
          target.animation = "block"
          target.animationFrame = 1
        else
          -- Take damage
          target.health = target.health - weapon_damage
          -- Knockback
          local dx = target.battle_x - self.battle_x
          local dy = target.battle_y - self.battle_y
          local dist = math.sqrt(dx*dx + dy*dy)
          if dist > 0 then
            local kb = 12
            target.battle_x = target.battle_x + dx/dist * kb
            target.battle_y = target.battle_y + dy/dist * kb
          end
          -- Stagger chance
          if math.random() < 0.2 then
            target.state = "staggered"
            target.state_timer = stagger_time
            target.animation = "stagger"
            target.animationFrame = 1
            -- Bigger knockback
            if dist > 0 then
              local kb = 28
              target.battle_x = target.battle_x + dx/dist * kb
              target.battle_y = target.battle_y + dy/dist * kb
            end
          end
        end
      end
      self._attack_resolved = true
    end
    -- Animation: 3-frame attack
    self.animationFrame = 1 + math.floor((attack_speed/3 - self.state_timer) / (attack_speed/9))
    if self.state_timer <= 0 then
      self.state = "recovering"
      self.state_timer = recover_time
      self.animation = "recover"
      self.animationFrame = 1
    end
  elseif self.state == "recovering" then
    self.animation = "recover"
    if self.state_timer <= 0 then
      self.state = "idle"
      self.animation = "idle"
      self.animationFrame = 1
    end
  elseif self.state == "blocking" then
    self.animation = "block"
    if self.state_timer <= 0 then
      self.state = "idle"
      self.animation = "idle"
      self.animationFrame = 1
    end
  elseif self.state == "staggered" then
    self.animation = "stagger"
    if self.state_timer <= 0 then
      self.state = "idle"
      self.animation = "idle"
      self.animationFrame = 1
    end
  end
end

local UnitModule = {}

UnitModule.debugCollision = true
UnitModule.debugOnlyCollision = true

function UnitModule.create(templateName)
  return Unit(templateName)
end

function UnitModule.getComposedImage(unit)
  return unit:getComposedImage()
end

return UnitModule 