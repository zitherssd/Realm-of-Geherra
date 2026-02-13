-- systems/party_system.lua
-- Handle party-level mechanics: membership, movement, stats aggregation

local PartySystem = {}

local GameContext = require("game.game_context")

-- Add an actor to a party
function PartySystem.addActor(party, actor)
    if not party or not actor then return false end
    
    -- Check if actor is already in party
    for _, a in ipairs(party.actors) do
        if a == actor then
            return false  -- Already in party
        end
    end
    
    table.insert(party.actors, actor)
    return true
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

-- Get the party leader
function PartySystem.getLeader(party)
    if not party then return nil end
    return party.leaderId
end

-- Recruit an actor into the party, spending favor
function PartySystem.recruitActor(party, actor, favorCost)
    if not party or not actor then return false, "Invalid arguments" end
    
    local currentFavor = GameContext.data.favor or 0
    if currentFavor < favorCost then
        return false, "Not enough favor"
    end
    
    if PartySystem.addActor(party, actor) then
        GameContext.data.favor = currentFavor - favorCost
        return true
    else
        return false, "Party full or actor already in party"
    end
end

return PartySystem
