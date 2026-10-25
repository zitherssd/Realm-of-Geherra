-- systems/trader_system.lua
-- Shared helpers for merchant NPCs: building `.inventory` from a troop def's
-- declarative `stock` list, and lazily refreshing it on an interval.

local TraderSystem = {}

local TimeSystem = require("src.systems.time_system")
local TroopsData = require("src.data.troops")
local Items = require("src.data.items")
local InventorySystem = require("src.systems.inventory_system")

-- Build a fresh inventory list from a troop def's `stock` entries. Always
-- copies each item def so the shared data/items.lua catalog is never mutated.
function TraderSystem.buildStockInventory(troopDef)
    local inventory = {}
    if not troopDef or not troopDef.stock then
        return inventory
    end

    for _, entry in ipairs(troopDef.stock) do
        local itemDef = Items[entry.id]
        if itemDef then
            local copy = InventorySystem.deepClone(itemDef)
            copy.quantity = entry.quantity or 1
            table.insert(inventory, copy)
        end
    end

    return inventory
end

-- Refill `npc.inventory` from its troop def's `stock` list once
-- `npc.restockIntervalDays` days have passed since the last refresh.
-- No-op for NPCs without a `restockIntervalDays` (e.g. traders, whose stock
-- changes through the existing shop interactions).
function TraderSystem.maybeRefreshStock(npc)
    if not npc or not npc.restockIntervalDays then
        return
    end

    local currentDay = TimeSystem.getDay()
    local lastRefresh = npc.lastStockRefreshDay or -math.huge
    if currentDay - lastRefresh < npc.restockIntervalDays then
        return
    end

    local troopDef = TroopsData[npc.troopType]
    npc.inventory = TraderSystem.buildStockInventory(troopDef)
    npc.inventoryFormat = "list"
    npc.lastStockRefreshDay = currentDay
end

return TraderSystem
