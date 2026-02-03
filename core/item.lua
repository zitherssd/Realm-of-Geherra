-- core/item.lua
--
-- Defines the item data structure.

local Item = {}

local REQUIRED_FIELDS = {
	"id",
	"name",
	"category",
}

local function is_non_empty_string(value)
	return type(value) == "string" and value ~= ""
end

local function is_number(value)
	return type(value) == "number"
end

local function validate_slots(slots, errors)
	if type(slots) ~= "table" then
		table.insert(errors, "slots must be a table")
		return
	end

	if #slots == 0 then
		table.insert(errors, "slots must contain at least one slot")
	end

	for index, slot in ipairs(slots) do
		if not is_non_empty_string(slot) then
			table.insert(errors, "slots[" .. index .. "] must be a non-empty string")
		end
	end
end

local function validate_stat_modifiers(stat_modifiers, errors)
	if stat_modifiers == nil then
		return
	end

	if type(stat_modifiers) ~= "table" then
		table.insert(errors, "stat_modifiers must be a table when provided")
		return
	end

	for stat, value in pairs(stat_modifiers) do
		if not is_number(value) then
			table.insert(errors, "stat_modifiers." .. tostring(stat) .. " must be a number")
		end
	end
end

local function validate_actions(actions, errors)
	if actions == nil then
		return
	end

	if type(actions) ~= "table" then
		table.insert(errors, "actions must be a table when provided")
		return
	end

	for index, action_id in ipairs(actions) do
		if not is_non_empty_string(action_id) then
			table.insert(errors, "actions[" .. index .. "] must be a non-empty string")
		end
	end
end

local function validate_requirements(requirements, errors)
	if requirements == nil then
		return
	end

	if type(requirements) ~= "table" then
		table.insert(errors, "requirements must be a table when provided")
		return
	end

	for key, value in pairs(requirements) do
		if not is_number(value) then
			table.insert(errors, "requirements." .. tostring(key) .. " must be a number")
		end
	end
end

function Item.validate(definition)
	local errors = {}

	if type(definition) ~= "table" then
		return false, { "item definition must be a table" }
	end

	for _, field in ipairs(REQUIRED_FIELDS) do
		if not is_non_empty_string(definition[field]) then
			table.insert(errors, field .. " must be a non-empty string")
		end
	end

	validate_slots(definition.slots, errors)
	validate_stat_modifiers(definition.stat_modifiers, errors)
	validate_actions(definition.actions, errors)
	validate_requirements(definition.requirements, errors)

	return #errors == 0, errors
end

function Item.normalize(definition)
	return {
		id = definition.id,
		name = definition.name,
		description = definition.description or "",
		category = definition.category,
		slots = definition.slots,
		stat_modifiers = definition.stat_modifiers or {},
		actions = definition.actions or {},
		requirements = definition.requirements or {},
	}
end

function Item.new(definition)
	local ok, errors = Item.validate(definition)
	if not ok then
		return nil, errors
	end

	return Item.normalize(definition)
end

function Item.build_index(definitions)
	local index = {}
	local errors = {}

	if type(definitions) ~= "table" then
		return nil, { "definitions must be a table" }
	end

	for _, definition in ipairs(definitions) do
		local item, item_errors = Item.new(definition)
		if not item then
			for _, err in ipairs(item_errors) do
				table.insert(errors, err)
			end
		else
			if index[item.id] then
				table.insert(errors, "duplicate item id: " .. item.id)
			else
				index[item.id] = item
			end
		end
	end

	if #errors > 0 then
		return nil, errors
	end

	return index, nil
end

return Item
