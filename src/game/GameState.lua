local GameState = {}

GameState.stack = {}

function GameState:push(newState, ...)
  local instance
  if type(newState) == "table" and newState.new then
    -- If it's a class with a new method, create an instance
    instance = newState:new()
  else
    -- If it's already an instance, use it directly
    instance = newState
  end
  table.insert(self.stack, instance)
  if instance.enter then instance:enter(...) end
end

function GameState:pop()
  table.remove(self.stack)
  local top = self:top()
  if top and top.enter then top:enter() end
end

function GameState:top()
  return self.stack[#self.stack]
end

function GameState:update(dt)
  local top = self:top()
  if top and top.update then top:update(dt) end
end

function GameState:draw()
  local top = self:top()
  if top and top.draw then top:draw() end
end

function GameState:keypressed(key)
  local top = self:top()
  if top and top.keypressed then top:keypressed(key) end
end

function GameState:mousepressed(x, y, button)
  local top = self:top()
  if top and top.mousepressed then top:mousepressed(x, y, button) end
end

function GameState:mousereleased(x, y, button)
  local top = self:top()
  if top and top.mousereleased then top:mousereleased(x, y, button) end
end

return GameState 