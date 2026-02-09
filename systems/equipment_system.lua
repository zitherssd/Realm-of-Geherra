-- systems/equipment_system.lua
-- Handle equipment and gear

local EquipmentSystem = {}

local SLOTS = {"head", "body", "hands", "feet", "mainHand", "offHand"}

function EquipmentSystem.equip(actor, itemId, slot)
    if not actor.equipment then
        actor.equipment = {}
    end
    
    -- Unequip previous item if any
    if actor.equipment[slot] then
        EquipmentSystem.unequip(actor, slot)
    end
    
    actor.equipment[slot] = itemId
end

function EquipmentSystem.unequip(actor, slot)
    if not actor.equipment then return end
    
    local itemId = actor.equipment[slot]
    actor.equipment[slot] = nil
    return itemId
end

function EquipmentSystem.getEquipped(actor, slot)
    if not actor.equipment then return nil end
    return actor.equipment[slot]
end

function EquipmentSystem.getEquipment(actor)
    return actor.equipment or {}
end

return EquipmentSystem
