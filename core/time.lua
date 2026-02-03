-- core/time.lua
--
-- Defines the world time data structure and helpers.

local Time = {}
Time.__index = Time

local DEFAULT_SECONDS_PER_DAY = 18
local HOURS_PER_DAY = 24

local TIME_PERIODS = {
    { name = "Stilldark", start_hour = 0, end_hour = 3 },
    { name = "Lowlight", start_hour = 3, end_hour = 6 },
    { name = "Firstlight", start_hour = 6, end_hour = 9 },
    { name = "Highsun", start_hour = 9, end_hour = 12 },
    { name = "Suncrest", start_hour = 12, end_hour = 15 },
    { name = "Falling Sun", start_hour = 15, end_hour = 18 },
    { name = "Dusktide", start_hour = 18, end_hour = 21 },
    { name = "Gloamhour", start_hour = 21, end_hour = 24 },
}

function Time.new(seconds_per_day)
    local self = setmetatable({}, Time)
    self.seconds_per_day = seconds_per_day or DEFAULT_SECONDS_PER_DAY
    self.seconds_per_hour = self.seconds_per_day / HOURS_PER_DAY
    self.elapsed_seconds = 0
    return self
end

function Time:advance(seconds)
    if seconds <= 0 then
        return
    end
    self.elapsed_seconds = self.elapsed_seconds + seconds
end

function Time:advance_hours(hours)
    if hours <= 0 then
        return
    end
    self:advance(hours * self.seconds_per_hour)
end

function Time:get_day()
    return math.floor(self.elapsed_seconds / self.seconds_per_day) + 1
end

function Time:get_hour()
    local seconds_into_day = self.elapsed_seconds % self.seconds_per_day
    return (seconds_into_day / self.seconds_per_day) * HOURS_PER_DAY
end

function Time:get_period()
    local hour = self:get_hour()
    for _, period in ipairs(TIME_PERIODS) do
        if hour >= period.start_hour and hour < period.end_hour then
            return period
        end
    end
    return TIME_PERIODS[1]
end

function Time:get_period_label()
    return self:get_period().name
end

function Time:get_night_tint_alpha(max_alpha)
    local hour = self:get_hour()
    local peak = max_alpha or 0.6

    if hour >= 18 and hour < 21 then
        return peak * ((hour - 18) / 3)
    end

    if hour >= 21 or hour < 4 then
        return peak
    end

    if hour >= 4 and hour < 8 then
        return peak * (1 - ((hour - 4) / 4))
    end

    return 0
end

return Time
