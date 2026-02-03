-- scenes/title_scene.lua
--
-- Manages the title screen scene.

local WorldScene = require("scenes.world_scene")

local TitleScene = {}
TitleScene.__index = TitleScene

function TitleScene.new(game)
	local self = setmetatable({}, TitleScene)
	self.game = game
	return self
end

function TitleScene:update(dt)
end

function TitleScene:draw()
	love.graphics.clear(0.07, 0.08, 0.12)

	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()

	love.graphics.setColor(1, 1, 1)
	love.graphics.printf("Realms of Geherra", 0, height * 0.38, width, "center")
	love.graphics.setColor(0.8, 0.8, 0.85)
	love.graphics.printf("Press Enter to Begin", 0, height * 0.52, width, "center")
end

function TitleScene:keypressed(key)
	if key == "return" or key == "enter" then
		self.game:change_scene(WorldScene.new(self.game))
	elseif key == "escape" then
		love.event.quit()
	end
end

return TitleScene
