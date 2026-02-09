-- core/time.lua
-- Time scaling & pausing

local Time = {}

local timeScale = 1.0
local isPaused = false

function Time.setPaused(paused)
    isPaused = paused
end

function Time.isPaused()
    return isPaused
end

function Time.setTimeScale(scale)
    timeScale = math.max(0, scale)
end

function Time.getTimeScale()
    return timeScale
end

function Time.update(dt)
    if isPaused then
        return 0
    end
    return dt * timeScale
end

return Time
