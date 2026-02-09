-- systems/inventory_system.lua
-- Handle item management and inventory

local InventorySystem = {}

function InventorySystem.addItem(actor, itemId, quantity)
    if not actor.inventory then
        actor.inventory = {}
    end
    if not actor.inventory[itemId] then
        actor.inventory[itemId] = 0
    end
    actor.inventory[itemId] = actor.inventory[itemId] + (quantity or 1)
end

function InventorySystem.removeItem(actor, itemId, quantity)
    if not actor.inventory or not actor.inventory[itemId] then return false end
    
    quantity = quantity or 1
    if actor.inventory[itemId] >= quantity then
        actor.inventory[itemId] = actor.inventory[itemId] - quantity
        if actor.inventory[itemId] <= 0 then
            actor.inventory[itemId] = nil
        end
        return true
    end
    return false
end

function InventorySystem.getItemCount(actor, itemId)
    if not actor.inventory or not actor.inventory[itemId] then return 0 end
    return actor.inventory[itemId]
end

function InventorySystem.getInventory(actor)
    return actor.inventory or {}
end

return InventorySystem
