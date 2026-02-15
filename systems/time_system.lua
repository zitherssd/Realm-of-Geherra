-- systems/time_system.lua
-- Manages game time, day/night cycles, and time periods.

local TimeSystem = {}

local GameContext = require("game.game_context")

-- Configuration
local SECONDS_PER_DAY = 18 -- Real-time seconds for one game day
local HOURS_PER_SECOND = 24 / SECONDS_PER_DAY

-- Time Periods
local TIME_PERIODS = {
    {name = "Lowlight",    start = 3,  finish = 6},
    {name = "Firstlight",  start = 6,  finish = 9},
    {name = "Highsun",     start = 9,  finish = 12},
    {name = "Suncrest",    start = 12, finish = 15},
    {name = "Falling Sun", start = 15, finish = 18},
    {name = "Dusktide",    start = 18, finish = 21},
    {name = "Gloamhour",   start = 21, finish = 24},
    {name = "Stilldark",   start = 0,  finish = 3},
}

-- System State (Transient)
local accumulator = 0
local paused = false

-- Helper to access time data safely
local function getTimeData()
    if not GameContext.data then
        GameContext.data = {}
    end
    if not GameContext.data.time then
        GameContext.data.time = {
            day = 1,
            hour = 6 -- Start at 6AM
        }
    end
    return GameContext.data.time
end

function TimeSystem.update(dt)
    if paused then return end

    local timeData = getTimeData()

    accumulator = accumulator + (dt * HOURS_PER_SECOND)

    -- Update in 1-minute increments (1/60th of an hour)
    local step = 1/60
    while accumulator >= step do
        timeData.hour = timeData.hour + step
        accumulator = accumulator - step

        if timeData.hour >= 24 then
            timeData.hour = timeData.hour - 24
            timeData.day = timeData.day + 1
            -- TODO: Emit 'NewDay' event here via EventBus if needed
        end
    end
end

function TimeSystem.getPeriodName()
    local h = getTimeData().hour
    for _, period in ipairs(TIME_PERIODS) do
        if period.start < period.finish then
            if h >= period.start and h < period.finish then
                return period.name
            end
        else -- Wraps around midnight (e.g., 21 to 3)
            if h >= period.start or h < period.finish then
                return period.name
            end
        end
    end
    return "Unknown"
end

function TimeSystem.getHour()
    return getTimeData().hour
end

function TimeSystem.getDay()
    return getTimeData().day
end

function TimeSystem.setPaused(isPaused)
    paused = isPaused and true or false
end

function TimeSystem.getTimeStatus()
    return paused and "PAUSED" or "RUNNING"
end

function TimeSystem.isNightTime()
    local h = getTimeData().hour
    return h >= 20 or h < 7
end

function TimeSystem.getNightTint()
    local h = getTimeData().hour
    -- Full sun from 8:00 to 18:00
    -- Fade in 18:00-21:00, full 21:00-4:00, fade out 4:00-8:00
    
    local alpha = 0
    if h >= 18 or h < 8 then
        if h >= 18 and h < 21 then
            alpha = (h - 18) / 3 * 0.5 -- Fade in to 0.5
        elseif (h >= 21 and h < 24) or (h >= 0 and h < 4) then
            alpha = 0.5 -- Full night
        elseif h >= 4 and h < 8 then
            alpha = (8 - h) / 4 * 0.5 -- Fade out
        end
        -- Return a dark blueish tint with calculated alpha
        return 0.05, 0.08, 0.15, alpha
    end
    
    -- No tint during the day
    return 0, 0, 0, 0
end

return TimeSystem