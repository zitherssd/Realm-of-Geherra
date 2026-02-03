-- battle/battle_rules.lua
--
-- Defines the rules for battle resolution.

local Math = require("util.math")

local BattleRules = {}

local function clamp_percent(value)
	return Math.clamp(value, 5, 95)
end

function BattleRules.hit_chance(attacker_stats, defender_stats)
	local attack = attacker_stats.attack or 0
	local defense = defender_stats.defense or 0

	if defense <= 0 then
		return 0.95
	end

	local ratio = attack / defense
	local percent = 50 + (ratio - 1) * 35
	percent = clamp_percent(percent)
	return percent / 100
end

function BattleRules.roll_hit(attacker_stats, defender_stats)
	local chance = BattleRules.hit_chance(attacker_stats, defender_stats)
	return love.math.random() <= chance
end

local function action_damage_bonus(action)
	if not action or not action.execution or type(action.execution.effects) ~= "table" then
		return 0
	end

	for _, effect in ipairs(action.execution.effects) do
		if effect.type == "damage" then
			return effect.damage_bonus or 0
		end
	end

	return 0
end

function BattleRules.compute_damage(attacker_stats, defender_stats, action)
	local strength = attacker_stats.strength or 0
	local protection = defender_stats.protection or 0
	local bonus = action_damage_bonus(action)
	local effective_strength = strength + bonus

	local denominator = effective_strength - protection
	if denominator <= 0 then
		denominator = 1
	end

	local multiplier = effective_strength / denominator
	local base_damage = effective_strength * multiplier

	local variance = (love.math.random() * 0.4) - 0.2
	local damage = base_damage * (1 + variance)
	local rounded = math.floor(damage + 0.5)

	if rounded < 1 then
		rounded = 1
	end

	return rounded
end

return BattleRules
