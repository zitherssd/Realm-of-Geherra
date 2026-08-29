-- debug/profiler.lua
-- Performance profiler

local Profiler = {}

Profiler.enabled = false
Profiler.measurements = {}

function Profiler.startMeasure(name)
    Profiler.measurements[name] = {
        startTime = love.timer.getTime(),
        duration = 0
    }
end

function Profiler.endMeasure(name)
    if Profiler.measurements[name] then
        local endTime = love.timer.getTime()
        Profiler.measurements[name].duration = 
            endTime - Profiler.measurements[name].startTime
    end
end

function Profiler.getMeasurement(name)
    if Profiler.measurements[name] then
        return Profiler.measurements[name].duration
    end
    return 0
end

function Profiler.draw()
    if not Profiler.enabled then return end
    
    love.graphics.setColor(1, 1, 1)
    local y = 10
    for name, data in pairs(Profiler.measurements) do
        love.graphics.print(name .. ": " .. 
            string.format("%.2f", data.duration * 1000) .. "ms", 10, y)
        y = y + 20
    end
end

return Profiler
