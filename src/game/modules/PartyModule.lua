local PartyModule = {}

PartyModule.parties = {}

function PartyModule:update(dt)
  -- Update all parties (AI, movement, etc.)
  for _, party in ipairs(self.parties) do
    -- party update logic here
  end
end

function PartyModule:draw()
  -- Draw all parties (placeholder: circles)
  for _, party in ipairs(self.parties) do
    love.graphics.setColor(1, 1, 0)
    love.graphics.circle('fill', party.position.x, party.position.y, 12)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(party.name, party.position.x + 14, party.position.y - 8)
  end
end

return PartyModule 