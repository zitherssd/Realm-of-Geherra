-- entities/party.lua
-- Persistent group of actors traveling together

local Party = {}
Party.__index = Party

function Party.new(id, name, leaderId)
    local self = {
        id = id,
        name = name or "Party",
        
        -- Party composition
        leaderId = leaderId,  -- Reference to leader actor
        memberIds = {},       -- List of actor IDs in the party
        
        -- Party state
        x = 0,
        y = 0,
        faction = nil,
        
        -- Party resources
        inventory = {},
        treasury = 0,         -- Shared gold/currency
        supplies = 100,       -- Food, water, equipment condition
        
        -- Party modifiers
        speedModifier = 1.0,   -- Multiplier on base movement speed
        visibilityModifier = 1.0,  -- How easily spotted by enemies
        
        -- Party condition flags
        isMoving = false,
        currentObjective = nil,  -- What the party is doing
        morale = 100
    }
    setmetatable(self, Party)
    return self
end

-- Set party position
function Party:setPosition(x, y)
    self.x = x
    self.y = y
end

-- Get party position
function Party:getPosition()
    return self.x, self.y
end

-- Add a member to the party
function Party:addMember(actorId)
    table.insert(self.memberIds, actorId)
    
    -- If this is the first member, make them leader
    if self.leaderId == nil then
        self.leaderId = actorId
    end
end

-- Remove a member from the party
function Party:removeMember(actorId)
    for i, id in ipairs(self.memberIds) do
        if id == actorId then
            table.remove(self.memberIds, i)
            
            -- If removed actor was leader, assign new leader
            if self.leaderId == actorId then
                if #self.memberIds > 0 then
                    self.leaderId = self.memberIds[1]
                else
                    self.leaderId = nil
                end
            end
            return true
        end
    end
    return false
end

-- Get all member IDs
function Party:getMembers()
    return self.memberIds
end

-- Get member count
function Party:getMemberCount()
    return #self.memberIds
end

-- Check if an actor is in this party
function Party:hasMember(actorId)
    for _, id in ipairs(self.memberIds) do
        if id == actorId then
            return true
        end
    end
    return false
end

-- Add items to party inventory
function Party:addToInventory(item)
    table.insert(self.inventory, item)
end

-- Remove item from party inventory
function Party:removeFromInventory(itemIndex)
    if itemIndex >= 1 and itemIndex <= #self.inventory then
        local item = self.inventory[itemIndex]
        table.remove(self.inventory, itemIndex)
        return item
    end
    return nil
end

-- Add currency to party treasury
function Party:addTreasury(amount)
    self.treasury = self.treasury + amount
end

-- Withdraw currency from party treasury
function Party:withdrawTreasury(amount)
    if self.treasury >= amount then
        self.treasury = self.treasury - amount
        return true
    end
    return false
end

-- Get party treasury balance
function Party:getTreasury()
    return self.treasury
end

-- Set objective for the party
function Party:setObjective(objective)
    self.currentObjective = objective
end

-- Get current objective
function Party:getObjective()
    return self.currentObjective
end

-- Adjust morale
function Party:adjustMorale(amount)
    self.morale = math.max(0, math.min(100, self.morale + amount))
end

-- Get morale status
function Party:getMorale()
    return self.morale
end

-- Consume supplies (traveling, camping, etc.)
function Party:consumeSupplies(amount)
    self.supplies = math.max(0, self.supplies - amount)
    return self.supplies > 0  -- Returns false if party is now out of supplies
end

-- Replenish supplies
function Party:replenishSupplies(amount)
    self.supplies = math.min(100, self.supplies + amount)
end

-- Check if party has adequate supplies
function Party:hasAdequateSupplies()
    return self.supplies > 20
end

-- Apply speed modifier (e.g., from terrain, injuries, etc.)
function Party:setSpeedModifier(modifier)
    self.speedModifier = modifier
end

-- Apply visibility modifier (e.g., from stealth, weather, etc.)
function Party:setVisibilityModifier(modifier)
    self.visibilityModifier = modifier
end

return Party
