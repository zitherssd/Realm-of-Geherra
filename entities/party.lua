-- entities/party.lua
-- Persistent group of actors traveling together

local Party = {}
Party.__index = Party

function Party.new(name, leaderId, id)
    local self = {
        id = id or (tostring(os.time()) .. "-" .. tostring(math.random(10000, 99999))),
        name = name or "Party",
        
        -- Party composition
        leaderId = leaderId,  -- Reference to leader actor
        actors = {},          -- List of actor entities in the party
        
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

function Party:getLeader()
    if not self.leaderId then return nil end
    for _, actor in ipairs(self.actors) do
        if actor.id == self.leaderId then
            return actor
        end
    end
    return nil
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

-- Add an actor to the party
function Party:addActor(actor)
    table.insert(self.actors, actor)
    
    -- If this is the first member, make them leader
    if self.leaderId == nil then
        self.leaderId = actor.id
    end
end

-- Remove an actor from the party
function Party:removeActor(actor)
    for i, a in ipairs(self.actors) do
        if a == actor then
            table.remove(self.actors, i)
            
            -- If removed actor was leader, assign new leader
            if self.leaderId == actor.id then
                if #self.actors > 0 then
                    self.leaderId = self.actors[1].id
                else
                    self.leaderId = nil
                end
            end
            return true
        end
    end
    return false
end

-- Get all actors
function Party:getActors()
    return self.actors
end

-- Get member count
function Party:getActorCount()
    return #self.actors
end

-- Check if an actor is in this party
function Party:hasActor(actor)
    for _, a in ipairs(self.actors) do
        if a == actor then
            return true
        end
    end
    return false
end

-- Add items to party inventory
function Party:addToInventory(item)
    -- Try to stack with existing items first
    for _, existing in ipairs(self.inventory) do
        if existing.id == item.id then
            existing:addToStack(item.quantity)
            return
        end
    end
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
