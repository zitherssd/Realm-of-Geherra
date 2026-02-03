-- battle/battle_ai.lua
--
-- Minimal battle AI behavior.

local BattleActions = require("battle.battle_actions")

local BattleAI = {}

local function manhattan(a, b)
	return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

local function nearest_enemy(state, unit)
	local best = nil
	local best_dist = math.huge
	for _, other in ipairs(state.units) do
		if other.team ~= unit.team and (other.current_hp or 0) > 0 then
			local dist = manhattan(unit.position, other.position)
			if dist < best_dist then
				best = other
				best_dist = dist
			end
		end
	end
	return best, best_dist
end

function BattleAI.update(state)
	for _, unit in ipairs(state.units) do
		if unit.team ~= "player" and (unit.current_hp or 0) > 0 then
			if (unit.cooldown or 0) <= 0 and not BattleActions.has_pending_action(state, unit) then
				local enemy = nearest_enemy(state, unit)
				if enemy then
					local action_ids = BattleActions.unit_actions(unit)
					local chosen_action = nil
					for _, action_id in ipairs(action_ids) do
						local action = BattleActions.get_action(action_id)
						if action and action.targeting.type == "unit" and BattleActions.validate_target(state, action, unit, enemy) then
							chosen_action = action
							break
						end
					end

					if chosen_action then
						BattleActions.queue_action(state, unit, chosen_action, enemy)
					else
						local move_action = BattleActions.get_action("move_step")
						local step = { x = unit.position.x, y = unit.position.y }
						if enemy.position.x > unit.position.x then
							step.x = step.x + 1
						elseif enemy.position.x < unit.position.x then
							step.x = step.x - 1
						end
						if enemy.position.y > unit.position.y then
							step.y = step.y + 1
						elseif enemy.position.y < unit.position.y then
							step.y = step.y - 1
						end
						if move_action and BattleActions.validate_target(state, move_action, unit, step) then
							BattleActions.queue_action(state, unit, move_action, step)
						end
					end
				end
			end
		end
	end
end

return BattleAI
