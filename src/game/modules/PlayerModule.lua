local PlayerModule = {}
local PartyModule = require('src.game.modules.PartyModule')
local LocationsModule = require('src.game.modules.LocationsModule')
local InputModule = require('src.game.modules.InputModule')

function PlayerModule:getPlayerParty()
  for _, party in ipairs(PartyModule.parties) do
    if party.id == "player" then return party end
  end
end

function PlayerModule:update(dt)
  local player = self:getPlayerParty()
  if not player then return end
  local x, y = InputModule:getMovementDirection()
  -- Normalize diagonal movement
  if x ~= 0 and y ~= 0 then
    local norm = math.sqrt(x * x + y * y)
    x, y = x / norm, y / norm
  end
  local speed = 100 -- pixels per second
  player.position.x = player.position.x + x * speed * dt
  player.position.y = player.position.y + y * speed * dt
end

function PlayerModule:checkNearbyInteractables()
  local player = self:getPlayerParty()
  if not player then return end
  local px, py = player.position.x, player.position.y
  local radius = 32
  -- Check locations
  for _, loc in ipairs(LocationsModule.locations) do
    local dx, dy = loc.position.x - px, loc.position.y - py
    if (dx*dx + dy*dy) <= (radius*radius) then
      print("Near location: " .. loc.name .. " (interactions: " .. table.concat(loc.interactions, ", ") .. ")")
    end
  end
  -- Check other parties
  for _, party in ipairs(PartyModule.parties) do
    if party.id ~= "player" then
      local dx, dy = party.position.x - px, party.position.y - py
      if (dx*dx + dy*dy) <= (radius*radius) then
        print("Near party: " .. party.name .. " (interactions: " .. table.concat(party.interactions, ", ") .. ")")
      end
    end
  end
end

function PlayerModule:isMoving()
  local x, y = InputModule:getMovementDirection()
  return x ~= 0 or y ~= 0
end

return PlayerModule 