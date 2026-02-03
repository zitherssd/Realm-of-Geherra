-- battle/battle_system.lua
--
-- System for managing the battle logic.

local BattleMap = require("battle.battle_map")
local BattleState = require("battle.battle_state")
local BattleGrid = require("battle.battle_grid")

local BattleSystem = {}

local DEFAULT_WIDTH = 30
local DEFAULT_HEIGHT = 13
local DEFAULT_CELL_SIZE = 42

function BattleSystem.create_state(config)
	local map = BattleMap.new(config.width or DEFAULT_WIDTH, config.height or DEFAULT_HEIGHT, config.cell_size or DEFAULT_CELL_SIZE)
	return BattleState.new({
		width = map.width,
		height = map.height,
		cell_size = map.cell_size,
		grid = map.grid,
		units = config.units or {},
		player_unit_id = config.player_unit_id,
		parties = config.parties or {},
		stage = config.stage,
		deployment = config.deployment or {},
	})
end

function BattleSystem.update_ticks(state, ticks)
	state.tick = state.tick + (ticks or 1)
end

function BattleSystem.place_unit(grid, unit, x, y)
	return BattleGrid.add_unit(grid, x, y, unit)
end

return BattleSystem
