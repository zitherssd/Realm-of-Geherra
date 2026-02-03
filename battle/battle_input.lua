-- battle/battle_input.lua
--
-- Input helpers for battle scene.

local BattleGrid = require("battle.battle_grid")
local BattleActions = require("battle.battle_actions")

local BattleInput = {}

function BattleInput.move_player(state, unit, dx, dy)
	local action = BattleActions.get_action("move_step")
	if not action then
		return false
	end

	local target = { x = unit.position.x + dx, y = unit.position.y + dy }
	if not BattleActions.validate_target(state, action, unit, target) then
		return false
	end

	if not BattleGrid.can_place(state.grid, target.x, target.y, unit.size or 1) then
		return false
	end

	BattleActions.queue_action(state, unit, action, target)
	return true
end

return BattleInput
