local Encounter = {
    active = false,
    party = nil,
    options = nil,
    selected = 1,
    onChoice = nil
}

function Encounter:startEncounter(party, onChoice)
    self.active = true
    self.party = party
    self.selected = 1
    self.onChoice = onChoice
    if party.party_type == "enemy" or party.party_type == "bandit" then
        self.options = {"Fight", "Flee"}
    else
        self.options = {"Ignore"}
    end
end

function Encounter:update(dt)
    -- No update needed for static dialogue
end

function Encounter:draw(screenWidth, screenHeight)
    if not self.active then return end
    local w, h = 400, 200
    local x = (screenWidth - w) / 2
    local y = (screenHeight - h) / 2
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', x, y, w, h)
    local party = self.party
    love.graphics.print("Encountered a " .. (party and party.party_type or "party") .. "!", x + 20, y + 20)
    love.graphics.print("Units: " .. table.concat(party and party.types or {}, ", "), x + 20, y + 50)
    for i, option in ipairs(self.options or {}) do
        if i == self.selected then
            love.graphics.setColor(1, 1, 0, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        love.graphics.print(option, x + 40, y + 80 + 30 * (i-1))
    end
end

function Encounter:keypressed(key)
    if not self.active then return end
    if key == "up" or key == "w" then
        self.selected = math.max(1, self.selected - 1)
    elseif key == "down" or key == "s" then
        self.selected = math.min(#self.options, self.selected + 1)
    elseif key == "return" or key == "space" then
        if self.onChoice then
            self.onChoice(self.options[self.selected], self.party)
        end
        self:clear()
    elseif key == "escape" then
        self:clear()
    end
end

function Encounter:clear()
    self.active = false
    self.party = nil
    self.options = nil
    self.selected = 1
    self.onChoice = nil
end

return Encounter