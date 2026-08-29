-- core/input.lua
-- Abstracted input layer

local Input = {}

local keyState = {}
local mouseState = {}
local mouseX, mouseY = 0, 0

function Input.init()
    keyState = {}
    mouseState = {pressed = false, x = 0, y = 0}
end

function Input.update(dt)
    -- Update input states if needed
end

function Input.keypressed(key)
    keyState[key] = true
end

function Input.keyreleased(key)
    keyState[key] = nil
end

function Input.mousepressed(x, y, button)
    mouseState.pressed = true
    mouseState.button = button
    mouseState.x = x
    mouseState.y = y
end

function Input.mousereleased(x, y, button)
    mouseState.pressed = false
end

function Input.mousemoved(x, y, dx, dy)
    mouseX = x
    mouseY = y
    mouseState.x = x
    mouseState.y = y
end

function Input.wheelmoved(x, y)
    mouseState.wheelX = x
    mouseState.wheelY = y
end

function Input.isKeyDown(key)
    return keyState[key] or false
end

function Input.getMousePosition()
    return mouseX, mouseY
end

function Input.isMousePressed()
    return mouseState.pressed
end

function Input.getMouseState()
    return mouseState
end

return Input
