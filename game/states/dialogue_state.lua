-- game/states/dialogue_state.lua
-- Dialogue interaction state

local DialogueState = {}

function DialogueState.enter()
    -- Initialize dialogue
end

function DialogueState.exit()
    -- Cleanup dialogue state
end

function DialogueState.update(dt)
    -- Update dialogue logic
end

function DialogueState.draw()
    love.graphics.clear(0.2, 0.2, 0.3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Dialogue State", 10, 10)
end

return DialogueState
