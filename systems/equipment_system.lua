-- systems/equipment_system.lua
-- Handle equipment and gear

local EquipmentSystem = {}
local EquipmentData = require("data.equipment")

local function itemSupportsSlot(equipData, slot)
    if not equipData then return false end
    if equipData.slot then
        return equipData.slot == slot
    end
    if equipData.slots then
        for _, s in ipairs(equipData.slots) do
            if s == slot then
                return true
            end
        end
    end
    return false
end

function EquipmentSystem.canEquip(actor, itemId, slot)
    local equipData = EquipmentData[itemId]
    if not equipData then
        return false, "unknown_item"
    end

    if not itemSupportsSlot(equipData, slot) then
        return false, "wrong_slot"
    end

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
        return false, "missing_slot"
    end

    local requirements = equipData.requires
    if requirements and requirements.attributes then
        local attributes = actor.attributes or {}
        for attrName, minValue in pairs(requirements.attributes) do
            local current = attributes[attrName] or 0
            if current < minValue then
                return false, "requirements_not_met"
            end
        end
    end

    return true, nil
end

function EquipmentSystem.equip(actor, itemId, slot)
    if not actor.equipment then
        actor.equipment = {}
    end

    local ok, err = EquipmentSystem.canEquip(actor, itemId, slot)
    if not ok then
        return false, err
    end
    
    -- Unequip previous item if any
    local previousItemId = nil
    if actor.equipment[slot] then
        previousItemId = EquipmentSystem.unequip(actor, slot)
    end
    
    actor.equipment[slot] = itemId
    return previousItemId
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
