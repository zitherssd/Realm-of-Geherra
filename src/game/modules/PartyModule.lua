local PartyModule = {}
local TimeModule = require('src.game.modules.TimeModule')

PartyModule.parties = {}

function PartyModule:update(dt)
  -- Update all parties (AI, movement, etc.)
  for _, party in ipairs(self.parties) do
    -- party update logic here

    -- Passive regen for the player's party while time is running
    if party.id == "player" and TimeModule:getTimeStatus() == "RUNNING" then
      local regenPerSecond = 0.3 -- HP per second (tweak as desired)
      if party.units then
        for _, u in ipairs(party.units) do
          if u.health and u.max_health and u.max_health > 0 and u.health > 0 and u.health < u.max_health then
            u.health = math.min(u.max_health, u.health + regenPerSecond * dt)
          end
        end
      end
    end
  end
end

function PartyModule:getPartyLeader(party)
  if not party or not party.units then return nil end
  return party.units[1] -- Assuming the first unit is the leader
end

function PartyModule:draw()
  -- Draw all parties (placeholder: circles)
  for _, party in ipairs(self.parties) do
    love.graphics.setColor(1, 1, 0)
    love.graphics.draw(PartyModule:getPartyLeader(party).sprite, party.position.x, party.position.y, 0, 0.5,0.5)
    --love.graphics.circle('fill', party.position.x, party.position.y, 12)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(party.name, party.position.x + 14, party.position.y - 8)
  end
end

function PartyModule:getPartyHealthAverage(party)
  local totalPercentage = 0
  local validCount = 0
  for _, unit in ipairs(party.units) do
    if unit.health and unit.max_health and unit.max_health > 0 then
      totalPercentage = totalPercentage + (unit.health / unit.max_health)
      validCount = validCount + 1
    end
  end
    if validCount == 0 then
    return 0
  end

  return totalPercentage / validCount
end

function PartyModule.addUnit(unit)
  if not unit then return end
  local playerParty = PartyModule.parties[1]
  if playerParty then
    playerParty.units = playerParty.units or {}
    -- Handle both single units and arrays of units
    if unit[1] then
      -- It's an array, add all units
      for _, u in ipairs(unit) do
        table.insert(playerParty.units, u)
      end
    else
      -- It's a single unit
      table.insert(playerParty.units, unit)
    end
  end
end

return PartyModule