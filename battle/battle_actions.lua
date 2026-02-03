-- battle/battle_actions.lua
--
-- Action helpers and resolution pipeline.

local BattleRules = require("battle.battle_rules")
local BattleGrid = require("battle.battle_grid")
local StatSystem = require("systems.stat_system")
local ActionData = require("data.actions")

local BattleActions = {}

local function manhattan(a, b)
	return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

local function action_in_range(action, attacker, target)
	if action.targeting.type == "self" then
		return true
	end
	if action.targeting.type == "unit" or action.targeting.type == "cell" then
		return manhattan(attacker.position, target) <= action.targeting.range
	end
	return false
end

function BattleActions.get_action(action_id)
	return ActionData.by_id[action_id]
end

function BattleActions.unit_actions(unit)
	local actions = { "move_step" }
	for _, action_id in ipairs(unit.actions or {}) do
		table.insert(actions, action_id)
	end
	return actions
end

function BattleActions.has_pending_action(state, unit)
	for _, pending in ipairs(state.pending_actions) do
		if pending.unit == unit then
			return true
		end
	end
	return false
end

function BattleActions.find_unit_at(state, x, y)
	for _, unit in ipairs(state.units) do
		if unit.position.x == x and unit.position.y == y then
			return unit
		end
	end
	return nil
end

function BattleActions.can_target_unit(attacker, target)
	return attacker.team ~= target.team
end

function BattleActions.validate_target(state, action, attacker, target)
	if action.targeting.type == "self" then
		return true
	end

	if action.targeting.type == "unit" then
		if not target or not BattleActions.can_target_unit(attacker, target) then
			return false
		end
		return action_in_range(action, attacker, target.position)
	end

	if action.targeting.type == "cell" then
		return BattleGrid.in_bounds(state.grid, target.x, target.y) and action_in_range(action, attacker, target)
	end

	return false
end

function BattleActions.queue_action(state, unit, action, target)
	local execute_tick = state.tick + (action.windup_ticks or 0)
	table.insert(state.pending_actions, {
		unit = unit,
		action = action,
		target = target,
		execute_tick = execute_tick,
	})
	unit.cooldown = action.cooldown_ticks or 0
end

function BattleActions.execute_pending(state)
	local remaining = {}
	for _, pending in ipairs(state.pending_actions) do
		if pending.execute_tick <= state.tick then
			BattleActions.resolve_action(state, pending.unit, pending.action, pending.target)
		else
			table.insert(remaining, pending)
		end
	end
	state.pending_actions = remaining
end

function BattleActions.resolve_action(state, attacker, action, target)
	for _, effect in ipairs(action.execution.effects or {}) do
		if effect.type == "move" then
			BattleGrid.move_unit(state.grid, attacker, target.x, target.y)
		elseif effect.type == "damage" then
			if not target then
				return
			end
			local attacker_stats = StatSystem.aggregate(attacker.base_stats, attacker.items, attacker.status_effects)
			local target_stats = StatSystem.aggregate(target.base_stats, target.items, target.status_effects)
			if BattleRules.roll_hit(attacker_stats, target_stats) then
				local damage = BattleRules.compute_damage(attacker_stats, target_stats, action)
				target.current_hp = math.max(0, (target.current_hp or 0) - damage)
			end
		end
	end
end

return BattleActions
