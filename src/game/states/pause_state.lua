-- game/states/pause_state.lua
-- Pause menu state

local PauseState = {}

function PauseState.enter()
    -- Initialize pause menu
end

function PauseState.exit()
    -- Cleanup pause menu
end

function PauseState.update(dt)
    -- Update pause logic
end

function PauseState.draw()
    love.graphics.clear(0, 0, 0, 0.7)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("PAUSED", 0, 384, 1024, "center")
end

return PauseState
