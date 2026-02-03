local Object = require('lib.classic')
local unitTemplates = require('src.data.unit_templates')
local assetManager = require('src.game.util.AssetManager')
local ItemModule = require('src.game.modules.ItemModule')
local nextUnitId = 1

local Unit = Object:extend()


function Unit:new(templateName)
  local tpl = unitTemplates[templateName]
  if not tpl then error('Unknown unit template: ' .. tostring(templateName)) end
  if tpl.sprite then
    self.sprite = assetManager:loadImage(tpl.sprite)
  else
    self.sprite = assetManager:loadImage("units/peasant.png")
  end
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
  -- Structured equipment slots: { {type="main_hand", item=nil}, ... }
  self.equipmentSlots = {}
  if tpl.equipmentSlots then
    for _, entry in ipairs(tpl.equipmentSlots) do
      if type(entry) == 'string' then
        table.insert(self.equipmentSlots, { type = entry, item = nil })
      elseif type(entry) == 'table' then
        table.insert(self.equipmentSlots, { type = entry.type, item = entry.item })
      end
    end
  end
  -- Legacy quick lookup map kept in sync for existing battle code
  self.equipment = {}
  for _, slot in ipairs(self.equipmentSlots) do
    if slot.item then self.equipment[slot.type] = slot.item end
  end
  self.abilities = tpl.abilities
  self.scale = tpl.scale or 1
  self.size = tpl.size or 3
  self.controllable = tpl.controllable or false
  self.unit_type = tpl.unit_type or "human"
  self.actions = tpl.actions or {}
  -- Commander support
  self.commander = tpl.commander or false
  if self.commander and not self.squads then
    -- Initialize 4 empty squads for commanders
    self.squads = {
      { units = {} },
      { units = {} },
    }
  end
  -- State machine fields
  self.state = "idle"
  self.state_timer = 0
  self.animation = 'idle'
  self.animationFrame = 1
  -- For drawing
  self.battle_x = 0
  self.battle_y = 0
  self.visuals = {
    flash_color = {1, 1, 1}, -- RGB tint
    flash_alpha = 0,         -- 0 = none, 1 = full flash
    shake_intensity = 0,
    shake_time = 0
}
end


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

function Unit:draw()
    if self.health <= 0 then return end
    local sprite = self.sprite
    if not sprite then return end

    local v = self.visuals
    local spriteScale = (self.scale or 1) + math.max(0, (self.size - 3) * 0.1)
    local spriteWidth = sprite:getWidth() * spriteScale
    local spriteHeight = sprite:getHeight() * spriteScale
    local drawX = self.battle_x - 10
    local drawY = self.battle_y - spriteHeight + 6

    -- Apply facing
    local flipX = self.facing_right
    local scaleX = flipX and -spriteScale or spriteScale
    if flipX then drawX = self.battle_x + spriteWidth / 2 end

    -- Shake
    if v.shake_time > 0 then
        drawX = drawX + love.math.random(-v.shake_intensity, v.shake_intensity)
        drawY = drawY + love.math.random(-v.shake_intensity, v.shake_intensity)
    end

   -- 🔹 Step 1: draw the base sprite normally
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sprite, drawX, drawY, 0, scaleX, spriteScale)

    -- 🔹 Step 2: overlay the flash using additive blending (does not affect transparency)
    if v.flash_alpha > 0 then
        love.graphics.setBlendMode("add")
        local intensity = v.flash_alpha * 0.8
        love.graphics.setColor(
            v.flash_color[1],
            v.flash_color[2],
            v.flash_color[3],
            intensity
        )
        love.graphics.draw(sprite, drawX, drawY, 0, scaleX, spriteScale)
        love.graphics.setBlendMode("alpha")
    end


        -- Draw health bar for player unit
    if self.controllable then
        local healthPercent = self.health / (self.max_health or self.health)
        local hpBarY = self.battle_y + 7
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle('fill', self.battle_x - 15, hpBarY, 30, 4)
        love.graphics.setColor(0.2, 1, 0.2, 1)
        love.graphics.rectangle('fill', self.battle_x - 15, hpBarY, 30 * healthPercent, 4)
    end
end
  
function Unit:flash(color, duration)
    self.visuals.flash_color = color or {1, 1, 1}
    self.visuals.flash_timer = duration or 0.2
    self.visuals.flash_duration = self.visuals.flash_timer
end

function Unit:shake(duration, intensity)
    self.visuals.shake_time = duration or 0.2
    self.visuals.shake_intensity = intensity or 1
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

function Unit:_applyItemStats(item)
  if not item or not item.stats then return end
  local s = item.stats
  self.attack = (self.attack or 0) + (s.attack or 0)
  self.defense = (self.defense or 0) + (s.defense or 0)
  -- Map item.damage to unit.strength as requested
  self.strength = (self.strength or 0) + (s.damage or 0)
  self.protection = (self.protection or 0) + (s.protection or 0)
end

function Unit:_removeItemStats(item)
  if not item or not item.stats then return end
  local s = item.stats
  self.attack = (self.attack or 0) - (s.attack or 0)
  self.defense = (self.defense or 0) - (s.defense or 0)
  self.strength = (self.strength or 0) - (s.damage or 0)
  self.protection = (self.protection or 0) - (s.protection or 0)
end

-- Action application helpers (tie actions to the item that granted them)
function Unit:_addItemActions(item)
  if not item or not item.actions then return end
  self.actions = self.actions or {}
  for _, act in ipairs(item.actions) do
    local exists = false
    for __, ua in ipairs(self.actions) do
      if ua.id == act.id and ua.sourceItemId == item.id then
        exists = true; break
      end
    end
    if not exists then
      local copy = {}
      for k, v in pairs(act) do copy[k] = v end
      copy.sourceItemId = item.id
      table.insert(self.actions, copy)
    end
  end
end

function Unit:_removeItemActions(item)
  if not item or not self.actions then return end
  local filtered = {}
  for _, ua in ipairs(self.actions) do
    if ua.sourceItemId ~= item.id then
      table.insert(filtered, ua)
    end
  end
  self.actions = filtered
end

function Unit:equip(item)
  if not item then return nil end
  local allowed = ItemModule.resolveEquipSlotTypes(item)
  -- 1) Try exact template slot first if empty
  if item.slot then
    for _, slot in ipairs(self.equipmentSlots or {}) do
      if slot.type == item.slot and slot.item == nil then
        slot.item = item
        self.equipment[slot.type] = item
        self:_applyItemStats(item)
        self:_addItemActions(item)
        return nil
      end
    end
  end
  -- 2) Try any compatible empty slot
  if allowed and #allowed > 0 then
    for _, slot in ipairs(self.equipmentSlots or {}) do
      for _, t in ipairs(allowed) do
        if slot.type == t and slot.item == nil then
          slot.item = item
          self.equipment[slot.type] = item
          self:_applyItemStats(item)
          self:_addItemActions(item)
          return nil
        end
      end
    end
  end
  return nil
end

function Unit:unequip(slotType)
  for _, slot in ipairs(self.equipmentSlots or {}) do
    if slot.type == slotType and slot.item ~= nil then
      local prev = slot.item
      slot.item = nil
      self.equipment[slot.type] = nil
      self:_removeItemStats(prev)
      self:_removeItemActions(prev)
      return prev
    end
  end
  return nil
end

local UnitModule = {}

function UnitModule.create(templateName)
  return Unit(templateName)
end

function UnitModule.createMultiple(templateName, count)
  local units = {}
  for i = 1, count do
    table.insert(units, Unit(templateName))
  end
  return units
end



return UnitModule 