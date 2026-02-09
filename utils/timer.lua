-- utils/timer.lua
-- Timer utility

local Timer = {}

function Timer.new(duration, callback, repeat_)
    local self = {
        duration = duration,
        elapsed = 0,
        callback = callback,
        repeat_ = repeat_ or false,
        finished = false
    }
    return self
end

function Timer:update(dt)
    if self.finished then return end
    
    self.elapsed = self.elapsed + dt
    
    if self.elapsed >= self.duration then
        if self.callback then
            self.callback()
        end
        
        if self.repeat_ then
            self.elapsed = 0
        else
            self.finished = true
        end
    end
end

function Timer:isFinished()
    return self.finished
end

function Timer:reset()
    self.elapsed = 0
    self.finished = false
end

return Timer
