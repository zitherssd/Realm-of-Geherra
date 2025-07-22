local ItemModule = {}
local itemTemplates = require('src.data.item_templates')

local nextItemId = 1

function ItemModule.create(templateName, quantity)
  local tpl = itemTemplates[templateName]
  if not tpl then error('Unknown item template: ' .. tostring(templateName)) end
  local item = {
    id = 'item_' .. nextItemId,
    template = templateName,
    name = tpl.name,
    type = tpl.type,
    slot = tpl.slot,
    stats = tpl.stats,
    weight = tpl.weight,
    value = tpl.value,
    sprite = tpl.sprite,
    stackable = tpl.stackable,
    quantity = tpl.stackable and (quantity or 1) or nil,
    hungerRestore = tpl.hungerRestore,
  }
  nextItemId = nextItemId + 1
  return item
end

-- Add an item to an inventory, merging stacks if possible
function ItemModule.addToInventory(inventory, item)
  if item.stackable then
    for _, invItem in ipairs(inventory) do
      if invItem.template == item.template then
        invItem.quantity = (invItem.quantity or 0) + (item.quantity or 1)
        return
      end
    end
    -- No stack found, create a new item object to avoid reference issues
    local newItem = ItemModule.create(item.template, item.quantity or 1)
    table.insert(inventory, newItem)
  else
    table.insert(inventory, item)
  end
end

-- Remove a quantity of an item from inventory (by template), returns removed item(s)
function ItemModule.removeFromInventory(inventory, template, quantity)
  for i, invItem in ipairs(inventory) do
    if invItem.template == template then
      if invItem.stackable then
        local removeQty = math.min(invItem.quantity or 1, quantity or 1)
        invItem.quantity = invItem.quantity - removeQty
        local removed = ItemModule.create(template, removeQty)
        if invItem.quantity <= 0 then
          table.remove(inventory, i)
        end
        return removed
      else
        table.remove(inventory, i)
        return invItem
      end
    end
  end
  return nil
end

return ItemModule 