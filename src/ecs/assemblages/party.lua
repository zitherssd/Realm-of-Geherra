-- ecs/assemblages/party.lua
-- Assembles a persistent group of actors traveling together.

local Concord = require("src.libs.concord")

local function partyAssemblage(e, name, leaderId, id)
    e:give("party")
    e.id = id or (tostring(os.time()) .. "-" .. tostring(math.random(10000, 99999)))
    e.name = name or "Party"

    -- Party composition
    e.leaderId = leaderId  -- Reference to leader actor's id
    e.actors = {}          -- List of actor entities in the party

    -- Party state
    e.x, e.y = 0, 0
    e.faction = nil

    -- Party resources
    e.inventory = {}
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
    -- "chase" | "travel". Only parties that opt in (wanderOriginX set, or a
    -- travel system taking ownership) actually move on their own.
    e.state = "idle"
    e.wanderOriginX, e.wanderOriginY = nil, nil
    e.wanderRadius = nil
    e.wanderTarget = nil
    e.wanderPauseTimer = 0
end

local Party = {assemble = partyAssemblage}

function Party.create(world, name, leaderId, id)
    return Concord.entity(world):assemble(partyAssemblage, name, leaderId, id)
end

return Party
