-- ui/inventory_view.lua
--
-- Primitive inventory + equipment view for the player commander.

local InventoryView = {}
InventoryView.__index = InventoryView

local function build_slot_list(unit_def)
	local slots = {}
	for slot_name in pairs(unit_def.equipment_slots or {}) do
		table.insert(slots, slot_name)
	end
	table.sort(slots)
	return slots
end

local function item_fits_slot(unit_def, item, slot_name, equipment)
	if not item or type(item.slots) ~= "table" then
		return false
	end
	for _, slot in ipairs(item.slots) do
		if slot == slot_name then
			return unit_def.equipment_slots and unit_def.equipment_slots[slot_name] ~= nil
		end
	end
	return false
end

local function first_valid_slot(unit_def, item, equipment)
	for _, slot_name in ipairs(build_slot_list(unit_def)) do
		if item_fits_slot(unit_def, item, slot_name, equipment) then
			local all_free = true
			for _, slot in ipairs(item.slots or {}) do
				if equipment[slot] then
					all_free = false
					break
				end
			end
			if all_free then
				return slot_name
			end
		end
	end
	return nil
end

local function slots_available(item, equipment)
	if not item or type(item.slots) ~= "table" then
		return false
	end
	for _, slot in ipairs(item.slots) do
		if equipment[slot] then
			return false
		end
	end
	return true
end

local function clear_item_from_slots(equipment, item)
	for _, slot in ipairs(item.slots or {}) do
		if equipment[slot] == item.id then
			equipment[slot] = nil
		end
	end
end

function InventoryView.new(player_party, unit_def, item_data)
	local self = setmetatable({}, InventoryView)
	self.player_party = player_party
	self.unit_def = unit_def
	self.item_data = item_data
	self.focus = "inventory"
	self.inventory_index = 1
	self.slot_index = 1
	self.slots = build_slot_list(unit_def)
	return self
end

function InventoryView:ensure_equipment()
	self.player_party.equipment = self.player_party.equipment or {}
	return self.player_party.equipment
end

function InventoryView:current_inventory_item()
	local inventory = self.player_party.inventory or {}
	local item_id = inventory[self.inventory_index]
	return item_id and self.item_data.by_id[item_id] or nil
end

function InventoryView:current_slot_name()
	return self.slots[self.slot_index]
end

function InventoryView:handle_key(key)
	local inventory = self.player_party.inventory or {}
	local equipment = self:ensure_equipment()

	if key == "tab" then
		self.focus = (self.focus == "inventory") and "slots" or "inventory"
		return
	end

	if key == "up" then
		if self.focus == "inventory" then
			self.inventory_index = math.max(1, self.inventory_index - 1)
		else
			self.slot_index = math.max(1, self.slot_index - 1)
		end
		return
	end

	if key == "down" then
		if self.focus == "inventory" then
			self.inventory_index = math.min(#inventory, self.inventory_index + 1)
		else
			self.slot_index = math.min(#self.slots, self.slot_index + 1)
		end
		return
	end

	if key == "return" or key == "enter" then
		if self.focus == "inventory" then
			local item = self:current_inventory_item()
			local slot_name = first_valid_slot(self.unit_def, item, equipment)
			if item and slot_name and slots_available(item, equipment) then
				equipment[slot_name] = item.id
				for _, slot in ipairs(item.slots or {}) do
					equipment[slot] = item.id
				end
				table.remove(inventory, self.inventory_index)
				self.inventory_index = math.min(self.inventory_index, #inventory)
			end
		else
			local slot_name = self:current_slot_name()
			local item_id = slot_name and equipment[slot_name]
			local item = item_id and self.item_data.by_id[item_id] or nil
			if item then
				clear_item_from_slots(equipment, item)
				table.insert(inventory, item.id)
			end
		end
		return
	end

	if key == "escape" then
		return "close"
	end
end

function InventoryView:draw()
	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()

	love.graphics.setColor(0, 0, 0, 0.75)
	love.graphics.rectangle("fill", 0, 0, width, height)

	local panel_w = width * 0.75
	local panel_h = height * 0.75
	local panel_x = (width - panel_w) * 0.5
	local panel_y = (height - panel_h) * 0.5

	love.graphics.setColor(0.08, 0.09, 0.12, 0.95)
	love.graphics.rectangle("fill", panel_x, panel_y, panel_w, panel_h, 8, 8)

	love.graphics.setColor(1, 1, 1)
	love.graphics.print("Inventory", panel_x + 16, panel_y + 12)

	local inventory = self.player_party.inventory or {}
	local list_x = panel_x + 16
	local list_y = panel_y + 44
	local list_w = panel_w * 0.45
	local line_h = 22

	for index, item_id in ipairs(inventory) do
		local item = self.item_data.by_id[item_id]
		local label = item and item.name or item_id
		local y = list_y + (index - 1) * line_h
		if self.focus == "inventory" and index == self.inventory_index then
			love.graphics.setColor(0.95, 0.9, 0.2)
			love.graphics.rectangle("fill", list_x - 6, y - 2, list_w - 10, line_h, 4, 4)
			love.graphics.setColor(0.1, 0.1, 0.1)
			love.graphics.print(label, list_x, y)
		else
			love.graphics.setColor(0.9, 0.9, 0.9)
			love.graphics.print(label, list_x, y)
		end
	end

	local slot_x = panel_x + panel_w * 0.52
	local slot_y = panel_y + 44
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("Equipment", slot_x, slot_y - 22)

	local equipment = self:ensure_equipment()
	for index, slot_name in ipairs(self.slots) do
		local y = slot_y + (index - 1) * line_h
		local item_id = equipment[slot_name]
		local item = item_id and self.item_data.by_id[item_id] or nil
		local label = slot_name .. ": " .. (item and item.name or "-")
		if self.focus == "slots" and index == self.slot_index then
			love.graphics.setColor(0.95, 0.9, 0.2)
			love.graphics.rectangle("fill", slot_x - 6, y - 2, list_w, line_h, 4, 4)
			love.graphics.setColor(0.1, 0.1, 0.1)
			love.graphics.print(label, slot_x, y)
		else
			love.graphics.setColor(0.9, 0.9, 0.9)
			love.graphics.print(label, slot_x, y)
		end
	end

	local detail_x = panel_x + panel_w * 0.52
	local detail_y = panel_y + panel_h - 90
	local selected = self:current_inventory_item()
	if selected then
		love.graphics.setColor(1, 1, 1)
		love.graphics.print(selected.name, detail_x, detail_y)
		love.graphics.setColor(0.75, 0.75, 0.8)
		love.graphics.print(selected.description or "", detail_x, detail_y + 18)
		love.graphics.print("Slots: " .. table.concat(selected.slots or {}, ", "), detail_x, detail_y + 36)
	end

	love.graphics.setColor(0.7, 0.7, 0.75)
	love.graphics.print("Tab: Switch  Enter: Equip/Unequip  Esc: Back", panel_x + 16, panel_y + panel_h - 26)
end

return InventoryView
