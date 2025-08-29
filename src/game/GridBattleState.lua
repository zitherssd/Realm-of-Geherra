local GridBattleState = {}

local PartyModule = require('src.game.modules.PartyModule')
local GameState = require('src.game.GameState')
local PlayerModule = require('src.game.modules.PlayerModule')
local UnitModule = require('src.game.modules.UnitModule')

-- Grid configuration
local GRID_SIZE = 32
local GRID_WIDTH = 20
local GRID_HEIGHT = 12
local BATTLE_WIDTH = GRID_WIDTH * GRID_SIZE
local BATTLE_HEIGHT = GRID_HEIGHT * GRID_SIZE

-- Timing system (20 ticks per second)
local TICKS_PER_SECOND = 20
local ATTACK_COOLDOWN = 50  -- ticks after attacking
local MOVE_COOLDOWN_BASE = 120  -- base ticks for movement cooldown

-- Battle phases
local PHASES = {
  DEPLOYMENT = "deployment",
  BATTLE = "battle",
  VICTORY = "victory"
}

function GridBattleState:new()
  local obj = {
    grid = {},
    units = {},
    parties = {},
    phase = PHASES.DEPLOYMENT,
    selectedUnit = nil,
    tickTimer = 0,
    currentTick = 0,
    result = nil,
    backgroundImage = nil,
    playerUnit = nil,
    playerInputCooldown = 0
  }
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function GridBattleState:initializeGrid()
  self.grid = {}
  for x = 1, GRID_WIDTH do
    self.grid[x] = {}
    for y = 1, GRID_HEIGHT do
      self.grid[x][y] = {
        unit = nil,
        walkable = true,
        x = x,
        y = y
      }
    end
  end
end

function GridBattleState:placeUnit(unit, gridX, gridY)
  if gridX < 1 or gridX > GRID_WIDTH or gridY < 1 or gridY > GRID_HEIGHT then
    return false
  end
  
  if self.grid[gridX][gridY].unit then
    return false -- Cell occupied
  end
  
  unit.gridX = gridX
  unit.gridY = gridY
  unit.battle_x = (gridX - 1) * GRID_SIZE + GRID_SIZE / 2
  unit.battle_y = (gridY - 1) * GRID_SIZE + GRID_SIZE / 2
  unit.battle_party = unit.battle_party or 1
  unit.battle_cooldown = 0
  unit.battle_target = nil
  unit.last_action = "none"
  unit.action_cooldown = 0
  
  self.grid[gridX][gridY].unit = unit
  table.insert(self.units, unit)
  
  return true
end

function GridBattleState:deployParties(party1, party2)
  self.parties = {party1, party2}
  
  -- Deploy party 1 on the left side
  local leftX = 3
  for i, unit in ipairs(party1.units) do
    local gridY = 3 + (i - 1) * 2
    if gridY <= GRID_HEIGHT then
      self:placeUnit(unit, leftX, gridY)
      unit.battle_party = 1
      
      -- Mark the first controllable unit as the player unit
      if unit.controllable and not self.playerUnit then
        self.playerUnit = unit
      end
    end
  end
  
  -- Deploy party 2 on the right side
  local rightX = GRID_WIDTH - 2
  for i, unit in ipairs(party2.units) do
    local gridY = 3 + (i - 1) * 2
    if gridY <= GRID_HEIGHT then
      self:placeUnit(unit, rightX, gridY)
      unit.battle_party = 2
    end
  end
end

function GridBattleState:getGridPosition(mouseX, mouseY)
  local gridX = math.floor(mouseX / GRID_SIZE) + 1
  local gridY = math.floor(mouseY / GRID_SIZE) + 1
  return gridX, gridY
end

function GridBattleState:isValidMove(unit, targetX, targetY)
  if targetX < 1 or targetX > GRID_WIDTH or targetY < 1 or targetY > GRID_HEIGHT then
    return false
  end
  
  if self.grid[targetX][targetY].unit then
    return false
  end
  
  -- Check if target is within movement range
  local distance = math.abs(targetX - unit.gridX) + math.abs(targetY - unit.gridY)
  local moveRange = unit.speed and math.floor(unit.speed / 10) or 1
  return distance <= moveRange
end

function GridBattleState:moveUnit(unit, targetX, targetY)
  if not self:isValidMove(unit, targetX, targetY) then
    return false
  end
  
  -- Clear old position
  self.grid[unit.gridX][unit.gridY].unit = nil
  
  -- Set new position
  unit.gridX = targetX
  unit.gridY = targetY
  unit.battle_x = (targetX - 1) * GRID_SIZE + GRID_SIZE / 2
  unit.battle_y = (targetY - 1) * GRID_SIZE + GRID_SIZE / 2
  
  -- Update grid
  self.grid[targetX][targetY].unit = unit
  
  return true
end

function GridBattleState:findTarget(unit)
  local enemies = {}
  for _, u in ipairs(self.units) do
    if u.battle_party ~= unit.battle_party and u.health > 0 then
      table.insert(enemies, u)
    end
  end
  
  if #enemies == 0 then return nil end
  
  -- Find nearest enemy
  local nearest = nil
  local minDistance = math.huge
  
  for _, enemy in ipairs(enemies) do
    local distance = math.abs(enemy.gridX - unit.gridX) + math.abs(enemy.gridY - unit.gridY)
    if distance < minDistance then
      minDistance = distance
      nearest = enemy
    end
  end
  
  return nearest
end

-- Simple A* pathfinding
function GridBattleState:findPath(startX, startY, targetX, targetY)
  if startX == targetX and startY == targetY then
    return {}
  end
  
  local openSet = {}
  local closedSet = {}
  local cameFrom = {}
  local gScore = {}
  local fScore = {}
  
  local function heuristic(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
  end
  
  local function getKey(x, y)
    return x .. "," .. y
  end
  
  local function reconstructPath(current)
    local path = {}
    while cameFrom[current] do
      local x, y = current:match("(%d+),(%d+)")
      table.insert(path, 1, {x = tonumber(x), y = tonumber(y)})
      current = cameFrom[current]
    end
    return path
  end
  
  local startKey = getKey(startX, startY)
  table.insert(openSet, startKey)
  gScore[startKey] = 0
  fScore[startKey] = heuristic(startX, startY, targetX, targetY)
  
  while #openSet > 0 do
    -- Find lowest fScore
    local currentKey = openSet[1]
    local currentIndex = 1
    for i, key in ipairs(openSet) do
      if fScore[key] < fScore[currentKey] then
        currentKey = key
        currentIndex = i
      end
    end
    
    -- Remove from openSet
    table.remove(openSet, currentIndex)
    table.insert(closedSet, currentKey)
    
    local currentX, currentY = currentKey:match("(%d+),(%d+)")
    currentX, currentY = tonumber(currentX), tonumber(currentY)
    
    -- Check if we reached the target
    if currentX == targetX and currentY == targetY then
      return reconstructPath(currentKey)
    end
    
    -- Check neighbors (orthogonal only)
    local neighbors = {
      {currentX + 1, currentY},
      {currentX - 1, currentY},
      {currentX, currentY + 1},
      {currentX, currentY - 1}
    }
    
    for _, neighbor in ipairs(neighbors) do
      local nx, ny = neighbor[1], neighbor[2]
      local neighborKey = getKey(nx, ny)
      
      -- Skip if out of bounds
      if nx >= 1 and nx <= GRID_WIDTH and ny >= 1 and ny <= GRID_HEIGHT then
        -- Skip if in closed set
        local found = false
        for _, key in ipairs(closedSet) do
          if key == neighborKey then
            found = true
            break
          end
        end
        
        if not found then
          -- Skip if occupied by a unit (unless it's the target)
          if not self.grid[nx][ny].unit or (nx == targetX and ny == targetY) then
            local tentativeGScore = gScore[currentKey] + 1
            
            -- Check if neighbor is in openSet
            local inOpenSet = false
            for _, key in ipairs(openSet) do
              if key == neighborKey then
                inOpenSet = true
                break
              end
            end
            
            if not inOpenSet then
              table.insert(openSet, neighborKey)
              cameFrom[neighborKey] = currentKey
              gScore[neighborKey] = tentativeGScore
              fScore[neighborKey] = tentativeGScore + heuristic(nx, ny, targetX, targetY)
            elseif tentativeGScore < (gScore[neighborKey] or math.huge) then
              cameFrom[neighborKey] = currentKey
              gScore[neighborKey] = tentativeGScore
              fScore[neighborKey] = tentativeGScore + heuristic(nx, ny, targetX, targetY)
            end
          end
        end
      end
    end
  end
  
  -- No path found
  return nil
end

function GridBattleState:attack(attacker, target)
  if not target or target.health <= 0 then return false end
  
  -- Calculate Manhattan distance (no diagonal attacks)
  local distance = math.abs(target.gridX - attacker.gridX) + math.abs(target.gridY - attacker.gridY)
  local attackRange = attacker.attack_range or 1
  
  -- Only allow orthogonal attacks (not diagonal)
  local dx = math.abs(target.gridX - attacker.gridX)
  local dy = math.abs(target.gridY - attacker.gridY)
  local isDiagonal = dx > 0 and dy > 0
  
  if distance <= attackRange and not isDiagonal then
    -- Calculate damage
    local damage = attacker.attack or 10
    local defense = target.defense or 5
    local finalDamage = math.max(1, damage - defense)
    
    target.health = math.max(0, target.health - finalDamage)
    
    -- Visual feedback
    target.battle_flash = 0.2
    
    print(string.format("%s attacks %s for %d damage!", attacker.name, target.name, finalDamage))
    return true
  end
  return false
end

function GridBattleState:updateUnitAI(unit)
  if unit.health <= 0 then return end
  
  -- Skip AI for player-controlled units
  if unit.controllable and unit == self.playerUnit then
    -- Still decrement cooldown for player unit
    if unit.action_cooldown > 0 then
      unit.action_cooldown = unit.action_cooldown - 1
    end
    return
  end
  
  -- Check if unit is on cooldown
  if unit.action_cooldown > 0 then
    unit.action_cooldown = unit.action_cooldown - 1
    return
  end
  
  -- Check if current target is still alive, if not, clear it
  if unit.battle_target and unit.battle_target.health <= 0 then
    unit.battle_target = nil
  end
  
  local target = unit.battle_target or self:findTarget(unit)
  if not target then return end
  
  local distance = math.abs(target.gridX - unit.gridX) + math.abs(target.gridY - unit.gridY)
  local attackRange = unit.attack_range or 1
  
  -- Check if we can attack (must be orthogonal, not diagonal)
  local dx = math.abs(target.gridX - unit.gridX)
  local dy = math.abs(target.gridY - unit.gridY)
  local isDiagonal = dx > 0 and dy > 0
  local canAttack = distance <= attackRange and not isDiagonal
  
  if canAttack then
    -- Attack
    if self:attack(unit, target) then
      unit.last_action = "attack"
      unit.action_cooldown = ATTACK_COOLDOWN
      
      -- Check if target died from this attack
      if target.health <= 0 then
        unit.battle_target = nil  -- Clear target so we find a new one next tick
      end
    end
  else
    -- Move towards target using pathfinding
    local path = self:findPath(unit.gridX, unit.gridY, target.gridX, target.gridY)
    
    if path and #path > 0 then
      -- Move to the first step in the path
      local nextStep = path[1]
      local moveX, moveY = nextStep.x, nextStep.y
      
      if self:isValidMove(unit, moveX, moveY) then
        if self:moveUnit(unit, moveX, moveY) then
          unit.last_action = "move"
          -- Calculate movement cooldown based on unit speed
          local moveCooldown = math.floor(MOVE_COOLDOWN_BASE / (unit.speed or 30))
          unit.action_cooldown = moveCooldown
        end
      else
        -- Path is blocked, try to find a new path next tick
        unit.battle_target = target  -- Keep the target, but don't move this tick
      end
    else
      -- No path found, try simple movement as fallback
      local dx = target.gridX - unit.gridX
      local dy = target.gridY - unit.gridY
      
      local moveX = unit.gridX
      local moveY = unit.gridY
      
      if math.abs(dx) > math.abs(dy) then
        moveX = unit.gridX + (dx > 0 and 1 or -1)
      else
        moveY = unit.gridY + (dy > 0 and 1 or -1)
      end
      
      if self:isValidMove(unit, moveX, moveY) then
        if self:moveUnit(unit, moveX, moveY) then
          unit.last_action = "move"
          -- Calculate movement cooldown based on unit speed
          local moveCooldown = math.floor(MOVE_COOLDOWN_BASE / (unit.speed or 30))
          unit.action_cooldown = moveCooldown
        end
      end
    end
  end
end

function GridBattleState:update(dt)
  if self.phase == PHASES.DEPLOYMENT then
    -- Wait for deployment to complete
    return
  elseif self.phase == PHASES.BATTLE then
    -- Update player input cooldown
    if self.playerInputCooldown > 0 then
      self.playerInputCooldown = self.playerInputCooldown - dt
    end
    
    -- Update tick timer
    self.tickTimer = self.tickTimer + dt
    local ticksThisFrame = math.floor(self.tickTimer * TICKS_PER_SECOND)
    
    -- Process ticks
    for i = 1, ticksThisFrame do
      self.currentTick = self.currentTick + 1
      
      -- Update all units for this tick
      for _, unit in ipairs(self.units) do
        if unit.health > 0 then
          self:updateUnitAI(unit)
        end
      end
    end
    
    -- Reset tick timer
    self.tickTimer = self.tickTimer - (ticksThisFrame / TICKS_PER_SECOND)
    
    -- Update flash effects (still use dt for smooth visual effects)
    for _, unit in ipairs(self.units) do
      if unit.battle_flash then
        unit.battle_flash = unit.battle_flash - dt
        if unit.battle_flash <= 0 then
          unit.battle_flash = nil
        end
      end
    end
    
    -- Check victory
    self:checkVictory()
  end
end

function GridBattleState:checkVictory()
  local alive1, alive2 = false, false
  
  for _, unit in ipairs(self.units) do
    if unit.battle_party == 1 and unit.health > 0 then
      alive1 = true
    elseif unit.battle_party == 2 and unit.health > 0 then
      alive2 = true
    end
  end
  
  if not alive1 then
    self.result = "Enemy Victory!"
    self.phase = PHASES.VICTORY
  elseif not alive2 then
    self.result = "Player Victory!"
    self.phase = PHASES.VICTORY
  end
end

function GridBattleState:mousepressed(x, y, button)
  if self.phase == PHASES.DEPLOYMENT then
    local gridX, gridY = self:getGridPosition(x, y)
    if self.selectedUnit then
      if self:placeUnit(self.selectedUnit, gridX, gridY) then
        self.selectedUnit = nil
        -- Check if all units are deployed
        local deployed = 0
        for _, unit in ipairs(self.units) do
          if unit.gridX then deployed = deployed + 1 end
        end
        if deployed == #self.units then
          self.phase = PHASES.BATTLE
        end
      end
    end
  end
end

function GridBattleState:keypressed(key)
  if key == 'escape' then
    GameState:pop()
  elseif key == 'space' then
    if self.phase == PHASES.DEPLOYMENT then
      -- Auto-deploy remaining units
      self:autoDeploy()
      self.phase = PHASES.BATTLE
    elseif self.phase == PHASES.BATTLE then
      -- Player attack
      self:handlePlayerAttack()
    end
  elseif self.phase == PHASES.BATTLE and self.playerUnit then
    -- Player movement
    if key == 'w' then
      self:handlePlayerMove(0, -1)
    elseif key == 's' then
      self:handlePlayerMove(0, 1)
    elseif key == 'a' then
      self:handlePlayerMove(-1, 0)
    elseif key == 'd' then
      self:handlePlayerMove(1, 0)
    end
  end
end

function GridBattleState:autoDeploy()
  -- Auto-deploy any remaining units
  for _, party in ipairs(self.parties) do
    for _, unit in ipairs(party.units) do
      if not unit.gridX then
        -- Find empty position
        for x = 1, GRID_WIDTH do
          for y = 1, GRID_HEIGHT do
            if not self.grid[x][y].unit then
              self:placeUnit(unit, x, y)
              break
            end
          end
          if unit.gridX then break end
        end
      end
    end
  end
end

function GridBattleState:draw()
  local w, h = love.graphics.getDimensions()
  
  -- Draw background
  love.graphics.setColor(0.2, 0.3, 0.4, 1)
  love.graphics.rectangle('fill', 0, 0, w, h)
  
  -- Draw grid
  love.graphics.setColor(0.3, 0.4, 0.5, 0.5)
  for x = 0, GRID_WIDTH do
    love.graphics.line(x * GRID_SIZE, 0, x * GRID_SIZE, BATTLE_HEIGHT)
  end
  for y = 0, GRID_HEIGHT do
    love.graphics.line(0, y * GRID_SIZE, BATTLE_WIDTH, y * GRID_SIZE)
  end
  
  -- Draw units
  for _, unit in ipairs(self.units) do
    if unit.health > 0 then
      -- Flash effect when taking damage
      if unit.battle_flash then
        love.graphics.setColor(1, 0, 0, 1)
      else
        love.graphics.setColor(1, 1, 1, 1)
      end
      
      -- Draw unit as a colored circle
      local color = unit.battle_party == 1 and {0, 0.7, 1, 1} or {1, 0.3, 0.3, 1}
      
      -- Special color for player unit
      if unit == self.playerUnit then
        color = {0, 1, 0, 1}  -- Green for player
      end
      
      -- Dim the unit if it's on cooldown
      if unit.action_cooldown and unit.action_cooldown > 0 then
        color[4] = 0.5  -- Reduce alpha
      end
      
      love.graphics.setColor(unpack(color))
      love.graphics.circle('fill', unit.battle_x, unit.battle_y, 12)
      
      -- Draw extra border for player unit
      if unit == self.playerUnit then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle('line', unit.battle_x, unit.battle_y, 14)
      end
      
      -- Draw cooldown indicator
      if unit.action_cooldown and unit.action_cooldown > 0 then
        love.graphics.setColor(1, 1, 0, 0.8)
        love.graphics.circle('line', unit.battle_x, unit.battle_y, 16)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(unit.action_cooldown, unit.battle_x - 10, unit.battle_y - 8, 20, 'center')
      end
      
      -- Draw unit name
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.printf(unit.name, unit.battle_x - 30, unit.battle_y - 25, 60, 'center')
      
      -- Draw health bar
      local healthPercent = unit.health / (unit.max_health or unit.health)
      love.graphics.setColor(0.2, 0.2, 0.2, 1)
      love.graphics.rectangle('fill', unit.battle_x - 15, unit.battle_y + 15, 30, 4)
      love.graphics.setColor(0.2, 1, 0.2, 1)
      love.graphics.rectangle('fill', unit.battle_x - 15, unit.battle_y + 15, 30 * healthPercent, 4)
    end
  end
  
  -- Draw UI
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print("Phase: " .. self.phase, 10, 10)
  love.graphics.print("Tick: " .. self.currentTick, 10, 25)
  
  if self.phase == PHASES.DEPLOYMENT then
    love.graphics.print("Click to place units, Space to auto-deploy", 10, 40)
  elseif self.phase == PHASES.BATTLE then
    love.graphics.print("Battle in progress...", 10, 40)
    love.graphics.print("WASD: Move player (green), Space: Attack", 10, 55)
  end
  
  if self.result then
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.printf(self.result, 0, h/2 - 20, w, 'center')
    love.graphics.setColor(1, 1, 1, 1)
  end
end

function GridBattleState:handlePlayerMove(dx, dy)
  if not self.playerUnit or self.playerUnit.health <= 0 then return end
  if self.playerUnit.action_cooldown > 0 then return end
  if self.playerInputCooldown > 0 then return end
  
  local newX = self.playerUnit.gridX + dx
  local newY = self.playerUnit.gridY + dy
  
  if self:isValidMove(self.playerUnit, newX, newY) then
    if self:moveUnit(self.playerUnit, newX, newY) then
      self.playerUnit.last_action = "move"
      -- Calculate movement cooldown based on unit speed
      local moveCooldown = math.floor(MOVE_COOLDOWN_BASE / (self.playerUnit.speed or 30))
      self.playerUnit.action_cooldown = moveCooldown
      self.playerInputCooldown = 0.1 -- Prevent rapid input
    end
  end
end

function GridBattleState:handlePlayerAttack()
  if not self.playerUnit or self.playerUnit.health <= 0 then return end
  if self.playerUnit.action_cooldown > 0 then return end
  if self.playerInputCooldown > 0 then return end
  
  local attackRange = self.playerUnit.attack_range or 1
  local attacked = false
  
  -- Find nearest enemy within attack range
  for _, unit in ipairs(self.units) do
    if unit.battle_party ~= self.playerUnit.battle_party and unit.health > 0 then
      local distance = math.abs(unit.gridX - self.playerUnit.gridX) + math.abs(unit.gridY - self.playerUnit.gridY)
      
      -- Check if we can attack (must be orthogonal, not diagonal)
      local dx = math.abs(unit.gridX - self.playerUnit.gridX)
      local dy = math.abs(unit.gridY - self.playerUnit.gridY)
      local isDiagonal = dx > 0 and dy > 0
      
      if distance <= attackRange and not isDiagonal then
        if self:attack(self.playerUnit, unit) then
          self.playerUnit.last_action = "attack"
          self.playerUnit.action_cooldown = ATTACK_COOLDOWN
          self.playerInputCooldown = 0.1 -- Prevent rapid input
          attacked = true
          break -- Attack first valid target
        end
      end
    end
  end
  
  if not attacked then
    print("No valid target in range!")
  end
end

function GridBattleState:enter(party1, party2, stage)
  self:initializeGrid()
  self:deployParties(party1, party2)
  self.phase = PHASES.DEPLOYMENT
  self.result = nil
end

return GridBattleState 