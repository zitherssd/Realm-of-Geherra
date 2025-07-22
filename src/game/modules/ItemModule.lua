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

return ItemModule 