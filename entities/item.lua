-- entities/item.lua
-- Inventory and equipment items

local Entity = require("entities.entity")
local Item = setmetatable({}, Entity)
Item.__index = Item

function Item.new(id, itemType)
    local self = Entity.new(id, "item")
    setmetatable(self, Item)
    
    self.itemType = itemType or "misc"
    self.name = ""
    self.description = ""
    self.weight = 1.0
    self.value = 0
    self.quantity = 1
    
    self:addTag("item")
    self:addTag(itemType)
    
    return self
end

function Item:getStackSize()
    return self.quantity
end

function Item:addToStack(count)
    self.quantity = self.quantity + count
end

function Item:removeFromStack(count)
    self.quantity = math.max(0, self.quantity - count)
    return self.quantity <= 0
end

return Item
