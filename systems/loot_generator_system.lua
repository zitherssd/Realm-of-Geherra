-- systems/loot_generator_system.lua
-- System for generating loot from drop tables

local LootGeneratorSystem = {}
local TroopsData = require("data.troops")
local ItemsData = require("data.items")
local Item = require("entities.item")

-- Generate loot based on a troop type's definition
function LootGeneratorSystem.generateFromTroop(troopType, targetList)
    targetList = targetList or {}
    local data = TroopsData[troopType]
    if data and data.loot then
        LootGeneratorSystem.generateFromTable(data.loot, targetList)
    end
    return targetList
end

-- Generate loot from a specific loot table
function LootGeneratorSystem.generateFromTable(lootTable, targetList)
    targetList = targetList or {}
    
    for _, drop in ipairs(lootTable) do
        if math.random() < drop.chance then
            local count = math.random(drop.min, drop.max)
            
            -- Check for existing stack in targetList to merge
            local found = false
            for _, existingItem in ipairs(targetList) do
                if existingItem.id == drop.id then
                    existingItem:addToStack(count)
                    found = true
                    break
                end
            end
            
            if not found then
                local itemDef = ItemsData[drop.id]
                if itemDef then
                    local newItem = Item.new(drop.id, itemDef.type)
                    newItem.name = itemDef.name
                    newItem.description = itemDef.description
                    newItem.quantity = count
                    table.insert(targetList, newItem)
                end
            end
        end
    end
    
    return targetList
end

return LootGeneratorSystem