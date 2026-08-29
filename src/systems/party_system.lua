-- systems/party_system.lua
-- Handle party-level mechanics: membership, movement, resources, stats aggregation

local PartySystem = {}

-- Try to stack an item with an existing entry of the same id in a list.
-- Returns true when merged; false when the caller should insert the item.
local function mergeIntoStack(list, item)
    for _, existing in ipairs(list) do
        if existing.id == item.id then
            if type(existing.addToStack) == "function" then
                existing:addToStack(item.quantity or 1)
            else
                existing.quantity = (existing.quantity or 1) + (item.quantity or 1)
            end
            return true
        end
    end
    return false
end

-- Add an actor to a party (first member added becomes leader by default)
function PartySystem.addActor(party, actor)
    if not party or not actor then return false end
    
    -- Check if actor is already in party
    for _, a in ipairs(party.actors) do
        if a == actor then
            return false  -- Already in party
        end
    end
    
    table.insert(party.actors, actor)

    if party.leaderId == nil then
        party.leaderId = actor.id
    end

    return true
end

-- Remove a specific actor entity from a party
function PartySystem.removeActor(party, actor)
    if not party then return false end

    for i, a in ipairs(party.actors) do
        if a == actor then
            table.remove(party.actors, i)

            if party.leaderId == actor.id then
                party.leaderId = party.actors[1] and party.actors[1].id or nil
            end
            return true
        end
    end
    return false
end

-- True when the given actor entity is a member of the party
function PartySystem.hasActor(party, actor)
    if not party then return false end
    for _, a in ipairs(party.actors) do
        if a == actor then
            return true
        end
    end
    return false
end

-- Get the party's position
function PartySystem.getPosition(party)
    return party.x, party.y
end

-- Set the party's position
function PartySystem.setPosition(party, x, y)
    party.x = x
    party.y = y
end

-- Add an already-instantiated item table to the party inventory, merging into
-- an existing stack of the same id when present.
function PartySystem.addToInventory(party, item)
    if not mergeIntoStack(party.inventory, item) then
        table.insert(party.inventory, item)
    end
end

-- Add a fresh, independent copy of an item definition (e.g. Items[itemId]) to
-- the party inventory. Never stores a reference to the shared data/items.lua
-- catalog tables, and merges into an existing stack of the same id when present.
function PartySystem.addItemDefCopy(party, itemDef, quantity)
    quantity = quantity or 1
    if quantity <= 0 then return end

    local copy = {}
    for k, v in pairs(itemDef or {}) do
        copy[k] = v
    end
    copy.quantity = quantity

    if not mergeIntoStack(party.inventory, copy) then
        table.insert(party.inventory, copy)
    end
end

-- Remove an item from the party inventory by index, returning the removed item
function PartySystem.removeFromInventory(party, itemIndex)
    if itemIndex >= 1 and itemIndex <= #party.inventory then
        local item = party.inventory[itemIndex]
        table.remove(party.inventory, itemIndex)
        return item
    end
    return nil
end

-- Add currency to the party treasury
function PartySystem.addTreasury(party, amount)
    party.treasury = party.treasury + amount
end

-- Withdraw currency from the party treasury; false if insufficient funds
function PartySystem.withdrawTreasury(party, amount)
    if party.treasury >= amount then
        party.treasury = party.treasury - amount
        return true
    end
    return false
end

-- Get the party treasury balance
function PartySystem.getTreasury(party)
    return party.treasury
end

-- Set/get the party's current objective
function PartySystem.setObjective(party, objective)
    party.currentObjective = objective
end

function PartySystem.getObjective(party)
    return party.currentObjective
end

-- Adjust/get morale (clamped 0-100)
function PartySystem.adjustMorale(party, amount)
    party.morale = math.max(0, math.min(100, party.morale + amount))
end

function PartySystem.getMorale(party)
    return party.morale
end

-- Remove an actor from a party
function PartySystem.removeFromParty(party, actorId)
    if not party then return false end
    
    for i, actor in ipairs(party.actors) do
        if actor.id == actorId then
            table.remove(party.actors, i)
            
            -- If removed actor was leader, assign new leader
            if party.leaderId == actorId then
                if #party.actors > 0 then
                    party.leaderId = party.actors[1].id
                else
                    party.leaderId = nil
                end
            end
            return true
        end
    end
    return false
end

-- Get party members (returns actual actor objects from game context)
function PartySystem.getActors(party)
    if not party then return {} end
    
    -- Return the list of actors directly
    return party.actors
end

-- Calculate party's average movement speed
function PartySystem.getPartySpeed(party)
    if not party or #party.actors == 0 then return 100 end
    
    local totalSpeed = 0
    local count = 0
    
    -- This is a simplified calculation
    -- In a full implementation, you'd aggregate from actual actor stats
    for _, actor in ipairs(party.actors) do
        -- Base speed per member (would come from actor stats in real implementation)
        totalSpeed = totalSpeed + 100
        count = count + 1
    end
    
    -- Apply modifiers
    local avgSpeed = totalSpeed / count
    avgSpeed = avgSpeed * (party.speedModifier or 1.0)
    
    return avgSpeed
end

-- Calculate party's detection visibility (how easily they're spotted)
function PartySystem.getPartyVisibility(party)
    if not party or #party.actors == 0 then return 100 end
    
    -- Visibility is based on:
    -- - Party size (more people = more visible)
    -- - Equipment and units (armor glints, formations, etc.)
    -- - Stealth skills of members
    
    local baseVisibility = 100 * (#party.actors / 10)  -- Scale by party size
    local visibility = baseVisibility * (party.visibilityModifier or 1.0)
    
    return visibility
end

-- Average HP percentage (0.0-1.0) across all party members, for HUD bars
function PartySystem.getAveragePartyHpPercent(party)
    if not party or #party.actors == 0 then return 1 end

    local totalCurrent, totalMax = 0, 0
    for _, actor in ipairs(party.actors) do
        local max = actor.maxHp or (actor.stats and actor.stats.health) or 100
        local current = actor.hp or max
        totalCurrent = totalCurrent + current
        totalMax = totalMax + max
    end

    if totalMax <= 0 then return 1 end
    return math.max(0, math.min(1, totalCurrent / totalMax))
end

-- Calculate party's military strength rating
function PartySystem.getPartyStrength(party)
    if not party or #party.actors == 0 then return 0 end
    
    local totalStrength = 0
    
    -- This would aggregate stats from all party members in a real implementation
    for _, actor in ipairs(party.actors) do
        totalStrength = totalStrength + 50  -- Placeholder value
    end
    
    return totalStrength
end

-- Move the party to a new location
function PartySystem.movePartyTo(party, x, y)
    if not party then return false end
    
    party.x = x
    party.y = y
    return true
end

-- Get party's current location
function PartySystem.getPartyLocation(party)
    if not party then return nil, nil end
    return party.x, party.y
end

-- Check if party can undertake travel based on member status
function PartySystem.canTravel(party)
    if not party or #party.actors == 0 then return false end
    
    -- In a full implementation, would check:
    -- - All members are conscious/not wounded
    -- - Party has supplies
    -- - Party movement is not restricted by conditions
    
    return true
end

-- Set party leadership
function PartySystem.setLeader(party, actorId)
    if not party then return false end
    
    for _, actor in ipairs(party.actors) do
        if actor.id == actorId then
            party.leaderId = actorId
            return true
        end
    end
    return false  -- Actor not in party
end

-- Get the party leader's actor entity (nil if no leader assigned)
function PartySystem.getLeader(party)
    if not party or not party.leaderId then return nil end
    for _, actor in ipairs(party.actors) do
        if actor.id == party.leaderId then
            return actor
        end
    end
    return nil
end


return PartySystem
