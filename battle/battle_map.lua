-- battle/battle_map.lua
--
-- Defines the battle map data structure.

local BattleGrid = require("battle.battle_grid")

local BattleMap = {}

function BattleMap.new(width, height, cell_size)
	local map = {
		width = width,
		height = height,
		cell_size = cell_size,
		grid = BattleGrid.new(width, height, 10),
	}

	return map
end

return BattleMap
