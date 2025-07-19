-- inventory.lua
-- Player inventory and equipment management
-- Items are unique tables. Equipping moves item from inventory to unit.equipment[slot], unequipping moves it back.

local Inventory = {}

-- Add an item to the inventory
function Inventory.addItem(player, item)
    table.insert(player.inventory, item)
end

-- Remove an item from the inventory (by reference)
function Inventory.removeItem(player, item)
    for i, invItem in ipairs(player.inventory) do
        if invItem == item then
            table.remove(player.inventory, i)
            return true
        end
    end
    return false
end

-- Equip an item to a unit (moves from inventory to unit.equipment[slot])
function Inventory.equipItem(player, unit, item)
    local slot = item.slot
    assert(slot, "Item must have a slot field")
    -- Remove from inventory
    assert(Inventory.removeItem(player, item), "Item not found in inventory")
    -- If something is already equipped, unequip it first
    if unit.equipment[slot] then
        Inventory.unequipItem(player, unit, slot)
    end
    unit.equipment[slot] = item
end

-- Unequip an item from a unit (moves from unit.equipment[slot] to inventory)
function Inventory.unequipItem(player, unit, slot)
    local item = unit.equipment[slot]
    if item then
        Inventory.addItem(player, item)
        unit.equipment[slot] = nil
    end
end

-- Get the player's inventory
function Inventory.getInventory(player)
    return player.inventory
end

return Inventory