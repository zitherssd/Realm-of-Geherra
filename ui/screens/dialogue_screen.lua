-- ui/screens/dialogue_screen.lua
-- Dialogue interaction screen

local DialogueScreen = {}

function DialogueScreen.show()
    -- Initialize dialogue
end

function DialogueScreen.hide()
    -- Cleanup
end

function DialogueScreen.update(dt)
    -- Update dialogue
end

function DialogueScreen.draw()
    love.graphics.clear(0.05, 0.05, 0.1)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Dialogue", 0, height - 100, width, "left")
end

return DialogueScreen
