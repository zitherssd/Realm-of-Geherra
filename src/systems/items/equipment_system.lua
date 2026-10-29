-- systems/items/equipment_system.lua
-- Handle equipment and gear

local EquipmentSystem = {}
local Items = require("src.data.items")
local Inventory = require("src.systems.items.inventory_system")

local function itemSupportsSlot(item, slot)
    if not item then return false end
    if item.slot then
        return item.slot == slot
    end
    if item.slots then
        for _, s in ipairs(item.slots) do
            if s == slot then
                return true
            end
        end
    end
    return false
end

function EquipmentSystem.canEquip(actor, itemId, slot)
    local item = Items[itemId]
    if not item then
        return false, "unknown_item"
    end

    if not itemSupportsSlot(item, slot) then
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

    local requirements = item.requires
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

-- Slots retain their existing item-ID references; instance state travels with the slot.
function EquipmentSystem.getEquippedItem(actor, slot)
    local id = actor.equipment and actor.equipment[slot]
    if not id then return nil end
    local stored = actor.equipmentItems and actor.equipmentItems[slot]
    if stored and stored.id ~= id then stored = nil end
    local item = Inventory.deepClone(stored or Items[id] or {id = id})
    item.quantity = 1
    if (slot == "offHand" or not stored) and actor.itemDurability and actor.itemDurability[id] ~= nil then
        item.durabilityRemaining = actor.itemDurability[id]
    end
    return item
end

function EquipmentSystem.equip(actor, itemSpec, slot)
    local itemId = type(itemSpec) == "table" and itemSpec.id or itemSpec
    local ok, err = EquipmentSystem.canEquip(actor, itemId, slot)
    if not ok then return false, err end
    local previousId, previousItem = EquipmentSystem.unequip(actor, slot)
    actor.equipment = actor.equipment or {}
    actor.equipmentItems = actor.equipmentItems or {}
    local item = Inventory.deepClone(type(itemSpec) == "table" and itemSpec or Items[itemId])
    item.quantity = 1
    actor.equipment[slot] = itemId
    actor.equipmentItems[slot] = item
    actor.itemDurability = actor.itemDurability or {}
    if slot == "offHand" then actor.itemDurability[itemId] = item.durabilityRemaining end
    return previousId, previousItem
end

function EquipmentSystem.unequip(actor, slot)
    local item = EquipmentSystem.getEquippedItem(actor, slot)
    if not item then return nil end
    actor.equipment[slot] = nil
    if actor.equipmentItems then actor.equipmentItems[slot] = nil end
    if actor.itemDurability and (slot == "offHand" or actor.equipment.offHand ~= item.id) then
        actor.itemDurability[item.id] = nil
    end
    return item.id, item
end

function EquipmentSystem.getEquipped(actor, slot)
    if not actor.equipment then return nil end
    return actor.equipment[slot]
end

function EquipmentSystem.getEquipment(actor)
    return actor.equipment or {}
end

return EquipmentSystem
