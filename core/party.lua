-- core/party.lua
--
-- Defines the party data structure.

local Party = {}

local REQUIRED_FIELDS = {
	"id",
	"name",
	"position",
	"speed",
}

local function is_non_empty_string(value)
	return type(value) == "string" and value ~= ""
end

local function is_number(value)
	return type(value) == "number"
end

local function validate_position(position, errors)
	if type(position) ~= "table" then
		table.insert(errors, "position must be a table")
		return
	end

	if not is_number(position.x) then
		table.insert(errors, "position.x must be a number")
	end
	if not is_number(position.y) then
		table.insert(errors, "position.y must be a number")
	end
end

local function validate_string_list(field_name, list, errors)
	if list == nil then
		return
	end

	if type(list) ~= "table" then
		table.insert(errors, field_name .. " must be a table when provided")
		return
	end

	for index, value in ipairs(list) do
		if not is_non_empty_string(value) then
			table.insert(errors, field_name .. "[" .. index .. "] must be a non-empty string")
		end
	end
end

function Party.validate(definition)
	local errors = {}

	if type(definition) ~= "table" then
		return false, { "party definition must be a table" }
	end

	for _, field in ipairs(REQUIRED_FIELDS) do
		if definition[field] == nil then
			table.insert(errors, field .. " is required")
		end
	end

	if not is_non_empty_string(definition.id) then
		table.insert(errors, "id must be a non-empty string")
	end
	if not is_non_empty_string(definition.name) then
		table.insert(errors, "name must be a non-empty string")
	end

	validate_position(definition.position, errors)

	if definition.faction ~= nil and type(definition.faction) ~= "string" then
		table.insert(errors, "faction must be a string or nil")
	end

	if not is_number(definition.speed) then
		table.insert(errors, "speed must be a number")
	end

	if definition.gold ~= nil and not is_number(definition.gold) then
		table.insert(errors, "gold must be a number when provided")
	end

	if definition.is_player ~= nil and type(definition.is_player) ~= "boolean" then
		table.insert(errors, "is_player must be a boolean when provided")
	end

	validate_string_list("commanders", definition.commanders, errors)
	validate_string_list("units", definition.units, errors)
	validate_string_list("inventory", definition.inventory, errors)

	return #errors == 0, errors
end

function Party.normalize(definition)
	return {
		id = definition.id,
		name = definition.name,
		faction = definition.faction or nil,
		position = { x = definition.position.x, y = definition.position.y },
		speed = definition.speed,
		commanders = definition.commanders or {},
		units = definition.units or {},
		inventory = definition.inventory or {},
		gold = definition.gold or 0,
		is_player = definition.is_player or false,
		color = definition.color,
		radius = definition.radius,
	}
end

function Party.new(definition)
	local ok, errors = Party.validate(definition)
	if not ok then
		return nil, errors
	end

	return Party.normalize(definition)
end

function Party.build_index(definitions)
	local index = {}
	local errors = {}

	if type(definitions) ~= "table" then
		return nil, { "definitions must be a table" }
	end

	for _, definition in ipairs(definitions) do
		local party, party_errors = Party.new(definition)
		if not party then
			for _, err in ipairs(party_errors) do
				table.insert(errors, err)
			end
		else
			if index[party.id] then
				table.insert(errors, "duplicate party id: " .. party.id)
			else
				index[party.id] = party
			end
		end
	end

	if #errors > 0 then
		return nil, errors
	end

	return index, nil
end

return Party
