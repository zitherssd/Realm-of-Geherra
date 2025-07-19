local PartySystem = {}

local GRID_SIZE = 128

function PartySystem:init(party_defs)
    self.parties = {}
    for _, party in ipairs(party_defs) do
        table.insert(self.parties, party)
    end
    self:buildPartyGrid()
end

function PartySystem:getCell(x, y)
    return math.floor(x / GRID_SIZE), math.floor(y / GRID_SIZE)
end

function PartySystem:buildPartyGrid()
    local grid = {}
    for _, party in ipairs(self.parties) do
        local cx, cy = self:getCell(party.x, party.y)
        grid[cx] = grid[cx] or {}
        grid[cx][cy] = grid[cx][cy] or {}
        table.insert(grid[cx][cy], party)
    end
    self.partyGrid = grid
end

function PartySystem:getNearbyParties(px, py, radius)
    local cx, cy = self:getCell(px, py)
    local parties = {}
    for dx = -1, 1 do
        for dy = -1, 1 do
            local cell = self.partyGrid[cx + dx] and self.partyGrid[cx + dx][cy + dy]
            if cell then
                for _, party in ipairs(cell) do
                    local dist = math.sqrt((px - party.x)^2 + (py - party.y)^2)
                    if dist < radius then
                        table.insert(parties, party)
                    end
                end
            end
        end
    end
    return parties
end

function PartySystem:addParty(party)
    table.insert(self.parties, party)
    self:buildPartyGrid()
end

function PartySystem:removeParty(party)
    for i, p in ipairs(self.parties) do
        if p == party then
            table.remove(self.parties, i)
            break
        end
    end
    self:buildPartyGrid()
end

function PartySystem:update(dt, player)
    -- Example: update bandit parties (expand for more AI later)
    for _, party in ipairs(self.parties) do
        if party.party_type == "bandit" then
            -- Add bandit AI here (wander, chase, etc.)
        end
        -- Add other party types' AI here as needed
    end
    self:buildPartyGrid()
end

return PartySystem