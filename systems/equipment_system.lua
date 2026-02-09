-- systems/equipment_system.lua
-- Handle equipment and gear

local EquipmentSystem = {}

function EquipmentSystem.equip(actor, itemId, slot)
    if not actor.equipment then
        actor.equipment = {}
    end
    
    -- Validate that the actor has this slot
    local hasSlot = false
    if actor.availableSlots then
        for _, s in ipairs(actor.availableSlots) do
            if s == slot then
                hasSlot = true
                break
            end
        end
    end
    
    if not hasSlot then
        return false -- Actor does not have this slot
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
