-- world/encounter.lua
-- Combat or event encounter

local Encounter = {}

function Encounter.new(id, encounterType)
    local self = {
        id = id,
        type = encounterType or "bandits",
        active = false,
        enemies = {},
        allies = {},
        rewards = {gold = 0, items = {}, reputation = {}}
    }
    return self
end

function Encounter:addEnemy(actor)
    table.insert(self.enemies, actor)
end

function Encounter:addAlly(actor)
    table.insert(self.allies, actor)
end

function Encounter:getEnemies()
    return self.enemies
end

function Encounter:getAllies()
    return self.allies
end

function Encounter:isActive()
    return self.active
end

return Encounter
