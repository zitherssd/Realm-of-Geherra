-- Optional personal memory or party memory. Entries contain only IDs and flags.
local Concord = require("src.libs.concord")
local worlds = setmetatable({}, {__mode = "kv"})
local Memory = Concord.component.new("memory", function(component)
    component.knownEvents = {}
    -- Runtime provenance lives outside serialized data. Rehoming an entity or
    -- transplanting its component must not reinterpret event_1 in another world.
    worlds[component] = component.__entity.__world
end)

function Memory:isForWorld(world)
    return worlds[self] == world
end

return Memory
