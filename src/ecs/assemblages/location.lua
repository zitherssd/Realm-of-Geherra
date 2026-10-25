-- ecs/assemblages/location.lua
-- Assembles a persistent world-map location (village, town, ruin, etc.).

local Concord = require("src.libs.concord")
local IdAllocator = require("src.core.id_allocator")

local function locationAssemblage(e, id, name)
    e:give("location")
    local allocator = IdAllocator.forWorld(e.__world)
    if id ~= nil then
        e.id = allocator:claim(id)
    else
        e.id = allocator:allocate("location")
    end
    e.name = name or "Location"
    e.type = "town"
    e.x, e.y = 0, 0
    e.sprite = nil  -- optional world-map marker sprite path (scaled down)
    e.faction = nil
    e.owner = nil
    e.population = 100
    e.prosperity = 50
    e.profile = 50        -- discoverability; overridden by location_population_system
    e.discovered = true   -- flips false for hidden types (see data/visibility.lua)
    e.npcs = {}
    e.stationedParties = {}
    e.quests = {}
    e.shops = {}
end

local Location = {assemble = locationAssemblage}

function Location.create(world, id, name)
    if id ~= nil then
        IdAllocator.forWorld(world):assertAvailable(id)
    end
    return Concord.entity(world):assemble(locationAssemblage, id, name)
end

return Location
