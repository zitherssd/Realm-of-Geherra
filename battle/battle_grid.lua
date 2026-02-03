-- battle/battle_grid.lua
--
-- Grid + stacking helpers for battles.

local BattleGrid = {}

function BattleGrid.new(width, height, capacity)
	local grid = {
		width = width,
		height = height,
		capacity = capacity or 10,
		cells = {},
	}

	for y = 1, height do
		grid.cells[y] = {}
		for x = 1, width do
			grid.cells[y][x] = {
				units = {},
				size_used = 0,
			}
		end
	end

	return grid
end

function BattleGrid.in_bounds(grid, x, y)
	return x >= 1 and x <= grid.width and y >= 1 and y <= grid.height
end

function BattleGrid.get_cell(grid, x, y)
	if not BattleGrid.in_bounds(grid, x, y) then
		return nil
	end
	return grid.cells[y][x]
end

function BattleGrid.can_place(grid, x, y, unit_size)
	local cell = BattleGrid.get_cell(grid, x, y)
	if not cell then
		return false
	end

	return (cell.size_used + unit_size) <= grid.capacity
end

function BattleGrid.add_unit(grid, x, y, unit)
	local size = unit.size or 1
	if not BattleGrid.can_place(grid, x, y, size) then
		return false
	end

	local cell = BattleGrid.get_cell(grid, x, y)
	cell.size_used = cell.size_used + size
	table.insert(cell.units, unit)
	unit.position = { x = x, y = y }
	return true
end

function BattleGrid.remove_unit(grid, unit)
	if not unit.position then
		return
	end

	local cell = BattleGrid.get_cell(grid, unit.position.x, unit.position.y)
	if not cell then
		return
	end

	for index, existing in ipairs(cell.units) do
		if existing == unit then
			table.remove(cell.units, index)
			cell.size_used = cell.size_used - (unit.size or 1)
			break
		end
	end
end

function BattleGrid.move_unit(grid, unit, x, y)
	local size = unit.size or 1
	if not BattleGrid.can_place(grid, x, y, size) then
		return false
	end

	BattleGrid.remove_unit(grid, unit)
	return BattleGrid.add_unit(grid, x, y, unit)
end

return BattleGrid
