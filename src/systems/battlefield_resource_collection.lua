local BattlefieldRemainsSystem = require("src.systems.battlefield_remains_system")
local PartySystem = require("src.systems.party_system")

local BattlefieldResourceCollection = {}

local function copySerializable(value, path, ancestors)
    local valueType = type(value)
    if valueType == "nil" or valueType == "string" or valueType == "boolean" then
        return value
    end
    if valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            error(path .. " must contain finite numbers", 3)
        end
        return value
    end
    if valueType ~= "table" then
        error(path .. " contains a non-serializable " .. valueType, 3)
    end

    ancestors = ancestors or {}
    if ancestors[value] then error(path .. " contains a cycle", 3) end
    ancestors[value] = true
    local copy = {}
    for key, child in pairs(value) do
        if type(key) ~= "string" and type(key) ~= "number" then
            error(path .. " contains a non-primitive key", 3)
        end
        copy[key] = copySerializable(child, path .. "." .. tostring(key), ancestors)
    end
    ancestors[value] = nil
    return copy
end

local function finiteNonNegative(value, label)
    if type(value) ~= "number" or value < 0 or value ~= value or
        value == math.huge or value == -math.huge then
        error(label .. " must be a finite non-negative number", 3)
    end
end

local function findSite(map, siteId)
    if type(map) ~= "table" then return nil end
    if type(siteId) ~= "string" and type(siteId) ~= "number" then return nil end
    for _, site in ipairs(BattlefieldRemainsSystem.getAll(map)) do
        if site.id == siteId then return site end
    end
    return nil
end

local function validateItemList(items, label)
    if type(items) ~= "table" then
        error(label .. " must be a list", 3)
    end

    local count = #items
    for key, item in pairs(items) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or key > count then
            error(label .. " must be a dense item list", 3)
        end
        if type(item) ~= "table" then
            error(label .. " entries must be item tables", 3)
        end
    end
    for index = 1, count do
        if items[index] == nil then
            error(label .. " must be a dense item list", 3)
        end
    end
    return count
end

function BattlefieldResourceCollection.collect(map, siteId, playerParty)
    local site = findSite(map, siteId)
    if not site then
        return {success = false, reason = "site_missing", items = {}, gold = 0}
    end
    if not site.discovered then
        return {success = false, reason = "site_not_discovered", items = {}, gold = 0}
    end
    if type(playerParty) ~= "table" or
        (type(playerParty.id) ~= "string" and type(playerParty.id) ~= "number") then
        return {success = false, reason = "party_missing", items = {}, gold = 0}
    end
    if type(site.loot) ~= "table" or type(site.loot.items) ~= "table" then
        error("Battlefield site has invalid loot data", 2)
    end

    local supplyCount = validateItemList(site.loot.items, "Battlefield supplies")
    local inventoryCount = validateItemList(playerParty.inventory, "Player party inventory")
    local partyGold = playerParty.treasury
    finiteNonNegative(partyGold, "Player treasury")
    finiteNonNegative(site.loot.gold, "Battlefield gold")
    if site.loot.gold % 1 ~= 0 or partyGold % 1 ~= 0 then
        error("Battlefield and player treasury amounts must be whole numbers", 2)
    end

    local resources = {}
    for index = 1, supplyCount do
        local item = site.loot.items[index]
        if type(item) ~= "table" or item.id == nil then
            error("Battlefield supply entries must be item instances with IDs", 2)
        end
        local quantity = item.quantity == nil and 1 or item.quantity
        finiteNonNegative(quantity, "Battlefield supply quantity")
        if quantity < 1 or quantity % 1 ~= 0 then
            error("Battlefield supply quantity must be a positive whole number", 2)
        end
        resources[index] = copySerializable(item, "Battlefield supply item")
    end

    local gold = site.loot.gold
    local newInventory = {}
    for index = 1, inventoryCount do
        newInventory[index] = playerParty.inventory[index]
    end
    for _, item in ipairs(resources) do
        newInventory[#newInventory + 1] = item
    end
    local newTreasury = partyGold + gold
    finiteNonNegative(newTreasury, "Collected treasury")

    local result = {
        success = true,
        collected = #resources > 0 or gold > 0,
        items = copySerializable(resources, "Collected supplies"),
        gold = gold
    }
    playerParty.inventory = newInventory
    PartySystem.addTreasury(playerParty, gold)
    site.loot.items = {}
    site.loot.gold = 0

    return result
end

return BattlefieldResourceCollection
