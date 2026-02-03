-- systems/stat_system.lua
--
-- Aggregates effective stats from base stats and modifiers.

local StatSystem = {}

local function copy_stats(stats)
	local result = {}
	for key, value in pairs(stats or {}) do
		result[key] = value
	end
	return result
end

local function apply_modifiers(stats, modifiers)
	if type(modifiers) ~= "table" then
		return
	end

	for key, value in pairs(modifiers) do
		if type(value) == "number" then
			stats[key] = (stats[key] or 0) + value
		end
	end
end

function StatSystem.aggregate(base_stats, item_list, status_effects)
	local effective = copy_stats(base_stats)

	if type(item_list) == "table" then
		for _, item in ipairs(item_list) do
			apply_modifiers(effective, item.stat_modifiers)
		end
	end

	if type(status_effects) == "table" then
		for _, effect in ipairs(status_effects) do
			apply_modifiers(effective, effect.stat_modifiers)
		end
	end

	return effective
end

return StatSystem
