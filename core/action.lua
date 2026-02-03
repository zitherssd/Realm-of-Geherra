-- core/action.lua
--
-- Defines the battle action data structure.

local Action = {}

local function is_non_empty_string(value)
	return type(value) == "string" and value ~= ""
end

local function is_number(value)
	return type(value) == "number"
end

local function validate_tags(tags, errors)
	if tags == nil then
		return
	end

	if type(tags) ~= "table" then
		table.insert(errors, "tags must be a table when provided")
		return
	end

	for index, tag in ipairs(tags) do
		if not is_non_empty_string(tag) then
			table.insert(errors, "tags[" .. index .. "] must be a non-empty string")
		end
	end
end

local function validate_targeting(targeting, errors)
	if type(targeting) ~= "table" then
		table.insert(errors, "targeting must be a table")
		return
	end

	if not is_non_empty_string(targeting.type) then
		table.insert(errors, "targeting.type must be a non-empty string")
	end
	if not is_number(targeting.range) then
		table.insert(errors, "targeting.range must be a number")
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
		if type(key) ~= "string" then
			table.insert(errors, "requirements keys must be strings")
		end
		if type(value) ~= "boolean" and type(value) ~= "number" then
			table.insert(errors, "requirements." .. tostring(key) .. " must be a boolean or number")
		end
	end
end

local function validate_effect(effect, errors, index)
	if type(effect) ~= "table" then
		table.insert(errors, "effects[" .. index .. "] must be a table")
		return
	end

	if not is_non_empty_string(effect.type) then
		table.insert(errors, "effects[" .. index .. "].type must be a non-empty string")
	end
	if effect.stat ~= nil and not is_non_empty_string(effect.stat) then
		table.insert(errors, "effects[" .. index .. "].stat must be a non-empty string when provided")
	end
	if effect.formula ~= nil and type(effect.formula) ~= "string" then
		table.insert(errors, "effects[" .. index .. "].formula must be a string when provided")
	end
	if effect.damage_bonus ~= nil and type(effect.damage_bonus) ~= "number" then
		table.insert(errors, "effects[" .. index .. "].damage_bonus must be a number when provided")
	end
end

local function validate_execution(execution, errors)
	if type(execution) ~= "table" then
		table.insert(errors, "execution must be a table")
		return
	end

	if execution.aoe ~= nil and type(execution.aoe) ~= "table" then
		table.insert(errors, "execution.aoe must be a table when provided")
	end

	if type(execution.effects) ~= "table" then
		table.insert(errors, "execution.effects must be a table")
		return
	end

	for index, effect in ipairs(execution.effects) do
		validate_effect(effect, errors, index)
	end
end

function Action.validate(definition)
	local errors = {}

	if type(definition) ~= "table" then
		return false, { "action definition must be a table" }
	end

	if not is_non_empty_string(definition.action_id) then
		table.insert(errors, "action_id must be a non-empty string")
	end
	if not is_non_empty_string(definition.name) then
		table.insert(errors, "name must be a non-empty string")
	end
	if definition.description ~= nil and type(definition.description) ~= "string" then
		table.insert(errors, "description must be a string when provided")
	end

	if not is_number(definition.windup_ticks) then
		table.insert(errors, "windup_ticks must be a number")
	end
	if not is_number(definition.cooldown_ticks) then
		table.insert(errors, "cooldown_ticks must be a number")
	end

	validate_tags(definition.tags, errors)
	validate_targeting(definition.targeting, errors)
	validate_requirements(definition.requirements, errors)
	validate_execution(definition.execution, errors)

	return #errors == 0, errors
end

function Action.normalize(definition)
	return {
		action_id = definition.action_id,
		name = definition.name,
		description = definition.description or "",
		tags = definition.tags or {},
		windup_ticks = definition.windup_ticks,
		cooldown_ticks = definition.cooldown_ticks,
		targeting = {
			type = definition.targeting.type,
			range = definition.targeting.range,
		},
		requirements = definition.requirements or {},
		execution = {
			aoe = definition.execution.aoe,
			effects = definition.execution.effects,
		},
	}
end

function Action.new(definition)
	local ok, errors = Action.validate(definition)
	if not ok then
		return nil, errors
	end

	return Action.normalize(definition)
end

function Action.build_index(definitions)
	local index = {}
	local errors = {}

	if type(definitions) ~= "table" then
		return nil, { "definitions must be a table" }
	end

	for _, definition in ipairs(definitions) do
		local action, action_errors = Action.new(definition)
		if not action then
			for _, err in ipairs(action_errors) do
				table.insert(errors, err)
			end
		else
			if index[action.action_id] then
				table.insert(errors, "duplicate action id: " .. action.action_id)
			else
				index[action.action_id] = action
			end
		end
	end

	if #errors > 0 then
		return nil, errors
	end

	return index, nil
end

return Action
