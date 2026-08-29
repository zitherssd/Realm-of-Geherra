-- ecs/assemblages/location.lua
-- Assembles a persistent world-map location (village, town, ruin, etc.).

local Concord = require("src.libs.concord")

local function locationAssemblage(e, id, name)
    e:give("location")
    e.id = id
    e.name = name or "Location"
    e.type = "town"
    e.x, e.y = 0, 0
    e.sprite = nil  -- optional world-map marker sprite path (scaled down)
    e.faction = nil
    e.owner = nil
    e.population = 100
    e.prosperity = 50
    e.npcs = {}
    e.quests = {}
    e.shops = {}
end

local Location = {assemble = locationAssemblage}

function Location.create(world, id, name)
    return Concord.entity(world):assemble(locationAssemblage, id, name)
end

return Location
