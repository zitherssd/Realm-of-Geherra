local TimeSystem = {}

-- Config
local SECONDS_PER_DAY = 30 -- 30 seconds per game day

-- State
TimeSystem.day = 1
TimeSystem.hour = 6 -- Start at 6AM (Morning)
TimeSystem._accum = 0
TimeSystem._paused = false

local timePeriods = {
  {name = "Lowlight",        start = 3,  finish = 6},
  {name = "Firstlight",     start = 6,  finish = 9},
  {name = "Highsun",start = 9,  finish = 12},
  {name = "Suncrest",        start = 12, finish = 15},
  {name = "Falling Sun",   start = 15, finish = 18},
  {name = "Dusktide",     start = 18, finish = 21},
  {name = "Gloamhour",       start = 21, finish = 24},
  {name = "Stilldark",    start = 0,  finish = 3},
}

function TimeSystem:update(dt)
  if self._paused then return end
  -- Advance time by dt, scaled to game day length
  local hoursPerSecond = 24 / SECONDS_PER_DAY
  self._accum = self._accum + dt * hoursPerSecond
  while self._accum >= 1/60 do -- update in 1-minute increments
    self.hour = self.hour + 1/60
    self._accum = self._accum - 1/60
    if self.hour >= 24 then
      self.hour = self.hour - 24
      self.day = self.day + 1
    end
  end
end

function TimeSystem:getPeriodName()
  local h = self.hour
  for _, period in ipairs(timePeriods) do
    if period.start < period.finish then
      if h >= period.start and h < period.finish then return period.name end
    else -- midnight wraps
      if h >= period.start or h < period.finish then return period.name end
    end
  end
  return "Unknown"
end

function TimeSystem:getHour()
  return self.hour
end

function TimeSystem:getDay()
  return self.day
end

function TimeSystem:setPaused(paused)
  self._paused = paused and true or false
end

function TimeSystem:getTimeStatus()
  return self._paused and "PAUSED" or "RUNNING"
end

function TimeSystem:getNightTint()
  local h = self.hour
  -- Full sun from 8:00 to 18:00
  -- Fade in 18:00-21:00, full 21:00-4:00, fade out 4:00-8:00
  local alpha = 0
  if h >= 18 or h < 8 then
    if h >= 18 and h < 21 then
      alpha = (h - 18) / 3 * 0.5 -- fade in to 0.5
    elseif (h >= 21 and h < 24) or (h >= 0 and h < 4) then
      alpha = 0.5 -- full night
    elseif h >= 4 and h < 8 then
      alpha = (8 - h) / 4 * 0.5 -- fade out
    end
    return 0.2, 0.3, 0.7, alpha
  end
  return 0, 0, 0, 0
end

function TimeSystem:isNightTime()
  local h = self.hour
  return h >= 20 or h < 7
end

return TimeSystem 