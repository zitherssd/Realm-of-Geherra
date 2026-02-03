-- battle/battle_camera.lua
--
-- Camera helpers for battle scene.

local Math = require("util.math")

local BattleCamera = {}

function BattleCamera.new()
	return {
		x = 0,
		y = 0,
	}
end

function BattleCamera.update(camera, target_x, target_y, map_width, map_height, cell_size, dt)
	local map_px_w = map_width * cell_size
	local map_px_h = map_height * cell_size

	local desired_x = target_x
	local desired_y = target_y

	local speed = math.min(dt * 6, 1)
	camera.x = Math.lerp(camera.x, desired_x, speed)
	camera.y = Math.lerp(camera.y, desired_y, speed)

	local half_w = love.graphics.getWidth() * 0.5
	local half_h = love.graphics.getHeight() * 0.5

	camera.x = Math.clamp(camera.x, half_w, math.max(half_w, map_px_w - half_w))
	camera.y = Math.clamp(camera.y, half_h, math.max(half_h, map_px_h - half_h))
end

function BattleCamera.world_to_screen(camera, world_x, world_y)
	local screen_w = love.graphics.getWidth()
	local screen_h = love.graphics.getHeight()
	local screen_x = (world_x - camera.x) + screen_w * 0.5
	local screen_y = (world_y - camera.y) + screen_h * 0.5
	return screen_x, screen_y
end

return BattleCamera
