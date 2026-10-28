-- data/items.lua
-- Combines the item definitions grouped under data/items/.

local Registry = require("src.data.definition_registry")
local categories = {}
categories[#categories + 1] = require("src.data.items.consumables")
categories[#categories + 1] = require("src.data.items.melee_weapons")
categories[#categories + 1] = require("src.data.items.ranged_weapons")
categories[#categories + 1] = require("src.data.items.armor")
categories[#categories + 1] = require("src.data.items.quest_items")

local items = {}
for _, category in ipairs(categories) do
    for id, item in pairs(category) do
        Registry.checkId("item", id, item)
        if items[id] then
            error("Duplicate item definition: " .. id)
        end
        items[id] = item
    end
end

return items
