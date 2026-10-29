-- systems/items/inventory_system.lua
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

local function validQuantity(amount)
    return type(amount) == "number" and amount > 0 and amount % 1 == 0 and
        amount == amount and amount ~= math.huge
end

local function validList(inventory)
    if type(inventory) ~= "table" then return false end
    local count = #inventory
    for key, item in pairs(inventory) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or key > count or
            type(item) ~= "table" or type(item.id) ~= "string" or item.id == "" or
            not validQuantity(item.quantity or 1) then
            return false
        end
    end
    for index = 1, count do
        if inventory[index] == nil then return false end
    end
    return true
end

local function normalizeItem(item, fallbackQuantity)
    if type(item) == "string" then
        return { id = item, quantity = fallbackQuantity or 1 }
    end
    if type(item) ~= "table" then
        return nil
    end

    local copy = deepClone(item, {})
    copy.quantity = fallbackQuantity or copy.quantity or 1
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

function InventorySystem.new()
    return {}
end

InventorySystem.isValid = validList

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
    local definition = require("src.data.items")[itemA.id]
    if itemA.stackable == false or itemB.stackable == false or
        itemA.instanceId ~= nil or itemB.instanceId ~= nil or
        (definition and definition.stackable == false) then return false end
    return deepEqual(InventorySystem.itemSignature(itemA), InventorySystem.itemSignature(itemB))
end

function InventorySystem.addItem(owner, itemSpec, quantity)
    if not owner then return nil end
    local inventory = InventorySystem.getInventory(owner)
    local item = normalizeItem(itemSpec, quantity)
    if not validList(inventory) or not item or type(item.id) ~= "string" or
        item.id == "" or not validQuantity(item.quantity) then return nil end

    for index, existing in ipairs(inventory) do
        if item.instanceId ~= nil and existing.instanceId == item.instanceId then return nil end
        if InventorySystem.stackable(existing, item) then
            if not validQuantity((existing.quantity or 1) + item.quantity) then return nil end
            existing.quantity = (existing.quantity or 1) + item.quantity
            return index
        end
    end
    local definition = require("src.data.items")[item.id]
    if item.instanceId ~= nil and item.quantity ~= 1 then return nil end
    if item.stackable == false or (definition and definition.stackable == false) then
        local firstIndex = #inventory + 1
        for _ = 1, item.quantity do
            local single = InventorySystem.deepClone(item)
            single.quantity = 1
            inventory[#inventory + 1] = single
        end
        return firstIndex
    end
    inventory[#inventory + 1] = item
    return #inventory
end

local function findIndex(inventory, itemSpec)
    if type(itemSpec) == "number" then
        if itemSpec >= 1 and itemSpec % 1 == 0 and itemSpec <= #inventory then return itemSpec end
    else
        for index, item in ipairs(inventory) do
            if item == itemSpec or item.id == itemSpec then return index end
        end
    end
end

-- IDs select the first matching stack; use an index or instance to select stateful items.
function InventorySystem.removeItem(owner, itemSpec, quantity)
    if not owner or not validList(owner.inventory) then return nil end
    local inventory = owner.inventory
    local index = findIndex(inventory, itemSpec)
    if not index then return nil end
    local item = inventory[index]
    local amount = quantity or item.quantity or 1
    if not validQuantity(amount) or amount > (item.quantity or 1) then return nil end
    if amount == (item.quantity or 1) then return table.remove(inventory, index) end
    local removed = InventorySystem.deepClone(item)
    removed.quantity = amount
    item.quantity = item.quantity - amount
    return removed
end

function InventorySystem.getItemCount(owner, itemId)
    local total = 0
    for _, item in ipairs(owner and owner.inventory or {}) do
        if item.id == itemId then total = total + (item.quantity or 1) end
    end
    return total
end

function InventorySystem.hasItem(owner, itemId, quantity)
    quantity = quantity or 1
    return validQuantity(quantity) and InventorySystem.getItemCount(owner, itemId) >= quantity
end

function InventorySystem.transferItem(sourceOwner, itemSpec, targetOwner, quantity)
    if not sourceOwner or not targetOwner or sourceOwner == targetOwner or
        sourceOwner.inventory == targetOwner.inventory or
        not validList(sourceOwner.inventory) or
        not validList(targetOwner.inventory or {}) then return nil end
    local index = findIndex(sourceOwner.inventory, itemSpec)
    if not index then return nil end
    local item = sourceOwner.inventory[index]
    local amount = quantity or item.quantity or 1
    if not validQuantity(amount) or amount > (item.quantity or 1) then return nil end
    local incoming = InventorySystem.deepClone(item)
    incoming.quantity = amount
    if not InventorySystem.addItem(targetOwner, incoming) then return nil end
    InventorySystem.removeItem(sourceOwner, index, amount)
    return incoming
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
        sourceOwner.inventory == targetOwner.inventory or
        not validList(sourceOwner.inventory) or not validList(targetOwner.inventory) then
        return false
    end
    -- Preflight the entire operation before either owner's inventory changes.
    local prepared = {inventory = InventorySystem.copyInventory(targetOwner.inventory)}
    for _, item in ipairs(sourceOwner.inventory) do
        if not InventorySystem.addItem(prepared, item) then return false end
    end
    while #sourceOwner.inventory > 0 do
        assert(InventorySystem.transferItem(sourceOwner, 1, targetOwner))
    end
    return true
end

function InventorySystem.replaceListContents(owner, items)
    if not owner or not validList(owner.inventory) or
        not validList(items) then
        return false
    end

    items = InventorySystem.copyInventory(items)
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
