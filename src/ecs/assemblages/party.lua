-- ecs/assemblages/party.lua
-- Assembles a persistent group of actors traveling together.

local Concord = require("src.libs.concord")
local IdAllocator = require("src.core.id_allocator")

local function partyAssemblage(e, name, leaderId, id)
    e:give("party")
    e:give("memory")
    e:give("world_activity")
    local allocator = IdAllocator.forWorld(e.__world)
    if id ~= nil then
        e.id = allocator:claim(id)
    else
        e.id = allocator:allocate("party")
    end
    e.name = name or "Party"

    -- Party composition
    e.leaderId = leaderId  -- Reference to leader actor's id
    e.actors = {}          -- List of actor entities in the party

    -- Party state
    e.x, e.y = 0, 0
    e.faction = nil

    -- Party resources
    e.inventory = {}
    e.inventoryFormat = "list"
    e.treasury = 0        -- Shared gold/currency
    e.supplies = 100       -- Food, water, equipment condition

    -- Party modifiers
    e.speedModifier = 1.0       -- Multiplier on base movement speed
    e.visibilityModifier = 1.0  -- How easily spotted by enemies
    e.visible = false           -- Recomputed every frame by systems/visibility_system.lua

    -- Party condition flags
    e.isMoving = false
    e.currentObjective = nil  -- What the party is doing
    e.morale = 100

    -- World-map AI state (see systems/party_ai_system.lua): "idle" | "wander" |
    -- "chase" | "travel". TravelActivity owns movement while the latter is set.
    e.state = "idle"
    e.wanderOriginX, e.wanderOriginY = nil, nil
    e.wanderRadius = nil
    e.wanderTarget = nil
    e.wanderPauseTimer = 0
end

local Party = {assemble = partyAssemblage}

function Party.create(world, name, leaderId, id)
    if id ~= nil then
        IdAllocator.forWorld(world):assertAvailable(id)
    end
    return Concord.entity(world):assemble(partyAssemblage, name, leaderId, id)
end

return Party
