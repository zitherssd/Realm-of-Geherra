-- systems/inventory_system.lua
-- Handle item management and inventory for actor, party, and stock inventories.

local InventorySystem = {}

local function deepClone(value, seen)
    if type(value) ~= "table" then
        return value
    end

    if seen and seen[value] then
        return seen[value]
    end

    local copy = {}
    if seen then
        seen[value] = copy
    end

    for key, child in pairs(value) do
        copy[key] = deepClone(child, seen)
    end

    return copy
end

local function inventoryIsList(owner)
    if owner.inventoryFormat == "list" then return true end
    if type(owner.inventory) ~= "table" then return false end
    for key in pairs(owner.inventory) do
        if type(key) == "number" then return true end
    end
    return false
end

local function validQuantity(amount)
    return type(amount) == "number" and amount > 0 and amount % 1 == 0 and
        amount == amount and amount ~= math.huge
end

local function validList(inventory)
    if type(inventory) ~= "table" then return false end
    local count = #inventory
    for key, item in pairs(inventory) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or key > count or
            type(item) ~= "table" or item.id == nil then
            return false
        end
    end
    for index = 1, count do
        if inventory[index] == nil then return false end
    end
    return true
end

local function itemIdOf(item)
    if type(item) == "table" then
        return item.id
    end
    return item
end

local function normalizeItem(item, fallbackQuantity)
    if type(item) == "string" then
        return { id = item, quantity = fallbackQuantity or 1 }
    end
    if type(item) ~= "table" then
        return nil
    end

    local copy = deepClone(item, {})
    copy.quantity = copy.quantity or fallbackQuantity or 1
    return copy
end

local function serializeMetadata(item)
    if type(item) ~= "table" then
        return nil
    end

    local signature = {}
    for key, value in pairs(item) do
        if key ~= "quantity" then
            signature[key] = deepClone(value, {})
        end
    end
    return signature
end

local function deepEqual(left, right)
    if type(left) ~= type(right) then
        return false
    end
    if type(left) ~= "table" then
        return left == right
    end

    for key, value in pairs(left) do
        if not deepEqual(value, right[key]) then
            return false
        end
    end

    for key in pairs(right) do
        if left[key] == nil then
            return false
        end
    end

    return true
end

function InventorySystem.deepClone(value)
    return deepClone(value, {})
end

function InventorySystem.copyInventory(inventory)
    local copied = {}
    if type(inventory) ~= "table" then
        return copied
    end

    for index, item in ipairs(inventory) do
        copied[index] = InventorySystem.deepClone(item)
    end
    return copied
end

function InventorySystem.getInventory(owner)
    if not owner then return {} end
    owner.inventory = owner.inventory or {}
    return owner.inventory
end

function InventorySystem.itemSignature(item)
    if type(item) ~= "table" then
        return nil
    end
    return serializeMetadata(item)
end

function InventorySystem.stackable(itemA, itemB)
    if type(itemA) ~= "table" or type(itemB) ~= "table" then
        return false
    end
    if itemA.id ~= itemB.id then
        return false
    end
    return deepEqual(InventorySystem.itemSignature(itemA), InventorySystem.itemSignature(itemB))
end

function InventorySystem.addItem(owner, itemSpec, quantity)
    if not owner then return nil end

    local inventory = InventorySystem.getInventory(owner)
    local item = normalizeItem(itemSpec, quantity)
    if not item or not validQuantity(item.quantity) then
        return nil
    end

    if inventoryIsList(owner) then
        if not validList(inventory) or item.id == nil then return nil end
        for index, existing in ipairs(inventory) do
            if InventorySystem.stackable(existing, item) then
                existing.quantity = (existing.quantity or 1) + (item.quantity or 1)
                return index
            end
        end
        table.insert(inventory, item)
        return #inventory
    end

    local key = itemIdOf(item)
    if not key then
        return nil
    end

    inventory[key] = (inventory[key] or 0) + (item.quantity or 1)
    return key
end

function InventorySystem.removeItem(owner, itemSpec, quantity)
    if not owner then return nil end

    local inventory = InventorySystem.getInventory(owner)
    if inventoryIsList(owner) then
        if type(itemSpec) ~= "number" then
            return nil
        end

        if itemSpec < 1 or itemSpec % 1 ~= 0 or itemSpec > #inventory then
            return nil
        end

        local item = inventory[itemSpec]
        if type(item) ~= "table" then return nil end
        local amount = quantity or item.quantity or 1
        if not validQuantity(amount) or amount > (item.quantity or 1) then return nil end
        if amount == (item.quantity or 1) then
            table.remove(inventory, itemSpec)
            return item
        end
        item.quantity = item.quantity - amount
        local removed = InventorySystem.deepClone(item)
        removed.quantity = amount
        return removed
    end

    local key = itemSpec
    local amount = quantity or 1
    if not validQuantity(amount) or type(inventory[key]) ~= "number" or
        inventory[key] < amount then
        return nil
    end
    if inventory[key] <= amount then
        inventory[key] = nil
        return { id = key, quantity = amount }
    end
    inventory[key] = inventory[key] - amount
    return { id = key, quantity = amount }
end

function InventorySystem.getItemCount(owner, itemId)
    if not owner or not owner.inventory then return 0 end
    if inventoryIsList(owner) then
        local total = 0
        for _, item in ipairs(owner.inventory) do
            if item and item.id == itemId then
                total = total + (item.quantity or 1)
            end
        end
        return total
    end
    return owner.inventory[itemId] or 0
end

function InventorySystem.transferItem(sourceOwner, sourceIndex, targetOwner, quantity)
    if not sourceOwner or not targetOwner or sourceOwner == targetOwner then return nil end
    local sourceInventory = sourceOwner.inventory
    local targetInventory = targetOwner.inventory
    if sourceInventory ~= nil and sourceInventory == targetInventory then return nil end
    local sourceIsList = inventoryIsList(sourceOwner)
    local targetIsList = inventoryIsList(targetOwner)
    if type(sourceInventory) ~= "table" then return nil end

    if sourceIsList then
        if not validList(sourceInventory) or type(sourceIndex) ~= "number" or
            sourceIndex < 1 or sourceIndex % 1 ~= 0 or sourceIndex > #sourceInventory then
            return nil
        end
        local item = sourceInventory[sourceIndex]
        local amount = quantity or item.quantity or 1
        if not validQuantity(amount) or amount > (item.quantity or 1) then return nil end

        local incoming = InventorySystem.deepClone(item)
        incoming.quantity = amount
        if targetIsList then
            targetInventory = targetInventory or {}
            if not validList(targetInventory) then return nil end
            if amount == (item.quantity or 1) then
                table.remove(sourceInventory, sourceIndex)
            else
                item.quantity = item.quantity - amount
            end
            targetOwner.inventory = targetInventory
            InventorySystem.addItem(targetOwner, incoming)
            return incoming
        end

        for key in pairs(incoming) do
            if key ~= "id" and key ~= "quantity" then return nil end
        end
        if type(incoming.id) ~= "string" then return nil end
        targetInventory = targetInventory or {}
        for key, count in pairs(targetInventory) do
            if type(key) ~= "string" or type(count) ~= "number" or count < 0 then
                return nil
            end
        end
        if amount == (item.quantity or 1) then
            table.remove(sourceInventory, sourceIndex)
        else
            item.quantity = item.quantity - amount
        end
        targetOwner.inventory = targetInventory
        targetInventory[incoming.id] = (targetInventory[incoming.id] or 0) + amount
        return incoming
    end

    if type(sourceIndex) ~= "string" or type(sourceInventory[sourceIndex]) ~= "number" then
        return nil
    end
    local amount = quantity or 1
    if not validQuantity(amount) or sourceInventory[sourceIndex] < amount then return nil end
    targetInventory = targetInventory or {}
    if targetIsList then
        if not validList(targetInventory) then return nil end
        local incoming = { id = sourceIndex, quantity = amount }
        sourceInventory[sourceIndex] = sourceInventory[sourceIndex] - amount
        if sourceInventory[sourceIndex] == 0 then sourceInventory[sourceIndex] = nil end
        targetOwner.inventory = targetInventory
        InventorySystem.addItem(targetOwner, incoming)
        return incoming
    end
    if type(targetInventory) ~= "table" then return nil end
    for key, count in pairs(targetInventory) do
        if type(key) ~= "string" or type(count) ~= "number" or count < 0 then
            return nil
        end
    end

    sourceInventory[sourceIndex] = sourceInventory[sourceIndex] - amount
    if sourceInventory[sourceIndex] == 0 then sourceInventory[sourceIndex] = nil end
    targetOwner.inventory = targetInventory
    targetInventory[sourceIndex] = (targetInventory[sourceIndex] or 0) + amount
    return { id = sourceIndex, quantity = amount }
end

function InventorySystem.transferGold(sourceOwner, targetOwner, amount)
    if not sourceOwner or not targetOwner or sourceOwner == targetOwner or
        not validQuantity(amount) then
        return false
    end
    local sourceGold = sourceOwner.treasury
    local targetGold = targetOwner.treasury
    if type(sourceGold) ~= "number" or type(targetGold) ~= "number" or
        sourceGold < amount or sourceGold < 0 or targetGold < 0 or
        sourceGold ~= sourceGold or targetGold ~= targetGold or
        sourceGold == math.huge or targetGold == math.huge then
        return false
    end
    sourceOwner.treasury = sourceGold - amount
    targetOwner.treasury = targetGold + amount
    return true
end

function InventorySystem.transferAll(sourceOwner, targetOwner)
    if not sourceOwner or not targetOwner or sourceOwner == targetOwner or
        not inventoryIsList(sourceOwner) or not inventoryIsList(targetOwner) then
        return false
    end
    local sourceInventory = sourceOwner.inventory
    local targetInventory = targetOwner.inventory
    if sourceInventory == targetInventory or not validList(sourceInventory) or
        not validList(targetInventory) then
        return false
    end
    for _, item in ipairs(sourceInventory) do
        if not validQuantity(item.quantity or 1) then return false end
    end

    for _, item in ipairs(sourceInventory) do
        InventorySystem.addItem(targetOwner, item)
    end
    for index = #sourceInventory, 1, -1 do
        sourceInventory[index] = nil
    end
    return true
end

function InventorySystem.replaceListContents(owner, items)
    if not owner or not inventoryIsList(owner) or not validList(owner.inventory) or
        not validList(items) then
        return false
    end

    local inventory = owner.inventory
    for index = #inventory, 1, -1 do
        inventory[index] = nil
    end
    for _, item in ipairs(items) do
        inventory[#inventory + 1] = InventorySystem.deepClone(item)
    end
    return true
end

return InventorySystem
