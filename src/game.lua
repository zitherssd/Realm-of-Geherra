-- src/game.lua
--
-- Core game loop and scene management.

local TitleScene = require("scenes.title_scene")

local Game = {
    current_scene = nil,
}

function Game:init()
    self:change_scene(TitleScene.new(self))
end

function Game:change_scene(scene)
    self.current_scene = scene
end

function Game:update(dt)
    if self.current_scene and self.current_scene.update then
        self.current_scene:update(dt)
    end
end

function Game:draw()
    if self.current_scene and self.current_scene.draw then
        self.current_scene:draw()
    end
end

function Game:keypressed(key)
    if self.current_scene and self.current_scene.keypressed then
        self.current_scene:keypressed(key)
    end
end

function Game:mousepressed(x, y, button)
    if self.current_scene and self.current_scene.mousepressed then
        self.current_scene:mousepressed(x, y, button)
    end
end

function Game:mousereleased(x, y, button)
    if self.current_scene and self.current_scene.mousereleased then
        self.current_scene:mousereleased(x, y, button)
    end
end

return Game
