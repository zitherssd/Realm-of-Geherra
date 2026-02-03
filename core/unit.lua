-- core/unit.lua
--
-- Defines the core unit data structure.

local Unit = {}

local REQUIRED_STATS = {
	"hp",
	"attack",
	"defense",
	"strength",
	"protection",
}

local function is_non_empty_string(value)
	return type(value) == "string" and value ~= ""
end

local function is_number(value)
	return type(value) == "number"
end

local function validate_size(size, errors)
	if size == nil then
		return
	end

	if not is_number(size) then
		table.insert(errors, "size must be a number when provided")
		return
	end

	if size < 1 or size > 10 then
		table.insert(errors, "size must be between 1 and 10")
	end
end

local function validate_sprite(sprite, errors)
	if sprite == nil then
		return
	end

	if type(sprite) ~= "table" then
		table.insert(errors, "sprite must be a table when provided")
		return
	end

	if not is_non_empty_string(sprite.image) then
		table.insert(errors, "sprite.image must be a non-empty string")
	end

	if sprite.scale ~= nil and not is_number(sprite.scale) then
		table.insert(errors, "sprite.scale must be a number when provided")
	end

	if sprite.offset ~= nil then
		if type(sprite.offset) ~= "table" then
			table.insert(errors, "sprite.offset must be a table when provided")
		else
			if sprite.offset.x ~= nil and not is_number(sprite.offset.x) then
				table.insert(errors, "sprite.offset.x must be a number when provided")
			end
			if sprite.offset.y ~= nil and not is_number(sprite.offset.y) then
				table.insert(errors, "sprite.offset.y must be a number when provided")
			end
		end
	end
end

local function validate_stats(stats, errors)
	if type(stats) ~= "table" then
		table.insert(errors, "stats must be a table")
		return
	end

	for _, key in ipairs(REQUIRED_STATS) do
		if not is_number(stats[key]) then
			table.insert(errors, "stats." .. key .. " must be a number")
		end
	end
end

local function validate_equipment_slots(equipment_slots, errors)
	if equipment_slots == nil then
		return
	end

	if type(equipment_slots) ~= "table" then
		table.insert(errors, "equipment_slots must be a table when provided")
		return
	end

	for slot_name, slot in pairs(equipment_slots) do
		if not is_non_empty_string(slot_name) then
			table.insert(errors, "equipment slot keys must be non-empty strings")
		end
		if type(slot) ~= "table" then
			table.insert(errors, "equipment slot '" .. tostring(slot_name) .. "' must be a table")
		elseif not is_non_empty_string(slot.type) then
			table.insert(errors, "equipment slot '" .. tostring(slot_name) .. "' must define a non-empty type")
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

local function validate_starting_equipment(starting_equipment, errors)
	if starting_equipment == nil then
		return
	end

	if type(starting_equipment) ~= "table" then
		table.insert(errors, "starting_equipment must be a table when provided")
		return
	end

	for slot, item_id in pairs(starting_equipment) do
		if type(slot) ~= "string" or slot == "" then
			table.insert(errors, "starting_equipment slot keys must be non-empty strings")
		end
		if type(item_id) ~= "string" or item_id == "" then
			table.insert(errors, "starting_equipment for slot '" .. tostring(slot) .. "' must be a non-empty string")
		end
	end
end

function Unit.validate(definition)
	local errors = {}

	if type(definition) ~= "table" then
		return false, { "unit definition must be a table" }
	end

	if not is_non_empty_string(definition.id) then
		table.insert(errors, "id must be a non-empty string")
	end

	if not is_non_empty_string(definition.name) then
		table.insert(errors, "name must be a non-empty string")
	end

	if definition.description ~= nil and type(definition.description) ~= "string" then
		table.insert(errors, "description must be a string when provided")
	end

	validate_sprite(definition.sprite, errors)
	validate_size(definition.size, errors)
	validate_stats(definition.stats, errors)
	validate_equipment_slots(definition.equipment_slots, errors)
	validate_actions(definition.actions, errors)
	validate_starting_equipment(definition.starting_equipment, errors)

	return #errors == 0, errors
end

function Unit.normalize(definition)
	return {
		id = definition.id,
		name = definition.name,
		description = definition.description or "",
		sprite = definition.sprite and {
			image = definition.sprite.image,
			scale = definition.sprite.scale or 1.0,
			offset = definition.sprite.offset or { x = 0, y = 0 },
		} or nil,
		size = definition.size or 1,
		stats = {
			hp = definition.stats.hp,
			attack = definition.stats.attack,
			defense = definition.stats.defense,
			strength = definition.stats.strength,
			protection = definition.stats.protection,
		},
		equipment_slots = definition.equipment_slots or {},
		actions = definition.actions or {},
		starting_equipment = definition.starting_equipment or {},
	}
end

function Unit.new(definition)
	local ok, errors = Unit.validate(definition)
	if not ok then
		return nil, errors
	end

	return Unit.normalize(definition)
end

function Unit.build_index(definitions)
	local index = {}
	local errors = {}

	if type(definitions) ~= "table" then
		return nil, { "definitions must be a table" }
	end

	for _, definition in ipairs(definitions) do
		local unit, unit_errors = Unit.new(definition)
		if not unit then
			for _, err in ipairs(unit_errors) do
				table.insert(errors, err)
			end
		else
			if index[unit.id] then
				table.insert(errors, "duplicate unit id: " .. unit.id)
			else
				index[unit.id] = unit
			end
		end
	end

	if #errors > 0 then
		return nil, errors
	end

	return index, nil
end

return Unit
