-- systems/items/loot_generator_system.lua
-- System for generating loot from drop tables

local LootGeneratorSystem = {}
local TroopsData = require("src.data.troops")
local ItemsData = require("src.data.items")
local Inventory = require("src.systems.items.inventory_system")
local Item = require("src.entities.item")

-- Generate loot based on a troop type's definition
function LootGeneratorSystem.generateFromTroop(troopType, targetList)
    targetList = targetList or {}
    local totalGold = 0
    local data = TroopsData[troopType]
    if data and data.loot then
        totalGold = LootGeneratorSystem.generateFromTable(data.loot, targetList)
    end
    return targetList, totalGold
end

-- Generate loot from a specific loot table
function LootGeneratorSystem.generateFromTable(lootTable, targetList)
    targetList = targetList or {}
    local totalGold = 0
    
    for _, drop in ipairs(lootTable) do
        if math.random() < drop.chance then
            local count = math.random(drop.min, drop.max)

            if drop.currency == "gold" then
                totalGold = totalGold + count
            else
                local itemDef = ItemsData[drop.id]
                if itemDef then
                    local item = Item.new(drop.id, itemDef.type)
                    item.name, item.description = itemDef.name, itemDef.description
                    assert(Inventory.addItem({inventory = targetList}, item, count), "Invalid generated loot")
                end
            end
        end
    end
    
    return totalGold
end

return LootGeneratorSystem