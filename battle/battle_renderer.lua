-- battle/battle_renderer.lua
--
-- Rendering helpers for battle scene.

local BattleCamera = require("battle.battle_camera")

local BattleRenderer = {}

local function cell_center(cell_size, x, y)
	return (x - 0.5) * cell_size, (y - 0.5) * cell_size
end

function BattleRenderer.draw_grid(state, camera)
	local cell_size = state.cell_size
	local width = state.width
	local height = state.height

	love.graphics.setColor(0.2, 0.2, 0.25)
	for y = 0, height do
		local wy = y * cell_size
		local sx1, sy1 = BattleCamera.world_to_screen(camera, 0, wy)
		local sx2, sy2 = BattleCamera.world_to_screen(camera, width * cell_size, wy)
		love.graphics.line(sx1, sy1, sx2, sy2)
	end
	for x = 0, width do
		local wx = x * cell_size
		local sx1, sy1 = BattleCamera.world_to_screen(camera, wx, 0)
		local sx2, sy2 = BattleCamera.world_to_screen(camera, wx, height * cell_size)
		love.graphics.line(sx1, sy1, sx2, sy2)
	end
end

function BattleRenderer.draw_units(state, camera)
	local units = {}
	for _, unit in ipairs(state.units) do
		table.insert(units, unit)
	end
	
	table.sort(units, function(a, b)
		if a.position.y == b.position.y then
			return a.position.x < b.position.x
		end
		return a.position.y < b.position.y
	end)

	for _, unit in ipairs(units) do
		local wx, wy = cell_center(state.cell_size, unit.position.x, unit.position.y)
		local sx, sy = BattleCamera.world_to_screen(camera, wx, wy)
		local radius = (state.cell_size * 0.25) + (unit.size or 1)
		if unit.team == "player" then
			love.graphics.setColor(0.9, 0.85, 0.25)
		else
			love.graphics.setColor(0.8, 0.35, 0.35)
		end
		love.graphics.circle("fill", sx, sy, radius)
		love.graphics.setColor(0, 0, 0, 0.6)
		love.graphics.circle("line", sx, sy, radius)
	end
end

function BattleRenderer.draw_target_cursor(state, camera, cursor)
	if not cursor then
		return
	end

	local wx, wy = cell_center(state.cell_size, cursor.x, cursor.y)
	local sx, sy = BattleCamera.world_to_screen(camera, wx, wy)
	local half = state.cell_size * 0.5

	love.graphics.setColor(1, 1, 1)
	love.graphics.rectangle("line", sx - half, sy - half, state.cell_size, state.cell_size)
end

return BattleRenderer
