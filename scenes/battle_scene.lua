-- scenes/battle_scene.lua
--
-- Manages the tactical battle scene.

local BattleScene = {}
BattleScene.__index = BattleScene

function BattleScene.new(game, return_scene)
	local self = setmetatable({}, BattleScene)
	self.game = game
	self.return_scene = return_scene
	return self
end

function BattleScene:update(dt)
end

function BattleScene:draw()
	love.graphics.clear(0.08, 0.06, 0.08)

	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()

	love.graphics.setColor(1, 1, 1)
	love.graphics.printf("Battle Scene (placeholder)", 0, height * 0.42, width, "center")
	love.graphics.setColor(0.8, 0.8, 0.85)
	love.graphics.printf("Press Esc to return to the world", 0, height * 0.52, width, "center")
end

function BattleScene:keypressed(key)
	if key == "escape" then
		if self.return_scene then
			self.game:change_scene(self.return_scene)
		end
	end
end

return BattleScene
